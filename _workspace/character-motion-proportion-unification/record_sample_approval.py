"""Bind the user's approval to the exact three reviewed sample images."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent


def main():
    path = WORK / "03_sample_review/report.json"
    report = json.loads(path.read_text())
    approved = []
    for row in report["samples"]:
        actual = hashlib.sha256((ROOT / row["review_path"]).read_bytes()).hexdigest()
        assert actual == row["review_sha256"], row["character_id"]
        approved.append({"character_id": row["character_id"], "visual_state_id": "idle", "path": row["review_path"], "sha256": actual})
        row["user_approved"] = True
    receipt = {"user_approved": True, "approved_on": "2026-10-15", "user_message": "승인한다.",
               "approval_scope": "Three idle samples: body proportions and displayed size. Not approval of the remaining unmade motions or production installation.",
               "samples": approved}
    target = WORK / "03_sample_approval.json"
    assert not target.exists(), "Approval already recorded; do not replace it."
    target.write_text(json.dumps(receipt, ensure_ascii=False, indent=2) + "\n")
    report["status"] = "sample-proportions-approved"
    report["approval_record"] = str(target.relative_to(ROOT))
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("SAMPLE APPROVAL: three exact reviewed idle samples, 2026-10-15.")


if __name__ == "__main__":
    main()
