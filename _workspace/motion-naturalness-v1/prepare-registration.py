"""Prepare a read-only pilot installation plan and the remaining art brief.

No user approval record is created. No runtime asset is written.
"""
from pathlib import Path
import hashlib
import json
import re
import subprocess
import sys

BASE = Path(__file__).resolve().parent
ROOT = BASE.parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def relative(path):
    return path.relative_to(ROOT).as_posix()


def motion(row):
    return row.get('visual_state_id', Path(row['sprite_frames_path']).stem)


catalog_path = BASE / 'candidate-catalog.json'
scope_path = BASE / 'candidate-scope.json'
review_path = BASE / 'review/pilot-r04/motion-review.json'
manifest_path = ROOT / 'assets/character/manifest.json'
catalog = read(catalog_path)
manifest = read(manifest_path)
current = {(r['character_id'], motion(r)): r for r in manifest['assets']
           if r.get('type') == 'animation-runtime'}
approval_path = BASE / 'user-motion-registration-approval.json'
assert not approval_path.exists(), 'approval exists: inspect it rather than rewrite the plan'

targets = []
for row in catalog['assets']:
    key = row['character_id'], row['visual_state_id']
    old = current.get(key)
    consumer = old['sprite_frames_path'] if old else (
        f'res://assets/character/{key[0]}/animation/runtime/{key[1]}.tres')
    folder = Path(consumer.removeprefix('res://')).parent
    targets.append({
        'character_id': key[0], 'motion': key[1],
        'asset_id': old['asset_id'] if old else row['asset_id'],
        'png_path': (folder / f'{key[1]}_{row["frame_count"]}f_natural-v02.png').as_posix(),
        'sprite_frames_path': consumer,
    })
targets_path = BASE / 'registration-targets.json'
write(targets_path, {
    'schema_version': 1, 'kind': 'motion-registration-targets',
    'approval_record': relative(approval_path), 'motions': targets,
})

# All approved drawings/consumers, not only the files mentioned in the pilot.
protected = {manifest_path, ROOT/'forest_arena/data/resource_registry.json'}
for row in manifest['assets']:
    for field in ('path', 'sprite_frames_path'):
        if row.get(field):
            path = ROOT / row[field].removeprefix('res://')
            if path.is_file():
                protected.add(path)
before = {relative(p): sha(p) for p in protected}
command = [sys.executable, 'tools/forest_arena/register_motion_candidates.py',
           '--project-root', '.', '--catalog', relative(catalog_path),
           '--scope', relative(scope_path), '--scope-sha256', sha(scope_path),
           '--review', relative(review_path), '--targets', relative(targets_path)]
first = subprocess.run(command, cwd=ROOT, check=True, text=True, capture_output=True)
second = subprocess.run(command, cwd=ROOT, check=True, text=True, capture_output=True)
plan = json.loads(first.stdout)
assert plan == json.loads(second.stdout), 'same inputs produced different registration plans'
assert plan['writes'] is False
assert plan['approval_status'] == 'explicit per-motion human approval record is missing'
assert len(plan['plan']['motions']) == 10
assert sum(r['operation'] == 'replace' for r in plan['plan']['motions']) == 9
assert sum(r['operation'] == 'add' for r in plan['plan']['motions']) == 1
assert before == {relative(p): sha(p) for p in protected}, 'planning modified approved assets'
assert not approval_path.exists()
assert all(not (ROOT/t['png_path']).exists() for t in targets)
write(BASE/'registration-plan.json', plan)

old_scope_path = ROOT/'_workspace/two-fighter-combat-v2/candidate-scope.json'
old_catalog_path = old_scope_path.with_name('candidate-catalog.json')
old_scope = read(old_scope_path)
assert old_scope['catalog_sha256'] == sha(old_catalog_path)
old_catalog = read(old_catalog_path)
full = {(r['character_id'], r['motion']) for r in old_scope['motions']}
pilot = {(r['character_id'], r['motion']) for r in read(scope_path)['motions']}
assert len(full) == 36 and len(pilot) == 10 and pilot < full
rows = {(r['character_id'], r['visual_state_id']): r for r in old_catalog['assets']}
attack_timings = {}
attack_sources = {}
for character_id, stem in [('ja-hyun', 'ja_hyun'), ('nabi', 'nabi')]:
    path = ROOT / f'assets/combat/movesets/two_fighter_{stem}_moveset.tres'
    attack_sources[relative(path)] = sha(path)
    for block in path.read_text().split('[sub_resource'):
        attack_id = re.search(r'^attack_id = &"([^"]+)"$', block, re.M)
        visual = re.search(r'^visual_state_id = &"([^"]+)"$', block, re.M)
        if attack_id and visual:
            times = {field: int(re.search(rf'^{field} = (\d+)$', block, re.M)[1])
                     for field in ['startup_ticks', 'active_ticks', 'recovery_ticks']}
            attack_timings.setdefault((character_id, visual[1]), []).append(
                {'attack_id': attack_id[1], **times})
scarf_keys = {'special_neutral': ['scarf_root'],
              'attack_air_light': ['scarf_hand'], 'attack_air_heavy': ['scarf_hand'],
              'special_scarf_sweep': ['scarf_root', 'scarf_tips']}
remaining = []
for key in sorted(full - pilot):
    attack = key[1].startswith(('attack_', 'special_'))
    if attack:
        assert key in attack_timings, 'art brief must refer to the current actual attack'
    remaining.append({
        'character_id': key[0], 'motion': key[1],
        'expected_action': rows[key]['expected_action'].replace('별도 리본 효과', '착용 중인 목도리 천을 연결한 효과'),
        'category': 'attack' if attack else 'state',
        'status': 'waiting for pilot user review before new artwork',
        'frame_count': None, 'allowed_frame_counts': [16, 24, 32],
        'requires_worn_scarf_anchors': key[0] == 'ja-hyun' and attack,
        'required_anchor_keys': scarf_keys.get(key[1], []) if key[0] == 'ja-hyun' else [],
        'actual_attack_timings_60hz': attack_timings.get(key, []),
        'next_review': 'full frames, normal/slow actual transitions, mirror, small scale',
    })
assert len(remaining) == 26
write(BASE/'remaining-motion-brief.json', {
    'schema_version': 1, 'kind': 'remaining-motion-production-brief',
    'pilot_approval_status': 'pending',
    'full_scope_path': relative(old_scope_path), 'full_scope_sha256': sha(old_scope_path),
    'pilot_scope_path': relative(scope_path), 'pilot_scope_sha256': sha(scope_path),
    'actual_attack_sources': attack_sources,
    'scarf_rule': '캐릭터가 실제 메고 있는 목도리의 승인 천을 사용한다. 별도 리본이나 새 목도리로 대체하지 않는다.',
    'timing_rule': '그림 수와 표시 가중치는 실제 준비·판정·회복 시간을 바꾸지 않는다. 판정 틱보다 많은 새 공격 그림을 배정하지 않는다.',
    'scope_counts': {'full': 36, 'pilot': 10, 'remaining': 26},
    'motions': remaining,
})
write(BASE/'qa/registration-plan-check-r01.json', {
    'kind': 'read-only-registration-plan-check',
    'plan_sha256': plan['plan_sha256'],
    'same_inputs_same_plan': True, 'protected_files_unchanged': len(protected),
    'operations': {'replace': 9, 'add': 1}, 'outputs': len(plan['plan']['outputs']),
    'runtime_writes': False, 'user_approval_record_created': False,
    'missing_approval_refused': True, 'remaining_scope_exact': True,
    'command': command,
})
print('PASS: 9 preserved consumers + 1 new kick; no runtime writes; exact remaining 26')
