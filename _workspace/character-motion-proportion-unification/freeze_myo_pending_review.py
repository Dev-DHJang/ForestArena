"""Freeze the 28 shown candidates without granting approval."""
from pathlib import Path
import hashlib
import json

ROOT=Path(__file__).resolve().parents[2]
WORK=Path(__file__).resolve().parent
BATCH=WORK/"06_myo_ryung-style-locked"

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    target=BATCH/"05_remaining/pending-review-28.json"
    assert not target.exists(), "Review already frozen; do not silently replace the shown files"
    report_path=BATCH/"04_review/31-motion-report.json"
    report=json.loads(report_path.read_text())
    rows=[r for r in report["states"] if not r["user_approved"]]
    assert len(rows)==28
    states=[]
    for row in rows:
        path=ROOT/row["review_path"]
        assert sha(path)==row["review_sha256"]
        source=ROOT/row["source_path"]
        assert sha(source)==row["source_sha256"]
        files=[{"path":str(p.relative_to(ROOT)),"sha256":sha(p)} for p in sorted(path.parent.iterdir()) if p.is_file()]
        files.append({"path":row["source_path"],"sha256":sha(source)})
        states.append({"visual_state_id":row["visual_state_id"],"user_approved":False,"files":files,
                       "review_path":row["review_path"],"review_sha256":row["review_sha256"]})
    result={"date":"2026-10-16","timezone":"Asia/Seoul","status":"pending-user-approval","user_approved":False,
            "approved_3_record":"../approval-proof-3.json","review_report_sha256":sha(report_path),"states":states,
            "scope":"Exact 28 new review candidates shown to the user; no runtime installation approval or inferred approval."}
    target.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print("Frozen 28 review candidates; approval is still pending.")

if __name__=="__main__":
    main()
