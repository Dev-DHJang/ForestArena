#!/usr/bin/env python3
"""Small physical-device MENU09 check, using the existing isolated QA session."""
import hashlib
import json
import sys
import time
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(ROOT / 'tools/forest_arena'))
from android_fleet import ADB, DeviceRun, require

APK = ROOT / 'build/android/ForestArena-debug.apk'
OUTPUT = ROOT / '_workspace/menu-sketch-ui/app-media-r01/android-device-r02'
RUN_OUTPUT = ROOT / 'build/menu09-android-smoke' / uuid.uuid4().hex
EXPECTED = 'e8f2c2ca718acd8b76e97c1c33687bdcc85aac7e62a178757dd3179191f1d295'
if len(sys.argv) != 2:
    raise SystemExit('Usage: device_smoke.py <explicit-device-serial>')
DEVICE = ADB('adb', sys.argv[1], 'com.forestarena.welllbeing')
run = DeviceRun(DEVICE, 'device-1', RUN_OUTPUT.name, RUN_OUTPUT, 'com.godot.game.GodotAppLauncher', apk_sha256=EXPECTED)
checks = []

def check(name, condition):
    checks.append({'name': name, 'pass': bool(condition)})
    require(condition, name)
    print(name, 'PASS', flush=True)

def screen(name):
    return run.screen(name, timeout=30)

def tap(qa_id):
    run.tap(id=qa_id)

def capture(name):
    run.adb.screenshot(OUTPUT / (name + '.png'))

try:
    info = run.setup(APK)
    check('물리 기기 설치 및 가로 화면', info['physical_size'][0] > info['physical_size'][1])
    cards = [x for x in run.read().get('ui', []) if x.get('kind') == 'button' and x.get('text') == '자현']
    check('격리 검사 프로필 시작', bool(cards))
    run.tap(id=cards[0]['id'])
    screen('home')
    capture('01-lobby')
    run.tap(text='캐릭터')
    screen('character_collection')
    tap('menu/character_collection/detail')
    screen('character_detail')
    tap('menu/media/play/ja-hyun.light')
    run.wait(lambda s:any(x.get('id') == 'menu/media/toggle' and x.get('text') == '일시정지' for x in s.get('ui', [])), label='영상 재생 시작')
    time.sleep(1.2)
    capture('02-video-playing')
    first = DEVICE.run('exec-out', 'screencap', '-p')
    time.sleep(1.2)
    second = DEVICE.run('exec-out', 'screencap', '-p')
    check('기술 영상 화면 진행', hashlib.sha256(first).digest() != hashlib.sha256(second).digest())
    tap('menu/media/toggle')
    run.wait(lambda s:any(x.get('id') == 'menu/media/toggle' and x.get('text') == '이어서 재생' for x in s.get('ui', [])), label='영상 일시정지')
    capture('03-video-paused')
    check('영상 일시정지', True)
    tap('menu/media/toggle')
    run.wait(lambda s:any(x.get('id') == 'menu/media/toggle' and x.get('text') == '일시정지' for x in s.get('ui', [])), label='영상 이어서 재생')
    tap('menu/media/close')
    check('닫기 후 기술 화면 유지', screen('character_detail')['screen'] == 'character_detail')
    tap('menu/character_detail/back')
    screen('character_collection')
    tap('menu/character_collection/back')
    screen('home')
    run.tap(text='상점')
    screen('shop')
    tap('menu/shop/detail/ja-hyun')
    check('상점 캐릭터 목록에서 상세 진입', screen('shop_detail')['screen'] == 'shop_detail')
    capture('04-shop-detail')
    tap('menu/shop_detail/back')
    check('상점 상세에서 목록 복귀', screen('shop')['screen'] == 'shop')
    after = DEVICE.original_store_hashes()
    check('일반 저장 파일 보존', after == run.original_hashes)
    result = {'status':'pass','device':'Galaxy S23 Ultra (SM-S918N)','android':'16','apk_sha256':EXPECTED,'input':'ADB touch','qa_profile':'isolated','checks':checks,'run_output':str(RUN_OUTPUT.relative_to(ROOT))}
except Exception as error:
    result = {'status':'fail','device':'Galaxy S23 Ultra (SM-S918N)','apk_sha256':EXPECTED,'checks':checks,'error':str(error),'run_output':str(RUN_OUTPUT.relative_to(ROOT))}
    raise
finally:
    (OUTPUT / 'device-results.json').write_text(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    if run.logcat and run.logcat.poll() is None: run.logcat.terminate()
    for stream in (run.logfile, run.logstderr):
        if stream: stream.close()
