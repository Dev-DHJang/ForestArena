#!/usr/bin/env python3
"""Copy existing MENU09 images and make native Godot video copies of the review media."""

import argparse
import hashlib
import json
import shutil
import struct
import subprocess
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
RECORDS = Path(__file__).resolve().parent
ASSET_MAP = ROOT / "_workspace/menu-sketch-ui/media-assets-r01/asset-map.json"
REGISTRY = ROOT / "forest_arena/data/resource_registry.json"
OUTPUT = ROOT / "forest_arena/assets/ui/menu09-media"
ARTIFACTS = {"iron-armor", "boxing-gloves", "thorns", "explosive-gloves", "ultimate-charm", "phoenix-revive"}
CHARACTERS = {"myo-ryung", "ja-hyun", "nabi", "yu-ran"}
TECHNIQUES = {"light", "heavy", "jump-light", "jump-heavy", "special"}
VIDEO_SLOTS = {f"VIDEO/{owner}/{clip}" for owner in CHARACTERS for clip in TECHNIQUES}
VIDEO_SLOTS.update({"VIDEO/accessory/iron-armor", "VIDEO/accessory/pebble-yoyo"})


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verified_source(relative_path, expected_hash):
    path = ROOT / relative_path
    if sha256(path) != expected_hash:
        raise ValueError(f"Review media SHA256 differs: {relative_path}")
    return path


def png_size(path):
    with path.open("rb") as file:
        header = file.read(24)
    if header[:8] != b"\x89PNG\r\n\x1a\n" or header[12:16] != b"IHDR":
        raise ValueError(f"Invalid PNG header: {path}")
    return struct.unpack(">II", header[16:24])


def video_probe(path):
    data = json.loads(subprocess.check_output([
        "ffprobe", "-v", "error", "-show_entries",
        "stream=codec_name,codec_type,width,height,r_frame_rate,duration:format=duration",
        "-of", "json", str(path),
    ]))
    return data["streams"], float(data["format"]["duration"])


def make_row(logical_id, relative, name, size):
    path = OUTPUT / relative
    extension = path.suffix[1:]
    return {
        "id": logical_id,
        "relative_path": path.relative_to(ROOT / "forest_arena/assets").as_posix(),
        "category": "video" if extension == "ogv" else "ui",
        "purpose": name,
        "priority": "current",
        "quality_dependent": False,
        "path": "res://" + path.relative_to(ROOT).as_posix(),
        "format": extension,
        "width": size[0],
        "height": size[1],
    }


def copy_image(stage, logical_id, relative, name, source_path, expected_hash):
    source = verified_source(source_path, expected_hash)
    target = stage / relative
    shutil.copyfile(source, target)
    copied_hash = sha256(target)
    if copied_hash != expected_hash:
        raise ValueError(f"Copied image SHA256 differs: {relative}")
    return make_row(logical_id, relative, name, png_size(source)), {
        "id": logical_id, "source": source_path, "source_sha256": expected_hash,
        "path": (OUTPUT / relative).relative_to(ROOT).as_posix(),
        "sha256": copied_hash, "bytes": target.stat().st_size,
    }


def encode_video(source, target, encoder):
    decode_args = [
        "ffmpeg", "-v", "error", "-i", str(source), "-vf", "scale=960:540:flags=lanczos,fps=30",
        "-an", "-pix_fmt", "yuv420p", "-f", "yuv4mpegpipe", "-",
    ]
    encode_args = [encoder, "-v", "8", "-z", "2", "-k", "30", "-q", "-o", str(target), "-"]
    with subprocess.Popen(decode_args, stdout=subprocess.PIPE) as decoder:
        try:
            subprocess.run(encode_args, stdin=decoder.stdout, check=True, capture_output=True)
        except subprocess.CalledProcessError as exc:
            raise RuntimeError(exc.stderr.decode(errors="replace")) from exc
        finally:
            decoder.stdout.close()
        if decoder.wait() != 0:
            raise RuntimeError(f"FFmpeg could not read {source.name}")


def make_clip(stage, encoder, asset):
    _, owner, clip = asset["slot"].split("/")
    slug = owner + "-" + clip
    poster_id = f"fa.ui.menu09.poster.{owner}.{clip}"
    video_id = f"fa.ui.menu09.video.{owner}.{clip}"
    poster_row, poster = copy_image(
        stage, poster_id, Path("posters") / f"{slug}.png", asset["name"] + " 포스터",
        asset["poster"], asset["poster_sha256"],
    )
    source = verified_source(asset["file"], asset["sha256"])
    relative = Path("videos") / f"{slug}.ogv"
    target = stage / relative
    encode_video(source, target, encoder)
    streams, duration = video_probe(target)
    _, source_duration = video_probe(source)
    if len(streams) != 1 or streams[0].get("codec_name") != "theora":
        raise ValueError(f"Expected one Theora video stream: {slug}")
    stream = streams[0]
    if (stream.get("width"), stream.get("height"), stream.get("r_frame_rate")) != (960, 540, "30/1"):
        raise ValueError(f"Unexpected Ogg dimensions or frame rate: {slug}")
    if abs(duration - source_duration) > 1 / 30:
        raise ValueError(f"Ogg duration differs from the review video: {slug}")
    subprocess.run(["ffmpeg", "-v", "error", "-xerror", "-i", str(target), "-f", "null", "-"], check=True)
    print(f"{asset['slot']}: {duration:.3f}s · {target.stat().st_size:,} bytes", flush=True)
    video = {
        "id": video_id, "source": asset["file"], "source_sha256": asset["sha256"],
        "path": (OUTPUT / relative).relative_to(ROOT).as_posix(),
        "sha256": sha256(target), "bytes": target.stat().st_size,
        "source_duration_seconds": source_duration, "duration_seconds": duration,
        "width": 960, "height": 540, "fps": 30, "codec": "theora", "audio": False,
    }
    return [poster_row, make_row(video_id, relative, asset["name"], (960, 540))], {
        "slot": asset["slot"], "poster": poster, "video": video,
    }


def write_json(path, data):
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--encoder", required=True, help="Xiph libtheora 1.2.0 examples/encoder_example")
    parser.add_argument("--jobs", type=int, default=3)
    args = parser.parse_args()
    source_assets = json.loads(ASSET_MAP.read_text())["assets"]
    by_slot = {asset["slot"]: asset for asset in source_assets}
    expected = VIDEO_SLOTS | {f"IMG/accessory/{name}" for name in ARTIFACTS} | {"IMG/rank/emblem/silver-3"}
    if set(by_slot) != expected or len(source_assets) != len(expected):
        raise ValueError("The review asset map does not contain exactly the expected 29 slots")

    registry = json.loads(REGISTRY.read_text())
    existing = {row["id"]: row for row in registry["assets"]}
    reused = []
    for slot, logical_id in (
        ("IMG/rank/emblem/silver-3", "fa.rank.rank.silver"),
        ("IMG/accessory/pebble-yoyo", "fa.accessory.pebble.yoyo"),
    ):
        path = existing[logical_id]["path"].removeprefix("res://")
        digest = sha256(ROOT / path)
        if slot in by_slot and digest != by_slot[slot]["sha256"]:
            raise ValueError(f"Existing resource does not match the review image: {slot}")
        reused.append({"slot": slot, "id": logical_id, "path": path, "sha256": digest})

    rows, images, videos = [], [], []
    with tempfile.TemporaryDirectory(prefix="menu09-app-media-") as temp:
        stage = Path(temp)
        for directory in ("artifacts", "posters", "videos"):
            (stage / directory).mkdir()
        for name in sorted(ARTIFACTS):
            slot = f"IMG/accessory/{name}"
            asset = by_slot[slot]
            row, record = copy_image(
                stage, f"fa.ui.menu09.artifact.{name}", Path("artifacts") / f"{name}.png",
                asset["name"], asset["file"], asset["sha256"],
            )
            rows.append(row)
            images.append({"slot": slot, **record})
        with ThreadPoolExecutor(max_workers=args.jobs) as pool:
            results = pool.map(lambda slot: make_clip(stage, args.encoder, by_slot[slot]), sorted(VIDEO_SLOTS))
            for new_rows, record in results:
                rows.extend(new_rows)
                videos.append(record)
        for file in stage.glob("*/*"):
            destination = OUTPUT / file.relative_to(stage)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(file, destination)

    new_ids = {row["id"] for row in rows}
    registry["assets"] = [row for row in registry["assets"] if row["id"] not in new_ids] + rows
    registry["logical_asset_count"] = len(registry["assets"])
    write_json(REGISTRY, registry)
    write_json(RECORDS / "app-media-manifest.json", {
        "schema_version": 1,
        "source_map": ASSET_MAP.relative_to(ROOT).as_posix(),
        "source_map_sha256": sha256(ASSET_MAP),
        "encoder": "Xiph libtheora 1.2.0 encoder_example, quality 8, speed 2, 30-frame keyframe interval",
        "images": images,
        "clips": videos,
        "reused": reused,
    })
    print(f"Registered {len(rows)} assets, reused {len(reused)} existing IDs", flush=True)


if __name__ == "__main__":
    main()
