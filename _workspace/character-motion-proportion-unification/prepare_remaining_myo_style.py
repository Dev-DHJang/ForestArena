"""Generate prompt records for the remaining states; no image generation or runtime writes."""
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
BATCH=WORK/"06_myo_ryung-style-locked"

def main():
    approval=json.loads((BATCH/"approval-proof-3.json").read_text())
    assert approval["user_approved"]
    for row in approval["files"]:
        assert hashlib.sha256((ROOT/row["path"]).read_bytes()).hexdigest()==row["sha256"], row["path"]
    proofs=json.loads((BATCH/"generation-prompts-r01.json").read_text())
    common=proofs[0]["prompt"].split("\nMOTION idle:")[0]
    intents=json.loads((WORK/"05_myo_ryung/generation-prompts-r02.json").read_text())
    entries=[e for e in json.loads((WORK/"01_baseline.json").read_text())["runtime_entries"] if e["character_id"]=="myo-ryung"]
    expected={e["visual_state_id"] for e in entries}-set(approval["approved_states"])
    refs=proofs[0]["referenced_image_paths"]
    records=[]
    for old in intents:
        state=old["state"]
        if state not in expected:
            continue
        intent=old["intent"]
        for phrase in ("as in the action reference", "as in the reference", "as in the action reference:", "Preserve the reference's physical entrance", "Preserve the existing action reference's hand-led attack"):
            intent=intent.replace(phrase, {"Preserve the reference's physical entrance":"Keep a physical entrance", "Preserve the existing action reference's hand-led attack":"Keep a hand-led attack"}.get(phrase,""))
        entry=next(e for e in entries if e["visual_state_id"]==state)
        records.append({"state":state,"intent":intent,"prompt":common+"\nMOTION "+state+": "+intent,
                        "referenced_image_paths":refs,"transparent_background":False,
                        "fps":entry["fps"],"loop":entry["loop"]})
    assert len(records)==28 and {r["state"] for r in records}==expected
    destination=BATCH/"05_remaining/generation-prompts-r01.json"
    assert not destination.exists(), "Do not overwrite recorded prompts"
    destination.write_text(json.dumps(records,ensure_ascii=False,indent=2)+"\n")
    print("28 remaining prompts, identical common style block and only the two selected-master references.")

if __name__=="__main__":
    main()
