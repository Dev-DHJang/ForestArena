"""Review derivatives only; verify lossless source and draw every captured tick."""
import hashlib
import json
from pathlib import Path
import subprocess
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[4]
BASE = ROOT / "_workspace/hit-reaction-restart-v1/qa"
OUT = Path(__file__).resolve().parent
result = {"scope": "all 240 captured RGBA frames, source hashes and archive receipts", "clips": []}
for variant in ["live-normal-r01", "live-mirror-small-r01"]:
    folder = BASE / variant
    receipt = json.loads((folder / "raw-archive.json").read_text())
    report_file = folder / "state-report.json"
    report = json.loads(report_file.read_text())
    assert not report["errors"]
    assert receipt["capture_report_sha256"] == hashlib.sha256(report_file.read_bytes()).hexdigest()
    for name, digest in report["sources"].items():
        assert hashlib.sha256((ROOT / name).read_bytes()).hexdigest() == digest, name
    for clip in receipt["clips"]:
        path = folder / clip["archive"]
        assert hashlib.sha256(path.read_bytes()).hexdigest() == clip["archive_sha256"]
        raw = subprocess.check_output(["ffmpeg", "-v", "error", "-i", str(path), "-pix_fmt", "rgba", "-f", "rawvideo", "-"])
        assert hashlib.sha256(raw).hexdigest() == clip["source_raw_sha256"]
        frame_bytes = 1280 * 720 * 4
        assert len(raw) == 60 * frame_bytes
        row = next(s for s in report["scenarios"] if s["name"] == clip["clip"])
        board_paths = []
        for half in range(2):
            board = Image.new("RGB", (1440, 1100), "#10202e")
            draw = ImageDraw.Draw(board)
            for cell, tick in enumerate(range(half * 30, (half + 1) * 30)):
                pixels = raw[tick * frame_bytes:(tick + 1) * frame_bytes]
                assert hashlib.md5(pixels).hexdigest() == clip["rgba_md5"][tick]
                frame = Image.frombytes("RGBA", (1280, 720), pixels)
                if "mirror" in variant:
                    frame = frame.crop((560, 260, 720, 400)).resize((240, 210))
                else:
                    frame = frame.crop((520, 205, 760, 415))
                x, y = cell % 6 * 240, cell // 6 * 220
                board.paste(frame.convert("RGB"), (x, y))
                visual = row["states"][tick]["drawn"][0]
                label = f"t{tick:02d} {visual['shown_motion']} f{visual['frame']:02d}"
                draw.rectangle((x, y + 192, x + 239, y + 219), fill="#10202e")
                draw.text((x + 3, y + 197), label, fill="white")
            target = OUT / f"{variant}__{clip['clip']}__{half + 1}.png"
            board.save(target)
            board_paths.append(str(target.relative_to(ROOT)))
        result["clips"].append({"variant": variant, "clip": clip["clip"], "frames": 60, "all_rgba_frames_match_receipt": True, "capture_sources_match_current_files": True, "boards": board_paths})
        print(variant, clip["clip"], "60 frames verified")

manifest = json.loads((ROOT / "assets/character/manifest.json").read_text())
asset_paths = ["assets/character/manifest.json"]
for entry in manifest["assets"]:
    if entry.get("type") != "animation-runtime" or entry.get("character_id") not in ["ja-hyun", "nabi"] or entry.get("visual_state_id") not in ["idle", "hitstun"]:
        continue
    png = entry["path"].removeprefix("res://")
    assert hashlib.sha256((ROOT / png).read_bytes()).hexdigest() == entry["sha256"]
    asset_paths.extend([png, entry["sprite_frames_path"].removeprefix("res://")])
result["current_runtime_asset_hashes"] = {p: hashlib.sha256((ROOT / p).read_bytes()).hexdigest() for p in asset_paths}
(OUT / "capture-verification.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
