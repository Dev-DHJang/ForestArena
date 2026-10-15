#!/usr/bin/env python3
"""Actual ADB smoke on one explicitly selected emulator; never a physical PASS."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import sys
import time
import uuid

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools/forest_arena'))
from android_fleet import ADB, DeviceRun, Failure, require, redact


def original_hashes(adb):
    if not adb.shell('pm', 'path', adb.package).startswith('package:'):
        return {}
    paths = ('local_player.json', 'local_player.json.bak', 'db_profile_session.json',
             'demo_guest_session.json', 'forest_arena_audio.cfg',
             'menu_presets_v01.json', 'menu_presets_v01.json.bak',
             'menu_controls_v01.json', 'menu_controls_v01.json.bak',
             'menu_identity_v01.json', 'menu_identity_v01.json.bak',
             'menu_progress_v01.json', 'menu_progress_v01.json.bak')
    script = "'for qa_store_path in " + ' '.join('files/' + p for p in paths)
    script += '; do if [ -f "$qa_store_path" ]; then sha256sum "$qa_store_path" || exit 73; fi; done; printf HASH_DONE\''
    raw = adb.run('exec-out', 'run-as', adb.package, 'sh', '-c', script).decode()
    require('HASH_DONE' in raw, '기존 저장 해시 확인 완료 표시 누락')
    return {line.split()[-1]: line.split()[0] for line in raw.splitlines() if len(line.split()) == 2}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--apk', type=Path, required=True)
    parser.add_argument('--adb', default=str(Path.home() / 'Library/Android/sdk/platform-tools/adb'))
    parser.add_argument('--serial', default='emulator-5554')
    parser.add_argument('--package', default='com.forestarena.welllbeing')
    args = parser.parse_args()
    require(args.serial.startswith('emulator-'), '이 도구는 명시된 에뮬레이터만 검사합니다.')
    adb = ADB(args.adb, args.serial, args.package)
    require(adb.shell('getprop', 'sys.boot_completed') == '1', '에뮬레이터가 아직 부팅되지 않았습니다.')
    run_id = 'menu_emu_' + uuid.uuid4().hex[:16]
    output = Path(__file__).parent / run_id
    output.mkdir()
    report = {'kind': 'emulator_only', 'physical_device_status': '미확인', 'run_id': run_id,
              'serial': args.serial, 'apk': str(args.apk.resolve()),
              'apk_sha256': hashlib.sha256(args.apk.read_bytes()).hexdigest(), 'checks': []}
    before = original_hashes(adb)
    report['original_hashes_before'] = before
    runner = None
    started = time.time()
    try:
        install = adb.run('install', '-r', str(args.apk.resolve()), timeout=180).decode()
        require('Success' in install, 'APK 교체 설치 실패: ' + install)
        activity = adb.shell('cmd', 'package', 'resolve-activity', '--brief', args.package).splitlines()[-1].split('/', 1)[1]
        runner = DeviceRun(adb, 'emulator', run_id, output, activity, screen_timeout=30)
        runner.case_id = 'EMULATOR-SMOKE'
        dimensions = re.search(r'(\d+)x(\d+)', adb.shell('wm', 'size'))
        require(dimensions is not None, '에뮬레이터 실제 화면 크기를 읽지 못했습니다.')
        sides = [int(dimensions.group(1)), int(dimensions.group(2))]
        runner.physical_size = (max(sides), min(sides))
        report['physical_landscape_size'] = list(runner.physical_size)
        # No physical fleet setup/inspect and no OS settings or application clearing.
        runner.launch()
        runner.screen('first')
        runner.evidence('cold-start-first')
        report['checks'].append({'name': 'cold-start', 'status': 'pass', 'boot_id': runner.state['boot_id']})
        cards = [item for item in runner.read()['ui'] if item['kind'] == 'button' and item['text'] != '저장 모드 · 기기 저장']
        runner.tap(id=cards[0]['id'])
        runner.screen('home')
        runner.evidence('first-grant-lobby')
        report['checks'].append({'name': 'first-grant', 'status': 'pass', 'character': runner.state['profile']['selected_character']})
        runner.tap('캐릭터')
        runner.screen('character_collection')
        runner.evidence('character-menu')
        runner.tap(id='menu/character_collection/back')
        runner.screen('home')
        report['checks'].append({'name': 'character-back-lobby', 'status': 'pass'})
        runner.tap('상점 · 모두 0원')
        runner.screen('shop')
        runner.tap(id='menu/shop/category/accessory')
        product = 'fixture-iron-armor'
        runner.tap(id='purchase/' + product)
        runner.evidence('purchase-modal')
        require(product not in runner.read()['profile']['accessories'], '확인 전에 구매됐습니다.')
        runner.tap(id='menu/shop/purchase_confirm/' + product)
        runner.wait(lambda state: product in state['profile']['accessories'], label='무료 구매 저장')
        runner.evidence('purchase-completed')
        report['checks'].append({'name': 'zero-price-modal-purchase', 'status': 'pass', 'id': product})
        runner.tap(id='menu/shop/back')
        runner.screen('home')
        runner.tap('접근성 설정')
        runner.screen('accessibility')
        runner.tap(id='menu/settings/category/controls')
        runner.screen('controls')
        runner.tap(id='menu/controls/draft/joystick_mode/floating')
        runner.tap(id='menu/controls/settings_apply')
        controls_path = f'files/qa/{run_id}/menu_controls_v01.json'
        runner.wait(lambda state: json.loads(adb.run('exec-out', 'run-as', args.package, 'cat', controls_path))['controls']['joystick_mode'] == 'floating', label='플로팅 설정 저장')
        controls = json.loads(adb.run('exec-out', 'run-as', args.package, 'cat', controls_path))
        profile = runner.read()['profile']
        runner.evidence('controls-applied')
        runner.launch()
        runner.screen('home')
        require(runner.state['profile'] == profile, '재실행 프로필 복원이 다릅니다.')
        runner.tap('접근성 설정')
        runner.screen('accessibility')
        runner.tap(id='menu/settings/category/controls')
        runner.screen('controls')
        require(json.loads(adb.run('exec-out', 'run-as', args.package, 'cat', controls_path)) == controls, '재실행 조작 저장 복원이 다릅니다.')
        require(any(item.get('id') == 'menu/controls/draft/joystick_mode/floating' and item.get('text', '').endswith(' ✓') for item in runner.read()['ui']), '재실행 화면의 플로팅 선택 표시가 다릅니다.')
        runner.evidence('controls-restored')
        report['checks'].append({'name': 'controls-apply-relaunch-restore', 'status': 'pass', 'controls': controls['controls']})
        runner.tap(id='menu/controls/back')
        runner.screen('home', 'accessibility')
        if runner.state['screen'] == 'accessibility':
            runner.tap(id='menu/settings/back')
            runner.screen('home')
        runner.tap('미션')
        runner.screen('mission')
        runner.tap(id='menu/mission/category/weekly')
        runner.evidence('mission-weekly-local')
        runner.tap(id='menu/mission/category/achievements')
        runner.evidence('mission-achievements-local')
        runner.tap(id='menu/mission/back')
        runner.screen('home')
        runner.tap('친구')
        runner.screen('social')
        runner.tap(id='menu/social/category/search')
        runner.evidence('social-unlinked-search')
        runner.tap(id='menu/social/all_menu')
        runner.tap(id='menu/social/open/rank')
        runner.screen('rank')
        runner.tap(id='menu/rank/scope/month')
        runner.evidence('rank-unlinked-month')
        runner.tap(id='menu/rank/all_menu')
        runner.tap(id='menu/rank/open/profile')
        runner.screen('profile')
        runner.evidence('profile-local')
        for _ in range(5):
            if runner.read()['screen'] == 'home':
                break
            adb.shell('input', 'keyevent', '4')
            time.sleep(.4)
        runner.screen('home')
        report['checks'].append({'name': 'mission-social-rank-profile-native-menu-navigation', 'status': 'pass', 'network_service': 'unlinked; real API tested separately'})
        runner.prepare()
        runner.start_match()
        adb.shell('input', 'keyevent', '4')
        runner.screen('pause')
        runner.tap('조작 설정')
        runner.screen('controls')
        runner.tap(id='menu/controls/back')
        runner.screen('pause')
        runner.evidence('controls-back-pause')
        runner.tap('계속하기')
        runner.screen('match')
        report['checks'].append({'name': 'pause-controls-back-resume', 'status': 'pass'})
        report['status'] = 'pass'
    except Exception as error:
        report['status'] = 'fail'
        report['error'] = redact(str(error))
        if runner:
            runner.read()
            runner.evidence('failure')
    finally:
        try:
            after = original_hashes(adb)
            report['original_hashes_after'] = after
            report['original_hashes_unchanged'] = before == after
            if before != after: report['status'] = 'fail'
        except Exception as error:
            report['original_hashes_unchanged'] = None
            report['hash_error'] = redact(str(error))
            report['status'] = 'blocked'
        report['elapsed_seconds'] = round(time.time() - started, 1)
        logs = adb.run('logcat', '-d', '-t', '1500', timeout=20, check=False).decode(errors='replace')
        (output / 'logcat-tail.txt').write_text(redact(logs))
        (output / 'summary.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n')
        print(json.dumps({'status': report['status'], 'kind': report['kind'], 'checks': report['checks'], 'error': report.get('error'), 'artifact': str(output)}, ensure_ascii=False))
    return 0 if report['status'] == 'pass' else 1

if __name__ == '__main__':
    raise SystemExit(main())
