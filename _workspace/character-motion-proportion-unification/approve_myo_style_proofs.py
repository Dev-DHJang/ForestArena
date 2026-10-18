"""Record the human's three-motion approval, bound to immutable output hashes."""
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
BATCH=WORK/"06_myo_ryung-style-locked"
EXPECTED={"idle":"11c9cb76fd51cf6d8562c5e1978e62029c3042ab3919a39d946655c40a8c2a84",
          "run":"238a36b938fe32a1ebf78d6ee30551c03146eb649cad1dca8540690f9356ddb8",
          "attack_air_heavy":"c2d371664a604767c821aee2634edba71aa28b23117acd68d2798bab388d4ef1"}

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    receipt=BATCH/"approval-proof-3.json"
    assert not receipt.exists(), "Approval already recorded; do not overwrite"
    report_path=BATCH/"04_review/report.json"
    report=json.loads(report_path.read_text())
    assert {r["visual_state_id"] for r in report["states"]}==set(EXPECTED)
    files=[]
    for row in report["states"]:
        state=row["visual_state_id"]
        assert row["review_sha256"]==EXPECTED[state]==sha(ROOT/row["review_path"])
        assert row["source_sha256"]==sha(ROOT/row["source_path"])
        for path in sorted((BATCH/"04_review"/state).glob("*")):
            if path.is_file():
                files.append({"path":str(path.relative_to(ROOT)),"sha256":sha(path)})
        files.append({"path":row["source_path"],"sha256":sha(ROOT/row["source_path"])})
        row["user_approved"]=True
        row["approval_record"]=str(receipt.relative_to(ROOT))
    selection=json.loads((BATCH/"01_style_reference/selection.json").read_text())
    for path,expected in zip(selection["reference_paths"],selection["reference_sha256"]):
        assert sha(ROOT/path)==expected
        files.append({"path":path,"sha256":expected})
    record={"user_approved":True,"date":"2026-10-15","timezone":"Asia/Seoul","user_text":"승인한다.",
            "approved_states":EXPECTED,"files":files,
            "scope":"Approval of the three displayed remade motions and continuation of the remaining Myo-Ryung batch. Not approval of unmade states or early runtime installation.",
            "style_selection_sha256":sha(BATCH/"01_style_reference/selection.json")}
    receipt.write_text(json.dumps(record,ensure_ascii=False,indent=2)+"\n")
    report["status"]="three-style-proofs-user-approved"
    report["approval_record"]=str(receipt.relative_to(ROOT))
    report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2)+"\n")
    print("MYO STYLE PROOF APPROVAL: 3 approved motions, all displayed files hash-bound; remaining 28 pending.")

if __name__=="__main__":
    main()
