"""Archive captured review samples without claiming full-frame visual coverage."""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def rgba_frame_hashes(arguments: list[str]) -> list[str]:
    raw = subprocess.check_output(["ffmpeg", "-v", "error", *arguments,
                                   "-pix_fmt", "rgba", "-f", "framemd5", "-"]).decode()
    return [line.rsplit(",", 1)[1].strip() for line in raw.splitlines()
            if line and not line.startswith("#")]


parser = argparse.ArgumentParser()
parser.add_argument("capture", type=Path)
args = parser.parse_args()
base = args.capture.resolve()
qa = Path(__file__).resolve().parent / "qa"
assert base.is_relative_to(qa.resolve()) and base.name.startswith("remaining-")
report_path = base / "state-report.json"
report = json.loads(report_path.read_text())
assert report["errors"] == [] and report["scenarios"]
receipt = base / "sample-archive.json"
assert not receipt.exists()
records = []
for clip in report["scenarios"]:
    assert not clip["state_only"] and clip["actual_fixed_tick"] and not clip["synthetic_phases"]
    stride = int(clip["capture_stride"])
    assert 1 <= stride <= 4 and 60 % stride == 0
    folder = base / clip["name"]
    frames = sorted(folder.glob("frame-*.png"))
    expected = [f"frame-{index:03d}.png" for index in range(0, clip["frame_count"], stride)]
    assert [frame.name for frame in frames] == expected, f"incomplete samples: {clip['name']}"
    source = str(folder / "frame-*.png")
    input_args = ["-framerate", str(60 // stride), "-pattern_type", "glob", "-i", source]
    original = rgba_frame_hashes(input_args)
    movie = base / f"{clip['name']}-lossless-sampled-rgb.mkv"
    assert not movie.exists()
    subprocess.run(["ffmpeg", "-v", "error", *input_args, "-c:v", "libx264rgb",
                    "-crf", "0", "-preset", "slow", "-pix_fmt", "rgb24", str(movie)], check=True)
    restored = rgba_frame_hashes(["-i", str(movie)])
    assert len(original) == len(frames) and original == restored, f"RGBA mismatch: {clip['name']}"
    records.append({"clip": clip["name"], "source_ticks": clip["frame_count"],
                    "sample_stride_ticks": stride, "sampled_frames": len(frames),
                    "sample_names": expected, "archive": movie.name, "archive_sha256": digest(movie),
                    "png_sha256": {frame.name: digest(frame) for frame in frames},
                    "rgba_md5": original})
receipt.write_text(json.dumps({"capture_report_sha256": digest(report_path),
                               "status": "sampled screenshots archived losslessly; motion quality review remains separate",
                               "clips": records}, ensure_ascii=False, indent=2) + "\n")
print(f"archived {len(records)} sampled clips; checked {sum(row['sampled_frames'] for row in records)} RGBA frames")
