"""Lossless full-frame capture archive, with every restored RGBA frame checked."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess

def digest(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def hashes(arguments):
    value = subprocess.check_output(["ffmpeg","-v","error",*arguments,"-pix_fmt","rgba","-f","framemd5","-"]).decode()
    return [line.rsplit(",",1)[1].strip() for line in value.splitlines() if line and not line.startswith("#")]

p = argparse.ArgumentParser()
p.add_argument("capture",type=Path)
args = p.parse_args()
base = args.capture.resolve()
assert base.is_relative_to(Path(__file__).resolve().parent / "qa")
report_path = base / "state-report.json"
report = json.loads(report_path.read_text())
assert report["errors"] == []
records = []
for clip in report["scenarios"]:
    assert clip["actual_fixed_tick"] and not clip["synthetic_phases"] and not clip["state_only"] and clip["capture_stride"] == 1
    folder = base / clip["name"]
    files = sorted(folder.glob("frame-*.png"))
    assert [f.name for f in files] == ["frame-%03d.png" % i for i in range(clip["frame_count"])]
    inputs = ["-framerate","60","-i",str(folder / "frame-%03d.png")]
    original = hashes(inputs)
    movie = base / (clip["name"]+"-lossless-rgb.mkv")
    preview = base / (clip["name"]+".mp4")
    assert not movie.exists() and not preview.exists()
    subprocess.run(["ffmpeg","-v","error",*inputs,"-c:v","libx264rgb","-crf","0","-preset","slow","-pix_fmt","rgb24",str(movie)],check=True)
    assert original == hashes(["-i",str(movie)])
    subprocess.run(["ffmpeg","-v","error","-i",str(movie),"-c:v","libx264","-crf","18","-pix_fmt","yuv420p","-movflags","+faststart",str(preview)],check=True)
    records.append({"clip":clip["name"],"source_frames":len(files),"fps":60,"archive":movie.name,"archive_sha256":digest(movie),"rgba_md5":original,"png_sha256":{f.name:digest(f) for f in files}})
receipt = base / "rgba-archive.json"
assert not receipt.exists()
receipt.write_text(json.dumps({"capture_report_sha256":digest(report_path),"status":"all60Hz captured RGBA frames restore exactly; visual judgment remains separate","clips":records},ensure_ascii=False,indent=2)+"\n")
backup = Path("/tmp/forest-arena-barrage-pngs-20261024") / base.name
backup.mkdir(parents=True,exist_ok=True)
for clip in report["scenarios"]:
    target = backup / clip["name"]
    target.mkdir(exist_ok=True)
    for file in (base / clip["name"]).glob("frame-*.png"):
        assert not (target / file.name).exists()
        shutil.move(str(file),str(target / file.name))
print("archived",sum(row["source_frames"] for row in records),"RGBA frames; source PNGs preserved at",backup)
