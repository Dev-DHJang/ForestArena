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


if __name__ == "__main__":
    unittest.main()
