"""Prepare review-only head-unit proposals; never install or repaint artwork."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys

root = Path(__file__).resolve().parents[2]
base = Path(__file__).resolve().parent
old = json.loads((base / 'remaining-candidate-catalog-r06.json').read_text())
proposal = json.loads((base / 'remaining/nabi/head-unit-proposals.json').read_text())
units = {row['source_png']: row for row in proposal['sources']}
new = copy.deepcopy(old)
new['assets'] = []
checks = []
for asset in old['assets']:
    if (asset['character_id'], asset['visual_state_id']) == ('ja-hyun', 'special_scarf_sweep'):
        continue  # This exact motion has separately been approved and installed.
    row = copy.deepcopy(asset)
    if row['character_id'] == 'nabi':
        spec = json.loads((root / row['conversion']['spec_path']).read_text())
        measured = [units[Path(path).name] for path in spec['source_paths']]
        for source, unit in zip(spec['source_paths'], measured):
            assert hashlib.sha256((root / source).read_bytes()).hexdigest() == unit['source_sha256']
        desired = [41.5 / item['source_head_unit_pixels'] for item in measured]
        original_world = spec['source_to_cell_scale'] * spec['presentation_scale']
        if len(desired) == 1:
            spec['presentation_scale'] *= desired[0] / original_world
        else:
            spec['source_scale_multipliers'] = [value / original_world for value in desired]
        spec['version'] = 'r07-head'
        spec['head_unit_proposal'] = {'target_world_pixels': 41.5,
            'measurement_source': str((base / 'remaining/nabi/head-unit-proposals.json').relative_to(root)),
            'source_units': measured, 'status': 'proposal; all-frame/link visual QA required',
            'method': 'one uniform scale per source sheet; common runtime display scale; no pose/body-part distortion'}
        path = base / 'remaining/layout-specs' / f"nabi-{row['visual_state_id']}-r07-head.json"
        path.write_text(json.dumps(spec, ensure_ascii=False, indent=2) + '\n')
        subprocess.run([sys.executable, str(base / 'pack-calibrated.py'), str(path)], cwd=root, check=True)
        row = json.loads((base / 'candidates/remaining/nabi' / f"{row['visual_state_id']}_r07-head.json").read_text())
        if len(desired) == 1:
            assert row['sha256'] == asset['sha256'], 'single-sheet calibration changes metadata only'
        factors = row['conversion']['source_scale_multipliers']
        actual_units = [u['source_head_unit_pixels'] * row['conversion']['uniform_scale'] * f * row['presentation_scale']
                        for u, f in zip(measured, factors)]
        assert all(abs(value - 41.5) < 0.0001 for value in actual_units)
        checks.append({'motion': row['visual_state_id'], 'source_units': actual_units,
                       'png_unchanged': row['sha256'] == asset['sha256'],
                       'source_sheet_uniform_scales': row['conversion']['per_source_uniform_scales']})
    paths = row['source_paths']
    hashes = [hashlib.sha256((root / path).read_bytes()).hexdigest() for path in paths]
    row['source_path'] = paths[0]
    row['source_sheet_sha256'] = hashes
    row['source_sha256'] = hashes[0]
    row['creation'] = {'method': 'built-in image_gen source poses; deterministic original-figure atlas layout',
                       'provider': 'OpenAI built-in image generation', 'version': 'remaining-motion-r07-head-proposal',
                       'source_inputs': [{'path': p, 'sha256': h, 'frame_range': [i * 16, (i + 1) * 16]}
                                         for i, (p, h) in enumerate(zip(paths, hashes))]}
    row['rights'] = {'status': 'derivative of the approved character appearance; separate per-motion user approval required; external license verification not asserted',
                     'references': ['assets/character/manifest.json', str((base / 'remaining-motion-brief.json').relative_to(root))]}
    new['assets'].append(row)
assert len(new['assets']) == 25
path = base / 'remaining-candidate-catalog-r07.json'
path.write_text(json.dumps(new, ensure_ascii=False, indent=2) + '\n')
scope = {'schema_version': 1, 'kind': 'candidate-motion-review',
         'catalog_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
         'motions': [{'character_id': a['character_id'], 'motion': a['visual_state_id']} for a in new['assets']]}
path = base / 'remaining-candidate-scope-r07.json'
path.write_text(json.dumps(scope, ensure_ascii=False, indent=2) + '\n')
path.with_suffix('.sha256').write_text(hashlib.sha256(path.read_bytes()).hexdigest() + '\n')
(base / 'qa/nabi-head-calibration-r07.json').write_text(json.dumps({'status': 'technical proposal only',
    'target_world_head_unit': 41.5, 'source_pngs_unchanged': True, 'motions': checks,
    'visual_qa': 'pending; initial landmarks are approximate, not all-pose validation'}, ensure_ascii=False, indent=2) + '\n')
print('25 pending candidates, 13 Nabi head-unit proposals; no runtime writes')
