"""Pack review-only samples using a fixed measured body scale per character.

No production files or 2048x128 runtime candidates are written at this stage.
"""
from pathlib import Path
import hashlib
import json
import sys
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / "tools/forest_arena"))
from motion_sheet_regions import split_regions

IDS = ("ja-hyun", "myo-ryung", "nabi", "yu-ran")


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def segments(row):
    height = row["sole_y"] - row["crown_y"]
    return [(row["chin_y"] - row["crown_y"]) / height,
            (row["pelvis_y"] - row["chin_y"]) / height,
            (row["sole_y"] - row["pelvis_y"]) / height]


def on_matte(image, color):
    out = Image.new("RGBA", image.size, color)
    out.alpha_composite(image)
    return out.convert("RGB")


def pack(frames):
    sheet = Image.new("RGBA", (512, 512))
    for i, frame in enumerate(frames):
        sheet.alpha_composite(frame, ((i % 4) * 128, (i // 4) * 128))
    return sheet


def labeled_pose(pose, row, path):
    board = on_matte(pose.resize((pose.width * 3, pose.height * 3)), "#344154")
    draw = ImageDraw.Draw(board)
    colors = {"crown_y": "#ffca61", "chin_y": "#8fffc0", "pelvis_y": "#84bdff", "sole_y": "#ffffff"}
    for key, color in colors.items():
        y = min(board.height - 1, row[key] * 3)
        draw.line((0, y, board.width - 1, y), fill=color, width=2)
        draw.text((3, max(0, y - 13)), f"{key} = {row[key]}", fill=color)
    board.save(path)


def main():
    spec = json.loads((WORK / "03_landmarks.json").read_text())
    out = WORK / "03_sample_review"
    out.mkdir(exist_ok=True)
    reference_strip = Image.open(WORK / "01_references/ja-hyun/idle_16f.png").convert("RGBA")
    reference_frames = [reference_strip.crop((i * 128, 0, (i + 1) * 128, 128)) for i in range(16)]
    pack(reference_frames).save(out / "ja-hyun-reference-4x4.png")
    after = {"ja-hyun": reference_frames}
    before = {"ja-hyun": reference_frames}
    records = []
    target_height = spec["reference"]["body_height"]
    reference_segments = segments(spec["reference"])
    labeled_pose(reference_frames[0], spec["reference"], out / "ja-hyun-measurement.png")
    for cid, row in spec["samples"].items():
        source = WORK / row["source"]
        original = Image.open(source)
        assert original.mode == "RGBA"
        assert original.getchannel("A").getextrema()[0] == 0
        extracted = split_regions(original)
        assert len(extracted) == 16
        scale = target_height / (row["sole_y"] - row["crown_y"])
        frame_rows, normalized = [], []
        for i, pose in enumerate(extracted):
            size = (round(pose.width * scale), round(pose.height * scale))
            assert min(size) > 0 and max(size) <= 120, (cid, i, size)
            rgba = np.asarray(pose)
            # Use both shoes in the lower 22% to avoid centering on a tail.
            foot_band = rgba[round(pose.height * .78):, :, 3] >= 64
            _, xs = np.nonzero(foot_band)
            assert len(xs), (cid, i, "missing foot contact")
            support_x = (int(xs.min()) + int(xs.max()) + 1) / 2
            resized = pose.resize(size, Image.Resampling.LANCZOS)
            x = round(64 - support_x * scale)
            y = 124 - size[1]
            assert x >= 2 and x + size[0] <= 126 and y >= 2, (cid, i, x, y, size)
            cell = Image.new("RGBA", (128, 128))
            cell.alpha_composite(resized, (x, y))
            normalized.append(cell)
            frame_rows.append({"index": i, "extracted_size": list(pose.size),
                               "scale": scale, "normalized_bbox": list(cell.getbbox()),
                               "rgba_sha256": hashlib.sha256(cell.tobytes()).hexdigest()})
        folder = out / cid
        folder.mkdir(exist_ok=True)
        sheet_path = folder / "idle-proportion-r01-clean.png"
        pack(normalized).save(sheet_path)
        normalized[0].save(folder / "idle-proportion-r01-preview-128.png")
        animation = [on_matte(f, "#344154") for f in normalized]
        # GIF time units are 10ms: alternate 120/130ms for exactly 8 FPS on average.
        animation[0].save(folder / "idle-proportion-r01.gif", save_all=True, append_images=animation[1:], duration=[120, 130] * 8, loop=0)
        labeled_pose(extracted[0], row, folder / "idle-landmarks.png")
        ratios = segments(row)
        differences = [abs(a / b - 1) for a, b in zip(ratios, reference_segments)]
        assert max(differences) <= spec["limits"]["segment_ratio_relative_difference"], (cid, differences)
        unique = len({r["rgba_sha256"] for r in frame_rows})
        assert unique == 16, (cid, unique)
        report_row = {"character_id": cid, "visual_state_id": "idle", "user_approved": False,
                      "source_path": str(source.relative_to(ROOT)), "source_sha256": sha(source),
                      "source_dimensions": list(original.size), "source_alpha": list(original.getchannel("A").getextrema()),
                      "review_path": str(sheet_path.relative_to(ROOT)), "review_sha256": sha(sheet_path),
                      "review_dimensions": [512, 512], "frame_count": 16, "unique_frames": unique,
                      "body_height_after_scale": (row["sole_y"] - row["crown_y"]) * scale,
                      "fixed_character_scale": scale, "segment_fractions": ratios,
                      "relative_segment_differences": differences,
                      "quantitative_scope": "first pose head/torso/bent-leg vertical fractions; not 3D joint lengths or a proof of identity",
                      "frames": frame_rows}
        records.append(report_row)
        after[cid] = normalized
        old_strip = Image.open(WORK / f"01_references/{cid}/idle_16f.png").convert("RGBA")
        before[cid] = [old_strip.crop((i * 128, 0, (i + 1) * 128, 128)) for i in range(16)]
    board = Image.new("RGB", (1100, 720), "#1e2734")
    draw = ImageDraw.Draw(board)
    draw.text((24, 12), "Ja-Hyun body-proportion review / same 128px cells, display scale 1.0", fill="white")
    for col, cid in enumerate(IDS):
        x = 45 + col * 260
        draw.text((x, 42), cid, fill="white")
        for y, frames, label in ((78, before[cid], "before"), (370, after[cid], "candidate / approval pending")):
            draw.text((x, y - 20), label, fill="#b5c8e0")
            image = on_matte(frames[0], "#344154").resize((256, 256), Image.Resampling.NEAREST)
            board.paste(image, (x, y))
    board.save(out / "comparison-before-after.png")
    for background, name in (("#f2f4f7", "light"), ("#243044", "dark")):
        strip = Image.new("RGBA", (512, 128), background)
        for col, cid in enumerate(IDS):
            strip.alpha_composite(after[cid][0], (col * 128, 0))
        strip.convert("RGB").resize((1536, 384), Image.Resampling.NEAREST).save(out / f"same-size-{name}.png")
    (out / "report.json").write_text(json.dumps({"status": "sample-review-pending", "reference": spec["reference"],
                                                "reference_segment_fractions": reference_segments, "samples": records}, ensure_ascii=False, indent=2) + "\n")
    print("SAMPLE STRUCTURE: PASS (3x16 unique RGBA poses; fixed body scale; review only)")
    for row in records:
        print(row["character_id"], "segment differences", [round(d * 100, 2) for d in row["relative_segment_differences"]], "percent")


if __name__ == "__main__":
    main()
