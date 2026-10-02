"""Build a non-runtime playback GIF from a 4x4 motion review sheet."""

from argparse import ArgumentParser
from pathlib import Path

from PIL import Image


def main() -> None:
    parser = ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--size", type=int, default=256)
    parser.add_argument("--duration-ms", type=int, default=83)
    parser.add_argument(
        "--order",
        default=",".join(str(index) for index in range(1, 17)),
        help="comma-separated one-based source-cell playback order",
    )
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGB")
    order = [int(value) - 1 for value in args.order.split(",")]
    if sorted(order) != list(range(16)):
        raise ValueError("order must contain each one-based cell number exactly once")
    frames = []
    for index in order:
        column = index % 4
        row = index // 4
        edges = (
            round(column * source.width / 4),
            round(row * source.height / 4),
            round((column + 1) * source.width / 4),
            round((row + 1) * source.height / 4),
        )
        frame = source.crop(edges)
        frame.thumbnail((args.size, args.size), Image.Resampling.LANCZOS)
        canvas = Image.new("RGB", (args.size, args.size), "#34383f")
        canvas.paste(frame, ((args.size - frame.width) // 2, (args.size - frame.height) // 2))
        frames.append(canvas)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        args.output,
        save_all=True,
        append_images=frames[1:],
        duration=args.duration_ms,
        loop=0,
        optimize=True,
    )
    print(f"wrote {args.output} ({len(frames)} frames)")


if __name__ == "__main__":
    main()
