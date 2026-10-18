"""자동 묶음 뒤 같은 격리 QA 실행에서 실제 시작 영상·메뉴 화면을 확인한다."""
from pathlib import Path
import argparse
import json
import re
import struct
import subprocess
import sys
import time
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/forest_arena'))
from android_fleet import ADB, Blocked, DeviceRun, require, CHARACTER_LABELS

ROOT = Path(__file__).resolve().parents[2]
MENUS = ('character_collection', 'character_detail', 'accessory_collection', 'accessory_detail',
         'preset', 'shop', 'collection', 'mission', 'social', 'rank', 'profile', 'controls')


def capture_installed_icon(adb, out):
    adb.shell('am', 'start', '-W', '-a', 'android.settings.APPLICATION_DETAILS_SETTINGS',
              '-d', 'package:'+adb.package)
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        activities = adb.shell('dumpsys', 'activity', 'activities')
        resumed = [line.strip() for line in activities.splitlines()
                   if 'topResumedActivity=' in line or 'mResumedActivity:' in line]
        if any('com.android.settings/' in line for line in resumed):
            time.sleep(1)
            adb.screenshot(out / 'android-installed-app-icon.png')
            adb.shell('input', 'keyevent', '4')
            return {'status': 'pass', 'resumed_activity': resumed,
                    'screenshot': 'android-installed-app-icon.png'}
        time.sleep(.25)
    raise Blocked('Android 앱 정보 화면의 실제 전환을 확인하지 못했습니다.')


def capture_character_views(device, report, character_labels=CHARACTER_LABELS):
    device.prepare()
    device.command('select_config', mode=4, accessory='')
    report['character_views'] = []
    for character, label in character_labels.items():
        device.tap(label)
        device.wait(lambda state: state.get('profile', {}).get('selected_character') == character,
                    label=label+' 실제 선택')
        device.start_match()
        ready = device.wait(lambda state: device.player(state).get('character_id') == character and
                            device.player(state).get('state') == 'IDLE', label=label+' 실제 파이터 입력 준비')
        battle = device.evidence(character+'-battle')
        require(battle['screenshot'], label+' 전투 화면 저장 실패')
        before_jump = ready['msec']
        node = device.node(id='touch/jump')
        x, y = device.center(node)
        # Menu taps intentionally settle for 300ms; a short jump can finish
        # during that delay. Sample immediately after a real tap instead.
        device.adb.touch(x, y)
        with (device.output / 'adb-touch.jsonl').open('a') as stream:
            stream.write(json.dumps({'input_source': 'adb_touch', 'id': 'touch/jump',
                                     'x': x, 'y': y, 'hold_ms': 0,
                                     'settle_delay_ms': 0})+'\n')
        jumped = device.wait(lambda state: state.get('msec', -1) > before_jump and
                             device.player(state).get('character_id') == character and
                             device.player(state).get('state') in ('JUMP', 'FALL'), label=label+' 실제 점프 상태', poll=.03)
        jump = device.evidence(character+'-jump')
        require(jump['screenshot'], label+' 점프 화면 저장 실패')
        actor = device.player(jumped)
        report['character_views'].append({'character': character, 'presentation': actor.get('presentation', {}),
                                           'battle_evidence': battle, 'jump_evidence': jump,
                                           'input_source': 'adb_touch', 'status': 'pass'})
        device.prepare()
    device.tap('로비')
    device.screen('home')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run-directory', type=Path, required=True)
    parser.add_argument('--target-file', type=Path, required=True)
    args = parser.parse_args()
    run_id = args.run_directory.name
    require(bool(re.fullmatch(r'[a-f0-9]{32}', run_id)), 'QA 실행 ID가 올바르지 않습니다.')
    targets = json.loads(args.target_file.read_text())
    selected = None
    for row in targets:
        test = subprocess.run(['adb', '-s', row['serial'], 'get-state'], capture_output=True, timeout=10)
        if test.returncode == 0 and test.stdout.strip() == b'device':
            selected = row
            break
    require(selected is not None, '선택한 실기기 연결 없음')
    out = args.run_directory / 'supplemental'
    out.mkdir(exist_ok=True)
    adb = ADB('adb', selected['serial'], 'com.forestarena.welllbeing')
    device = DeviceRun(adb, 'device-1', run_id, out, 'com.godot.game.GodotAppLauncher')
    original = adb.original_store_hashes()
    report = {'status': 'running', 'run_id': run_id, 'cold_starts': [], 'menus': [],
              'device_model': selected['model'], 'original_stores_before': original}
    try:
        state = device.read()
        png = adb.run('exec-out', 'screencap', '-p')
        require(png.startswith(b'\x89PNG'), '실기기 화면 크기 확인 실패')
        device.physical_size = struct.unpack('!II', png[16:24])
        device.seq = int(state.get('command_seq', 0))
        device.prepare()
        device.tap('로비')
        device.screen('home')
        for index in range(1, 4):
            remote = f'/sdcard/forest-arena-qa-{run_id}-{index}.mp4'
            recording_log = (out / f'cold-start-{index}-recording.log').open('wb')
            recording = subprocess.Popen(['adb', '-s', selected['serial'], 'shell', 'screenrecord',
                                          '--size', '1544x720', '--bit-rate', '2000000', '--time-limit', '12', remote],
                                         stdout=recording_log, stderr=subprocess.STDOUT)
            try:
                time.sleep(.5)
                prior_boot = device.read().get('boot_id')
                adb.launch(device.activity, run_id, device.alias)
                device.wait(lambda s: s.get('boot_id') != prior_boot and s.get('screen') == 'title', label='새 타이틀 실행')
                title = device.wait(lambda s: s.get('screen') == 'title' and s.get('ready'), label='타이틀 준비')
                png = adb.run('exec-out', 'screencap', '-p')
                (out / f'cold-start-{index}-title.png').write_bytes(png)
                width, height = struct.unpack('!II', png[16:24])
                device.physical_size = width, height
                adb.touch(width//2, round(height*.78), hold_ms=200)
                game = device.wait(lambda s: s.get('screen') == 'home' and s.get('foreground'), label='새 터치 뒤 로비')
                adb.screenshot(out / f'cold-start-{index}-lobby.png')
                report['cold_starts'].append({'index': index, 'status': 'pass', 'title': title,
                                             'game_boot_id': game['boot_id'], 'game_screen': game['screen'],
                                             'input_source': 'adb_touch', 'video': f'cold-start-{index}.mp4'})
                device.seq = max(device.seq, int(game.get('command_seq', 0)))
                print(f'Cold start {index}: PASS', flush=True)
            finally:
                recording.wait(timeout=20)
                recording_log.close()
                adb.run('pull', remote, str(out / f'cold-start-{index}.mp4'), timeout=30)
                adb.shell('rm', remote)
        # The Android app information page renders the installed icon without
        # recording unrelated launcher icons or personal home-screen content.
        report['installed_icon'] = capture_installed_icon(adb, out)
        device.wait(lambda s: s.get('screen') == 'home' and s.get('foreground'), label='앱 정보 뒤 복귀')
        device.tap('접근성 설정')
        device.screen('accessibility')
        device.evidence('settings')
        report['menus'].append({'menu': 'settings', 'screen': 'accessibility', 'status': 'pass'})
        for menu in MENUS:
            previous = device.read().get('msec', -1)
            device.tap(id='menu/settings/all_menu')
            device.tap(id='menu/settings/open/'+menu)
            state = device.wait(lambda s: s.get('screen') == menu and s.get('msec', -1) > previous, label=menu+' 실제 진입')
            device.evidence('menu-'+menu)
            texts = [x.get('text', '') for x in state.get('ui', []) if x.get('visible', True)]
            adb.shell('input', 'keyevent', '4')
            returned = device.wait(lambda s: s.get('screen') == 'accessibility' and s.get('msec', -1) > state['msec'], label=menu+' 뒤로 복귀')
            report['menus'].append({'menu': menu, 'screen': state['screen'], 'msec': state['msec'],
                                    'returned_screen': returned['screen'], 'status': 'pass', 'visible_text': texts})
            print('Menu '+menu+': PASS', flush=True)
        # The same card component appears in three scrollable product views.
        report['body_swipes'] = []
        for menu in ('shop', 'accessory_collection', 'collection'):
            device.tap(id='menu/settings/all_menu')
            device.tap(id='menu/settings/open/'+menu)
            device.screen(menu)
            if menu == 'shop':
                category = next(n for n in device.read()['ui'] if n.get('id') == 'menu/shop/category/전체')
                if not category.get('disabled'):
                    device.tap(id='menu/shop/category/전체')
            before = device.read()
            candidates = [n for n in before.get('ui', []) if n.get('kind') == 'button' and
                          (n.get('id', '').startswith('purchase/') or
                           n.get('id', '').startswith('menu/accessory_collection/accessory/') or
                           n.get('id', '').startswith('menu/collection/read/'))]
            require(candidates, menu+' 스크롤 관측 대상 버튼 없음')
            target = max(candidates, key=lambda n: n['y'])
            width, height = device.viewport()
            x, start, end = (.36, .34, .22) if menu == 'shop' else (.50, .52, .25)
            adb.shell('input', 'swipe', str(round(width*x)), str(round(height*start)),
                      str(round(width*x)), str(round(height*end)), '700')
            after = device.wait(lambda state: state.get('msec', 0) > before['msec'] and
                                any(n.get('id') == target['id'] and n.get('y', 99) < target['y'] - .02
                                    for n in state.get('ui', [])), label=menu+' 실제 본문 드래그')
            observed = next(n for n in after['ui'] if n.get('id') == target['id'])
            device.evidence(menu+'-body-swipe')
            report['body_swipes'].append({'menu': menu, 'target': target['id'], 'before_y': target['y'],
                                         'after_y': observed['y'], 'input_source': 'adb_swipe', 'status': 'pass'})
            adb.shell('input', 'keyevent', '4')
            device.screen('accessibility')
            print('Body swipe '+menu+': PASS', flush=True)
        adb.shell('input', 'keyevent', '4')
        device.screen('home')
        capture_character_views(device, report)
        report['status'] = 'pass'
    except Exception as error:
        report.update(status='blocked' if isinstance(error, Blocked) else 'fail', error=str(error))
        try:
            adb.screenshot(out / 'failure.png')
        except Exception:
            pass  # A lost transport must not hide the original failure.
        raise
    finally:
        try:
            after = adb.original_store_hashes()
            report.update(original_stores_after=after, original_stores_unchanged=after == original)
            if after != original:
                report.update(status='fail', error='기존 저장 파일 해시 변경')
        except Exception as error:
            report.update(original_stores_after=None, original_stores_unchanged=None,
                          store_check_error=str(error))
            if report['status'] in ('running', 'pass'):
                report.update(status='blocked', error='연결 중단으로 기존 저장 확인 불가')
        (out / 'results.json').write_text(json.dumps(report, ensure_ascii=False, indent=2)+'\n')
    require(report['status'] == 'pass', report.get('error', '추가 검사 실패'))


if __name__ == '__main__':
    main()
