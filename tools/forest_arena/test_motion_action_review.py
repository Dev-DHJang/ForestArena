"""Review integrity regressions; these tests do not judge artwork semantics."""
import tempfile
import json
import unittest
from pathlib import Path

from PIL import Image, UnidentifiedImageError
from motion_layout import motion_id

from review_motion_actions import CHECKS, compact, prepare, read, sha, timeline_errors, validate, write


class MotionActionReviewTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for path in ("assets/character", "docs/contracts", "docs/gameplay", "scripts", "tools/forest_arena"):
            (self.root / path).mkdir(parents=True)
        self.sheet = self.root / "assets/character/run.png"
        Image.new("RGBA", (2048, 128), (32, 80, 10, 128)).save(self.sheet)
        self.sprite = self.root / "assets/character/run.tres"
        self.sprite.write_text("fixture SpriteFrames")
        self.manifest = self.root / "assets/character/manifest.json"
        write(self.manifest, {"assets": [{"type": "animation-runtime", "character_id": "test", "path": "assets/character/run.png", "visual_state_id": "run", "sprite_frames_path": "res://assets/character/run.tres"}]})
        write(self.root / "docs/contracts/attack-system-v01.json", {"characters": []})
        (self.root / "docs/gameplay/combat.md").write_text("달리기는 발을 교대한다")
        (self.root / "scripts/local_fighter_presentation.gd").write_text("fixture presentation")
        (self.root / "scripts/fighter_controller.gd").write_text("fixture fighter")
        (self.root / "tools/forest_arena/motion_layout.py").write_text("fixture tooling: motion_layout.py")
        timeline_sources = {p: sha(self.root / p) for p in ["assets/character/manifest.json", "assets/character/run.tres", "scripts/local_fighter_presentation.gd", "scripts/fighter_controller.gd", "docs/contracts/attack-system-v01.json", "docs/gameplay/combat.md", "tools/forest_arena/motion_layout.py"]}
        self.timeline = self.root / "timeline.json"
        write(self.timeline, {"schema_version": 1, "errors": [], "sources": timeline_sources, "motions": [{"required_variant_ids": ["state:run"], "character_id": "test", "motion": "run", "sheet_sha256": sha(self.sheet), "variants": [{"attack_id": "state:run", "samples": [{"frame": (i // 5) % 16, "shown": "run", "phase": "run", "duration_ms": 1000 / 60} for i in range(120)]}]}]})
        self.output = self.root / "review"
        prepare(self.root, self.timeline, self.output)
        self.review_path = self.output / "motion-review.json"
        self.review = read(self.review_path)
        self.review["reviewer"] = "independent fixture reviewer"

    def save_and_validate(self):
        write(self.review_path, self.review)
        return validate(self.root, self.review_path)

    def valid_pass(self):
        row = self.review["motions"][0]
        row.update(status="pass", observations="좌우 발의 지지와 공중 회수가 번갈아 반복된다", checks=dict.fromkeys(CHECKS, True))
        return row

    def test_prepare_never_claims_semantic_pass(self):
        row = self.review["motions"][0]
        self.assertEqual(row["status"], "blocked")
        self.assertFalse(any(row["checks"].values()))
        self.assertTrue((self.output / "index.html").is_file())
        self.assertEqual(self.save_and_validate(), [])

    def test_complete_observed_pass_record(self):
        self.valid_pass()
        self.assertEqual(self.save_and_validate(), [])

    def test_approval_mode_rejects_nonpass_decisions(self):
        write(self.review_path, self.review)
        self.assertTrue(any("not all pass" in e for e in validate(self.root, self.review_path, require_pass=True)))
        self.valid_pass()
        write(self.review_path, self.review)
        self.assertEqual(validate(self.root, self.review_path, require_pass=True), [])

    def test_valid_shape_can_still_be_action_failure(self):
        row = self.valid_pass()
        row.update(status="fix", observations="형식은 정상이나 1~16프레임의 두 다리가 같은 위치를 유지한다", issues=[{"frames": list(range(1, 17)), "reason": "발 교대 없이 정지 자세만 반복", "required_change": "좌우 발 지지와 회수를 교대로 표현"}])
        self.assertEqual(self.save_and_validate(), [])
        self.assertEqual(read(self.review_path)["motions"][0]["status"], "fix")

    def test_pass_requires_observation_and_all_inspections(self):
        row = self.valid_pass()
        row["observations"] = " "
        row["checks"]["runtime_timing"] = False
        failures = self.save_and_validate()
        self.assertTrue(any("observations" in e for e in failures))
        self.assertTrue(any("incomplete" in e for e in failures))

    def test_changed_png_invalidates_prior_review(self):
        self.valid_pass()
        Image.new("RGBA", (2048, 128), "red").save(self.sheet)
        self.assertTrue(any("asset changed" in e for e in self.save_and_validate()))

    def test_changed_spriteframes_invalidates_review(self):
        self.sprite.write_text("different frame order")
        self.assertTrue(any("asset changed" in e for e in self.save_and_validate()))

    def test_missing_and_duplicate_reviews_are_rejected(self):
        self.review["motions"] *= 2
        self.assertTrue(any("duplicate" in e for e in self.save_and_validate()))
        self.review["motions"] = []
        self.assertTrue(any("missing" in e for e in self.save_and_validate()))

    def test_review_material_change_is_rejected(self):
        material = next(iter(self.review["motions"][0]["materials"]))
        (self.output / material).write_bytes(b"changed board")
        self.assertTrue(any("evidence changed" in e for e in self.save_and_validate()))

    def test_fix_requires_actionable_frame_issue(self):
        row = self.valid_pass()
        row.update(status="fix", issues=[{"reason": "wrong action"}])
        self.assertTrue(any("frame/time" in e for e in self.save_and_validate()))

    def test_changed_runtime_sequence_is_rejected(self):
        self.review["motions"][0]["runtime_variants"][0]["sequence"][0][0] = 15
        self.assertTrue(any("runtime sequence differs" in e for e in self.save_and_validate()))

    def test_changed_timeline_is_rejected(self):
        self.output.joinpath("timeline.json").write_text("{}")
        self.assertTrue(any("timeline changed" in e for e in self.save_and_validate()))

    def test_timeline_rejects_wrong_motion_and_invalid_frame(self):
        timeline = read(self.timeline)
        sample = timeline["motions"][0]["variants"][0]["samples"][0]
        sample.update(shown="jump", frame=16)
        self.assertTrue(any("invalid runtime" in e for e in timeline_errors(self.root, timeline, read(self.manifest)["assets"])))

    def test_timeline_frame_bound_follows_declared_24_count(self):
        timeline=read(self.timeline)
        rows=read(self.manifest)["assets"]
        rows[0]["frame_count"]=24
        samples=timeline["motions"][0]["variants"][0]["samples"]
        samples[-1]["frame"]=23
        self.assertEqual(timeline_errors(self.root,timeline,rows),[])
        samples[-1]["frame"]=24
        self.assertTrue(any("invalid runtime sample" in e for e in timeline_errors(self.root,timeline,rows)))

    def test_loop_capture_length_includes_authored_duration_weights(self):
        timeline=read(self.timeline)
        rows=read(self.manifest)["assets"]
        rows[0].update(frame_count=24,fps=24,loop=True,frame_durations=[1.0]*23+[2.0])
        samples=timeline["motions"][0]["variants"][0]["samples"]
        self.assertTrue(any("incomplete runtime phases" in e for e in timeline_errors(self.root,timeline,rows)))
        samples.extend([dict(samples[0]) for _ in range(6)])
        self.assertEqual(timeline_errors(self.root,timeline,rows),[])

    def test_timeline_rejects_missing_motion_and_changed_source(self):
        timeline = read(self.timeline)
        timeline["motions"] = []
        self.manifest.write_text("changed")
        failures = timeline_errors(self.root, timeline, [])
        self.assertTrue(any("source changed" in e for e in failures))

    def test_action_source_change_invalidates_prior_pass(self):
        self.valid_pass()
        (self.root / "docs/gameplay/combat.md").write_text("different action definition")
        self.assertTrue(any("action source changed" in e for e in self.save_and_validate()))

    def test_timeline_rejects_truncated_and_malformed_phases(self):
        timeline = read(self.timeline)
        samples = timeline["motions"][0]["variants"][0]["samples"]
        samples[:] = samples[:1]
        samples[0].update(phase="garbage-phase", duration_ms=1)
        failures = timeline_errors(self.root, timeline, read(self.manifest)["assets"])
        self.assertTrue(any("incomplete runtime" in e for e in failures))
        self.assertTrue(any("invalid runtime" in e for e in failures))

    def test_spriteframes_change_between_export_and_prepare_is_rejected(self):
        self.sprite.write_text("changed after timeline export")
        with self.assertRaisesRegex(ValueError, "timeline source changed"):
            prepare(self.root, self.timeline, self.root / "second-review")

    def test_timeline_requires_spriteframes_fingerprint(self):
        timeline = read(self.timeline)
        del timeline["sources"]["assets/character/run.tres"]
        self.assertTrue(any("SpriteFrames fingerprints" in e for e in timeline_errors(self.root, timeline, read(self.manifest)["assets"])))

    def test_timeline_rejects_reordered_attack_phases(self):
        timeline = read(self.timeline)
        variant = timeline["motions"][0]["variants"][0]
        variant["attack_id"] = "test-attack"
        variant["phase_ticks"] = [1, 1, 1]
        variant["samples"] = [{"frame": i, "shown": "run", "phase": phase, "duration_ms": 1000 / 60} for i, phase in enumerate(["recovery", "active", "startup"])]
        timeline["motions"][0]["required_variant_ids"] = ["test-attack"]
        self.assertTrue(any("incomplete runtime phases" in e for e in timeline_errors(self.root, timeline, read(self.manifest)["assets"])))

    def test_timeline_rejects_omitted_recorded_variants(self):
        timeline = read(self.timeline)
        timeline["motions"][0]["required_variant_ids"].append("test-attack#charged-30")
        self.assertTrue(any("missing or unexpected runtime variant" in e for e in timeline_errors(self.root, timeline, read(self.manifest)["assets"])))

    def test_loop_capture_requires_complete_cycles(self):
        timeline = read(self.timeline)
        rows = read(self.manifest)["assets"]
        rows[0].update(loop=True, fps=12)
        self.assertTrue(any("incomplete runtime phases" in e for e in timeline_errors(self.root, timeline, rows)))
        samples = timeline["motions"][0]["variants"][0]["samples"]
        samples.extend(samples[:40])
        self.assertEqual(timeline_errors(self.root, timeline, rows), [])

    def test_charge_requires_hold_and_release_contexts(self):
        timeline = read(self.timeline)
        timeline["motions"][0]["motion"] = "attack_heavy_charge"
        row = read(self.manifest)["assets"][0]
        row["visual_state_id"] = "attack_heavy_charge"
        failures = timeline_errors(self.root, timeline, [row])
        self.assertTrue(any("dynamic release context" in e for e in failures))

    def test_prepare_rejects_non_png_data_with_png_filename(self):
        Image.new("RGB", (2048, 128), "red").save(self.sheet, format="JPEG")
        timeline = read(self.timeline)
        timeline["motions"][0]["sheet_sha256"] = sha(self.sheet)
        write(self.timeline, timeline)
        with self.assertRaises(UnidentifiedImageError):
            prepare(self.root, self.timeline, self.root / "jpeg-disguised-as-png")

    def test_prepare_preserves_existing_decisions(self):
        self.valid_pass()
        write(self.review_path, self.review)
        before = self.review_path.read_bytes()
        with self.assertRaisesRegex(ValueError, "already exists"):
            prepare(self.root, self.timeline, self.output)
        self.assertEqual(before, self.review_path.read_bytes())

    def test_compaction_preserves_hold_duration_and_phase_boundary(self):
        samples = [{"frame": 6, "phase": phase, "shown": "guard", "duration_ms": 10} for phase in ("startup", "startup", "active")]
        self.assertEqual(compact(samples), [[6, "startup", "guard", 20], [6, "active", "guard", 10]])


class MotionLayoutTest(unittest.TestCase):
    def test_legacy_defaults_and_visual_id_precedence(self):
        from motion_layout import layout, motion_id, frame_box
        spec = layout({})
        self.assertEqual(spec["sheet_size"], (2048,128))
        self.assertEqual(spec["frame_durations"], [1.0]*16)
        self.assertEqual(frame_box(15,spec),(1920,0,2048,128))
        self.assertEqual(motion_id({"path":"version_32f.png", "visual_state_id":"attack_light_combo_01"}),"attack_light_combo_01")
        self.assertEqual(motion_id({"path":"jump_24f.png"}),"jump")

    def test_two_row_layout_and_metadata_are_read_only(self):
        from motion_layout import layout, frame_box
        import copy
        row = {"frame_count":24, "atlas_columns":12, "frame_durations":[1.0]*23+[2.0],
               "phase_frame_ranges":[[0,8],[8,12],[12,24]],
               "jump_frame_ranges":{"ascent":[0,6],"apex":[6,10],"descent":[10,16],"landing":[16,24]},
               "run_stride_px":96, "frame_anchors":[{"body_root":[63.25,124],"scarf_root":[40,60],"scarf_hand":[65,70],"scarf_tips":[[10,50],[20,55]],"claw_hand":[72,66],"claw_tip":[88,53]} for _ in range(24)]}
        before=copy.deepcopy(row)
        spec=layout(row)
        self.assertEqual(spec["sheet_size"],(1536,256))
        self.assertEqual(frame_box(12,spec),(0,128,128,256))
        self.assertEqual(frame_box(23,spec),(1408,128,1536,256))
        self.assertEqual(row,before)
        self.assertEqual(layout({"frame_count":32})["sheet_size"],(2048,256))
        row["frame_anchors"][0]["scarf_tips"] = [[10,50],None]
        self.assertEqual(layout(row)["frame_count"],24)

    def test_reject_invalid_counts_atlases_durations_ranges_and_anchors(self):
        from motion_layout import layout
        invalid = [{"frame_count":n} for n in [0,17,25,33,True,24.0]]
        invalid += [{"frame_count":32,"atlas_columns":n} for n in [0,8,17,True]]
        invalid += [{"cell_size":64},{"frame_durations":[1]*15}]
        invalid += [{"frame_durations":[1]*15+[n]} for n in [0,-1,float("nan"),float("inf"),True]]
        invalid += [{"phase_frame_ranges":[[0,5],[4,10],[10,16]]},{"phase_frame_ranges":[[0,5],[5,10],[10,15]]},
                    {"jump_frame_ranges":{"ascent":[0,6]}},{"run_stride_px":0},
                    {"descent_frame_range":[10,17]},{"frame_anchors":[{}]*15},
                    {"frame_anchors":[{"scarf_root":[129,2]}]*16},{"frame_anchors":[{"scarf_tips":[[1,2]]}]*16},
                    {"frame_anchors":[{"body_root":[129,124]}]*16}, {"frame_anchors":[{"body_root":[63,float("inf")]}]*16},
                    {"frame_anchors":[{"claw_hand":[129,2]}]*16}, {"frame_anchors":[{"claw_tip":[float("nan"),2]}]*16},
                    {"frame_anchors":[{"scarf_tips":[None,None]}]*16}]
        for row in invalid:
            with self.subTest(row=row), self.assertRaises(ValueError): layout(row)

    def test_launch_release_json_numbers_are_valid_and_do_not_mutate_input(self):
        from motion_layout import layout
        import copy
        for count in [16,24,32]:
            row={"visual_state_id":"launch","frame_count":count,
                 "launch_release_frame_range":[float(count-4),float(count)],"launch_release_ticks":4.0}
            before=copy.deepcopy(row)
            self.assertEqual(layout(row)["frame_count"],count)
            self.assertEqual(row,before)

    def test_invalid_release_pairs_ranges_durations_and_state_timers_are_rejected(self):
        from motion_layout import layout
        valid={"visual_state_id":"launch","launch_release_frame_range":[12,16],"launch_release_ticks":4}
        cases=[{"launch_release_frame_range":[12,16]}, {"launch_release_ticks":4},
               {**valid,"visual_state_id":"guard"}, {**valid,"launch_release_ticks":3},
               {**valid,"launch_release_frame_range":[12,17]}, {**valid,"launch_release_frame_range":[16,16]}]
        for invalid in [True,False,0,-1,13,4.5,float("nan"),float("inf"),"4"]:
            cases.append({**valid,"launch_release_ticks":invalid})
        for invalid in [True,12.5,float("nan"),float("inf"),"12"]:
            cases.append({**valid,"launch_release_frame_range":[invalid,16]})
        for invalid in [True,0,-1,1.5,float("nan"),float("inf"),"12"]:
            cases.append({"state_duration_ticks":invalid})
        cases += [{"landing_down_frame_range":[12,17]}, {"landing_down_frame_range":[True,16]},
                  {"state_hold_frame":16}, {"state_hold_frame":-1}, {"state_hold_frame":True}]
        for row in cases:
            with self.subTest(row=row),self.assertRaises(ValueError):layout(row)

    def test_board_uses_declared_rows_not_horizontal_strip(self):
        from motion_layout import layout
        from review_motion_actions import make_board
        with tempfile.TemporaryDirectory() as temporary:
            sheet=Image.new("RGBA",(2048,256),(0,0,0,0))
            sheet.paste((190,20,40,255),(0,128,128,256))
            destination=Path(temporary)/"board.jpg"
            make_board(sheet,"24 frame fixture",destination,layout({"frame_count":24}))
            with Image.open(destination) as board:
                self.assertEqual(board.size,(528,840))
                pixel=board.getpixel((40,24+4*136+40))
                self.assertGreater(pixel[0],pixel[1]+100)


class CandidateMotionReviewTest(unittest.TestCase):
    """Pending candidates never replace approved runtime assets or default coverage."""

    def setUp(self):
        self.fixture = MotionActionReviewTest("test_prepare_never_claims_semantic_pass")
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.root = self.fixture.root
        self.work = self.root / "_workspace/candidate-test"
        self.work.mkdir(parents=True)
        self.sheet = self.work / "run.png"
        Image.new("RGBA", (2048, 128), (80, 30, 120, 200)).save(self.sheet)
        self.sprite = self.work / "run.tres"
        self.sprite.write_text('[gd_resource type="SpriteFrames" format=3]\n[ext_resource type="Texture2D" path="res://_workspace/candidate-test/run.png" id="1"]\n')
        self.attack = self.root / "assets/attack.tres"
        self.attack.write_text("fixture AttackData")
        (self.root / "tools/forest_arena").mkdir(parents=True, exist_ok=True)
        for name in ("motion_review_candidates.py", "review_motion_actions.py", "motion_review_timeline.gd", "motion_review_candidate_frames.gd", "motion_layout.py"):
            (self.root / "tools/forest_arena" / name).write_text("fixture tooling: " + name)
        self.catalog = self.work / "catalog.json"
        self.scope = self.work / "scope.json"
        self.row = {"type": "animation-candidate", "character_id": "test", "visual_state_id": "run", "path": "_workspace/candidate-test/run.png", "sprite_frames_path": "res://_workspace/candidate-test/run.tres", "fps": 12, "loop": False, "expected_action": "발 교대와 몸의 무게 이동을 확인", "action_source": "docs/gameplay/combat.md"}
        write(self.catalog, {"schema_version": 1, "kind": "motion-candidates", "approval_status": "pending", "attack_sources": ["assets/attack.tres"], "character_movesets": {"test": "assets/attack.tres"}, "assets": [self.row]})
        self.scope_doc = {"schema_version": 1, "kind": "candidate-motion-review", "catalog_sha256": sha(self.catalog), "motions": [{"character_id": "test", "motion": "run"}]}
        write(self.scope, self.scope_doc)
        self.scope_digest = sha(self.scope)
        from motion_review_candidates import load_selection
        selection = load_selection(self.root, self.catalog, self.scope, self.scope_digest)
        timeline = read(self.fixture.timeline)
        timeline["candidate_selection"] = selection["candidate_selection"]
        timeline["generator_sha256"] = sha(self.root / "tools/forest_arena/motion_review_timeline.gd")
        timeline["sources"].update({source: sha(self.root / source) for source in selection["required_sources"]})
        timeline["motions"][0]["sheet_sha256"] = sha(self.sheet)
        self.timeline = self.work / "timeline.json"
        write(self.timeline, timeline)
        self.output = self.work / "review"
        prepare(self.root, self.timeline, self.output, self.catalog, self.scope, self.scope_digest)
        self.review_path = self.output / "motion-review.json"
        self.review = read(self.review_path)
        self.review.update(reviewer="independent fixture reviewer", reviewer_role="qa")

    def test_phase_drawings_cannot_exceed_actual_combat_ticks(self):
        from motion_review_candidates import load_selection
        timeline = read(self.timeline)
        row = dict(self.row,phase_frame_ranges=[[0,4],[4,9],[9,16]])
        entry=timeline["motions"][0]
        entry.update(required_variant_ids=["test-attack"], variants=[{"attack_id":"test-attack","phase_ticks":[8,4,18],"samples":[{"frame":0,"shown":"run","phase":phase,"duration_ms":1000/60} for phase,count in [("startup",8),("active",4),("recovery",18)] for _ in range(count)]}])
        selection=load_selection(self.root,self.catalog,self.scope,self.scope_digest)
        self.assertTrue(any("more drawings" in e for e in timeline_errors(self.root,timeline,[row],selection)))
        row["reuse_approved_runtime"]=True
        self.assertEqual(timeline_errors(self.root,timeline,[row],selection),[])

    def test_new_phase_must_show_every_authored_drawing(self):
        from motion_review_candidates import load_selection
        timeline=read(self.timeline)
        row=dict(self.row,frame_count=24,phase_frame_ranges=[[0,8],[8,12],[12,24]])
        selection=load_selection(self.root,self.catalog,self.scope,self.scope_digest)
        samples=[{"frame":frame,"shown":"run","phase":phase,"duration_ms":1000/60} for phase,frames in [("startup",range(8)),("active",range(8,12)),("recovery",[12,12,13,13,14,14,15,15,16,17,18,19,20,20,21,22,23,23])] for frame in frames]
        entry=timeline["motions"][0]
        entry.update(required_variant_ids=["attack"],variants=[{"attack_id":"attack","phase_ticks":[8,4,18],"samples":samples}])
        self.assertEqual(timeline_errors(self.root,timeline,[row],selection),[])
        samples[8]["frame"]=9
        self.assertTrue(any("authored drawing skipped" in e for e in timeline_errors(self.root,timeline,[row],selection)))
        del row["phase_frame_ranges"]
        self.assertTrue(any("explicit phase_frame_ranges" in e for e in timeline_errors(self.root,timeline,[row],selection)))

    def test_new_sixteen_frame_weights_cannot_hide_authored_drawings(self):
        from motion_review_candidates import load_selection
        selection=load_selection(self.root,self.catalog,self.scope,self.scope_digest)
        timeline=read(self.timeline)
        row=dict(self.row,frame_count=16,frame_durations=[100.0,1,1,1]+[1.0]*12,phase_frame_ranges=[[0,4],[4,8],[8,16]])
        samples=[{"frame":frame,"shown":"run","phase":phase,"duration_ms":1000/60}
            for phase,frames in [("startup",[0,0,0,0,0,0,0,3]),("active",[4,5,6,7]),
                ("recovery",[8,8,9,9,10,10,11,11,12,12,13,13,14,14,15,15,15,15])]
            for frame in frames]
        timeline["motions"][0].update(required_variant_ids=["attack"],variants=[{"attack_id":"attack","phase_ticks":[8,4,18],"samples":samples}])
        self.assertTrue(any("authored drawing skipped" in error for error in timeline_errors(self.root,timeline,[row],selection)))
        row["reuse_approved_runtime"]=True
        self.assertEqual(timeline_errors(self.root,timeline,[row],selection),[])

        row.pop("reuse_approved_runtime")
        row["frame_durations"]=[1.0]*16
        for sample,frame in zip(samples,[0,0,1,1,2,2,3,3]): sample["frame"]=frame
        self.assertEqual(timeline_errors(self.root,timeline,[row],selection),[])

    def test_new_sixteen_frame_without_ranges_requires_every_drawing(self):
        from motion_review_candidates import load_selection
        selection=load_selection(self.root,self.catalog,self.scope,self.scope_digest)
        timeline=read(self.timeline)
        row=dict(self.row,frame_count=16)
        frames=list(range(16))+[15]*14
        phases=["startup"]*8+["active"]*4+["recovery"]*18
        samples=[{"frame":frame,"shown":"run","phase":phase,"duration_ms":1000/60} for frame,phase in zip(frames,phases)]
        timeline["motions"][0].update(required_variant_ids=["attack"],variants=[{"attack_id":"attack","phase_ticks":[8,4,18],"samples":samples}])
        self.assertEqual(timeline_errors(self.root,timeline,[row],selection),[])
        samples[7]["frame"]=6
        self.assertTrue(any("skipped by full attack playback" in error for error in timeline_errors(self.root,timeline,[row],selection)))
        row["reuse_approved_runtime"]=True
        self.assertEqual(timeline_errors(self.root,timeline,[row],selection),[])

    def test_jump_declared_landing_never_appears_in_air(self):
        from motion_review_candidates import load_selection
        timeline=read(self.timeline)
        ranges={"ascent":[0,4],"apex":[4,6],"descent":[6,10],"landing":[10,16]}
        row=dict(self.row,visual_state_id="jump",jump_frame_ranges=ranges)
        samples=[{"frame":ranges[phase][0],"shown":"jump","phase":phase,"duration_ms":1000/60} for phase,count in [("ascent",20),("apex",12),("descent",20),("landing",16)] for _ in range(count)]
        entry=timeline["motions"][0]
        entry.update(motion="jump",required_variant_ids=["state:jump"],variants=[{"attack_id":"state:jump","samples":samples}])
        selection=load_selection(self.root,self.catalog,self.scope,self.scope_digest)
        self.assertEqual(timeline_errors(self.root,timeline,[row],selection),[])
        samples[0]["frame"]=10
        self.assertTrue(any("airborne landing forbidden" in e for e in timeline_errors(self.root,timeline,[row],selection)))

    def test_run_stride_requires_actual_distance_samples(self):
        from motion_review_candidates import load_selection
        timeline=read(self.timeline)
        row=dict(self.row,run_stride_px=96)
        samples=timeline["motions"][0]["variants"][0]["samples"]
        selection=load_selection(self.root,self.catalog,self.scope,self.scope_digest)
        self.assertTrue(any("movement samples" in e for e in timeline_errors(self.root,timeline,[row],selection)))
        for i,sample in enumerate(samples): sample["position"]=[192*i/len(samples),0]
        self.assertEqual(timeline_errors(self.root,timeline,[row],selection),[])
        samples[-1]["position"]=[0,0]
        self.assertTrue(any("two distance cycles" in e for e in timeline_errors(self.root,timeline,[row],selection)))

    def test_short_state_timer_variants_are_complete_and_candidate_only(self):
        from motion_review_candidates import load_selection
        selection = load_selection(self.root, self.catalog, self.scope, self.scope_digest)
        for motion, identifier, duration in [("knock_down", "state:landing-down-18", 18), ("wake_up", "state:wakeup-protection-12", 12)]:
            with self.subTest(motion=motion):
                timeline = read(self.timeline)
                row = dict(self.row, visual_state_id=motion)
                entry = timeline["motions"][0]
                entry.update(motion=motion, required_variant_ids=[identifier], variants=[{"attack_id": identifier, "samples": [{"frame": 12, "shown": motion, "phase": motion, "duration_ms": 1000 / 60} for _ in range(duration)]}])
                self.assertEqual(timeline_errors(self.root, timeline, [row], selection), [])
                entry["variants"][0]["samples"].pop()
                self.assertTrue(any("incomplete runtime phases" in error for error in timeline_errors(self.root, timeline, [row], selection)))

    def check_review(self):
        write(self.review_path, self.review)
        return validate(self.root, self.review_path, False, self.catalog, self.scope, self.scope_digest)

    def check_input(self):
        from motion_review_candidates import load_selection
        return load_selection(self.root, self.catalog, self.scope)

    def update_catalog(self, change):
        catalog = read(self.catalog)
        change(catalog)
        write(self.catalog, catalog)
        self.scope_doc["catalog_sha256"] = sha(self.catalog)
        write(self.scope, self.scope_doc)

    def make_layout_only(self, png_path="assets/character/run.png", sprite_path="assets/character/run.tres"):
        row = read(self.catalog)["assets"][0]
        approved = {**row, "type": "animation-runtime", "asset_id": "test-" + row["visual_state_id"].replace("_", "-") + "-stable-v01",
                    "path": png_path, "sprite_frames_path": "res://" + sprite_path,
                    "consumer_path": "res://" + sprite_path, "sha256": sha(self.sheet), "presentation_scale": 1.0}
        for field in ("expected_action", "action_source", "layout_only_from_asset_id"):
            approved.pop(field, None)
        png, sprite = self.root / png_path, self.root / sprite_path
        png.parent.mkdir(parents=True, exist_ok=True)
        sprite.parent.mkdir(parents=True, exist_ok=True)
        png.write_bytes(self.sheet.read_bytes())
        sprite.write_text(self.sprite.read_text().replace("res://" + row["path"], "res://" + png_path))
        write(self.fixture.manifest, {"assets": [approved]})
        self.update_catalog(lambda doc: doc["assets"][0].update(layout_only_from_asset_id=approved["asset_id"],
            sha256=sha(self.sheet), presentation_scale=0.92))
        return approved

    def test_layout_only_keeps_pending_row_and_pins_approved_sources(self):
        before_png, before_tres = self.sheet.read_bytes(), self.sprite.read_bytes()
        approved = self.make_layout_only()
        selection = self.check_input()
        row = selection["rows"][0]
        self.assertEqual(row["type"], "animation-candidate")
        self.assertFalse(row.get("reuse_approved_runtime", False))
        self.assertEqual(row["presentation_scale"], 0.92)
        self.assertIn(approved["path"], selection["required_sources"])
        self.assertIn(approved["sprite_frames_path"].removeprefix("res://"), selection["required_sources"])
        self.assertEqual((before_png, before_tres), (self.sheet.read_bytes(), self.sprite.read_bytes()))
        self.update_catalog(lambda doc: doc["assets"][0].pop("layout_only_from_asset_id"))
        with self.assertRaisesRegex(ValueError, "exposed in runtime"):
            self.check_input()

    def test_layout_only_rejects_wrong_identity_pixels_and_non_scale_changes(self):
        approved = self.make_layout_only()
        original = read(self.catalog)["assets"][0]
        manifest = read(self.fixture.manifest)
        manifest["assets"].append({"type": "concept", "character_id": "other"})
        write(self.fixture.manifest, manifest)
        changes = [{"layout_only_from_asset_id": "wrong-asset"}, {"character_id": "other"}, {"visual_state_id": "guard"}]
        changes += [{"presentation_scale": value} for value in (0, -1, True, float("inf"), 1.0)]
        changes += [{"frame_durations": [2.0] * 16}, {"foot_pivot_y": 120}, {"phase_frame_ranges": [[0,4],[4,8],[8,16]]}, {"state_hold_frame": 0}]
        for change in changes:
            with self.subTest(change=change):
                self.update_catalog(lambda doc: doc.update(assets=[{**original, **change}]))
                with self.assertRaises(ValueError): self.check_input()
        self.update_catalog(lambda doc: doc.update(assets=[original]))
        self.sheet.write_bytes(self.sheet.read_bytes() + b"changed")
        with self.assertRaisesRegex(ValueError, "PNG bytes"):
            self.check_input()
        self.sheet.write_bytes((self.root / approved["path"]).read_bytes())
        self.sprite.write_text(self.sprite.read_text() + "\n# different SpriteFrames")
        with self.assertRaisesRegex(ValueError, "only in its PNG reference"):
            self.check_input()

    def test_pending_candidate_is_blocked_not_automatically_passed(self):
        self.assertEqual(self.review["motions"][0]["status"], "blocked")
        self.assertEqual(self.check_review(), [])
        page = (self.output / "index.html").read_text()
        self.assertIn("전체 16프레임 원화 FPS", page)
        self.assertIn("게임 코드의 실제 타이밍", page)
        self.assertIn(".25", page)
        self.assertTrue(validate(self.root, self.review_path, True, self.catalog, self.scope))

    def test_default_validation_cannot_accept_candidate_subset(self):
        write(self.review_path, self.review)
        self.assertTrue(any("explicit catalog and scope" in e for e in validate(self.root, self.review_path)))
        with self.assertRaisesRegex(ValueError, "explicit catalog and scope"):
            prepare(self.root, self.timeline, self.work / "invalid-default")

    def test_original_scope_byte_change_rejected_even_when_json_meaning_same(self):
        self.scope.write_text(self.scope.read_text() + "\n")
        self.assertTrue(any("scope original SHA256 changed" in e for e in self.check_review()))

    def test_scope_and_catalog_rewrite_cannot_reuse_old_review(self):
        self.scope_doc["note"] = "new scope bytes"
        write(self.scope, self.scope_doc)
        write(self.review_path, self.review)
        self.assertTrue(any("original scope changed" in e or "source changed" in e for e in validate(self.root, self.review_path, False, self.catalog, self.scope)))

    def test_missing_duplicate_unknown_scope_rejected(self):
        for motions in ([], self.scope_doc["motions"] * 2, [{"character_id": "test", "motion": "unknown"}]):
            write(self.scope, {**self.scope_doc, "motions": motions})
            with self.assertRaisesRegex(ValueError, "missing|unknown|duplicate"):
                self.check_input()

    def test_duplicate_catalog_and_unknown_character_rejected(self):
        self.update_catalog(lambda doc: doc["assets"].append(dict(self.row)))
        with self.assertRaisesRegex(ValueError, "duplicate"):
            self.check_input()
        self.update_catalog(lambda doc: doc.update(assets=[{**self.row, "character_id": "unknown"}]))
        with self.assertRaisesRegex(ValueError, "unknown"):
            self.check_input()

    def test_catalog_change_invalidates_scope_pin(self):
        self.catalog.write_text(self.catalog.read_text() + "\n")
        with self.assertRaisesRegex(ValueError, "catalog SHA256 changed"):
            self.check_input()

    def test_scope_required_with_catalog(self):
        self.assertTrue(any("both" in e for e in validate(self.root, self.review_path, catalog=self.catalog)))
        with self.assertRaisesRegex(ValueError, "both"):
            prepare(self.root, self.timeline, self.work / "incomplete", self.catalog)

    def test_escape_absolute_and_symlink_candidate_paths_rejected(self):
        for path in ("../outside.png", "/tmp/outside.png", "_workspace/candidate-test/../candidate-test/run.png", "assets/character/run.png"):
            self.update_catalog(lambda doc: doc["assets"][0].update(path=path))
            with self.assertRaisesRegex(ValueError, "path|_workspace"):
                self.check_input()
        outside = Path(self.fixture.temp.name).parent / (Path(self.fixture.temp.name).name + "-outside.png")
        Image.new("RGBA", (2048, 128), "red").save(outside)
        self.addCleanup(outside.unlink)
        (self.work / "escaped.png").symlink_to(outside)
        self.update_catalog(lambda doc: doc["assets"][0].update(path="_workspace/candidate-test/escaped.png"))
        with self.assertRaisesRegex(ValueError, "escaping"):
            self.check_input()

    def test_runtime_manifest_exposure_rejected_even_as_copy(self):
        approved = self.root / "assets/character/exposed.png"
        approved.write_bytes(self.sheet.read_bytes())
        manifest = read(self.fixture.manifest)
        manifest["assets"].append({"type": "animation-runtime", "character_id": "test", "path": "assets/character/exposed.png"})
        write(self.fixture.manifest, manifest)
        with self.assertRaisesRegex(ValueError, "exposed in runtime"):
            self.check_input()

    def test_runtime_consumer_reference_rejected(self):
        (self.root / "scripts/exposure.gd").write_text('var pending = preload("res://_workspace/candidate-test/run.tres")')
        with self.assertRaisesRegex(ValueError, "runtime consumer"):
            self.check_input()

    def test_spriteframes_cannot_load_other_png_or_scripts(self):
        self.sprite.write_text('[gd_resource type="SpriteFrames"]\n[ext_resource type="Script" path="res://scripts/fighter_controller.gd" id="1"]')
        with self.assertRaisesRegex(ValueError, "declared PNG"):
            self.check_input()

    def test_attack_data_and_presentation_changes_invalidate_review(self):
        for source in (self.attack, self.root / "scripts/local_fighter_presentation.gd"):
            before = source.read_text()
            source.write_text(before + " changed")
            self.assertTrue(any("source changed" in e for e in self.check_review()))
            source.write_text(before)

    def test_candidate_png_tres_and_html_changes_invalidate_review(self):
        for source in (self.sheet, self.sprite, self.output / "index.html"):
            before = source.read_bytes()
            source.write_bytes(before + b" changed")
            self.assertTrue(self.check_review())
            source.write_bytes(before)

    def test_missing_attack_and_generator_fingerprints_rejected(self):
        timeline = read(self.timeline)
        del timeline["sources"]["assets/attack.tres"]
        write(self.timeline, timeline)
        with self.assertRaisesRegex(ValueError, "fingerprints"):
            prepare(self.root, self.timeline, self.work / "missing-attack", self.catalog, self.scope)

    def test_fake_pass_without_inspection_or_independent_role_rejected(self):
        self.review["motions"][0]["status"] = "pass"
        self.review["reviewer_role"] = "producer"
        errors = self.check_review()
        self.assertTrue(any("independent qa" in e for e in errors))
        self.assertTrue(any("inspection" in e for e in errors))
        self.assertTrue(any("observations" in e for e in errors))

    def test_fixed_expected_action_and_pending_approval_are_enforced(self):
        self.review["motions"][0]["expected_action"] = "different choreography"
        self.review["approval_status"] = "approved"
        errors = self.check_review()
        self.assertTrue(any("fixed scope" in e for e in errors))
        self.assertTrue(any("user approval" in e for e in errors))

    def test_spriteframes_cannot_hide_an_extra_script_with_reordered_attributes(self):
        with self.sprite.open("a") as file:
            file.write('[ext_resource path="res://scripts/fighter_controller.gd" type="Script" id="evil"]\n')
        with self.assertRaisesRegex(ValueError, "declared PNG"):
            self.check_input()

    def test_missing_board_and_escaping_material_cannot_support_pass(self):
        row = self.review["motions"][0]
        row.update(status="pass", observations="관찰 설명을 기록해도 필수 비교판 누락은 허용하지 않는다", checks=dict.fromkeys(CHECKS, True))
        row["materials"] = {"../timeline.json": sha(self.timeline)}
        errors = self.check_review()
        self.assertTrue(any("frame board" in e for e in errors))
        self.assertTrue(any("escaping review evidence" in e for e in errors))

    def test_wrong_spriteframes_and_catalog_paths_do_not_change_default_mode(self):
        self.update_catalog(lambda doc: doc["assets"][0].update(sprite_frames_path="_workspace/candidate-test/run.tres"))
        with self.assertRaisesRegex(ValueError, "res://"):
            self.check_input()
        errors = validate(self.root, self.fixture.review_path)
        self.assertEqual(errors, ["missing schema or independent reviewer"])

    def test_approved_runtime_reuse_is_explicit_and_exact(self):
        manifest = read(self.fixture.manifest)
        manifest["assets"][0].update(fps=12, loop=False)
        write(self.fixture.manifest, manifest)
        approved = {**manifest["assets"][0], "reuse_approved_runtime": True, "expected_action": "기존 달리기의 발 교대를 새 전투 표시에서 확인", "action_source": "docs/gameplay/combat.md"}
        self.update_catalog(lambda doc: doc.update(assets=[approved]))
        # The fixture runtime tres must also reference its own PNG, as production files do.
        self.fixture.sprite.write_text('[gd_resource type="SpriteFrames"]\n[ext_resource type="Texture2D" path="res://assets/character/run.png" id="1"]\n')
        self.assertEqual(self.check_input()["rows"][0]["path"], "assets/character/run.png")
        self.update_catalog(lambda doc: doc["assets"][0].update(fps=24))
        with self.assertRaisesRegex(ValueError, "exactly match"):
            self.check_input()

    def test_runtime_type_without_explicit_registered_reuse_is_rejected(self):
        self.update_catalog(lambda doc: doc["assets"][0].update(type="animation-runtime"))
        with self.assertRaisesRegex(ValueError, "explicitly approved"):
            self.check_input()

    def test_missing_or_unpinned_character_moveset_mapping_is_rejected(self):
        self.update_catalog(lambda doc: doc.update(character_movesets={}))
        with self.assertRaisesRegex(ValueError, "character_movesets"):
            self.check_input()
        self.update_catalog(lambda doc: doc.update(character_movesets={"test": "assets/unpinned.tres"}))
        with self.assertRaisesRegex(ValueError, "pinned AttackData"):
            self.check_input()


class MotionRegistrationTest(unittest.TestCase):
    """Registration writes only artificial temporary project fixtures."""

    def setUp(self):
        self.fixture=CandidateMotionReviewTest("test_pending_candidate_is_blocked_not_automatically_passed")
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.root,self.work=self.fixture.root,self.fixture.work
        self.targets=self.work/"targets.json"
        self.approval=self.work/"user-approval.json"
        self.backup=self.work/"registration-backup"
        self.config={"schema_version":1,"kind":"motion-registration-targets","approval_record":str(self.approval.relative_to(self.root)),"motions":[{"character_id":"test","motion":"guard","asset_id":"test-guard-stable-v01","png_path":"assets/character/test/animation/runtime/guard_24f_v02.png","sprite_frames_path":"res://assets/character/test/animation/runtime/guard.tres"}]}
        self.original_source=self.work/"original-source.png"
        Image.new("RGBA",(128,128),(20,40,60,180)).save(self.original_source)
        self.provenance={"source_path":str(self.original_source.relative_to(self.root)),"source_sha256":sha(self.original_source),
            "creation":{"method":"Synthetic fixture drawing","provider":"unit test","version":"fixture-v02"},
            "rights":{"status":"Synthetic fixture only; no real asset approval","references":["fixture://original-art"]},
            "conversion":{"method":"Synthetic fixture packing","uniform_scale":1.0}}
        self.fixture.update_catalog(lambda doc: doc["assets"][0].update(self.provenance))
        self.prepare_art(24)

    def prepare_art(self,count,motion="guard"):
        from motion_review_candidates import load_selection
        columns=12 if count==24 else 16
        Image.new("RGBA",(columns*128,((count+columns-1)//columns)*128),(30,50,70,180)).save(self.fixture.sheet)
        self.fixture.update_catalog(lambda doc: doc["assets"][0].update(visual_state_id=motion,frame_count=count,atlas_columns=columns,sha256=sha(self.fixture.sheet)))
        scope=read(self.fixture.scope)
        scope["motions"]=[{"character_id":"test","motion":motion}]
        write(self.fixture.scope,scope)
        self.scope_hash=sha(self.fixture.scope)
        selection=load_selection(self.root,self.fixture.catalog,self.fixture.scope,self.scope_hash)
        timeline=read(self.fixture.timeline)
        timeline["candidate_selection"]=selection["candidate_selection"]
        timeline["sources"].update({source:sha(self.root/source) for source in selection["required_sources"]})
        row=timeline["motions"][0]
        row.update(motion=motion,sheet_sha256=sha(self.fixture.sheet),required_variant_ids=["state:"+motion])
        row["variants"]=[{"attack_id":"state:"+motion,"samples":[{"frame":i%count,"shown":motion,"phase":motion,"duration_ms":1000/60} for i in range(120)]}]
        write(self.fixture.timeline,timeline)
        output=self.work/("registration-review-"+str(len(list(self.work.glob("registration-review-*")))))
        prepare(self.root,self.fixture.timeline,output,self.fixture.catalog,self.fixture.scope,self.scope_hash)
        self.review=output/"motion-review.json"
        review=read(self.review)
        review.update(reviewer="independent QA fixture only",reviewer_role="qa")
        review["motions"][0].update(status="pass",observations="Temporary artificial fixture only; no real user approval",checks=dict.fromkeys(CHECKS,True))
        write(self.review,review)
        self.config["motions"][0].update(motion=motion,asset_id="test-"+motion.replace("_","-")+"-stable-v01",png_path=f"assets/character/test/animation/runtime/{motion}_{count}f_v02.png",sprite_frames_path=f"res://assets/character/test/animation/runtime/{motion}.tres")
        write(self.targets,self.config)

    def plan(self):
        from register_motion_candidates import plan_registration
        return plan_registration(self.root,self.fixture.catalog,self.fixture.scope,self.scope_hash,self.review,self.targets)

    def fixture_approval(self,plan):
        from register_motion_candidates import plan_digest
        # Never emit this artificial decision outside this disposable fixture.
        approval={"schema_version":1,"kind":"user-motion-registration-approval","source":"user","plan_sha256":plan_digest(plan),**{key:plan[key] for key in ["catalog_sha256","scope_sha256","qa_review_sha256","registration_targets_sha256"]},"motions":[{**{key:row[key] for key in ["character_id","motion","png_sha256","candidate_sprite_frames_sha256","registered_sprite_frames_sha256"]},"user_approved":True,"user_message":"Synthetic unit-test approval; not a real user decision","message_reference":"fixture://user-message/1","approved_on":"2026-10-21"} for row in plan["motions"]]}
        write(self.approval,approval)
        return approval

    def snapshot(self):
        return {str(path.relative_to(self.root)):path.read_bytes() for path in self.root.rglob("*") if path.is_file()}

    def test_dryrun_16_24_32_is_read_only_and_pins_rewritten_spriteframes(self):
        from register_motion_candidates import digest,plan_digest
        for count in [16,24,32]:
            self.prepare_art(count)
            before=self.snapshot()
            plan,pending=self.plan()
            self.assertEqual(before,self.snapshot())
            self.assertEqual(len(plan_digest(plan)),64)
            row=plan["motions"][0]
            rendered=pending[row["sprite_frames_path"].removeprefix("res://")]
            self.assertNotIn(b"_workspace/",rendered)
            self.assertIn(row["png_path"].encode(),rendered)
            self.assertEqual(digest(rendered),row["registered_sprite_frames_sha256"])

    def test_launch_release_metadata_survives_planning_and_approved_fixture_install(self):
        from register_motion_candidates import install
        fields={"launch_release_frame_range":[12,16],"launch_release_ticks":4}
        self.fixture.update_catalog(lambda doc:doc["assets"][0].update(visual_state_id="launch",**fields))
        self.prepare_art(16,"launch")
        before=self.snapshot();plan,pending=self.plan()
        self.assertEqual(before,self.snapshot())
        updated=json.loads(pending["assets/character/manifest.json"])
        row=next(row for row in updated["assets"] if row.get("visual_state_id")=="launch")
        self.assertEqual({key:row[key] for key in fields},fields)
        with self.assertRaisesRegex(ValueError,"human approval.*missing"):
            install(self.root,plan,pending,self.backup)
        self.assertEqual(before,self.snapshot())
        self.fixture_approval(plan)  # Synthetic temporary fixture decision only.
        install(self.root,plan,pending,self.backup)
        result=read(self.fixture.fixture.manifest)
        row=next(row for row in result["assets"] if row.get("visual_state_id")=="launch")
        self.assertEqual({key:row[key] for key in fields},fields)

    def test_existing_state_display_metadata_is_preserved_in_registration_plan(self):
        fields={"state_duration_ticks":18,"landing_down_frame_range":[12,16],"state_hold_frame":15}
        self.fixture.update_catalog(lambda doc:doc["assets"][0].update(visual_state_id="knock_down",**fields))
        self.prepare_art(16,"knock_down")
        before=self.snapshot();plan,pending=self.plan()
        self.assertEqual(before,self.snapshot())
        updated=json.loads(pending["assets/character/manifest.json"])
        row=next(row for row in updated["assets"] if row.get("visual_state_id")=="knock_down")
        self.assertEqual({key:row[key] for key in fields},fields)

    def test_layout_only_plan_keeps_approval_gate_and_does_not_publish_catalog_flag(self):
        from register_motion_candidates import install
        self.fixture.make_layout_only("assets/character/test/animation/runtime/guard_24f_v01.png",
                                    "assets/character/test/animation/runtime/guard.tres")
        self.prepare_art(24)
        before = self.snapshot()
        plan, pending = self.plan()
        self.assertEqual(before, self.snapshot())
        self.assertEqual(len(plan["motions"]), 1)
        self.assertEqual(plan["motions"][0]["operation"], "replace")
        result = json.loads(pending["assets/character/manifest.json"])["assets"][0]
        self.assertEqual(result["presentation_scale"], 0.92)
        self.assertNotIn("layout_only_from_asset_id", result)
        self.assertEqual(result["registration_history"][-1]["presentation_scale"], 1.0)
        with self.assertRaisesRegex(ValueError, "human approval.*missing"):
            install(self.root, plan, pending, self.backup)
        self.assertEqual(before, self.snapshot())
        self.assertFalse(self.backup.exists())

    def test_missing_approval_refuses_before_any_write_or_backup(self):
        from register_motion_candidates import install
        plan,pending=self.plan(); before=self.snapshot()
        with self.assertRaisesRegex(ValueError,"human approval.*missing"):
            install(self.root,plan,pending,self.backup)
        self.assertEqual(before,self.snapshot())
        self.assertFalse(self.backup.exists())

    def test_qa_pass_cannot_replace_explicit_user_approval(self):
        from register_motion_candidates import install
        plan,pending=self.plan(); approval=self.fixture_approval(plan)
        approval["source"]="qa"; write(self.approval,approval); before=self.snapshot()
        with self.assertRaisesRegex(ValueError,"user decision"):
            install(self.root,plan,pending,self.backup)
        self.assertEqual(before,self.snapshot())

    def test_each_plan_scope_review_artwork_hash_and_decision_is_required(self):
        from register_motion_candidates import verify_approval
        plan,_=self.plan()
        for field in ["plan_sha256","catalog_sha256","scope_sha256","qa_review_sha256","registration_targets_sha256","png_sha256","candidate_sprite_frames_sha256","registered_sprite_frames_sha256","user_approved","user_message","message_reference"]:
            with self.subTest(field=field):
                approval=self.fixture_approval(plan)
                if field in approval: approval[field]="wrong"
                else: approval["motions"][0][field]=False if field=="user_approved" else ""
                write(self.approval,approval)
                with self.assertRaises(ValueError): verify_approval(self.root,plan)

    def test_approval_covers_exactly_each_motion(self):
        from register_motion_candidates import verify_approval
        plan,_=self.plan()
        for mode in ["missing","duplicate","unknown"]:
            approval=self.fixture_approval(plan)
            if mode=="missing": approval["motions"]=[]
            elif mode=="duplicate": approval["motions"]*=2
            else: approval["motions"][0]["motion"]="unknown"
            write(self.approval,approval)
            with self.assertRaisesRegex(ValueError,"every planned motion"):
                verify_approval(self.root,plan)

    def test_stale_qa_or_source_refuses_registration(self):
        from register_motion_candidates import install
        plan,pending=self.plan(); self.fixture_approval(plan)
        (self.root/"scripts/local_fighter_presentation.gd").write_text("Changed after QA")
        before=self.snapshot()
        with self.assertRaisesRegex(ValueError,"QA review is not current"):
            install(self.root,plan,pending,self.backup)
        self.assertEqual(before,self.snapshot())

    def test_existing_png_and_unsafe_target_never_overwritten(self):
        for path in ["../escape_24f_v02.png","assets/character/other/animation/runtime/guard_24f_v02.png","assets/character/test/animation/runtime/guard_16f_v02.png"]:
            with self.subTest(path=path):
                config=read(self.targets); config["motions"][0]["png_path"]=path; write(self.targets,config)
                with self.assertRaises(ValueError): self.plan()
        write(self.targets,self.config)
        target=self.root/self.config["motions"][0]["png_path"]
        target.parent.mkdir(parents=True); target.write_bytes(b"existing immutable PNG")
        before=self.snapshot()
        with self.assertRaisesRegex(ValueError,"must not overwrite"):
            self.plan()
        self.assertEqual(before,self.snapshot())

    def test_fixture_install_preserves_existing_png_and_id_consumer(self):
        from register_motion_candidates import install
        manifest=read(self.fixture.fixture.manifest)
        old_png=self.root/"assets/character/test/animation/runtime/guard_16f_v01.png"
        old_png.parent.mkdir(parents=True)
        Image.new("RGBA",(2048,128),(10,20,30,160)).save(old_png)
        frame_path=self.root/"assets/character/test/animation/runtime/guard.tres"
        frame_path.write_text('previous approved SpriteFrames')
        existing={"type":"animation-runtime","asset_id":"test-guard-stable-v01","character_id":"test","visual_state_id":"guard","path":str(old_png.relative_to(self.root)),"sha256":sha(old_png),"sprite_frames_path":"res://"+str(frame_path.relative_to(self.root)),"consumer_path":"res://"+str(frame_path.relative_to(self.root)),"fps":12,"loop":False,"frame_count":16,
            "creation":{"method":"Old fixture creation","provider":"old fixture","version":"v01"},
            "rights":{"status":"Old fixture rights","references":["fixture://old-art"]},"motion_unification":{"source_path":"old-source.png","source_sha256":"old-sha"},
            "source_path":"old-source.png","source_sha256":"old-sha","conversion":{"method":"Old fixture packing"},"verified_on":"old-date",
            "registration_history":[{"path":"older-version.png","sha256":"older-sha"}]}
        manifest["assets"].append(existing); write(self.fixture.fixture.manifest,manifest)
        self.prepare_art(24)
        plan,pending=self.plan(); self.fixture_approval(plan)
        old_bytes=old_png.read_bytes(); source_bytes=self.fixture.sheet.read_bytes()
        receipt=install(self.root,plan,pending,self.backup)
        self.assertEqual(receipt["status"],"installed")
        self.assertEqual(old_png.read_bytes(),old_bytes)
        self.assertEqual((self.root/self.config["motions"][0]["png_path"]).read_bytes(),source_bytes)
        updated=read(self.fixture.fixture.manifest)
        result=next(row for row in updated["assets"] if row.get("visual_state_id")=="guard")
        self.assertEqual(result["asset_id"],existing["asset_id"])
        self.assertEqual(result["consumer_path"],existing["consumer_path"])
        self.assertEqual(result["sprite_frames_path"],existing["sprite_frames_path"])
        self.assertEqual(result["frame_count"],24)
        for field,value in self.provenance.items():
            self.assertEqual(result[field],value)
        self.assertEqual(result["motion_registration"]["provenance"],self.provenance)
        self.assertNotIn("motion_unification",result)
        self.assertNotIn("verified_on",result)
        self.assertEqual(result["registration_history"][0],existing["registration_history"][0])
        self.assertEqual(result["registration_history"][1],{key:value for key,value in existing.items() if key!="registration_history"})
        self.assertNotIn("registration_history",result["registration_history"][1])
        self.assertEqual((self.backup/str(frame_path.relative_to(self.root))).read_text(),"previous approved SpriteFrames")
        self.assertEqual(updated["assets"][0],manifest["assets"][0])

    def test_registration_requires_current_complete_provenance(self):
        for field in self.provenance:
            with self.subTest(field=field):
                self.fixture.update_catalog(lambda doc: doc["assets"][0].update(self.provenance))
                self.fixture.update_catalog(lambda doc: doc["assets"][0].pop(field))
                self.prepare_art(24)
                before=self.snapshot()
                with self.assertRaisesRegex(ValueError,"requires explicit source_path"):
                    self.plan()
                self.assertEqual(before,self.snapshot())

    def test_registration_rejects_changed_original_source(self):
        Image.new("RGBA",(128,128),(90,80,70,180)).save(self.original_source)
        before=self.snapshot()
        with self.assertRaisesRegex(ValueError,"original source PNG SHA256"):
            self.plan()
        self.assertEqual(before,self.snapshot())

    def test_original_source_change_after_plan_refuses_before_backup(self):
        from register_motion_candidates import install
        plan,pending=self.plan()
        self.fixture_approval(plan)
        Image.new("RGBA",(128,128),(90,80,70,180)).save(self.original_source)
        before=self.snapshot()
        with self.assertRaisesRegex(ValueError,"original source PNG SHA256"):
            install(self.root,plan,pending,self.backup)
        self.assertEqual(before,self.snapshot())
        self.assertFalse(self.backup.exists())

    def test_registration_rejects_incomplete_origin_descriptions(self):
        import copy
        for field,key in [("creation","provider"),("rights","status"),("conversion","method"),("rights","references")]:
            with self.subTest(field=field,key=key):
                provenance=copy.deepcopy(self.provenance)
                provenance[field].pop(key)
                self.fixture.update_catalog(lambda doc: doc["assets"][0].update(provenance))
                self.prepare_art(24)
                before=self.snapshot()
                with self.assertRaisesRegex(ValueError,"candidate .* requires"):
                    self.plan()
                self.assertEqual(before,self.snapshot())

    def test_replacement_cannot_change_logical_id_or_sprite_consumer(self):
        manifest=read(self.fixture.fixture.manifest)
        existing={"type":"animation-runtime","asset_id":"test-original-stable","character_id":"test","visual_state_id":"guard","path":"assets/character/run.png","sprite_frames_path":"res://assets/character/run.tres","consumer_path":"res://assets/character/run.tres"}
        manifest["assets"].append(existing); write(self.fixture.fixture.manifest,manifest)
        self.prepare_art(24)
        with self.assertRaisesRegex(ValueError,"preserve its existing logical ID"):
            self.plan()


class CandidateFramesGodotTest(unittest.TestCase):
    def setUp(self):
        import shutil
        if not shutil.which("godot"):
            self.skipTest("Godot unavailable; candidate SpriteFrames integration must run before delivery")
        self.project = Path(__file__).resolve().parents[2]
        self.temp = tempfile.TemporaryDirectory(prefix="motion-tool-test-", dir=self.project / "_workspace")
        self.addCleanup(self.temp.cleanup)
        self.work = Path(self.temp.name)
        self.sheet = self.work / "test.png"
        Image.new("RGBA", (2048, 128), (20, 70, 150, 180)).save(self.sheet)
        self.sprite = self.work / "test.tres"
        self.sheet_res = "res://" + str(self.sheet.relative_to(self.project))
        regions = "\n".join('[sub_resource type="AtlasTexture" id="f%d"]\natlas = ExtResource("1")\nregion = Rect2(%d, 0, 128, 128)\n' % (i, i * 128) for i in range(16))
        frames = ", ".join('{"duration": 1.0, "texture": SubResource("f%d")}' % i for i in range(16))
        self.sprite.write_text('[gd_resource type="SpriteFrames" load_steps=18 format=3]\n[ext_resource type="Texture2D" path="%s" id="1"]\n%s\n[resource]\nanimations = [{"frames": [%s], "loop": false, "name": &"guard", "speed": 12.0}]\n' % (self.sheet_res, regions, frames))
        self.fixture = self.work / "entry.json"
        write(self.fixture, {"path": str(self.sheet.relative_to(self.project)), "sprite_frames_path": "res://" + str(self.sprite.relative_to(self.project)), "visual_state_id": "guard", "fps": 12, "loop": False})

    def run_godot(self):
        import subprocess
        return subprocess.run(["godot", "--headless", "--path", str(self.project), "--script", "res://tests/motion_candidate_frames.gd", "--", str(self.fixture)], text=True, capture_output=True, timeout=30)

    def variable_fixture(self,count,columns=16):
        durations=[1.0+(i%3)*0.25 for i in range(count)]
        image=Image.new("RGBA",(columns*128,((count+columns-1)//columns)*128),(0,0,0,0))
        for i in range(count): image.paste((20,70,150,180),((i%columns)*128,(i//columns)*128,(i%columns+1)*128,(i//columns+1)*128))
        image.save(self.sheet)
        regions="\n".join('[sub_resource type="AtlasTexture" id="f%d"]\natlas = ExtResource("1")\nregion = Rect2(%d, %d, 128, 128)\n' % (i,(i%columns)*128,(i//columns)*128) for i in range(count))
        frames=", ".join('{"duration": %s, "texture": SubResource("f%d")}' % (durations[i],i) for i in range(count))
        self.sprite.write_text('[gd_resource type="SpriteFrames" load_steps=%d format=3]\n[ext_resource type="Texture2D" path="%s" id="1"]\n%s\n[resource]\nanimations = [{"frames": [%s], "loop": false, "name": &"guard", "speed": 12.0}]\n' % (count+2,self.sheet_res,regions,frames))
        entry=read(self.fixture)
        entry.update(frame_count=count,atlas_columns=columns,frame_durations=durations)
        write(self.fixture,entry)

    def test_two_row_24_and_32_frames_and_variable_durations_load(self):
        for count,columns in [(24,12),(32,16)]:
            with self.subTest(count=count):
                self.variable_fixture(count,columns)
                before={p:p.read_bytes() for p in (self.sheet,self.sprite,self.fixture)}
                result=self.run_godot()
                self.assertEqual(result.returncode,0,result.stdout+result.stderr)
                self.assertEqual(before,{p:p.read_bytes() for p in before})
                self.assertFalse(self.sheet.with_suffix(".png.import").exists())

    def test_second_row_wrong_region_or_duration_rejected(self):
        self.variable_fixture(24)
        self.sprite.write_text(self.sprite.read_text().replace("Rect2(0, 128, 128, 128)","Rect2(0, 0, 128, 128)"))
        result=self.run_godot()
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertIn("PNG/order/region/duration differs",result.stdout)
        self.variable_fixture(32)
        entry=read(self.fixture)
        entry["frame_durations"][-1]=9.0
        write(self.fixture,entry)
        result=self.run_godot()
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertIn("PNG/order/region/duration differs",result.stdout)

    def test_nontransparent_unused_cells_and_wrong_counts_rejected(self):
        self.variable_fixture(24)
        with Image.open(self.sheet) as source:
            image=source.copy(); image.putpixel((2047,255),(0,0,0,255)); image.save(self.sheet)
        result=self.run_godot()
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertIn("unused atlas cell must be transparent",result.stdout)
        self.variable_fixture(32)
        entry=read(self.fixture); entry["frame_count"]=33; write(self.fixture,entry)
        result=self.run_godot()
        self.assertEqual(result.returncode,1,result.stdout+result.stderr)
        self.assertIn("invalid candidate frame_count",result.stdout)

    def test_ignored_workspace_png_and_real_spriteframes_load_without_import(self):
        result = self.run_godot()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("MOTION_CANDIDATE_FRAMES: PASS", result.stdout)
        self.assertFalse(self.sheet.with_suffix(".png.import").exists(), "review must never import or publish candidates")

    def test_real_spriteframes_reordered_region_is_rejected(self):
        self.sprite.write_text(self.sprite.read_text().replace("Rect2(0, 0, 128, 128)", "Rect2(128, 0, 128, 128)", 1))
        result = self.run_godot()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("PNG/order/region/duration differs", result.stdout)

    def test_real_spriteframes_fps_and_frame_duration_are_rejected(self):
        self.sprite.write_text(self.sprite.read_text().replace('"speed": 12.0', '"speed": 30.0').replace('"duration": 1.0', '"duration": 2.0', 1))
        result = self.run_godot()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("fps/loop differs", result.stdout)
        self.assertIn("PNG/order/region/duration differs", result.stdout)

    def test_real_preapproved_runtime_reuse_uses_its_existing_import(self):
        manifest = read(self.project / "assets/character/manifest.json")
        approved = next(row for row in manifest["assets"] if row.get("type") == "animation-runtime" and row.get("character_id") == "ja-hyun" and row.get("visual_state_id") == "guard")
        write(self.fixture, {**approved, "reuse_approved_runtime": True})
        result = self.run_godot()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("MOTION_CANDIDATE_FRAMES: PASS", result.stdout)

    def test_default_timeline_covers_all_approved_motions_and_registered_timings(self):
        import subprocess
        from review_motion_actions import entries
        timeline=self.work/"legacy-timeline.json"
        result=subprocess.run(["godot","--headless","--path",str(self.project),"--script","res://tools/forest_arena/motion_review_timeline.gd","--","--output",str(timeline)],text=True,capture_output=True,timeout=30)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        captured=read(timeline)
        approved = entries(self.project)
        self.assertGreaterEqual(len(approved),120)
        self.assertEqual({(r['character_id'],motion_id(r)) for r in approved},
                         {(r['character_id'],r['motion']) for r in captured['motions']})
        self.assertEqual(len(captured["motions"]),len(approved))
        self.assertEqual(timeline_errors(self.project,captured,approved),[])
        self.assertTrue(all(variant["samples"] for row in captured["motions"] for variant in row["variants"]))
        for row in approved:
            if row.get('motion_registration') and row['character_id']=='ja-hyun' and motion_id(row)=='attack_light_combo_04':
                kick = next(r for r in captured['motions'] if r['character_id']=='ja-hyun' and r['motion']=='attack_light_combo_04')
                self.assertEqual([(v['attack_id'],v['phase_ticks']) for v in kick['variants']],
                                 [('ja-hyun-light-04',[10,4,22])])
                self.assertIn('assets/combat/movesets/two_fighter_ja_hyun_moveset.tres',captured['sources'])
                from review_motion_actions import action
                expected, source = action(self.project,'ja-hyun','attack_light_combo_04')
                self.assertIn('킥',expected)
                self.assertEqual(source,'_workspace/motion-naturalness-v1/02_expectations.md')

    def test_candidate_timeline_uses_explicit_new_movesets_not_legacy_base(self):
        import subprocess
        from motion_review_candidates import load_selection
        manifest = read(self.project / "assets/character/manifest.json")
        rows = []
        for cid, motion in (("ja-hyun", "special_neutral"), ("nabi", "special_side")):
            approved = next(row for row in manifest["assets"] if row.get("type") == "animation-runtime" and row.get("character_id") == cid and row.get("visual_state_id") == motion)
            rows.append({**approved, "reuse_approved_runtime": True, "expected_action": "자동 도구 연결 검사; 사람의 행위 검토와 사용자 승인은 아직 하지 않았다.", "action_source": "_workspace/two-fighter-combat-v2/00_request.md"})
        self.sprite.write_text(self.sprite.read_text().replace('&"guard"', '&"special_scarf_sweep"'))
        rows.append({"type": "animation-candidate", "character_id": "ja-hyun", "visual_state_id": "special_scarf_sweep", "path": str(self.sheet.relative_to(self.project)), "sprite_frames_path": "res://" + str(self.sprite.relative_to(self.project)), "fps": 12, "loop": False, "expected_action": "자동 도구 연결 검사; 원화 행위는 QA 통과하지 않았다.", "action_source": "_workspace/two-fighter-combat-v2/00_request.md"})
        catalog = self.work / "catalog.json"
        scope = self.work / "scope.json"
        movesets = {"ja-hyun": "assets/combat/movesets/two_fighter_ja_hyun_moveset.tres", "nabi": "assets/combat/movesets/two_fighter_nabi_moveset.tres"}
        write(catalog, {"schema_version": 1, "kind": "motion-candidates", "approval_status": "pending", "character_movesets": movesets, "attack_sources": list(movesets.values()), "assets": rows})
        write(scope, {"schema_version": 1, "kind": "candidate-motion-review", "catalog_sha256": sha(catalog), "motions": [{"character_id": row["character_id"], "motion": row["visual_state_id"]} for row in rows]})
        timeline = self.work / "timeline.json"
        result = subprocess.run(["godot", "--headless", "--path", str(self.project), "--script", "res://tools/forest_arena/motion_review_timeline.gd", "--", "--output", str(timeline), "--catalog", str(catalog), "--scope", str(scope), "--scope-sha256", sha(scope)], text=True, capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("MOTION_REVIEW_TIMELINE: PASS (3 motions)", result.stdout)
        captured = read(timeline)
        self.assertEqual(timeline_errors(self.project, captured, rows, load_selection(self.project, catalog, scope)), [])
        variants = {variant["attack_id"]: variant for row in captured["motions"] for variant in row["variants"]}
        self.assertEqual(set(variants), {"ja-hyun-heavy", "ja-hyun-special", "nabi-special"})
        self.assertEqual(variants["ja-hyun-heavy"]["phase_ticks"], [12, 5, 20])
        self.assertEqual(variants["ja-hyun-special"]["phase_ticks"], [12, 60, 24])
        self.assertEqual(variants["nabi-special"]["phase_ticks"], [10, 24, 20])
        self.assertIn("scripts/fighter_attack_effects.gd", captured["sources"])
        output = self.work / "materials"
        prepare(self.project, timeline, output, catalog, scope, sha(scope))
        pending = read(output / "motion-review.json")
        self.assertTrue(all(row["status"] == "blocked" for row in pending["motions"]))
        self.assertTrue(validate(self.project, output / "motion-review.json", True, catalog, scope))


if __name__ == "__main__":
    unittest.main()
