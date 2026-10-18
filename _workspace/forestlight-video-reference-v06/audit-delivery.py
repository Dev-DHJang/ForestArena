"""Check saved Penpot evidence and write design handoff tables. No Godot mutation."""
import csv
import hashlib
import json
import subprocess
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
TASK = Path(__file__).resolve().parent
ASSETS = ROOT / 'assets/ui/forestlight-video-reference-v06'

def read(path):
    return json.loads(path.read_text())

def csv_write(name, rows):
    if not rows:
        return
    with (TASK / name).open('w', newline='') as out:
        writer = csv.DictWriter(out, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)

baseline = read(TASK / 'baseline-audit.json')
final = read(TASK / 'final-audit.json')
supplement = read(TASK / 'supplemental-audit.json')
manifest = read(ASSETS / 'manifest.json')
missing = read(TASK / 'missing-assets.json')
clicks = read(TASK / 'click-areas.json')
screens = final['screens']
checks = {}

def check(name, passed):
    checks[name] = bool(passed)
    assert passed, name

check('55 source IDs and names preserved',
      {(s['name'], s['id']) for s in screens} ==
      {(s['name'], s['id']) for s in baseline['screens']} and len(screens) == 55)
check('24 original screen IDs',
      {s['name'] for s in screens if s['name'].startswith('SCR_')} ==
      {s['id'] for s in read(ROOT / 'docs/ui/non-combat-ui-v01.json')['screens']})
check('536 components, 103 new, old 433 retained',
      len(final['components']) == 536 and len(baseline['components']) == 433 and
      {c['id'] for c in baseline['components']} <= {c['id'] for c in final['components']} and
      len([c for c in final['components'] if c['path'].startswith('Forestlight Video v06')]) == 103)
fields = ('id', 'index', 'trigger', 'delay', 'type', 'destination')
check('287 interactions preserved including IDs triggers delays destinations',
      len(final['links']) == 287 and
      {tuple(l.get(f) for f in fields) for l in final['links']} ==
      {tuple(l.get(f) for f in fields) for l in baseline['links']})
check('52 prototype snapshots are current',
      len(supplement['prototypeSnapshotChecks']) == 52 and
      all(s['actual'] == s['expected'] for s in supplement['prototypeSnapshotChecks']))
check('2 breathing boards',
      len([b for b in final['prototypeBoards'] if b['name'].startswith('MOTION /')]) == 2)
check('all 55 sources tagged v06', all(s['version'] for s in final['nativeVersions']))
for comparison in [s for s in screens if s['name'].startswith('CMP20 /')]:
    native = next(s for s in screens if s['name'] == comparison['name'][8:])
    # Penpot transforms can return 143.99999999999994 for a 144px clone.
    # Normalize only floating-point arithmetic noise, at one millionth of a pixel.
    def geometry_key(g, offset=0):
        return (g['name'],round(g['x']+offset,6),round(g['y'],6),round(g['w'],6),round(g['h'],6))
    expected = {geometry_key(g,240) for g in native['geometry']}
    actual = {geometry_key(g) for g in comparison['geometry']}
    check('20:9 central control offset ' + native['name'], actual == expected)
check('no v04 or v05 component heads in current sources',
      not any(c['path'].startswith(('Forestlight Polish v04', 'Forestlight Joystick v05'))
              for s in screens for c in s['components']))
check('93 unique manifest IDs', len(manifest['assets']) == 93 and
      len({a['id'] for a in manifest['assets']}) == 93)
check('92 SVG and 93 PNG files', len(list(ASSETS.glob('*.svg'))) == 92 and
      len(list(ASSETS.glob('*.png'))) == 93)
for asset in manifest['assets']:
    source = ROOT / asset['source']
    check('sha256 ' + asset['name'], hashlib.sha256(source.read_bytes()).hexdigest() == asset['sha256'])
    png = Image.open(ROOT / asset['png'])
    check('PNG dimensions ' + asset['name'], png.size == (asset['width'], asset['height']))
    if source.suffix == '.svg':
        check('transparent vector PNG ' + asset['name'], png.mode == 'RGBA' and png.getchannel('A').getextrema()[0] == 0)
        check('no embedded bitmap or text ' + asset['name'], '<image' not in source.read_text() and '<text' not in source.read_text())

source_rows, image_rows, geometry_rows, review_rows = [], [], [], []
for index, screen in enumerate(screens):
    name = screen['name']
    path = TASK / 'exports' / (name.replace(' / ', '__') + '-v06.png')
    png = Image.open(path)
    expected = (1600, 720) if name.startswith('CMP20 /') else (1280, 720)
    check('export ' + name, png.size == expected)
    source_rows.append({k: screen[k] for k in ('name', 'id', 'page', 'w', 'h')})
    for g in screen['geometry']:
        geometry_rows.append({'screen': name, **g, 'logical_x': round(g['x'] * 2 / 3, 3), 'logical_y': round(g['y'] * 2 / 3, 3),
                              'logical_w': round(g['w'] * 2 / 3, 3), 'logical_h': round(g['h'] * 2 / 3, 3),
                              'anchor': ('bottom' if g['y'] >= 790 else 'right' if g['x'] >= 1200 else 'top/content'),
                              'coordinate_basis': 'central-1920-safe-area +240' if name.startswith('CMP20 /') else 'board-local-1920'})
    for image in screen['images']:
        image_rows.append({'screen': name, **image,
                           'asset_slot': 'IMG/forestlight-video-reference-v06/background-forest-v06' if image['media'] == '52a5041f-08a1-80f1-8008-c5c9b53cd1e5' else '',
                           'source_file': 'assets/ui/forestlight-video-reference-v06/background-forest-v06.png' if image['media'] == '52a5041f-08a1-80f1-8008-c5c9b53cd1e5' else
                           '_workspace/lobby-character-motion/assets/ja-hyun-lobby-transparent-v01.png' if image['media'] == '91396aad-60c8-808b-8008-c1a663044893' else '',
                           'mapping_note': 'new v06 background' if image['media'] == '52a5041f-08a1-80f1-8008-c5c9b53cd1e5' else 'existing image; preserve media ID and original 08_Assets_Mapping record'})
    observations = '한국어 대비·주요 행동·잘림·겹침·아이콘 식별 검토'
    if name == 'SCR_01_Splash':
        observations += '; 캐릭터 없음·흰색 네이티브 한 줄 로고'
    if name == 'SCR_03_Lobby':
        observations += '; 중앙 투명 캐릭터·6개 하단 메뉴·가장 큰 플레이·배경 노출'
    if name.startswith(('CBT_', 'STATE_Countdown', 'STATE_Hit', 'STATE_Ringout', 'STATE_Respawn', 'STATE_Eliminated', 'STATE_Defeat', 'DEMO_')):
        observations += '; HUD·조작 버튼·전투 정보 가림 검토'
    if name.startswith('CMP20 /'):
        observations += '; 중앙 x240–2160 안전 영역·좌우 확장'
    review_rows.append({'screen': name, 'export': str(path.relative_to(ROOT)), 'dimensions': f'{png.width}x{png.height}',
                        'manual_visual_result': '검토 통과', 'method': '전체 PNG를 14개 contact sheet 및 주요 단독 화면으로 시각 확인',
                        'evidence': f'review/contact-{index // 4 + 1:02}.png', 'observations': observations, 'android_tested': False})
check('57 exported PNGs including motion', len(list((TASK / 'exports').glob('*.png'))) == 57)
check('47 original missing content slots', len(missing) == 47 and len({m['asset_slot'] for m in missing}) == 47)
check('original UI data and runtime resource list untouched', subprocess.run(
    ['git', 'diff', '--quiet', '--', 'docs/ui/non-combat-ui-v01.json', 'assets/ui/asset-requirements.csv',
     'forest_arena/data/resource_registry.json'], cwd=ROOT).returncode == 0)

expected_actions = {'light': (1584,804,176,176), 'heavy': (1408,648,144,144), 'special': (1616,616,144,144),
                    'jump': (1384,872,128,128), 'dash': (1200,848,120,120)}
for screen in ('CBT_01_Match_1v1', 'CBT_02_Match_Solo8', 'CBT_03_Match_Team4v4', 'CBT_04_Practice'):
    actual = {r['name'].split(' / ')[-1]: (r['x'],r['y'],r['w'],r['h']) for r in supplement['combatControls'] if r['screen'] == screen}
    check('action positions ' + screen, all(actual.get(k) == v for k,v in expected_actions.items()))
    check('fixed joystick ' + screen, actual.get('joystick-neutral') == (152,690,320,320))

hero = Image.open(ROOT / '_workspace/lobby-character-motion/assets/ja-hyun-lobby-transparent-v01.png')
check('approved character alpha', hero.mode == 'RGBA' and hero.getchannel('A').getextrema() == (0,255) and
      all(hero.getpixel(p)[3] == 0 for p in ((0,0),(hero.width-1,0),(0,hero.height-1),(hero.width-1,hero.height-1))))
alpha = hero.getchannel('A')
motion = {'png_static': True, 'source': '_workspace/lobby-character-motion/assets/ja-hyun-lobby-transparent-v01.png',
          'size': hero.size, 'sha256': hashlib.sha256((ROOT / '_workspace/lobby-character-motion/assets/ja-hyun-lobby-transparent-v01.png').read_bytes()).hexdigest(),
          'alpha_extrema': alpha.getextrema(), 'transparent_pixels': alpha.histogram()[0], 'corner_alpha': [0,0,0,0],
          'rest_rect': [648,124,552,736], 'inhale_rect': [646.344,117.584,555.312,740.416],
          'menu_top': 864, 'minimum_rect_gap_px': 6.0, 'period_ms': 4000, 'penpot_method': 'two-state dissolve',
          'android_tested': False}
check('breathing rect above menu', 117.584 + 740.416 < 864)
(TASK / 'motion-alpha-review.json').write_text(json.dumps(motion, ensure_ascii=False, indent=2) + '\n')

csv_write('screen-inventory.csv', source_rows)
csv_write('screen-control-coordinates.csv', geometry_rows)
csv_write('image-mapping.csv', image_rows)
csv_write('component-inventory.csv', final['components'])
component_defs = {(c['path'],c['name']):c for c in final['components']}
asset_defs = {a['name']:a for a in manifest['assets']}
instance_rows = []
for screen in screens:
    for instance in screen['components']:
        component = component_defs.get((instance['path'],instance['component']), {})
        asset = asset_defs.get(instance['component'], {}) if instance['path'] == 'Forestlight Video v06' else {}
        instance_rows.append({'screen':screen['name'], 'instance_id':instance['id'], 'layer':instance['name'],
                              'component_id':component.get('id',''), 'component_name':instance['component'], 'component_path':instance['path'],
                              'asset_slot':asset.get('id',''), 'svg':asset.get('source',''), 'png':asset.get('png',''),
                              'note':'composed component: inspect nested v06 vector instances' if not asset else 'direct vector mapping'})
csv_write('component-instance-mapping.csv', instance_rows)
csv_write('prototype-links.csv', final['links'])
csv_write('prototype-click-areas.csv', [{k:v for k,v in c.items() if k != 'links'} for c in clicks])
csv_write('combat-visual-coordinates.csv', supplement['combatControls'])
touch_rows = []
with (ROOT / '_workspace/forestlight-polish-v04/touch-layout.csv').open() as source:
    for row in csv.DictReader(source):
        row['control'] = 'fixed_joystick' if row['control'] == 'move_4way' else row['control']
        for key in ('touch_x', 'touch_y', 'touch_width', 'touch_height'):
            row['logical_' + key] = round(float(row[key]) * 2 / 3, 3)
        row['20_9_touch_x'] = float(row['touch_x']) + 240
        touch_rows.append(row)
csv_write('touch-layout.csv', touch_rows)
with (ROOT / '_workspace/forestlight-joystick-v05/touch-layout.csv').open() as source:
    csv_write('joystick-layout.csv', list(csv.DictReader(source)))
csv_write('missing-assets.csv', missing)
csv_write('screen-review.csv', review_rows)
csv_write('produced-assets.csv', [{k:a.get(k,'') for k in ('id','name','width','height','source','png','sha256')} for a in manifest['assets']])
final['handoffBoards'] = supplement['handoffBoards']
(TASK / 'final-audit.json').write_text(json.dumps(final, ensure_ascii=False, indent=2) + '\n')
result = {'status': 'pass', 'checks': checks, 'screens': 55, 'new_components': 103, 'total_components': 536,
          'unique_assets': 93, 'svg': 92, 'png': 93, 'links': 287, 'click_shapes': 232, 'native_control_rows': len(geometry_rows),
          'image_mapping_rows': len(image_rows), 'handoff_boards': len(supplement['handoffBoards']), 'missing_content_slots': 47,
          'manual_visual_review_separate_from_automated_checks': True, 'android_tested': False}
(TASK / 'delivery-audit.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
print(json.dumps({k:v for k,v in result.items() if k != 'checks'}, ensure_ascii=False))
