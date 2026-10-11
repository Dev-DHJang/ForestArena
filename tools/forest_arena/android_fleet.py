#!/usr/bin/env python3
"""Selected real Android devices: ADB touch + debug autoplay, honest evidence.

No automatic pairing, am clear, release instrumentation, or Wi-Fi toggling.
"""
from __future__ import annotations
import argparse
import concurrent.futures
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
import uuid

ROOT = Path(__file__).resolve().parents[2]
SCHEMA_VERSION = 1
CANCELLED = threading.Event()
CHARACTER_LABELS = {'ja-hyun': '자현', 'myo-ryung': '묘령', 'nabi': '나비', 'yu-ran': '유란'}
CHARACTERS = ('ja-hyun', 'myo-ryung', 'nabi', 'yu-ran')
ACCESSORIES = ('', 'fixture-boxing-gloves', 'fixture-thorns', 'fixture-iron-armor',
               'fixture-phoenix-revive', 'fixture-ultimate-charm', 'fixture-explosive-gloves')
CASES = ('DEV-01', 'UI-01', 'OFF-01', 'INPUT-01', 'LIFE-01', 'OFF-02', 'MODE-01',
         'LAN-01', 'LAN-02', 'LAN-03', 'SOAK-01', 'MANUAL-01')


class Blocked(RuntimeError):
    """Environment/transport prevented a measurement."""


class NotExecuted(RuntimeError):
    """A deliberate deadline ended before this observation completed."""


class Failure(RuntimeError):
    """Measured behavior did not match the expected behavior."""


def require(value, message):
    if not value:
        raise Failure(message)


def selected_serials(values):
    serials = [serial.strip() for value in values for serial in value.split(',') if serial.strip()]
    if len(serials) > 4:
        raise ValueError('대상 실기기는 최대 4대입니다.')
    if len(set(serials)) != len(serials):
        raise ValueError('대상 serial이 중복되었습니다.')
    if any(not re.fullmatch(r'[A-Za-z0-9._:@-]+', serial) for serial in serials):
        raise ValueError('serial 형식이 잘못되었습니다.')
    return serials


def combination_jobs(device_count):
    if not 1 <= device_count <= 4:
        raise ValueError('device_count must be 1..4')
    jobs = [[] for _ in range(device_count)]
    for index, (character, accessory) in enumerate((c, a) for c in CHARACTERS for a in ACCESSORIES):
        jobs[index % device_count].append({'character': character, 'accessory': accessory})
    return jobs


def aggregate(results):
    statuses = [item['status'] for item in results]
    counts = {status: statuses.count(status) for status in ('pass', 'fail', 'blocked', '미실행')}
    overall = 'fail' if counts['fail'] else 'blocked' if counts['blocked'] else 'pass'
    # Mandatory automation cannot pass solely because every case was skipped.
    if not counts['pass'] and overall == 'pass':
        overall = 'blocked'
    return {'status': overall, 'counts': counts}


def redact(value):
    """Never persist private auth/reconnect keys, even in unexpected logs."""
    if isinstance(value, dict):
        return {key: ('[redacted]' if any(word in key.lower() for word in ('token', 'password', 'secret', 'pairing')) else redact(item)) for key, item in value.items()}
    if isinstance(value, list):
        return [redact(item) for item in value]
    if isinstance(value, str):
        value = re.sub(r'(?i)("?(?:access_token|refresh_token|reconnect_token|next_refresh_token|service_token)"?\s*[:=]\s*)"?[^\s,}\"]+', r'\1[redacted]', value)
        value = re.sub(r'(?i)Bearer\s+[A-Za-z0-9._~-]+', 'Bearer [redacted]', value)
    return value


def dump_json(path, value):
    path.write_text(json.dumps(redact(value), ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def hash_file(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def run_process(args, timeout=30, data=None, env=None):
    try:
        return subprocess.run(args, input=data, capture_output=True, timeout=timeout, env=env)
    except (FileNotFoundError, subprocess.TimeoutExpired) as error:
        raise Blocked(f'명령을 실행하지 못했습니다: {args[0]} ({type(error).__name__})') from error


def sdk_tool(name):
    found = shutil.which(name)
    if found:
        return found
    sdk = Path(os.environ.get('ANDROID_SDK_ROOT', os.environ.get('ANDROID_HOME', str(Path.home() / 'Library/Android/sdk'))))
    if name == 'adb':
        candidate = sdk / 'platform-tools/adb'
        return str(candidate) if candidate.exists() else name
    candidates = sorted(sdk.glob(f'build-tools/*/{name}'))
    return str(candidates[-1]) if candidates else name


def launcher_from_manifest(manifest):
    lines = manifest.splitlines()
    launchers = []
    for index, line in enumerate(lines):
        element = re.match(r'^(\s*)E: (activity|activity-alias) ', line)
        if not element:
            continue
        indent = len(element.group(1))
        end = index+1
        while end < len(lines) and (not re.match(r'^\s*E:', lines[end]) or len(lines[end])-len(lines[end].lstrip()) > indent):
            end += 1
        block = '\n'.join(lines[index:end])
        if '"android.intent.action.MAIN"' not in block or '"android.intent.category.LAUNCHER"' not in block:
            continue
        name = re.search(r'android:name[^=]*="([^"]+)"', block)
        if name and not re.search(r'android:exported[^\n]*0x0\b', block):
            launchers.append(name.group(1))
    require(len(launchers) == 1, 'APK MAIN/LAUNCHER activity 또는 alias를 하나로 확인하지 못했습니다.')
    return launchers[0]


def has_launch_adapter_marker(manifest):
    lines = manifest.splitlines()
    for index, line in enumerate(lines):
        element = re.match(r'^(\s*)E: meta-data ', line)
        if not element:
            continue
        indent = len(element.group(1))
        end = index+1
        while end < len(lines) and (not re.match(r'^\s*E:', lines[end]) or len(lines[end])-len(lines[end].lstrip()) > indent):
            end += 1
        block = '\n'.join(lines[index:end])
        if '"org.forest_arena.qa_launch_adapter"' in block:
            return bool(re.search(r'android:value[^\n]*(?:="1"|\)0x1\b)', block))
    return False


def inspect_apk(path, aapt):
    if not path.is_file():
        raise Blocked(f'APK 파일이 없습니다: {path}')
    result = run_process([aapt, 'dump', 'badging', str(path)])
    if result.returncode:
        raise Blocked('APK 메타데이터를 읽지 못했습니다.')
    badging = result.stdout.decode(errors='replace')
    package = re.search(r"package: name='([^']+)'", badging)
    activity = re.search(r"launchable-activity: name='([^']+)'", badging)
    require(package, 'APK package가 없습니다.')
    debug = run_process([aapt, 'dump', 'xmltree', str(path), 'AndroidManifest.xml'])
    manifest = debug.stdout.decode(errors='replace')
    activity_name = activity.group(1) if activity else launcher_from_manifest(manifest)
    require(re.search(r'android:debuggable[^\n]*(?:0xffffffff|0x1\b|true)', manifest), 'debug APK만 검사할 수 있습니다.')
    if not has_launch_adapter_marker(manifest):
        raise Blocked('APK에 debug QA 실행 인자 adapter 표시가 없습니다. 프로젝트 Android template 준비 후 APK를 다시 생성하세요.')
    sha256 = hash_file(path)
    return {'package': package.group(1), 'activity': activity_name,
            'sha256': sha256, 'debuggable': True, 'qa_launch_adapter': 1}


class ADB:
    def __init__(self, executable, serial, package):
        self.executable, self.serial, self.package = executable, serial, package

    def run(self, *args, timeout=30, data=None, check=True):
        result = run_process([self.executable, '-s', self.serial, *args], timeout, data)
        if check and result.returncode:
            status = run_process([self.executable, '-s', self.serial, 'get-state'], 5)
            if status.returncode or status.stdout.strip() != b'device':
                raise Blocked('ADB 연결이 끊겼습니다. 새 실행으로 다시 검사하세요.')
            raise Failure(f'ADB 명령 실패: {args[0:2]}: {redact(result.stderr.decode(errors="replace"))[:300]}')
        return result.stdout

    def shell(self, *args, **kwargs):
        return self.run('shell', *args, **kwargs).decode(errors='replace').strip()

    def inspect(self):
        state = self.run('get-state').strip()
        if state != b'device':
            raise Blocked('선택한 기기가 ADB device 상태가 아닙니다.')
        props = {key: self.shell('getprop', key) for key in ('ro.product.model', 'ro.build.version.release', 'ro.build.version.sdk', 'ro.kernel.qemu', 'ro.boot.qemu', 'ro.hardware', 'ro.boot.serialno', 'ro.serialno')}
        require(not self.serial.startswith('emulator-') and props['ro.kernel.qemu'] != '1' and props['ro.boot.qemu'] != '1' and props['ro.hardware'] not in ('ranchu', 'goldfish'), '에뮬레이터는 실기기 검사 대상이 아닙니다.')
        require(int(props['ro.build.version.sdk'] or '0') >= 29, 'Android 10 이상이 필요합니다.')
        props['screen_size'] = self.shell('wm', 'size')
        return props

    def original_store_hashes(self):
        paths = ('files/local_player.json', 'files/local_player.json.bak',
                 'files/db_profile_session.json', 'files/demo_guest_session.json')
        if self.run('get-state').strip() != b'device':
            raise Blocked('기존 저장 파일 확인 중 ADB 연결 상태를 확인하지 못했습니다.')
        installed = self.shell('pm', 'path', self.package)
        if not installed.startswith('package:'):
            packages = self.shell('pm', 'list', 'packages', self.package)
            if f'package:{self.package}' in packages.splitlines():
                raise Blocked('앱은 설치되어 있지만 저장 파일 경로를 읽지 못했습니다.')
            if self.run('get-state').strip() != b'device':
                raise Blocked('기존 저장 파일 확인 중 ADB 연결이 끊겼습니다.')
            return {}
        try:
            self.shell('run-as', self.package, 'pwd')
            # A completion marker distinguishes proven absence from empty ADB
            # output. Known constant paths only; no profile/token contents read.
            command = ("'for qa_store_path in " + ' '.join(paths) +
                       '; do if [ -f "$qa_store_path" ]; then sha256sum "$qa_store_path" || exit 73; fi; done; ' +
                       "printf FOREST_ARENA_STORE_HASHES_DONE'")
            data = self.run('exec-out', 'run-as', self.package, 'sh', '-c', command)
        except Failure as error:
            raise Blocked('기존 저장 파일 해시를 읽지 못했습니다. 보존 여부는 미확인입니다.') from error
        if self.run('get-state').strip() != b'device' or b'FOREST_ARENA_STORE_HASHES_DONE' not in data:
            raise Blocked('기존 저장 파일 해시 확인 도중 ADB 출력이 끊겼습니다. 파일 삭제로 판단하지 않습니다.')
        hashes = {}
        for line in data.decode(errors='replace').splitlines():
            match = re.fullmatch(r'([0-9a-f]{64})\s+(files/[A-Za-z0-9_.]+)', line)
            if match and match.group(2) in paths:
                hashes[match.group(2)] = match.group(1)
        return hashes

    def read_state(self, run_id):
        raw = self.run('exec-out', 'run-as', self.package, 'cat', f'files/qa/{run_id}/state.json', check=False)
        if not raw.strip():
            status = self.run('get-state').strip()
            if status != b'device':
                raise Blocked('ADB 연결이 끊겼습니다.')
            return None
        try:
            value = json.loads(raw)
        except (ValueError, UnicodeDecodeError):
            return None  # atomic runtime write may not yet exist
        if value.get('run_id') != run_id or value.get('schema_version') != SCHEMA_VERSION:
            raise Failure('테스트 상태의 실행 ID 또는 형식 버전이 다릅니다.')
        return value

    def write_command(self, run_id, command, timeout=30):
        # sh receives fixed safe paths only; JSON travels as stdin, never shell code.
        base = f'files/qa/{run_id}'
        self.run('shell', 'run-as', self.package, 'sh', '-c',
                 f"'cat > {base}/command.tmp && mv {base}/command.tmp {base}/command.json'",
                 data=json.dumps(command, ensure_ascii=False).encode(), timeout=timeout)

    def launch(self, activity, run_id, alias):
        self.shell('am', 'force-stop', self.package)
        output = self.shell('am', 'start', '-W', '-n', f'{self.package}/{activity}', '--esa', 'command_line_params',
                            f'--,--qa-run={run_id},--qa-device={alias}', timeout=30)
        require(not re.search(r'(?:^|\n)\s*(?:Error(?:\s+type\s+\d+)?[ :]|[^\n]*Exception)', output), 'Android 실행 실패: '+redact(output)[:500])
        status = re.search(r'^Status:\s*(\S+)', output, re.M)
        require(not status or status.group(1).lower() == 'ok', 'Android 실행 상태 오류: '+redact(output)[:500])

    def touch(self, x, y, hold_ms=0):
        if hold_ms:
            self.shell('input', 'swipe', str(x), str(y), str(x), str(y), str(hold_ms))
        else:
            self.shell('input', 'tap', str(x), str(y))

    def screenshot(self, path):
        data = self.run('exec-out', 'screencap', '-p', timeout=10)
        if data.startswith(b'\x89PNG'):
            path.write_bytes(data)


class DeviceRun:
    def __init__(self, adb, alias, run_id, output, activity, screen_timeout=30, match_timeout=300, stall_timeout=30, clock=time.monotonic, sleep=time.sleep, install_timeout=600, apk_sha256=None):
        self.adb, self.alias, self.run_id, self.output, self.activity = adb, alias, run_id, output, activity
        self.output.mkdir(parents=True, exist_ok=True)
        self.screen_timeout, self.match_timeout, self.stall_timeout = screen_timeout, match_timeout, stall_timeout
        self.install_timeout = install_timeout
        self.apk_sha256 = apk_sha256
        self.apk_identity = {}
        self.clock, self.sleep = clock, sleep
        self.seq, self.case_id, self.state = 0, 'DEV-01', {}
        self.results, self.metrics, self.combos = [], [], []
        self.device_info = {}
        self.logcat = None
        self.logfile = None
        self.evidence_seq = 0
        self.physical_size = None
        self.performance_signature = None
        self.system_metrics = []
        self.next_system_sample = self.clock() + 30
        self.metric_thread = None
        self.cleanup_autoplay = '미실행'
        self.original_hashes = None

    def read(self):
        if CANCELLED.is_set():
            raise Blocked('사용자가 실행을 중단했습니다. 현재 시도의 결과를 보존합니다.')
        value = self.adb.read_state(self.run_id)
        if value:
            self.state = value
            perf = value.get('performance', {})
            signature = json.dumps([value.get('match_generation', 0), perf], sort_keys=True)
            if perf and signature != self.performance_signature:
                self.performance_signature = signature
                self.metrics.append({'time': self.clock(), **perf})
            if self.clock() >= self.next_system_sample and self.state.get('boot_id') and (not self.metric_thread or not self.metric_thread.is_alive()):
                self.next_system_sample = self.clock() + 30
                self.metric_thread = threading.Thread(target=self.sample_system_metrics, daemon=True)
                self.metric_thread.start()
        return self.state

    def wait(self, predicate, timeout=None, label='화면 상태', poll=.15):
        deadline = self.clock() + (self.screen_timeout if timeout is None else timeout)
        while self.clock() < deadline:
            state = self.read()
            if predicate(state):
                return state
            self.sleep(poll)
        raise Failure(f'{label} 시간 초과 ({timeout or self.screen_timeout}초)')

    def screen(self, *names, timeout=None):
        return self.wait(lambda state: state.get('screen') in names, timeout, ' / '.join(names))

    def command(self, op, **args):
        self.seq += 1
        self.adb.write_command(self.run_id, {'schema_version': 1, 'run_id': self.run_id, 'seq': self.seq,
                                           'case_id': self.case_id, 'op': op, 'args': args})
        state = self.wait(lambda state: state.get('command_seq') == self.seq, label=f'명령 {op}')
        require(not state.get('command_error'), f'테스트 명령 {op}: {state.get("command_error")}')
        return state

    def viewport(self):
        if self.physical_size:
            return self.physical_size
        view = self.state.get('viewport', {})
        return float(view.get('width', 1280)), float(view.get('height', 720))

    def node(self, *, text=None, id=None, kind=None, occurrence=0, scroll=True):
        for _ in range(16 if scroll else 1):
            target_y = None
            state = self.read()
            nodes = [item for item in state.get('ui', []) if (id is None or item.get('id') == id) and (text is None or item.get('text') == text) and (kind is None or item.get('kind') == kind) and not item.get('disabled')]
            if len(nodes) > occurrence:
                item = nodes[occurrence]
                target_y = float(item.get('y', 1))
                x, y = self.center(item)
                width, height = self.viewport()
                if 0 <= x <= width and 0 <= y <= height and item.get('visible', True) and not item.get('clipped', False):
                    return item
            if scroll:
                width, height = self.viewport()
                start_y, end_y = (.25, .80) if target_y is not None and target_y < .2 else (.80, .25)
                # Shop purchase buttons consume drags on the right. The left
                # label/image column lets the ScrollContainer receive them.
                scroll_x = round(width * .19)
                self.adb.shell('input', 'swipe', str(scroll_x), str(round(height*start_y)), str(scroll_x), str(round(height*end_y)), '600')
                self.sleep(.35)
        raise Failure(f'터치할 UI를 찾지 못했습니다: {id or text or kind}')

    def center(self, item):
        width, height = self.viewport()
        return round(float(item['x']) * width), round(float(item['y']) * height)

    def tap(self, text=None, id=None, kind=None, hold_ms=0, occurrence=0):
        item = self.node(text=text, id=id, kind=kind, occurrence=occurrence)
        x, y = self.center(item)
        self.adb.touch(x, y, hold_ms)
        self.sleep(.30)
        with (self.output / 'adb-touch.jsonl').open('a', encoding='utf-8') as stream:
            stream.write(json.dumps({'case_id': self.case_id, 'input_source': 'adb_touch', 'id': item['id'], 'x': x, 'y': y, 'hold_ms': hold_ms}, ensure_ascii=False) + '\n')
        return self.read()

    def select_option(self, title, value):
        node = self.node(id=f"{self.state['screen']}/choice/{title}")
        self.tap(id=node['id'])
        # PopupMenu exposes no public item rectangles. Android keyboard events
        # select the actual focused native/Godot popup, then verify profile data.
        options = node.get('options', [])
        index = next((i for i, item in enumerate(options) if item.get('id') == value or item.get('text') == value), None)
        require(index is not None, f'선택 항목이 없습니다: {title}/{value}')
        delta = index - int(node.get('selected', 0))
        for _ in range(abs(delta)):
            self.adb.shell('input', 'keyevent', '20' if delta > 0 else '19')
        self.adb.shell('input', 'keyevent', '66')
        self.sleep(.35)
        with (self.output / 'adb-touch.jsonl').open('a', encoding='utf-8') as stream:
            stream.write(json.dumps({'case_id': self.case_id, 'input_source': 'adb_keyevent', 'id': node['id'], 'option': value, 'index': index}, ensure_ascii=False) + '\n')

    def evidence(self, label):
        self.evidence_seq += 1
        stem = f'{self.evidence_seq:03d}-{self.case_id}-{label}'
        dump_json(self.output / f'{stem}.json', self.state)
        try:
            self.adb.screenshot(self.output / f'{stem}.png')
        except (Blocked, Failure):
            pass

    def case(self, case_id, callback, input_source='adb_touch+debug_autoplay'):
        self.case_id = case_id
        started = self.clock()
        try:
            if self.state:
                self.command('context')
            observed = callback() or {}
            status, message = 'pass', '기대 동작과 관측값이 일치합니다.'
        except NotExecuted as error:
            observed, status, message = {}, '미실행', str(error)
        except Blocked as error:
            observed, status, message = {}, 'blocked', str(error)
        except (Failure, KeyError, TypeError, ValueError) as error:
            observed, status, message = {}, 'fail', str(error)
        self.evidence('end')
        result = {'schema_version': 1, 'run_id': self.run_id, 'device': self.alias, 'case_id': case_id,
                  'status': status, 'step': self.state.get('step', ''), 'input_source': input_source, 'duration_seconds': round(self.clock()-started, 3),
                  'expected': CASE_EXPECTATIONS[case_id], 'observed': observed, 'message': message}
        self.results.append(result)
        dump_json(self.output / 'results.json', self.results)
        return status

    def mark(self, case_id, status, message):
        self.results.append({'schema_version': 1, 'run_id': self.run_id, 'device': self.alias, 'case_id': case_id,
                             'status': status, 'expected': CASE_EXPECTATIONS[case_id], 'observed': {}, 'message': message})

    def launch(self):
        prior_boot = self.read().get('boot_id')
        self.state = {}
        self.adb.launch(self.activity, self.run_id, self.alias)
        state = self.wait(lambda s: s.get('boot_id') and s.get('boot_id') != prior_boot, label='새 앱 프로세스 시작')
        self.seq = max(self.seq, int(state.get('command_seq', 0)))

    def setup(self, apk):
        before_hash = hash_file(apk)
        self.apk_sha256 = self.apk_sha256 or before_hash
        self.apk_identity = {'expected': self.apk_sha256, 'source_before': before_hash}
        dump_json(self.output / 'apk-identity.json', self.apk_identity)
        if before_hash != self.apk_sha256:
            raise Blocked('실행 시작 뒤 원본 APK가 변경됐습니다. 다른 출력 경로로 생성한 뒤 새 실행을 시작하세요.')
        self.device_info = self.adb.inspect()
        self.original_hashes = self.adb.original_store_hashes()
        dump_json(self.output / 'original-stores.json', {'before': self.original_hashes, 'after': None, 'unchanged': None, 'status': 'pending'})
        self.adb.run('install', '-r', str(apk), timeout=self.install_timeout)
        after_hash = hash_file(apk)
        self.apk_identity['source_after'] = after_hash
        dump_json(self.output / 'apk-identity.json', self.apk_identity)
        if after_hash != self.apk_sha256:
            raise Blocked('무선 설치 중 원본 APK가 변경됐습니다. 이 시도는 APK 동일성 확인 불가입니다.')
        self.verify_installed_apk()
        # run-as also proves installed package is actually debuggable.
        self.adb.shell('run-as', self.adb.package, 'pwd')
        self.start_logcat()
        self.launch()
        state = self.screen('first')
        import struct
        png = self.adb.run('exec-out', 'screencap', '-p')
        require(png.startswith(b'\x89PNG') and len(png) > 24, '화면 크기를 읽지 못했습니다.')
        self.physical_size = struct.unpack('!II', png[16:24])
        width, height = self.viewport()
        require(width > height, '가로 화면이 아닙니다.')
        return {'screen': state['screen'], 'device_info': self.device_info, 'physical_size': self.physical_size}

    def verify_installed_apk(self):
        listed = self.adb.shell('pm', 'path', self.adb.package)
        base = next((line.removeprefix('package:') for line in listed.splitlines()
                     if line.startswith('package:') and line.endswith('/base.apk')), '')
        if not re.fullmatch(r'/[A-Za-z0-9_./=+~-]+', base):
            raise Blocked('설치된 base APK 경로를 안전하게 확인하지 못했습니다.')
        value = self.adb.shell('sha256sum', base, timeout=30)
        matched = re.match(r'^([a-f0-9]{64})\s+', value)
        if not matched:
            raise Blocked('설치된 APK 해시를 읽지 못했습니다.')
        self.apk_identity['installed'] = matched.group(1)
        dump_json(self.output / 'apk-identity.json', self.apk_identity)
        if matched.group(1) != self.apk_sha256:
            raise Blocked('선택한 원본 APK와 실기기에 설치된 APK 해시가 다릅니다. 새 실행으로 재검사하세요.')

    def start_logcat(self):
        listing = self.adb.shell('pm', 'list', 'packages', '-U', self.adb.package)
        uid = re.search(r'uid:(\d+)', listing)
        require(uid, 'APK UID를 읽지 못해 앱 로그 수집 불가')
        self.logfile = (self.output / 'game-log.raw').open('wb')
        # UID remains stable across cold starts; capture startup and relaunched processes.
        self.logcat = subprocess.Popen([self.adb.executable, '-s', self.adb.serial, 'logcat', f'--uid={uid.group(1)}', '-T', '1', '-v', 'threadtime'], stdout=self.logfile, stderr=subprocess.DEVNULL)

    def initial_ui(self):
        cards = [item for item in self.read().get('ui', []) if item.get('kind') == 'button' and item.get('text') not in ('저장 모드 · 기기 저장',)]
        require(cards, '첫 캐릭터 카드가 없습니다.')
        self.evidence('first-selection')
        self.tap(id=cards[0]['id'])
        self.screen('home')
        self.tap('상점 · 모두 0원')
        self.screen('shop')
        # All ten products must be bought by actual taps, re-reading after refresh.
        for _ in range(10):
            state = self.read()
            if len(state.get('profile', {}).get('characters', [])) == 4 and len(state.get('profile', {}).get('accessories', [])) == 6:
                break
            self.tap('0원 · 무료 구매')
            self.wait(lambda s: s.get('screen') == 'shop')
        self.evidence('shop-owned')
        profile = self.read()['profile']
        require(len(profile['characters']) == 4 and len(profile['accessories']) == 6, '상점 보유 목록이 네 캐릭터/여섯 장신구와 다릅니다.')
        self.adb.shell('input', 'keyevent', '4')
        self.screen('home')
        self.tap('접근성 설정')
        self.screen('accessibility')
        self.tap(id='accessibility/toggle/피격 번쩍임 줄이기')
        self.wait(lambda s: s.get('profile', {}).get('accessibility', {}).get('reduce_visual_effects') is True)
        saved = self.state['profile']
        self.launch()
        self.screen('home')
        require(self.state['profile'] == saved, '재실행 뒤 보유·선택·설정이 복원되지 않았습니다.')
        return {'profile': saved, 'relaunched': True}

    def prepare(self):
        if self.read().get('screen') == 'home':
            self.tap('오프라인 대전')
        elif self.state.get('screen') in ('match', 'pause'):
            if self.state['screen'] == 'match':
                self.adb.shell('input', 'keyevent', '4')
                self.screen('pause')
            self.tap('대전 종료 · 준비 화면')
        elif self.state.get('screen') == 'result':
            self.tap('대전 준비')
        self.screen('prepare')

    def wait_new_match(self, previous_generation, lan=False):
        wanted = 'lan_match' if lan else 'match'
        return self.wait(lambda state: state.get('screen') == wanted and
                         state.get('match_generation', 0) > previous_generation and
                         bool(state.get('snapshot', {}).get('fighters')), label='새 경기 관측')

    def start_match(self):
        previous_generation = int(self.read().get('match_generation', 0))
        self.tap('대전 시작')
        return self.wait_new_match(previous_generation)

    def selections(self):
        self.prepare()
        validated = []
        for character in CHARACTERS:
            self.tap(CHARACTER_LABELS[character])
            self.wait(lambda s: s.get('profile', {}).get('selected_character') == character)
            accessory = self.state['profile']['selected_accessory']
            self.start_match()
            self.assert_config(character, accessory)
            validated.append({'character': character, 'accessory': accessory})
            self.prepare()
        for accessory in ACCESSORIES:
            self.select_option('장신구', accessory)
            self.wait(lambda s: s.get('profile', {}).get('selected_accessory') == accessory)
            character = self.state['profile']['selected_character']
            self.start_match()
            self.assert_config(character, accessory)
            validated.append({'character': character, 'accessory': accessory})
            self.prepare()
        return {'actual_match_selections': validated}

    def assert_config(self, character, accessory):
        fighter = self.player(self.read())
        require(fighter.get('character_id') == character and fighter.get('accessory_id', '') == accessory,
                '선택과 실제 경기 데이터가 다릅니다.')

    def player(self, state=None):
        state = state or self.state
        slot = int(state.get('lan_slot', 0))
        expected = f'lan_{"host" if slot == 1 else "guest"}' if slot else 'player'
        return next((f for f in state.get('snapshot', {}).get('fighters', []) if f.get('id') == expected), {})

    @staticmethod
    def attack_family_matches(action, attack_id):
        families = {'attack_light': 'light', 'attack_heavy': 'heavy', 'attack_special': 'special'}
        family = families.get(action)
        return bool(family and re.match(r'^ja-hyun(?:\.base)?-(?:air-|dash-)?'+family+r'(?:-|$)', str(attack_id)))

    def assert_touch_edges(self, action, previous_seq):
        state = self.wait(lambda s: any(e.get('seq', 0) > previous_seq and e.get('action') == action and e.get('edge') == 'release' for e in s.get('touch_events', [])), label=f'{action} 누름·해제')
        events = [e for e in state.get('touch_events', []) if e.get('seq', 0) > previous_seq and e.get('action') == action]
        require({e.get('edge') for e in events} >= {'press', 'release'}, f'{action} 누름·해제 기록 부족')
        self.assert_released(state)
        return state

    def inputs(self):
        self.prepare()
        self.command('select_config', character='ja-hyun', accessory='', mode=4)
        self.start_match()
        self.command('autoplay', enabled=False)
        self.wait(lambda state: self.player(state).get('state') not in ('SPAWNING', 'DEAD', 'RING_OUT', None), label='플레이어 입력 준비')
        checked = []
        for action in ('move_right', 'move_left', 'jump', 'attack_light', 'attack_heavy', 'attack_special', 'evade'):
            before = self.read()
            previous_seq = max((e.get('seq', 0) for e in before.get('touch_events', [])), default=0)
            combat_seq = max((e.get('seq', 0) for e in before.get('combat_events', [])), default=0)
            previous = self.player(before).copy()
            self.tap(id=f'touch/{action}', hold_ms=160)
            self.assert_touch_edges(action, previous_seq)
            def changed(s):
                observations = [e for e in s.get('combat_events', []) if e.get('seq', 0) > combat_seq and e.get('fighter_id') == 'player' and e.get('id') == 'fighter_state']
                if action.startswith('move_'):
                    position = self.player(s).get('position', {})
                    before_position = previous.get('position', {})
                    delta_x = float(position.get('x', 0)) - float(before_position.get('x', 0))
                    return delta_x > 1 if action == 'move_right' else delta_x < -1
                if action == 'jump':
                    return any(e.get('state') == 'JUMP' for e in observations)
                if action == 'evade':
                    return any(e.get('state') == 'EVADE' for e in observations)
                return any(self.attack_family_matches(action, e.get('attack_id')) for e in observations)
            self.wait(changed, label=f'{action} 실제 전투 상태 변화')
            checked.append(action)
            self.sleep(1.0)
        # Gauge starts empty. This test uses real combat to earn readiness, never injects gauge.
        before = self.read()
        require(self.player(before).get('ultimate_gauge', float('inf')) < before.get('snapshot', {}).get('ultimate_gauge_max', 0), '궁극기 준비 전 검사의 실제 게이지 조건이 맞지 않습니다.')
        previous_seq = max((e.get('seq',0) for e in before.get('touch_events',[])),default=0)
        self.tap(id='touch/ultimate')
        self.assert_touch_edges('ultimate', previous_seq)
        require(not self.player().get('ultimate_used_this_stock'), '조건 충족 전에 궁극기가 사용됐습니다.')
        self.command('autoplay', enabled=True, ultimate=False)
        self.wait(lambda s: self.player(s).get('ultimate_gauge', 0) >= s.get('snapshot', {}).get('ultimate_gauge_max', 100), timeout=self.match_timeout, label='정상 전투 궁극기 준비')
        self.command('autoplay', enabled=False)
        previous_seq = max((e.get('seq',0) for e in self.read().get('touch_events',[])),default=0)
        self.tap(id='touch/ultimate', hold_ms=160)
        self.assert_touch_edges('ultimate', previous_seq)
        self.wait(lambda s: self.player(s).get('ultimate_used_this_stock') is True, label='궁극기 사용')
        self.prepare()
        return {'actions': checked, 'ultimate_before_ready': False, 'ultimate_after_ready': True}

    @staticmethod
    def assert_released(state, message='터치 입력이 해제되지 않았습니다.'):
        touch = state.get('touch', {})
        require(isinstance(touch.get('active'), list), '현재 눌린 입력 진단이 없어 입력 해제를 확인할 수 없습니다.')
        require(not touch['active'], message)

    def lifecycle(self):
        self.prepare()
        self.command('select_config', mode=3, character='ja-hyun', accessory='')
        self.start_match()
        self.adb.shell('input', 'keyevent', '4')
        state = self.screen('pause')
        require(state.get('snapshot', {}).get('paused'), 'BACK 뒤 전투가 멈추지 않았습니다.')
        self.assert_released(state, '일시정지 뒤 터치 입력 고착')
        self.tap('계속하기')
        self.screen('match')
        self.adb.shell('input', 'keyevent', '3')
        self.sleep(1)
        self.adb.shell('am', 'start', '-W', '-n', f'{self.adb.package}/{self.activity}')
        self.screen('pause')
        self.assert_released(self.state, 'HOME 복귀 뒤 터치 입력 고착')
        self.tap('계속하기')
        self.screen('match')
        self.prepare()
        self.tap('로비')
        self.screen('home')
        return {'back_pause_resume': True, 'home_pause_resume': True, 'prepare_home': True}

    def combat_result(self, deadline=None, lan=False):
        started = self.clock()
        stop = min(started + self.match_timeout, deadline) if deadline is not None else started+self.match_timeout
        last_change, previous = started, None
        result_screen = 'lan_result' if lan else 'result'
        while self.clock() < stop:
            state = self.read()
            if state.get('screen') == result_screen:
                self.evidence('result')
                result = state.get('latest_result', {})
                self.validate_result(result, state.get('snapshot', {}), lan=lan)
                return result
            require(state.get('screen') in ('lan_match', 'match'), '전투 중 예상하지 않은 화면 이동')
            fighters = state.get('snapshot', {}).get('fighters', [])
            key = tuple((f.get('id'), f.get('current_hp'), f.get('stocks')) for f in fighters)
            if key != previous:
                previous, last_change = key, self.clock()
            if self.clock() - last_change >= self.stall_timeout:
                raise Failure(f'{self.stall_timeout}초 동안 피해·남은 기회 변화가 없습니다.')
            self.sleep(.25)
        if deadline is not None and deadline <= started + self.match_timeout:
            return None  # Natural soak cutoff; unfinished combination stays 미실행.
        raise Failure('자동 전투가 한 판 제한 시간 안에 끝나지 않았습니다.')

    @staticmethod
    def validate_result(result, snapshot, lan=False):
        require(result, '결과 화면에 경기 결과가 없습니다.')
        tick = result.get('final_tick', 0)
        require(isinstance(tick, (int,float)) and not isinstance(tick,bool) and tick > 0 and tick == int(tick), '경기 종료 tick이 유효하지 않습니다.')
        require(re.fullmatch(r'[0-9a-f]{64}', str(result.get('snapshot_hash', ''))), '경기 결과 해시가 유효하지 않습니다.')
        if lan:
            winner = result.get('winner_slot')
            require(winner in (1,2) or (winner == 0 and result.get('reason') == 'draw'), 'LAN 승자 또는 무승부 결과가 유효하지 않습니다.')
        else:
            winner = result.get('winner_id', '')
            ids = {f.get('id') for f in snapshot.get('fighters', [])}
            require(winner == 'DRAW' or (winner and winner in ids), '오프라인 승자가 실제 참가자가 아닙니다.')
            if snapshot.get('mode') == 2 and winner != 'DRAW':
                require(result.get('winner_team_id') in ('alpha','beta'), '팀전 승리 팀 결과가 유효하지 않습니다.')

    @staticmethod
    def validate_mode_snapshot(snapshot, mode, count):
        require(snapshot.get('mode') == mode, f'선택 모드 {mode}와 실제 경기 모드가 다릅니다.')
        fighters = snapshot.get('fighters', [])
        require(len(fighters) == count, f'모드 {mode} 참가 인원 오류')
        teams = [f.get('team_id') for f in fighters]
        if mode == 2:
            require(teams.count('alpha') == 4 and teams.count('beta') == 4, '4대4 팀 구분 오류')
        if mode == 1:
            require(all(team == '' for team in teams), 'Solo 각자전에 팀이 배정되었습니다.')

    def assert_reset(self):
        state = self.wait(lambda s: s.get('snapshot', {}).get('fighters'), label='재대전 초기 상태')
        self.assert_released(state, '재대전 뒤 입력 고착')
        reset = state.get('reset_snapshot', state['snapshot'])
        for fighter in reset['fighters']:
            require(fighter['stocks'] == 3 and abs(fighter['current_hp'] - fighter['max_hp']) < .001, '재대전 체력·남은 기회가 초기화되지 않았습니다.')
        slot = int(state.get('lan_slot', 0))
        actor_id = ('lan_host' if slot == 1 else 'lan_guest') if slot else 'player'
        actor = next((f for f in reset['fighters'] if f.get('id') == actor_id), {})
        require(actor.get('input_direction') == 0 and actor.get('buffered_action') == '', '재대전 이동 방향·대기 입력이 초기화되지 않았습니다.')
        return state

    def offline_result(self):
        self.prepare()
        self.command('select_config', mode=3, character='ja-hyun', accessory='')
        self.start_match()
        self.command('autoplay', enabled=True)
        result = self.combat_result()
        self.command('autoplay', enabled=False)
        generation = int(self.read().get('match_generation', 0))
        self.tap('같은 조건으로 재대전')
        self.wait_new_match(generation)
        self.assert_reset()
        self.prepare()
        return {'result': result, 'rematch_reset': True}

    def modes(self):
        modes = []
        for mode, count in ((4, 2), (1, 8), (2, 8), (0, 2)):
            self.prepare()
            self.command('select_config', mode=mode, solo_count=8, team_size=4)
            self.start_match()
            self.validate_mode_snapshot(self.state['snapshot'], mode, count)
            if mode != 4:
                self.command('autoplay', enabled=True)
                result = self.combat_result()
                self.command('autoplay', enabled=False)
            else:
                result = {'practice_exit': True}
            modes.append({'mode': mode, 'participants': count, 'result': result})
            self.prepare()
        return {'modes': modes}

    def soak(self, duration, jobs):
        if not duration:
            self.mark('SOAK-01', '미실행', 'smoke 실행은 반복 대전을 생략합니다.')
            return
        def execute():
            deadline = self.clock()+duration
            games, index = 0, 0
            while self.clock() < deadline:
                job = jobs[index % len(jobs)]
                self.prepare()
                self.command('select_config', mode=3, **job)
                self.start_match()
                self.assert_config(job['character'], job['accessory'])
                self.command('autoplay', enabled=True)
                result = self.combat_result(deadline=deadline)
                self.command('autoplay', enabled=False)
                if result is None:
                    self.command('autoplay', enabled=False)
                    break
                if job not in self.combos:
                    self.combos.append(job)
                games += 1
                generation = int(self.read().get('match_generation', 0))
                self.tap('같은 조건으로 재대전')
                self.wait_new_match(generation)
                self.assert_reset()
                self.prepare()
                index += 1
            if not games:
                raise NotExecuted('설정한 반복 시간이 끝나 한 판의 결과·재대전을 완료하지 못했습니다. 진행 중 조합은 미실행입니다.')
            return {'games': games, 'duration_seconds': duration, 'completed_combinations': self.combos}
        self.case('SOAK-01', execute, 'debug_autoplay')

    def sample_system_metrics(self):
        sampled = {'time': self.clock(), 'memory': {'status': '미확인'}, 'thermal': {'status': '미확인'}}
        for service, name in ((('meminfo', self.adb.package), 'memory'), (('thermalservice',), 'thermal')):
            try:
                raw = self.adb.shell('dumpsys', *service, timeout=2)
                denied = re.search(r'Permission Denial|Can.t find service', raw)
                if name == 'memory':
                    pss = re.search(r'TOTAL PSS:\s*(\d+)', raw) or re.search(r'^\s*TOTAL\s+(\d+)', raw, re.M)
                    if pss and not denied:
                        sampled[name] = {'status': 'measured', 'total_pss_kb': int(pss.group(1))}
                else:
                    values = [float(v) for v in re.findall(r'mValue=([0-9.]+)', raw)]
                    status = re.search(r'Thermal Status:\s*(\d+)', raw)
                    if (values or status) and not denied:
                        sampled[name] = {'status': 'measured', 'temperature_celsius': values,
                                         'thermal_status': int(status.group(1)) if status else None}
                with (self.output / f'{name}.txt').open('a', encoding='utf-8') as stream:
                    stream.write(f'측정 시각(실행 초): {sampled["time"]}\n'+redact(raw)+'\n')
            except (Blocked, Failure):
                pass
        self.system_metrics.append(sampled)

    def stop_autoplay(self):
        if not self.state or not self.state.get('boot_id'):
            return
        self.seq = max(self.seq, int(self.state.get('command_seq', 0)))+1
        command = {'schema_version': 1, 'run_id': self.run_id, 'seq': self.seq,
                   'case_id': self.case_id, 'op': 'autoplay', 'args': {'enabled': False}}
        try:
            self.adb.write_command(self.run_id, command, timeout=2)
            stop = time.monotonic()+2
            while time.monotonic() < stop:
                state = self.adb.read_state(self.run_id)
                if state and state.get('command_seq') == self.seq and not state.get('autocontrol'):
                    self.cleanup_autoplay = 'confirmed_disabled'
                    return
                time.sleep(.15)
        except (Blocked, Failure):
            pass
        self.cleanup_autoplay = '미확인: ADB/앱 응답 제한 시간 초과'

    def close(self):
        self.stop_autoplay()
        if self.metric_thread:
            self.metric_thread.join(timeout=5)
        self.sample_system_metrics()
        if self.original_hashes is not None:
            try:
                after = self.adb.original_store_hashes()
                dump_json(self.output / 'original-stores.json', {'before': self.original_hashes, 'after': after, 'unchanged': after == self.original_hashes})
                if after != self.original_hashes:
                    self.mark('UI-01', 'fail', '기존 프로필/DB/게스트 저장 파일 해시가 검사 전후 다릅니다.')
            except (Blocked, Failure):
                dump_json(self.output / 'original-stores.json', {'before': self.original_hashes, 'after': None, 'unchanged': None, 'status': 'blocked'})
                self.mark('UI-01', 'blocked', '검사 종료 뒤 기존 저장 파일 보존 여부를 확인하지 못했습니다.')
        if self.logcat:
            self.logcat.terminate()
            try:
                self.logcat.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.logcat.kill()
                self.logcat.wait()
        if self.logfile:
            self.logfile.close()
            raw = self.output / 'game-log.raw'
            log = raw.read_text(errors='replace')
            if re.search(r'FATAL EXCEPTION|Fatal signal|ANR in|Application Not Responding', log):
                self.mark('SOAK-01', 'fail', '앱 로그에서 충돌 또는 응답 멈춤을 발견했습니다.')
            (self.output / 'game.log').write_text(redact(log), encoding='utf-8')
            raw.unlink()
        dump_json(self.output / 'performance.json', {'samples': self.metrics, 'system_samples': self.system_metrics,
                  'runtime_available': bool(self.metrics), 'cleanup_autoplay': self.cleanup_autoplay,
                  'thresholds': '미승인: 측정값만 보고'})
        dump_json(self.output / 'results.json', self.results)
        dump_json(self.output / 'device.json', self.device_info)


CASE_EXPECTATIONS = {
 'DEV-01': '선택한 실기기 debug APK 설치·가로 화면·첫 선택 진입',
 'UI-01': '실제 터치 첫 선택·0원 구매·설정·재실행 저장 복원',
 'OFF-01': '네 캐릭터·미장착과 여섯 장신구 실제 경기 반영',
 'INPUT-01': '실제 터치 누름·해제·전투 변화 및 궁극기 준비 전후',
 'LIFE-01': 'BACK/HOME 입력 해제·일시정지·복귀·준비·로비',
 'OFF-02': '정상 입력 자동 전투 결과·재대전 체력/남은 기회 초기화',
 'MODE-01': '연습 종료·Solo 8명·Team 4대4·Story 프롤로그 결과/복귀',
 'LAN-01': '실제 두 APK 게스트/닉네임·방 생성/참가·전투·결과 일치·재대전',
 'LAN-02': '잘못된 코드·없는 방·꺼진 서버·정원 초과 안내/복귀',
 'LAN-03': '10초 단절 같은 슬롯 복귀·65초 단절 이탈 패배·입력 해제',
 'SOAK-01': '정해진 시간 반복 결과·재대전·고착/충돌 없음',
 'MANUAL-01': '실제 Wi-Fi 수동 끄기/켜기·동시 터치·소리·진동 확인',
}

class LanServer:
    """Independent game process and in-memory guest fixture per device pair."""
    def __init__(self, bind, cidr, port, api_port, output, godot, run_id):
        self.bind, self.cidr, self.port, self.api_port = bind, cidr, port, api_port
        self.output, self.godot, self.run_id = output, godot, run_id
        self.output.mkdir(parents=True, exist_ok=True)
        self.fixture = self.process = self.stream = None
        self.code = f'FAH2|http://{bind}:{api_port}|ws://{bind}:{port}|2'

    def start(self):
        from android_fleet_auth_fixture import GuestFixture
        import secrets
        token = secrets.token_urlsafe(32)
        try:
            self.fixture = GuestFixture(self.bind, self.api_port, token).start()
        except OSError as error:
            raise Blocked(f'LAN 테스트 API 포트를 열 수 없습니다: {error}') from error
        env = os.environ.copy()
        env.update(FOREST_ARENA_LAN_API_URL=f'http://{self.bind}:{self.api_port}',
                   FOREST_ARENA_API_BASE_URL=f'http://{self.bind}:{self.api_port}',
                   FOREST_ARENA_SERVICE_TOKEN=token, FOREST_ARENA_ALLOWED_CIDR=self.cidr,
                   FOREST_ARENA_LAN_BIND_HOST=self.bind, FOREST_ARENA_LAN_ADVERTISED_WS_URL=f'ws://{self.bind}:{self.port}',
                   FOREST_ARENA_LAN_PORT=str(self.port), FOREST_ARENA_QA_RUN=self.run_id)
        self.stream = (self.output / 'server.raw').open('wb')
        try:
            self.process = subprocess.Popen([self.godot, '--headless', '--path', str(ROOT), 'res://server/game/lan_game_server.tscn'], stdout=self.stream, stderr=subprocess.STDOUT, env=env)
        except FileNotFoundError as error:
            raise Blocked('Godot 실행 파일이 없습니다.') from error
        deadline = time.monotonic()+30
        while time.monotonic() < deadline:
            if self.process.poll() is not None:
                raise Blocked('LAN 서버가 시작 중 종료되었습니다. server.log를 확인하세요.')
            if 'FOREST_ARENA_LAN_READY' in (self.output / 'server.raw').read_text(errors='replace'):
                return
            time.sleep(.15)
        raise Blocked('LAN 서버 준비 시간 초과')

    def results(self):
        results = []
        raw = self.output / 'server.raw'
        if raw.exists():
            for line in raw.read_text(errors='replace').splitlines():
                if 'FOREST_ARENA_QA_LAN_RESULT ' in line:
                    try:
                        results.append(json.loads(line.split('FOREST_ARENA_QA_LAN_RESULT ', 1)[1]))
                    except ValueError:
                        pass
        return results

    def input_resets(self):
        records = []
        raw = self.output / 'server.raw'
        if raw.exists():
            for line in raw.read_text(errors='replace').splitlines():
                if 'FOREST_ARENA_QA_LAN_INPUT_RESET ' in line:
                    try:
                        records.append(json.loads(line.split('FOREST_ARENA_QA_LAN_INPUT_RESET ',1)[1]))
                    except ValueError:
                        pass
        return records

    def close(self):
        if self.process:
            self.process.terminate()
            try:
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
                self.process.wait()
        if self.stream:
            self.stream.close()
            raw = self.output / 'server.raw'
            (self.output / 'server.log').write_text(redact(raw.read_text(errors='replace')), encoding='utf-8')
            raw.unlink()
        if self.fixture:
            self.fixture.close()


def _menu(device):
    if device.read().get('screen') == 'prepare':
        device.tap('로비')
        device.screen('home')
    if device.state.get('screen') == 'home':
        device.tap('LAN 1:1 · 같은 Wi-Fi')
    elif device.state.get('screen') == 'lan_match':
        device.tap('대전 나가기')
        device.screen('lan_leave_confirm')
        device.tap('대전 나가기')
    elif device.state.get('screen') in ('lan_result', 'lan_host', 'lan_join'):
        device.tap('LAN 메뉴')
    device.screen('lan_menu')


def _lan_login(device, intent, code):
    _menu(device)
    device.tap('방 만들기' if intent == 'host' else '초대 코드로 참가')
    device.screen('lan_host' if intent == 'host' else 'lan_join')
    line = device.node(kind='input')
    device.command('set_text', id=line['id'], value=code)
    device.tap('방 생성' if intent == 'host' else '방 참가')
    device.screen('demo_nickname')
    nickname = next((n for n in device.state.get('ui', []) if n.get('node_name') == 'DemoNicknameInput'), None)
    nickname = nickname or device.node(kind='input')
    device.command('set_text', id=nickname['id'], value=f'QA_{device.alias.replace("-", "")[-7:]}')
    device.tap('닉네임 저장')
    device.wait(lambda s: any(n.get('text') == '이 닉네임으로 계속' and not n.get('disabled') for n in s.get('ui', [])), label='닉네임 저장')
    device.tap('이 닉네임으로 계속')


def _pair_join(host, guest, server):
    generations = [int(d.read().get('match_generation', 0)) for d in (host, guest)]
    _lan_login(host, 'host', server.code)
    host.screen('lan_waiting')
    invite = host.wait(lambda s: bool(s.get('lan_invite')), label='공개 초대 코드')['lan_invite']
    _lan_login(guest, 'join', invite)
    host.wait_new_match(generations[0], lan=True)
    guest.wait_new_match(generations[1], lan=True)
    return invite


def _compare_lan_results(host, guest, server, timeout=300):
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda device: device.combat_result(lan=True), (host, guest)))
    for field in ('winner_slot', 'final_tick', 'snapshot_hash'):
        require(field in results[0] and results[0][field] == results[1].get(field), f'양쪽 APK 결과 {field} 불일치')
    records = server.results()
    require(records and any(all(record.get(field) == results[0].get(field) for field in ('winner_slot', 'final_tick', 'snapshot_hash')) for record in records), '서버와 양쪽 APK 결과가 일치하지 않습니다.')
    return results[0]


def _third_guest_rejection(server, invite):
    """Protocol probe for 2-device fleet; clearly separate from actual APK UI."""
    import base64
    import struct
    import urllib.request
    def request(path, data, token=None):
        headers = {'Content-Type': 'application/json'}
        if token:
            headers['Authorization'] = 'Bearer '+token
        req = urllib.request.Request(f'http://{server.bind}:{server.api_port}'+path, data=json.dumps(data).encode(), headers=headers, method='PATCH' if path.endswith('/profile') else 'POST')
        with urllib.request.urlopen(req, timeout=5) as response:
            return json.load(response)
    auth = request('/v1/auth/guest', {})
    request('/v1/guest/profile', {'nickname': 'QA_third'}, auth['access_token'])
    room = invite.split('|')[3]
    sock = socket.create_connection((server.bind, server.port), timeout=10)
    try:
        key = base64.b64encode(os.urandom(16)).decode()
        sock.sendall(f'GET / HTTP/1.1\r\nHost: {server.bind}:{server.port}\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\nSec-WebSocket-Version: 13\r\n\r\n'.encode())
        buffer = b''
        while b'\r\n\r\n' not in buffer:
            buffer += sock.recv(4096)
        require(buffer.startswith(b'HTTP/1.1 101'), '정원 초과 검사 socket 연결 실패')
        buffered = buffer.split(b'\r\n\r\n', 1)[1]
        payload = json.dumps({'protocol_version': 2, 'type': 'join_room', 'room_code': room, 'selection': {'character_id': 'ja-hyun', 'accessory_id': ''}, 'access_token': auth['access_token']}).encode()
        mask = os.urandom(4)
        header = bytes([0x82, 0x80 | len(payload)]) if len(payload) < 126 else bytes([0x82, 0xFE])+struct.pack('!H', len(payload))
        sock.sendall(header+mask+bytes(v ^ mask[i % 4] for i, v in enumerate(payload)))
        def exact(size):
            nonlocal buffered
            chunks, buffered = buffered[:size], buffered[size:]
            while len(chunks) < size:
                part = sock.recv(size-len(chunks))
                require(part, '정원 초과 응답 전 socket 종료')
                chunks += part
            return chunks
        response = None
        # Godot WebSocketMultiplayerPeer sends a four-byte peer ID before
        # application packets; preserve frames appended to HTTP handshake.
        for _ in range(5):
            first, second = exact(2)
            length = second & 0x7f
            if length == 126:
                length = struct.unpack('!H', exact(2))[0]
            elif length == 127:
                length = struct.unpack('!Q', exact(8))[0]
            require(length <= 8192, '정원 초과 응답 크기 오류')
            data = exact(length)
            if length == 4 and (first & 0xf) == 2:
                continue
            response = json.loads(data)
            break
        require(response, '정원 초과 응답 없음')
        require(response.get('code') == 'room_full', f'정원 초과 오류 불일치: {response.get("code")}')
        return {'room_full': 'pass', 'source': 'authenticated_protocol_probe', 'actual_third_apk_ui': '미실행'}
    finally:
        sock.close()


def lan_pair(host, guest, server):
    """Record each LAN case on both APKs, preserving partial results and blockers."""
    current = 'LAN-01'
    try:
        server.start()
        host.case_id = guest.case_id = current
        host.command('context')
        guest.command('context')
        invite = _pair_join(host, guest, server)
        full = _third_guest_rejection(server, invite)
        # HOME during LAN: server continues, local input is cleared.
        host.adb.shell('input', 'keyevent', '3')
        time.sleep(1)
        host.adb.shell('am', 'start', '-W', '-n', f'{host.adb.package}/{host.activity}')
        host.screen('lan_match')
        host.assert_released(host.state, 'LAN HOME 복귀 뒤 입력 고착')
        host.command('autoplay', enabled=True)
        guest.command('autoplay', enabled=True)
        result = _compare_lan_results(host, guest, server)
        host.command('autoplay', enabled=False)
        guest.command('autoplay', enabled=False)
        generations = [int(d.read().get('match_generation', 0)) for d in (host, guest)]
        for device in (host, guest):
            device.tap('같은 조건으로 재대전 요청')
        for device, generation in zip((host, guest), generations):
            device.wait_new_match(generation, lan=True)
            device.assert_reset()
            device.mark('LAN-01', 'pass', '게스트/닉네임·방·결과·서버 일치·재대전 초기화 확인')
            device.results[-1]['observed'] = {'result': result, 'auth_provider': 'ephemeral_test_fixture', 'home_restore_input': True}
            device.evidence('rematch')
        current = 'LAN-03'
        host.case_id = guest.case_id = current
        for device in (host, guest):
            device.command('context')
        slot = host.state.get('lan_slot')
        reset = host.state.get('input_reset_count', 0)
        reset_records_before = len(server.input_resets())
        host.command('interrupt', seconds=10)
        host.wait(lambda s: s.get('reconnecting') or not s.get('connected', True), timeout=5, label='10초 앱 연결 단절')
        host.assert_released(host.state, 'LAN 단절 입력 고착')
        guest.wait(lambda s: s.get('peer_connected') is False, timeout=5, label='상대 APK 단절 표시')
        host.wait(lambda s: s.get('connected') and not s.get('reconnecting') and s.get('lan_slot') == slot, timeout=25, label='같은 LAN 슬롯 복귀')
        require(host.state.get('input_reset_count', 0) > reset, 'LAN 단절 시 입력 초기화 미확인')
        guest.wait(lambda s: s.get('peer_connected') is True, timeout=5, label='상대 APK 복귀 표시')
        host.command('interrupt', seconds=65)
        guest.screen('lan_result', timeout=75)
        require(guest.state.get('latest_result', {}).get('reason') == 'disconnect' and guest.state.get('latest_result', {}).get('winner_slot') == guest.state.get('lan_slot'), '60초 초과 단절이 이탈 패배로 처리되지 않았습니다.')
        time.sleep(5)
        host.read()
        host.assert_released(host.state, '65초 단절 뒤 입력 고착')
        server_resets = [r for r in server.input_resets()[reset_records_before:] if r.get('slot') == slot]
        require(len(server_resets) >= 2 and all(r.get('input_direction') == 0 and not r.get('buffered_action') for r in server_resets), '10초/65초 실제 서버 입력 해제를 확인하지 못했습니다.')
        for device in (host, guest):
            device.mark(current, 'pass', '10초 같은 슬롯 복귀와 65초 이탈 패배·양쪽 APK/서버 입력 해제 확인')
            device.results[-1]['observed'] = {'server_input_resets': server_resets, 'peer_offline_and_online': True}
            device.evidence('disconnect')
        current = 'LAN-02'
        for device in (host, guest):
            device.case_id = current
            _menu(device)
        # Invalid public code: real APK button, debug-only text setup.
        host.tap('초대 코드로 참가')
        host.screen('lan_join')
        host.command('set_text', id=host.node(kind='input')['id'], value='INVALID')
        host.tap('방 참가')
        host.wait(lambda s: bool(s.get('last_lan_error')), label='잘못된 초대 코드 안내')
        require(host.state['last_lan_error'] in ('invalid_invite_code', 'invalid_room_code'), '잘못된 코드 오류 불일치')
        _menu(host)
        # Syntactically valid missing room on live server.
        parts = invite.split('|')
        parts[3] = 'ZZZZZZZZ'
        _lan_login(host, 'join', '|'.join(parts))
        host.wait(lambda s: s.get('last_lan_error') in ('room_not_found', 'invalid_room'), label='없는 방 안내')
        _menu(host)
        # Keep guest API up, stop game service; nickname/guest still normal.
        server.process.terminate()
        server.process.wait(timeout=5)
        _lan_login(host, 'host', server.code)
        host.wait(lambda s: s.get('last_lan_error') in ('connection_failed', 'connection_lost', 'request_timeout'), label='꺼진 LAN 서버 안내')
        _menu(host)
        host.mark(current, 'pass', '잘못된 코드·없는 방·꺼진 서버 APK 안내/복귀와 인증된 정원 초과 probe 확인')
        host.results[-1]['observed'] = {'full_room': full, 'actual_error_ui_device': host.alias, 'auth_provider': 'ephemeral_test_fixture'}
        host.results[-1]['input_source'] = 'adb_touch+debug_text_setup+authenticated_protocol_probe'
        host.evidence('errors')
        guest.mark(current, '미실행', f'접속 실패 화면은 짝 기기 {host.alias}에서 확인했습니다. 이 기기에서는 해당 화면을 조작하지 않았습니다.')
    except (Blocked, Failure, OSError, ValueError, KeyError) as error:
        status = 'blocked' if isinstance(error, (Blocked, OSError)) else 'fail'
        for device in (host, guest):
            if not any(r['case_id'] == current for r in device.results):
                device.mark(current, status, str(error))
            for case in ('LAN-01', 'LAN-02', 'LAN-03'):
                if not any(r['case_id'] == case for r in device.results):
                    device.mark(case, 'blocked', f'{current} 문제로 후속 검사 불가')
            device.evidence('failure')
    finally:
        server.close()


def offline(device, apk, mode, duration, jobs):
    steps = [('DEV-01', lambda: device.setup(apk)), ('UI-01', device.initial_ui), ('OFF-01', device.selections),
             ('INPUT-01', device.inputs), ('LIFE-01', device.lifecycle), ('OFF-02', device.offline_result), ('MODE-01', device.modes)]
    for index, (case, callback) in enumerate(steps):
        status = device.case(case, callback)
        if status != 'pass':
            for remaining, _ in steps[index+1:]:
                device.mark(remaining, 'blocked', f'{case} 문제로 후속 검사 불가')
            device.mark('SOAK-01', 'blocked', f'{case} 문제로 반복 검사 불가')
            return False
    device.soak(duration, jobs)
    return True


def discover_bind():
    # OS chooses the active private LAN route; no packets are sent by connect UDP.
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        try:
            sock.connect(('192.168.1.1', 9))
            address = sock.getsockname()[0]
        except OSError as error:
            raise Blocked('LAN IPv4를 찾지 못했습니다. --lan-bind를 지정하세요.') from error
    ip = ipaddress.ip_address(address)
    if not ip.is_private or ip.is_loopback:
        raise Blocked('사설 LAN IPv4가 필요합니다. --lan-bind를 지정하세요.')
    return address


def parser():
    parse = argparse.ArgumentParser(description='명시적으로 선택한 Android 실기기 1~4대 자동 플레이 검사')
    parse.add_argument('--apk', type=Path, default=ROOT / 'build/android/ForestArena-debug.apk')
    parse.add_argument('--serial', '--serials', action='append', default=[], help='ADB serial; 반복 또는 쉼표 목록. 자동 전체 선택 없음')
    parse.add_argument('--suite', '--mode', dest='mode', choices=('smoke', 'soak', 'extended'), default='smoke')
    parse.add_argument('--duration', type=float, help='반복 대전 초; 기본 smoke0/soak600/extended1800')
    parse.add_argument('--output', type=Path, default=ROOT / 'artifacts/android-fleet')
    parse.add_argument('--adb', default=sdk_tool('adb'))
    parse.add_argument('--aapt', default=sdk_tool('aapt'))
    parse.add_argument('--godot', default=shutil.which('godot') or 'godot')
    parse.add_argument('--lan-bind')
    parse.add_argument('--lan-cidr', help='허용하는 기기 사설 subnet; 기본 bind 주소의 /24')
    parse.add_argument('--lan-port', type=int, default=19777)
    parse.add_argument('--api-port', type=int, default=19881)
    parse.add_argument('--install-timeout', type=float, default=600, help='APK 설치 제한 초; 무선 전송 기본600')
    parse.add_argument('--screen-timeout', type=float, default=30)
    parse.add_argument('--match-timeout', type=float, default=300)
    parse.add_argument('--stall-timeout', type=float, default=30)
    return parse


def write_summary(output, run_id, meta, devices, global_results):
    results = global_results+[r for device in devices for r in device.results]
    summary = aggregate(results)
    if meta.get('mode') in ('soak', 'extended') and summary['status'] == 'pass' and not any(r['case_id'] == 'SOAK-01' and r['status'] == 'pass' for r in results):
        summary['status'] = 'blocked'
    required = [(c, a) for c in CHARACTERS for a in ACCESSORIES]
    completed = {(j['character'], j['accessory']) for d in devices for j in d.combos}
    coverage = [{'character': c, 'accessory': a, 'status': 'pass' if (c, a) in completed else '미실행'} for c, a in required]
    dump_json(output / 'results.json', {'schema_version': 1, 'run_id': run_id, 'metadata': meta, 'summary': summary, 'cases': results, 'combination_coverage': coverage})
    lines = [f'# Android 실기기 자동 플레이 · {run_id}', '', f'전체 판정: **{summary["status"]}**', '',
             '실기기에서 관측한 사례만 pass로 기록합니다. 테스트용 게스트 API는 제품 DB/API 검증 결과가 아닙니다.', '',
             '| 기기 | 사례 | 판정 | 내용 |', '| --- | --- | --- | --- |']
    lines += [f'| {r.get("device", "전체")} | {r["case_id"]} | {r["status"]} | {r["message"].replace("|", "/")} |' for r in results]
    lines += ['', f'28개 조합 중 완료 {len(completed)}개; 나머지는 미실행.', '',
              '성능 수치는 승인된 합격 기준이 없어 측정값만 제공합니다. 실제 Wi-Fi 끄기/켜기, 동시 터치, 소리 청취·진동 체감은 수동 재검사입니다.', '']
    (output / 'summary.md').write_text('\n'.join(lines), encoding='utf-8')
    return summary


def main(argv=None):
    args = parser().parse_args(argv)
    CANCELLED.clear()
    previous_handlers = {}
    if threading.current_thread() is threading.main_thread():
        for signum in (signal.SIGINT, signal.SIGTERM):
            previous_handlers[signum] = signal.signal(signum, lambda _signum, _frame: CANCELLED.set())
    try:
        serials = selected_serials(args.serial)
        duration = args.duration if args.duration is not None else {'smoke': 0, 'soak': 600, 'extended': 1800}[args.mode]
        if any(v <= 0 for v in (args.install_timeout, args.screen_timeout, args.match_timeout, args.stall_timeout)) or duration < 0:
            raise ValueError('대기 시간은 양수, 반복 시간은 0 이상이어야 합니다.')
        if not 1 <= args.lan_port <= 65534 or not 1 <= args.api_port <= 65534:
            raise ValueError('LAN/API 포트는 1~65534여야 합니다.')
        if {args.lan_port, args.lan_port+1} & {args.api_port, args.api_port+1}:
            raise ValueError('LAN/API 포트 범위가 겹칩니다.')
    except ValueError as error:
        parser().error(str(error))
    run_id = uuid.uuid4().hex
    output = args.output / run_id
    output.mkdir(parents=True, exist_ok=False)
    (output / '.gdignore').touch()
    meta = {'mode': args.mode, 'duration_seconds': duration, 'apk': str(args.apk.resolve()), 'selected_serials': serials,
            'auth_provider': 'ephemeral_test_fixture', 'code_version': ''}
    git = run_process(['git', '-C', str(ROOT), 'rev-parse', 'HEAD'])
    meta['code_version'] = git.stdout.decode().strip()
    meta['install_timeout_seconds'] = args.install_timeout
    meta['code_dirty'] = bool(run_process(['git', '-C', str(ROOT), 'status', '--porcelain']).stdout.strip())
    meta['tracked_diff_sha256'] = hashlib.sha256(run_process(['git', '-C', str(ROOT), 'diff', '--binary', 'HEAD']).stdout).hexdigest()
    devices, global_results = [], []
    stage = 'DEV-01'
    try:
        if not serials:
            raise Blocked('선택한 실기기가 없습니다. --serial을 명시하세요. 자동 전체 선택은 하지 않습니다.')
        meta['apk_metadata'] = inspect_apk(args.apk, args.aapt)
        identities = set()
        for index, serial in enumerate(serials):
            adb = ADB(args.adb, serial, meta['apk_metadata']['package'])
            info = adb.inspect()
            identity = info.get('ro.boot.serialno') or info.get('ro.serialno')
            if not identity:
                raise Blocked('물리 기기 serial을 읽지 못해 중복 기기 여부를 확인할 수 없습니다.')
            if identity in identities:
                raise Failure('서로 다른 ADB serial이 같은 물리 기기를 가리킵니다. 한 경로만 선택하세요.')
            identities.add(identity)
            device = DeviceRun(adb, f'device-{index+1}', run_id, output / f'device-{index+1}', meta['apk_metadata']['activity'], args.screen_timeout, args.match_timeout, args.stall_timeout, install_timeout=args.install_timeout, apk_sha256=meta['apk_metadata'].get('sha256'))
            device.device_info = info
            devices.append(device)
        jobs = combination_jobs(len(devices))
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(devices)) as pool:
            futures = [pool.submit(offline, device, args.apk, args.mode, duration, jobs[index]) for index, device in enumerate(devices)]
            eligible = [future.result() for future in futures]
        stage = 'LAN-01'
        bind = args.lan_bind or (discover_bind() if len(devices) >= 2 else None)
        if bind:
            ip = ipaddress.ip_address(bind)
            require(ip.version == 4 and ip.is_private and not ip.is_loopback, 'LAN bind는 실제 사설 IPv4여야 합니다.')
            cidr = args.lan_cidr or str(ipaddress.ip_network(bind+'/24', strict=False))
            require(ip in ipaddress.ip_network(cidr), 'LAN bind 주소가 허용 CIDR 밖입니다.')
            servers = []
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                futures = []
                for index in range(0, len(devices)-1, 2):
                    if eligible[index] and eligible[index+1]:
                        pair = index//2
                        server = LanServer(bind, cidr, args.lan_port+pair, args.api_port+pair, output/f'lan-pair-{pair+1}', args.godot, run_id)
                        futures.append(pool.submit(lan_pair, devices[index], devices[index+1], server))
                    else:
                        for device in devices[index:index+2]:
                            for case in ('LAN-01', 'LAN-02', 'LAN-03'):
                                device.mark(case, 'blocked', '앞선 기기 검사 문제로 두 APK LAN 검사 불가')
                for future in futures:
                    future.result()
        if len(devices) % 2:
            for case in ('LAN-01', 'LAN-02', 'LAN-03'):
                devices[-1].mark(case, '미실행', '마지막 기기는 짝이 없어 오프라인만 실행합니다.')
        for device in devices:
            device.mark('MANUAL-01', '미실행', '실제 Wi-Fi 단절·동시 터치·소리·진동은 사용자 수동 재검사 필요')
    except (Blocked, Failure, OSError, ValueError) as error:
        global_results.append({'case_id': stage, 'status': 'blocked' if isinstance(error, (Blocked, OSError)) else 'fail', 'message': str(error)})
    finally:
        for device in devices:
            for case_id in CASES:
                if not any(item['case_id'] == case_id for item in device.results):
                    device.mark(case_id, '미실행' if case_id == 'MANUAL-01' else 'blocked', '실행 전제 또는 앞선 검사 문제로 관측하지 못했습니다.')
            try:
                device.close()
            except Exception as error:
                global_results.append({'case_id': 'DEV-01', 'device': device.alias, 'status': 'blocked', 'message': f'증거 마무리 오류: {type(error).__name__}'})
        summary = write_summary(output, run_id, meta, devices, global_results)
        print(f'Android fleet: {summary["status"]}\n증거: {output / "summary.md"}')
        for signum, handler in previous_handlers.items():
            signal.signal(signum, handler)
    return {'pass': 0, 'fail': 1, 'blocked': 2}[summary['status']]


if __name__ == '__main__':
    sys.exit(main())
