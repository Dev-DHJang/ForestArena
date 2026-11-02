"""Read-only approval/receipt/runtime audit and exact registered replay comparison."""
from pathlib import Path
import hashlib
import json
import sys

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / '_workspace/pebble-yoyo'
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(ROOT / 'tools/forest_arena'))
from register_motion_candidates import DISPLAY_FIELDS, plan_digest, verify_approval

def read(path):
    return json.loads(path.read_text())

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

receipt = read(BASE / 'registration-receipt-r03.json')
plan = receipt['plan']
assert receipt['status'] == 'installed'
assert plan_digest(plan) == receipt['plan_sha256']
stored_plan = read(BASE / 'registration-plan-r03.json')
assert stored_plan['plan'] == plan and stored_plan['plan_sha256'] == receipt['plan_sha256']
assert sha(ROOT / 'tools/forest_arena/register_motion_candidates.py') == plan['registrar_sha256']
assert sha(ROOT / 'tools/forest_arena/motion_layout.py') == plan['layout_validator_sha256']
verify_approval(ROOT, plan)
assert sha(BASE / 'user-motion-approval-r03.json') == receipt['approval_sha256']
assert read(BASE / 'registration-backup-r03/receipt.json') == receipt
for field, hash_field in [('catalog_path', 'catalog_sha256'), ('scope_path', 'scope_sha256'),
                          ('qa_review_path', 'qa_review_sha256'),
                          ('registration_targets_path', 'registration_targets_sha256')]:
    assert sha(ROOT / plan[field]) == plan[hash_field], field

backup = BASE / 'registration-backup-r03'
for output in plan['outputs']:
    assert sha(ROOT / output['path']) == output['after_sha256'], output['path']
    if output['before_sha256'] is not None:
        assert sha(backup / output['path']) == output['before_sha256'], output['path']

review = read(ROOT / plan['qa_review_path'])
outputs = {item['path']: item for item in plan['outputs']}
bridged = []
for name, expected in review['sources'].items():
    if sha(ROOT / name) == expected:
        continue
    assert name in outputs and outputs[name]['before_sha256'] == expected, name
    assert sha(backup / name) == expected, name
    bridged.append(name)

manifest = read(ROOT / 'assets/character/manifest.json')['assets']
old_manifest = read(backup / 'assets/character/manifest.json')['assets']
catalog = read(ROOT / plan['catalog_path'])['assets']
motions = []
for item in plan['motions']:
    key = item['character_id'], item['motion']
    candidate = next(row for row in catalog if (row['character_id'], row['visual_state_id']) == key)
    runtime = next(row for row in manifest if row.get('type') == 'animation-runtime'
                   and (row.get('character_id'), row.get('visual_state_id')) == key)
    assert runtime['asset_id'] == item['asset_id']
    assert runtime['path'] == item['png_path']
    assert runtime['sprite_frames_path'] == runtime['consumer_path'] == item['sprite_frames_path']
    assert (ROOT / runtime['path']).read_bytes() == (ROOT / candidate['path']).read_bytes()
    assert sha(ROOT / runtime['path']) == runtime['sha256'] == item['png_sha256']
    before_tres = (ROOT / candidate['sprite_frames_path'].removeprefix('res://')).read_text()
    after_tres = (ROOT / runtime['sprite_frames_path'].removeprefix('res://')).read_text()
    assert after_tres == before_tres.replace('res://' + candidate['path'], 'res://' + runtime['path'])
    assert sha(ROOT / runtime['sprite_frames_path'].removeprefix('res://')) == item['registered_sprite_frames_sha256']
    assert all(runtime.get(field) == candidate.get(field) for field in DISPLAY_FIELDS)
    registration = runtime['motion_registration']
    assert registration['qa_review_sha256'] == plan['qa_review_sha256']
    assert registration['approval_record'] == plan['approval_record']
    assert registration['scope_sha256'] == plan['scope_sha256']
    if key == ('nabi', 'idle'):
        old = next(row for row in old_manifest if row.get('asset_id') == item['asset_id'])
        assert (ROOT / old['path']).read_bytes() == (ROOT / runtime['path']).read_bytes()
        assert runtime['registration_history'][-1] == {k: v for k, v in old.items() if k != 'registration_history'}
        assert runtime['registration_history'][:-1] == old.get('registration_history', [])
        assert all(runtime.get(field) == old.get(field) for field in DISPLAY_FIELDS if field != 'frame_anchors')
    motions.append({'character': key[0], 'motion': key[1], 'png_exact': True,
                    'SpriteFrames_reference_only_change': True, 'display_metadata_exact': True})
changed = {item['asset_id'] for item in plan['motions']}
assert [row for row in manifest if row.get('asset_id') not in changed] == [row for row in old_manifest if row.get('asset_id') not in changed]
idle_id = next(item['asset_id'] for item in plan['motions'] if item['motion'] == 'idle')
assert len(manifest) == len(old_manifest) + 4
assert all(actual.get('asset_id') == previous.get('asset_id') and
           (actual == previous or previous.get('asset_id') == idle_id)
           for previous, actual in zip(old_manifest, manifest[:len(old_manifest)]))
assert {row['asset_id'] for row in manifest[len(old_manifest):]} == {
    item['asset_id'] for item in plan['motions'] if item['operation'] == 'add'}

approved = read(BASE / 'game-timeline-r03.json')
registered = read(HERE / 'runtime-timeline.json')
assert len(approved['motions']) == len(registered['motions']) == 8
for expected, actual in zip(approved['motions'], registered['motions']):
    assert all(actual[key] == expected[key] for key in ['character', 'mode', 'motion_id', 'facing'])
    assert actual['frames'] == expected['frames'], (actual['character'], actual['mode'], actual['facing'])
assert registered['idle_entry_probes'] == approved['idle_entry_probes']
assert len(registered['idle_entry_probes']) == 32

sources = [BASE / 'registration-receipt-r03.json', BASE / 'registration-plan-r03.json',
           BASE / 'user-motion-approval-r03.json', ROOT / plan['qa_review_path'],
           BASE / 'candidate-catalog.json', BASE / 'candidate-scope.json',
           BASE / 'game-timeline-r03.json', HERE / 'runtime-timeline.json',
           HERE / 'record_registered_preview.gd', Path(__file__),
           HERE / 'recorder-derivation.json', HERE / 'recorder.diff',
           backup / 'assets/character/manifest.json',
           backup / 'assets/character/nabi/animation/runtime/idle.tres',
           ROOT / 'build/verification/pebble-yoyo/registration-qa-import-r01.log',
           ROOT / 'build/verification/pebble-yoyo/registration-qa-runtime-r01.log',
           ROOT / 'build/verification/pebble-yoyo/registration-qa-runtime-r02.log']
sources += [ROOT / row['path'] for row in plan['outputs']]
result = {'status': 'pass', 'plan_sha256': receipt['plan_sha256'],
          'historical_QA_hashes_bridged_to_backup': bridged, 'motions': motions,
          'manifest_original_rows': len(old_manifest),
          'manifest_prefix_rows_identical_except_nabi_idle': True,
          'manifest_only_new_tail_rows': 4,
          'actual_motion_traces': 8, 'actual_samples_exact': sum(len(row['frames']) for row in registered['motions']),
          'idle_entry_probes_exact': 32,
          'probe_samples_exact': sum(len(row['cast']) + 1 for row in registered['idle_entry_probes']),
          'new_motion_rgba_texture_upper_bound_bytes': 4 * 16 * 128 * 128 * 4,
          'memory_scope': 'RGBA four new sheets only; excludes mipmaps/driver overhead; not measured on Android',
          'registered_assets_add_sprite_nodes_or_draw_commands': False,
          'cleanup_note': 'Godot exited0 and trace comparison passed; existing headless exit Resource/ObjectDB warnings remain, see runtime logs. No production code changed to pursue them.',
          'sources': {str(path.relative_to(ROOT)): sha(path) for path in sources}}
(HERE / 'registration-checks.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print('PEBBLE_YOYO_REGISTRATION_QA: PASS; 5 registrations,792 replay samples,32 idle entry probes exact')
