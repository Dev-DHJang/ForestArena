"""Git에 보존한 승인90종·브랜딩·최신 시작 흐름의 재현 가능한 검사."""
from pathlib import Path
import hashlib
import json
import re
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / '_workspace/character-motion-proportion-unification'


def read(path):
    return json.loads(path.read_text())


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(root=ROOT):
    work = root / '_workspace/character-motion-proportion-unification'
    manifest = read(root / 'assets/character/manifest.json')
    entries = {(e['character_id'], e['visual_state_id']): e for e in manifest['assets']
               if e.get('type') == 'animation-runtime'}
    layout = read(root / 'forest_arena/data/character_display_layout_v01.json')
    drawing = {(e['character_id'], e['motion_id']): e for e in layout['motions']}
    assert len(entries) == len(drawing) == 120
    count = 0
    for cid, batch, total in [('myo-ryung', '06_myo_ryung-style-locked', 31),
                               ('nabi', '07_nabi-style-locked', 29),
                               ('yu-ran', '08_yu_ran-style-locked', 30)]:
        directory = work / batch
        approval_path = directory / f'approval-all-{total}.json'
        approval = read(approval_path)
        receipt = read(directory / '08_install_receipt.json')
        report_path = directory / f'04_review/{total}-motion-report.json'
        report = read(report_path)
        assert approval['user_approved'] is True and approval['approved_count'] == total
        assert sha(approval_path) == receipt['approval_sha256']
        assert sha(report_path) == approval['review_report_sha256']
        assert len(report['states']) == len(approval['approved_states']) == total
        assert approval['approved_states'] == {r['visual_state_id']: r['review_sha256'] for r in report['states']}
        for row in report['states']:
            key = cid, row['visual_state_id']
            entry = entries[key]
            review = root / row['review_path']
            assert sha(review) == row['review_sha256'] == approval['approved_states'][key[1]]
            source = Image.open(review)
            runtime = Image.open(root / entry['path'])
            assert source.mode == runtime.mode == 'RGBA'
            assert source.size == (512, 512) and runtime.size == (2048, 128)
            assert sha(root / entry['path']) == entry['sha256'] == drawing[key]['asset_sha256']
            assert entry['fps'] == row['original_fps'] and entry['loop'] == row['original_loop']
            assert entry['presentation_scale'] == drawing[key]['scale'] == 1.0
            assert entry['foot_pivot_y'] == drawing[key]['foot_pivot_y'] == 124
            for i in range(16):
                x, y = i % 4 * 128, i // 4 * 128
                frame = source.crop((x, y, x + 128, y + 128))
                assert frame.tobytes() == runtime.crop((i * 128, 0, (i + 1) * 128, 128)).tobytes(), key
            frames = root / entry['sprite_frames_path'].removeprefix('res://')
            assert 'res://' + entry['path'] in frames.read_text()
            count += 1
    assert count == 90
    final_receipt = read(work / '08_yu_ran-style-locked/08_install_receipt.json')
    assert sha(root / 'assets/character/manifest.json') == final_receipt['installed_manifest_sha256']
    for key, entry in entries.items():
        assert drawing[key]['asset_sha256'] == entry['sha256']
        assert sha(root / entry['path']) == entry['sha256']
    for number in (1, 2):
        alias = root / f'assets/character/nabi/animation/runtime/attack_light_combo_0{number}_16f.png'
        assert alias.read_bytes() == (root / entries[('nabi', f'attack_light_combo_0{number}')]['path']).read_bytes()
    branding = read(root / 'assets/branding/myo-ryung-v01/manifest.json')
    for asset in branding['assets']:
        assert sha(root / asset['path']) == asset['sha256']
    settings = (root / 'project.godot').read_text()
    assert 'run/main_scene="res://scenes/startup_title.tscn"' in settings
    assert 'boot_splash/show_image=false' in settings and 'boot_splash/minimum_display_time=0' in settings
    assert 'config/icon="res://assets/branding/myo-ryung-v01/app-icon-1024.png"' in settings
    presets = (root / 'export_presets.cfg').read_text()
    for field, filename in [('main_192x192', 'main-192.png'), ('adaptive_foreground_432x432', 'adaptive-foreground-432.png'), ('adaptive_background_432x432', 'adaptive-background-432.png')]:
        value = f'launcher_icons/{field}="res://assets/branding/myo-ryung-v01/{filename}"'
        assert presets.count(value) == 2
    assert presets.count('package/unique_name="com.forestarena.welllbeing"') == 2
    assert presets.count('package/signed=true') == 2
    print('GIT-INTEGRATION: PASS (90 approvals / 1440 exact cells; 120 runtime/layout hashes; branding; title; package compatibility).')


if __name__ == '__main__':
    verify()
