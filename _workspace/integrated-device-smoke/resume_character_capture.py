"""완료된 시작/메뉴를 보존하고 짧은 실제 점프와 설치 아이콘을 다시 확인한다."""
import argparse
import json
from pathlib import Path
import struct
import subprocess
from supplemental_device import ADB, DeviceRun, Blocked, require, capture_character_views, capture_installed_icon


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run-directory', type=Path, required=True)
    parser.add_argument('--target-file', type=Path, required=True)
    args = parser.parse_args()
    prior = json.loads((args.run_directory/'supplemental/results.json').read_text())
    require(len(prior['cold_starts']) == 3 and len(prior['menus']) == 13 and
            len(prior['body_swipes']) == 3 and prior['original_stores_unchanged'], '선행 검사 누락')
    require(all(item.get('status') == 'pass' for group in ('cold_starts','menus','body_swipes')
                for item in prior[group]), '선행 검사에 통과하지 않은 항목이 있습니다.')
    target = next((r for r in json.loads(args.target_file.read_text())
                   if subprocess.run(['adb','-s',r['serial'],'get-state'],capture_output=True,timeout=5).stdout.strip() == b'device'), None)
    require(target is not None, '실기기 연결 없음')
    out = args.run_directory/'supplemental-r03'
    out.mkdir(exist_ok=False)
    adb = ADB('adb',target['serial'],'com.forestarena.welllbeing')
    device = DeviceRun(adb,'device-1',args.run_directory.name,out,'com.godot.game.GodotAppLauncher')
    report = {'status':'running','prior_completed_capture':'../supplemental/results.json',
              'original_stores_before':adb.original_store_hashes()}
    try:
        state = device.read()
        device.seq = int(state.get('command_seq',0))
        png = adb.run('exec-out','screencap','-p')
        device.physical_size = struct.unpack('!II',png[16:24])
        capture_character_views(device,report)
        print('Four character battle and fresh jump captures: PASS',flush=True)
        report['installed_icon'] = capture_installed_icon(adb,out)
        device.wait(lambda s:s.get('screen')=='home' and s.get('foreground'),label='앱 정보 뒤 로비 복귀')
        report['status'] = 'pass'
    except Exception as error:
        report.update(status='blocked' if isinstance(error,Blocked) else 'fail',error=str(error))
        raise
    finally:
        try:
            after = adb.original_store_hashes()
            report.update(original_stores_after=after,original_stores_unchanged=after==report['original_stores_before'])
            if not report['original_stores_unchanged']:report.update(status='fail',error='기존 저장 변경')
        except Exception as error:
            report.update(status='blocked',store_check_error=str(error))
        (out/'results.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    require(report['status']=='pass', report.get('error','추가 재검사 실패'))


if __name__ == '__main__':
    main()
