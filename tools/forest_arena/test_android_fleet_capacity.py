#!/usr/bin/env python3
"""Headless real-server capacity fixture check; no Android-device pass claim."""
import argparse
from pathlib import Path
import shutil
import socket
import uuid

from android_fleet import (ROOT, Blocked, CapacityGuest, Failure, LanServer,
                           ProtocolPeer, _protocol_auth, _third_guest_rejection,
                           dump_json, require)


def free_ports():
    reservations = []
    try:
        for _ in range(2):
            reservation = socket.socket()
            reservation.bind(('127.0.0.1', 0))
            reservations.append(reservation)
        return [reservation.getsockname()[1] for reservation in reservations]
    finally:
        for reservation in reservations:
            reservation.close()


def verify_capacity(project_root, protocol, godot, output):
    port, api_port = free_ports()
    server = LanServer('127.0.0.1', '127.0.0.0/8', port, api_port, output, godot,
                       'capacity-'+uuid.uuid4().hex, project_root, protocol)
    host = capacity = None
    try:
        server.start()
        host = ProtocolPeer(server)
        host.send({'type': 'create_room', 'selection': {'schema_version': 1, 'character_id': 'ja-hyun', 'job_id': '', 'accessory_id': ''},
                   **_protocol_auth(server)})
        created = host.receive_until(lambda message: message.get('type') in ('room_created', 'error'))
        require(created.get('type') == 'room_created', '실제 서버의 새 방 생성 실패: '+str(created.get('code')))
        invite = created['invite_code']
        capacity = CapacityGuest(server, invite).start()
        started = host.receive_until(lambda message: message.get('type') in ('match_start', 'error'))
        require(started.get('type') == 'match_start' and started.get('slot') == 1,
                '실제 서버의 방장 슬롯/경기 시작 확인 실패')
        rejection = _third_guest_rejection(server, invite)
        observed = {'status': 'pass', 'protocol_version': protocol, 'server_project': str(Path(project_root).resolve()),
                    'capacity_fixture': capacity.observed, 'room_full_response': rejection,
                    'scope': 'headless_tool_check', 'actual_android_apk_ui': '미실행', 'physical_devices': 0}
        capacity.close()
        ended = host.receive_until(lambda message: message.get('type') == 'match_end')
        require(ended.get('winner_slot') == 1 and ended.get('reason') == 'disconnect',
                '정원용 임시 참가자의 정상 leave/정리 확인 실패')
        observed['fixture_cleanup'] = 'normal_leave_and_socket_closed'
        dump_json(output/'capacity-results.json', observed)
        return observed
    finally:
        if capacity:
            capacity.close()
        if host:
            host.close()
        server.close()


def main():
    parse = argparse.ArgumentParser(description='정원용 임시 참가자를 실제 Godot LAN 서버에서 확인')
    parse.add_argument('--project-root', type=Path, default=ROOT, help='LAN v2 프로젝트')
    parse.add_argument('--v1-project-root', type=Path, help='기존 LAN v1 프로젝트; 생략하면 v1 미실행')
    parse.add_argument('--godot', default=shutil.which('godot') or 'godot')
    parse.add_argument('--output', type=Path, default=ROOT/'artifacts/android-fleet-capacity')
    args = parse.parse_args()
    output = args.output/uuid.uuid4().hex
    output.mkdir(parents=True, exist_ok=False)
    (output/'.gdignore').touch()
    results = []
    for protocol, project in ((1, args.v1_project_root), (2, args.project_root)):
        if not project:
            results.append({'protocol_version': protocol, 'status': '미실행', 'message': '검사 프로젝트 미지정'})
            continue
        try:
            results.append(verify_capacity(project, protocol, args.godot, output/f'protocol-{protocol}'))
            print(f'ANDROID_FLEET_CAPACITY:v{protocol}:PASS (화면 없는 도구 검사)')
        except (Failure, Blocked, OSError, ValueError) as error:
            status = 'blocked' if isinstance(error, (Blocked, OSError)) else 'fail'
            results.append({'protocol_version': protocol, 'status': status, 'message': str(error)})
            print(f'ANDROID_FLEET_CAPACITY:v{protocol}:{status}')
    dump_json(output/'results.json', {'scope': 'headless_tool_check', 'protocols': results})
    print(f'증거: {output}')
    return int(any(result['status'] in ('fail', 'blocked') for result in results))


if __name__ == '__main__':
    raise SystemExit(main())
