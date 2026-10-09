"""Read-only cutout QA; does not modify images or registration data."""
from pathlib import Path
import json
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORK = Path(__file__).resolve().parent


def main():
    rows = []
    for path in sorted((WORK / '01_review').glob('*.png')):
        cid = path.name.split('-transparent-')[0]
        original = ROOT / f'assets/character/{cid}/concept/{cid}-concept-v01.png'
        source = np.asarray(Image.open(original).convert('RGB'), dtype=np.int16)
        with Image.open(path) as image:
            pixels = np.asarray(image.convert('RGBA'), dtype=np.int16)
            alpha = pixels[:, :, 3]
            rgb = pixels[:, :, :3]
            foreground = (source.max(axis=2) >= 50) & (alpha == 255)
            delta = np.abs(rgb - source)
            # A warning flag only: near-black source pixels may also be clothing.
            unexpected_color = ((source.max(axis=2) <= 3) & (alpha > 32)
                                & (rgb.max(axis=2) > 80))
            rows.append({
                'candidate': str(path.relative_to(ROOT)),
                'mode': image.mode, 'size': list(image.size),
                'alpha_range': [int(alpha.min()), int(alpha.max())],
                'transparent_fraction': round(float((alpha == 0).mean()), 6),
                'opaque_foreground_mean_rgb_delta': round(float(delta[foreground].mean()), 4),
                'opaque_foreground_exact_rgb_fraction': round(float((delta[foreground] == 0).all(axis=1).mean()), 6),
                'unexpected_color_on_near_black_source_pixels': int(unexpected_color.sum()),
                'note': 'Diagnostic flags, not anatomy/design approval or automatic registration.'
            })
    print(json.dumps(rows, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    main()
