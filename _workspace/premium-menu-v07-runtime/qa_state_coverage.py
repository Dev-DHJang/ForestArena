"""Map every approved design state to its real menu destination.

Future service examples resolve to honest empty screens; no fake profiles,
rankings, rewards or mission records are introduced to mimic design-only data.
Execution status is added only from the independent Godot report.
"""
import argparse
import csv
import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = {
    'SCR_04_CharacterCollection': 'character_collection',
    'SCR_05_CharacterDetail': 'character_detail',
    'SCR_06_AccessoryCollection': 'accessory_collection',
    'SCR_07_AccessoryDetail': 'accessory_detail', 'SCR_08_Preset': 'preset',
    'SCR_19_Shop': 'shop', 'SCR_20_Collection': 'collection',
    'SCR_21_Mission': 'mission', 'SCR_22_Social': 'social',
    'SCR_23_Rank': 'rank', 'SCR_24_Profile': 'profile',
    'EXT_06_GeneralSettings': 'settings', 'CBT_08_Settings': 'controls',
}
CHARACTERS = ['ja-hyun', 'myo-ryung', 'nabi', 'yu-ran']
ACCESSORIES = ['fixture-iron-armor', 'fixture-boxing-gloves', 'fixture-thorns', 'fixture-explosive-gloves', 'fixture-ultimate-charm', 'fixture-phoenix-revive']
rows = []
for design in csv.DictReader((ROOT / '_workspace/premium-menu-v07/state-table.csv').open()):
    screen = design['screen']
    base = next((x for x in BASE if x in screen), '')
    menu = BASE.get(base, '')
    params, action, policy = {}, 'open', 'implemented'
    note = '실제 목록·선택·필터·탭과 해당 화면에서 확인한다.'
    if match := re.search(r'char-(\d+)-tab-(\d+)-filter-(.+)', screen):
        params = {'selected_id': CHARACTERS[int(match[1])], 'tab': ['기술', '연계', '이야기'][int(match[2])], 'filter': match[3]}
    if match := re.search(r'item-(\d+)-filter-(.+)', screen):
        params = {'selected_id': ACCESSORIES[int(match[1])], 'filter': match[2]}
        if match[2] in ['이동', '방어', '기술']:
            params['selected_id'] = {'이동': 'fixture-thorns', '방어': 'fixture-iron-armor', '기술': 'fixture-boxing-gloves'}[match[2]]
    if match := re.search(r'slot-(\d+)', screen):
        params = {'slot': int(match[1])}; action = 'preset_slot'
    if 'category-' in screen:
        params = {'category': 'accessory' if screen.endswith('장신구') else 'character'}
    if '/ detail-' in screen and menu == 'shop':
        params = {'product_id': ACCESSORIES[int(screen.rsplit('-', 1)[1])]}
        action = 'open_product_modal'
    if menu == 'collection':
        params = {'category': 'accessory' if screen.endswith('/ accessory') else 'character', 'filter': '미보유' if screen.endswith('/ unowned') else '보유'}
        note = '실제 프로필의 보유 목록을 읽기 전용으로 표시한다. 장착·선택 저장은 없다.'
    if menu in ['mission', 'social', 'rank']:
        policy = 'honest_empty'; note = '사용자 승인 범위: 서비스 준비 중·빈 상태. 설계의 친구·미션·순위 예시는 만들지 않는다.'
        if '/ tab-' in screen: params['tab'] = ['일일', '주간', '업적'][int(screen.rsplit('-', 1)[1])]
        if screen.endswith('/ recent'): params['tab'] = '최근 플레이어'
        if any(x in screen for x in ['/ friend-', '/ detail-', 'connection-error', 'search-empty']):
            action = 'empty_state'; note += ' 데이터가 없으므로 가짜 상세·실패·검색 응답을 생성하지 않는다.'
    if menu == 'settings':
        params = {'category': 'accessibility' if '접근성' in screen else 'effects' if '화면 효과' in screen else 'sound'}
        if screen.endswith('-off'): action = 'draft_then_cancel_or_apply'
    if menu == 'controls':
        params = {'entry_context': 'pause'}
        if screen.endswith('/ floating'): action = 'draft_floating'
    if not menu:
        specific = screen.removeprefix('MENU07 / ')
        menu = 'controls'
        if 'Lobby' in specific or specific in ['ControlsFromLobby', 'ControlsFloatingFromLobby']:
            params['entry_context'] = 'lobby'
        else: params['entry_context'] = 'pause'
        if 'Floating' in specific: action = 'draft_floating'
        elif 'SettingsReset' in specific:
            if specific == 'SettingsResetGeneral': menu = 'settings'; params = {'category': 'sound'}
            action = 'settings_reset_modal'
        elif 'ControlsParameters' in specific: action = 'native_sliders'; note = '기기 설정의 버튼 크기·투명도 실제 슬라이더를 검사한다.'
        elif specific == 'EmptyList':
            menu = 'collection'; params = {'category': 'accessory', 'filter': '보유'}; action = 'empty_state'
        elif specific == 'SelectionRequired': menu = 'preset'; action = 'empty_slot_apply_modal'
        elif specific == 'Review':
            menu = 'settings'; params = {}; action = 'all_menu_navigation'; policy = 'handoff_only'
            note = '설계 검토용 모음 보드이며 제품 화면이 아니다. 하위 메뉴 전체 메뉴에서 13개 화면군으로 이동한다.'
    rows.append({'design_screen': screen, 'kind': design['kind'], 'runtime_menu': menu,
                 'params': params, 'action': action, 'policy': policy, 'reason': note,
                 'runtime_check': 'pending'})
assert len(rows) == 81 and len({r['design_screen'] for r in rows}) == 81
parser = argparse.ArgumentParser()
parser.add_argument('--report', type=Path, default=HERE / 'qa-runtime-r08-report.json', help='Independent Godot runtime report; pending if absent')
args = parser.parse_args()
report = json.loads(args.report.read_text()) if args.report.exists() else {}
executed = {record['design_screen']: record for record in report.get('state_coverage', [])}
if executed:
    assert len(executed) == 81 and set(executed) == {r['design_screen'] for r in rows}
    for row in rows:
        evidence = executed[row['design_screen']]
        row['runtime_check'] = f"{'pass' if evidence['pass'] else 'fail'} · {evidence['checks']}개 실제 상태 확인"
result = {'design_states': len(rows), 'runtime_menu_families': 13,
          'device_test': 'not_run', 'executed_states': len(executed), 'evidence_report': str(args.report.relative_to(ROOT)) if args.report.is_absolute() and args.report.is_relative_to(ROOT) else str(args.report), 'report_failures': len(report.get('failures', [])), 'states': rows}
(HERE / 'state-runtime-coverage.json').write_text(json.dumps(result, ensure_ascii=False, indent=2)+'\n')
with (HERE / 'state-runtime-coverage.csv').open('w', newline='') as out:
    writer = csv.DictWriter(out, fieldnames=rows[0].keys())
    writer.writeheader()
    for row in rows:
        row = dict(row); row['params'] = json.dumps(row['params'], ensure_ascii=False)
        writer.writerow(row)
print(f'Mapped {len(rows)} approved states; executed evidence {len(executed)} states.')
