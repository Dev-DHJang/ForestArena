"""Check both simulation evidence and the renderer log before accepting a clip."""
import argparse
import hashlib
import json
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("capture", type=Path)
parser.add_argument("--log", required=True, type=Path)
parser.add_argument("--clips", required=True, type=int)
args = parser.parse_args()
root = Path(__file__).resolve().parents[2]
report = json.loads((args.capture / "state-report.json").read_text())
log = args.log.read_text()
problems = []
if report["errors"]:
    problems.append("simulation checks failed")
if len(report["scenarios"]) != args.clips or args.clips < 1:
    problems.append("requested clips are missing")
if any(marker in log for marker in ("ERROR:", "SCRIPT ERROR:", "FAIL", "Traceback")):
    problems.append("renderer or script error in log")
if "PILOT_LIVE_RENDER: PASS" not in log:
    problems.append("render process did not report completion")
for clip in report["scenarios"]:
    if len(clip["states"]) != clip["frame_count"] or clip["state_only"]:
        problems.append("incomplete pixel capture")
    if not clip["actual_fixed_tick"] or clip["synthetic_phases"] or clip["capture_stride"] != 1:
        problems.append("not an every-tick live capture")
for path, expected in report["sources"].items():
    actual = hashlib.sha256((root / path).read_bytes()).hexdigest()
    if actual != expected:
        problems.append("source changed: " + path)
print(json.dumps({"status": "FAIL" if problems else "PASS", "problems": problems,
                  "clips": len(report["scenarios"]),
                  "frames": sum(clip["frame_count"] for clip in report["scenarios"])},
                 ensure_ascii=False, indent=2))
raise SystemExit(1 if problems else 0)
