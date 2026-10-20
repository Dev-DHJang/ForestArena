"""Review integrity regressions; these tests do not judge artwork semantics."""
import tempfile
import unittest
from pathlib import Path

from PIL import Image, UnidentifiedImageError

from review_motion_actions import CHECKS, compact, prepare, read, sha, timeline_errors, validate, write


class MotionActionReviewTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for path in ("assets/character", "docs/contracts", "docs/gameplay", "scripts"):
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
        timeline_sources = {p: sha(self.root / p) for p in ["assets/character/manifest.json", "assets/character/run.tres", "scripts/local_fighter_presentation.gd", "scripts/fighter_controller.gd", "docs/contracts/attack-system-v01.json", "docs/gameplay/combat.md"]}
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
        (self.root / "tools/forest_arena").mkdir(parents=True)
        for name in ("motion_review_candidates.py", "review_motion_actions.py", "motion_review_timeline.gd", "motion_review_candidate_frames.gd"):
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
