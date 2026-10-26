"""Verify the real two-sheet source, default compatibility and invalid factors."""
import copy
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
base = Path(__file__).resolve().parent
out = base / 'qa/packer-calibration-r01'
out.mkdir(exist_ok=True)
old = json.loads((base / 'candidates/remaining/nabi/special_side_r06-claw.json').read_text())
spec = json.loads((root / old['conversion']['spec_path']).read_text())
spec['candidate_output_directory'] = str(out.relative_to(root))
results = []
for label, factors in [('implicit-default', None), ('explicit-default', [1.0, 1.0])]:
    current = copy.deepcopy(spec)
    current['version'] = label
    if factors is not None:
        current['source_scale_multipliers'] = factors
    path = out / f'{label}.json'
    path.write_text(json.dumps(current) + '\n')
    subprocess.run([sys.executable, str(base / 'pack-calibrated.py'), str(path)], cwd=root, check=True, capture_output=True)
    row = json.loads((out / f'special_side_{label}.json').read_text())
    assert row['sha256'] == old['sha256']
    assert row['frame_anchors'] == old['frame_anchors']
    assert row['phase_frame_ranges'] == old['phase_frame_ranges']
    results.append({'case': label, 'status': 'PASS', 'all_32_pose_pixels_and_anchors_preserved': True})
for label, factors in [('wrong-length', [1.0]), ('nonpositive', [1.0, 0.0]), ('oversized', [1.0, 3.0])]:
    current = copy.deepcopy(spec)
    current['version'] = label
    current['source_scale_multipliers'] = factors
    path = out / f'{label}.json'
    path.write_text(json.dumps(current) + '\n')
    process = subprocess.run([sys.executable, str(base / 'pack-calibrated.py'), str(path)], cwd=root, capture_output=True)
    assert process.returncode != 0
    assert not (out / f'special_side_32f_{label}.png').exists()
    results.append({'case': label, 'status': 'PASS', 'invalid_input_rejected_before_png_write': True})
(out / 'result.json').write_text(json.dumps({'status': 'PASS', 'cases': results}, indent=2) + '\n')
print('PACKER_CALIBRATION: PASS (2 compatibility / 3 invalid-input cases)')
