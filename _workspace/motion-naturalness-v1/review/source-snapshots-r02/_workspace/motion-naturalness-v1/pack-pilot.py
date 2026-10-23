"""Package actual fixed-tick pilot captures; never alter candidate artwork."""
from __future__ import annotations

import argparse
import hashlib
import html
import json
from pathlib import Path
import subprocess

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def keyframes(item: dict) -> list[int]:
    states = item["states"]
    if item["scenario"] == "jump-land":
        airborne = [r["frame"] for r in states if not r["match"]["fighters"][0]["on_floor"]]
        apex = min(states, key=lambda r: r["match"]["fighters"][0]["position"]["y"])["frame"]
        landing = next(r["frame"] for r in states if r["frame"] > airborne[-1])
        return [0, airborne[0], apex, airborne[-1], landing, min(landing + 12, len(states)-1)]
    if item["scenario"] == "full-combo":
        seen: set[str] = set()
        impacts: list[int] = []
        for row in states:
            fighter = row["match"]["fighters"][0]
            if fighter["state"] == "ATTACK_ACTIVE" and fighter["attack_id"] not in seen:
                seen.add(fighter["attack_id"])
                impacts.append(row["frame"])
        choices = [0, *impacts, len(states)-1]
        while len(choices) < 6:
            choices.insert(-1, min(impacts[-1]+8, len(states)-2))
        return choices[:6]
    return [0, 12, 24, 48, 71, 90]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path(__file__).parent/"review/live-pilot")
    parser.add_argument("--lossless", action="store_true", help="also preserve FFV1 Matroska captures")
    parser.add_argument("--keep-frames", action="store_true")
    args = parser.parse_args()
    base = args.output.resolve()
    report_path = base/"state-report.json"
    report = json.loads(report_path.read_text())
    if report.get("errors"):
        raise ValueError("refusing to package a failed capture")
    if len(report.get("scenarios", [])) == 0:
        raise ValueError("capture has no scenarios")
    for path, expected in report["sources"].items():
        if sha(ROOT/path) != expected:
            raise ValueError(f"source changed after capture: {path}")
    for item in report["scenarios"]:
        if item["state_only"]:
            raise ValueError("state-only dry runs have no rendered media")
        folder = base/item["name"]
        frames = sorted(folder.glob("frame-*.png"))
        if len(frames) != item["frame_count"]:
            raise ValueError(f"incomplete capture: {item['name']}")
    sections: list[str] = []
    outputs: dict[str, str] = {}
    for item in report["scenarios"]:
        name = item["name"]
        folder = base/name
        source = folder/"frame-%03d.png"
        movie = base/(name+".mp4")
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", "60", "-i", str(source), "-c:v", "libx264", "-crf", "16", "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(movie)], check=True)
        outputs[str(movie.relative_to(ROOT))] = sha(movie)
        if args.lossless:
            lossless = base/(name+".mkv")
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", "60", "-i", str(source), "-c:v", "ffv1", str(lossless)], check=True)
            outputs[str(lossless.relative_to(ROOT))] = sha(lossless)
        indices = keyframes(item)
        board = Image.new("RGB", (1920,1620))
        for slot, frame in enumerate(indices):
            with Image.open(folder/(f"frame-{frame:03d}.png")) as image:
                thumb = image.convert("RGB")
                thumb.thumbnail((960,540))
                board.paste(thumb, ((slot%2)*960,(slot//2)*540))
        board_path = base/(name+".jpg")
        board.save(board_path, quality=92)
        outputs[str(board_path.relative_to(ROOT))] = sha(board_path)
        item["contact_board_frames"] = indices
        sections.append(f'<article><h2>{html.escape(name)}</h2><video controls loop muted playsinline src="{html.escape(name)}.mp4"></video><p><a href="{html.escape(name)}.jpg">실제 시간순 핵심 그림 6장</a> · 줌 {item["camera_zoom"]:.2f} · 좌우 반전 {item["flipped"]}</p></article>')
    page = '<!doctype html><html lang="ko"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>대표 모션 실제 입력 검토</title><style>body{background:#17272d;color:#f1f5ee;font:18px system-ui;margin:24px}video{width:min(100%,960px)}article{margin:32px 0}a{color:#a3d6ff}button{font:inherit;padding:8px 18px;margin:6px}</style><h1>대표 모션 실제 입력 검토</h1><p>승인 전 후보를 독립 검토 프로세스에서만 표시합니다. 실제 MatchController·지형·60Hz 입력이 이동·점프·연계·타격을 결정합니다. Android 실기기 검사가 아닙니다.</p><button onclick="document.querySelectorAll(\'video\').forEach(v=>v.playbackRate=1)">정상 속도</button><button onclick="document.querySelectorAll(\'video\').forEach(v=>v.playbackRate=.25)">0.25배</button>'+"".join(sections)+"</html>"
    (base/"index.html").write_text(page)
    report["render_files"] = outputs
    report["sources"][str(Path(__file__).resolve().relative_to(ROOT))] = sha(Path(__file__))
    report["capture_format"] = "1280x720 60fps H.264 CRF16"+(" + lossless FFV1" if args.lossless else "")
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2)+"\n")
    if not args.keep_frames:
        for item in report["scenarios"]:
            folder = base/item["name"]
            for image in folder.glob("frame-*.png"): image.unlink()
            folder.rmdir()
    print(f"packed {len(report['scenarios'])} actual pilot clips")


if __name__ == "__main__":
    main()
