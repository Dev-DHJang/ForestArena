"""Read the exported APK and verify actual icon pixels and packed boot settings."""
from pathlib import Path
from PIL import Image
import hashlib
import argparse
import io
import json
import re
import subprocess
import tempfile
import zipfile
import numpy as np

TASK = Path(__file__).resolve().parent
ROOT = TASK.parents[1]
ASSETS = ROOT / "assets/branding/myo-ryung-v02"
parser = argparse.ArgumentParser()
parser.add_argument("--apk", type=Path, default=ROOT / "build/android/ForestArena-debug.apk")
APK = parser.parse_args().apk.resolve()
issues = []


def check(condition, message):
    if not condition:
        issues.append(message)


def compare_icon(original, packed):
    if original.size != packed.size:
        return {"valid": False, "size_equal": False}
    a = np.asarray(original, dtype=np.int16)
    b = np.asarray(packed, dtype=np.int16)
    delta = np.abs(a - b)
    alpha_equal = bool(np.array_equal(a[:, :, 3], b[:, :, 3]))
    opaque = a[:, :, 3] == 255
    opaque_rgb_equal = bool(np.array_equal(a[:, :, :3][opaque], b[:, :, :3][opaque]))
    premultiplied = delta[:, :, :3] * (a[:, :, 3:4] / 255.0)
    mean_delta = float(premultiplied.mean())
    changed = np.any(delta > 0, axis=2)
    return {
        "valid": alpha_equal and opaque_rgb_equal and mean_delta < 0.05,
        "rgba_bytes_equal": original.tobytes() == packed.tobytes(),
        "alpha_equal": alpha_equal,
        "opaque_rgb_equal": opaque_rgb_equal,
        "changed_pixels": int(changed.sum()),
        "changed_visible_pixels": int(np.count_nonzero(changed & (a[:, :, 3] > 0))),
        "changed_alpha_range": [int(a[:, :, 3][changed].min()), int(a[:, :, 3][changed].max())] if changed.any() else None,
        "premultiplied_mean_channel_delta_255": mean_delta,
        "premultiplied_max_channel_delta_255": float(premultiplied.max()),
    }


manifest = json.loads((ASSETS / "manifest.json").read_text())
for entry in manifest["assets"]:
    path = ROOT / entry["path"]
    check(hashlib.sha256(path.read_bytes()).hexdigest() == entry["sha256"], "Asset hash: " + path.name)
    with Image.open(path) as im:
        check(list(im.size) == entry["size"], "Asset size: " + path.name)

foreground = Image.open(ASSETS / "adaptive-foreground-432.png").convert("RGBA")
alpha = foreground.getchannel("A")
check(alpha.getextrema() == (0, 255), "Foreground must have true transparency")
check(alpha.getbbox()[0] >= 36 and alpha.getbbox()[2] <= 396, "Foreground horizontal packing bounds")
check(alpha.getbbox()[1] >= 10 and alpha.getbbox()[3] <= 370, "Foreground vertical packing bounds")
# Visible connected shoulders and clothes must continue through the bottom of the launcher viewport.
check(int(np.count_nonzero(np.asarray(alpha)[345:360, 140:292] > 128)) > 1500, "Bust must continue to launcher bottom")
backup = TASK / "source/approved-myo-ryung.png"
check(hashlib.sha256(backup.read_bytes()).hexdigest() == manifest["approved_source_sha256"], "Approved source copy changed")

native = {
    "main-192.png": "res/mipmap-xxxhdpi-v4/icon.webp",
    "adaptive-foreground-432.png": "res/mipmap-xxxhdpi-v4/icon_foreground.webp",
    "adaptive-background-432.png": "res/mipmap-xxxhdpi-v4/icon_background.webp",
}
native_results = []
with zipfile.ZipFile(APK) as archive:
    for filename, packed_path in native.items():
        original = Image.open(ASSETS / filename).convert("RGBA")
        packed = Image.open(io.BytesIO(archive.read(packed_path))).convert("RGBA")
        comparison = compare_icon(original, packed)
        check(comparison["valid"], "APK native icon differs materially: " + filename)
        native_results.append({"source": filename, "apk_path": packed_path, **comparison})
    splash = Image.open(io.BytesIO(archive.read("res/drawable/splash_icon.webp"))).convert("RGBA")
    splash_comparison = compare_icon(foreground, splash)
    check(splash_comparison["valid"], "Android system splash must use Myo-ryung foreground")
    branding = Image.open(io.BytesIO(archive.read("res/drawable/splash_branding_image.webp"))).convert("RGBA")
    check(branding.getchannel("A").getextrema() == (0, 0), "Unexpected Android branding image")
    check(archive.read("assets/assets/branding/myo-ryung-v02/app-icon-1024.png") == (ASSETS / "app-icon-1024.png").read_bytes(), "Packed project icon differs")
    with tempfile.TemporaryDirectory(prefix="fa-app-branding-") as temporary:
        Path(temporary, "project.binary").write_bytes(archive.read("assets/project.binary"))
        result = subprocess.run(["godot", "--headless", "--path", temporary, "--script", str(TASK / "inspect_packaged_boot.gd")], text=True, capture_output=True, timeout=30)
        check(result.returncode == 0 and "SCRIPT ERROR" not in result.stderr, "Cannot inspect packed ProjectSettings")
        line = next((line for line in result.stdout.splitlines() if line.startswith("PACKAGED_BOOT ")), "")
        check(bool(line), "Packed boot settings were not read")
        boot = json.loads(line.removeprefix("PACKAGED_BOOT ")) if line else {}
        check(boot.get("show_image") is False, "Godot boot logo is enabled in APK")
        check(boot.get("minimum_display_time") == 0, "Unexpected boot display delay")
        check(boot.get("main_scene") == "res://scenes/startup_title.tscn", "Game entry scene changed")
        check(boot.get("icon") == "res://assets/branding/myo-ryung-v02/app-icon-1024.png", "Packed icon fallback")

report = {
    "status": "PASS" if not issues else "FIX",
    "apk_sha256": hashlib.sha256(APK.read_bytes()).hexdigest(),
    "native_icon_checks": native_results,
    "system_splash": "Myo-ryung foreground; branding image fully transparent",
    "system_splash_pixel_comparison": splash_comparison,
    "packed_boot_settings": boot,
    "physical_device": "not-run; requires connected physical Android",
    "issues": issues,
}
(TASK / "branding-checks.json").write_text(json.dumps(report, ensure_ascii=False, indent=2))
print(json.dumps(report, ensure_ascii=False, indent=2))
raise SystemExit(bool(issues))
