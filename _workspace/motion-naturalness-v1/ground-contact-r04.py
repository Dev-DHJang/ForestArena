"""Create a separate review version; preserve r03 pixels and its QA record."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
base = Path(__file__).resolve().parent
proposal = json.loads((base / "qa/remaining-independent-r01/ground-contact-proposals.json").read_text())
catalog = json.loads((base / "remaining-candidate-catalog.json").read_text())
assert hashlib.sha256((base / "remaining-candidate-catalog.json").read_bytes()).hexdigest() == proposal["catalog_sha256"]
changes = {}
for motion in proposal["motions"]:
    key = (motion["character_id"], motion["motion"])
    old = next(row for row in catalog["assets"] if (row["character_id"], row["visual_state_id"]) == key)
    assert old["sha256"] == motion["sha256"]
    spec = json.loads((root / old["conversion"]["spec_path"]).read_text())
    spec["version"] = "r04-ground"
    # Keep X at the common pivot. QA's contact X identifies a hand/shoe/body,
    # not a request to shift the whole fighter sideways between poses.
    spec["frame_anchors"] = [
        {"body_root": [64, frame["ground_contact_xy"][1]]} if frame["ground_contact_xy"] else {}
        for frame in motion["frames"]
    ]
    spec["ground_contact_review"] = {
        "source": "_workspace/motion-naturalness-v1/qa/remaining-independent-r01/ground-contact-proposals.json",
        "reviewed_by": "remaining_motion_qa; root directly checked contact proposal boards",
        "method": "whole-frame Y display alignment only; airborne knock-down poses remain unaligned",
    }
    path = base / "remaining/layout-specs" / ("%s-%s-r04-ground.json" % key)
    path.write_text(json.dumps(spec, ensure_ascii=False, indent=2) + "\n")
    subprocess.run([sys.executable, str(base / "pack-remaining.py"), str(path)], cwd=root, check=True)
    row_path = base / "candidates/remaining" / key[0] / (key[1] + "_r04-ground.json")
    row = json.loads(row_path.read_text())
    assert row["sha256"] == old["sha256"], "contact metadata must preserve the actual source pixels"
    changes[key] = row

updated = copy.deepcopy(catalog)
# The newly requested barrage has its own art/QA version; do not carry its old
# 32-frame sweep into a new request as though it were still the current design.
updated["assets"] = [changes.get((row["character_id"], row["visual_state_id"]), row)
                     for row in catalog["assets"]
                     if (row["character_id"], row["visual_state_id"]) != ("ja-hyun", "special_scarf_sweep")]
assert len(updated["assets"]) == 25
catalog_path = base / "remaining-candidate-catalog-r04.json"
catalog_path.write_text(json.dumps(updated, ensure_ascii=False, indent=2) + "\n")
scope = {"schema_version": 1, "kind": "candidate-motion-review",
         "catalog_sha256": hashlib.sha256(catalog_path.read_bytes()).hexdigest(),
         "motions": [{"character_id": row["character_id"], "motion": row["visual_state_id"]}
                     for row in updated["assets"]]}
scope_path = base / "remaining-candidate-scope-r04.json"
scope_path.write_text(json.dumps(scope, ensure_ascii=False, indent=2) + "\n")
scope_path.with_suffix(".sha256").write_text(hashlib.sha256(scope_path.read_bytes()).hexdigest() + "\n")
print("r04: 25 review motions; five pixel-identical sheets receive contact metadata; old r03 unchanged")
print(scope["catalog_sha256"])
