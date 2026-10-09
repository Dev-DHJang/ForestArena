#!/usr/bin/env python3
"""Run the isolated macOS LAN demo; never reset a database or log secrets."""
import argparse
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import secrets
import shutil
import signal
import subprocess
import sys
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
ENV = ROOT / 'database/.env.demo'
STATE = ROOT / '.godot/demo-server'
PID = STATE / 'server.pid'
LOG = STATE / 'server.log'
API_PID = STATE / 'api.pid'
API_LOG = STATE / 'api.log'


def run(args, **kwargs):
    return subprocess.run(args, cwd=ROOT, check=True, **kwargs)


def compose(*args, **kwargs):
    return run(['docker', 'compose', '--env-file', str(ENV), '-f', 'database/compose.demo.yml', *args], **kwargs)


def read_env():
    return dict(line.split('=', 1) for line in ENV.read_text().splitlines() if '=' in line and not line.startswith('#'))


def network():
    address = os.environ.get('FOREST_ARENA_DEMO_IP', '')
    cidr = os.environ.get('FOREST_ARENA_ALLOWED_CIDR', '')
    if not address:
        for interface in ('en0', 'en1'):
            try:
                candidate = subprocess.check_output(['ipconfig', 'getifaddr', interface], stderr=subprocess.DEVNULL, text=True).strip()
                mask = subprocess.check_output(['ipconfig', 'getoption', interface, 'subnet_mask'], stderr=subprocess.DEVNULL, text=True).strip()
                if mask:
                    address = candidate
                    cidr = cidr or str(ipaddress.IPv4Network(f'{candidate}/{mask}', strict=False))
                    break
            except (subprocess.CalledProcessError, FileNotFoundError):
                continue
    ip = ipaddress.IPv4Address(address)
    subnet = ipaddress.IPv4Network(cidr, strict=True)
    private = any(ip in ipaddress.IPv4Network(value) for value in ('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '127.0.0.0/8'))
    if not private or ip not in subnet or (subnet.prefixlen < 16 and not ip.is_loopback):
        raise ValueError('서버 사설 IPv4와 연결된 네트워크 CIDR을 지정하세요. 너무 넓은 범위는 허용하지 않습니다.')
    return str(ip), str(subnet)


def setup():
    address, cidr = network()
    if ENV.exists():
        values = read_env()
    else:
        existing_volume = subprocess.run(['docker', 'volume', 'inspect', 'forest_arena_demo_postgres'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
        if existing_volume:
            raise ValueError('기존 데모 DB가 있습니다. 이전 server/database/.env.demo를 이 폴더로 복원하세요. 새 인증 정보를 자동 생성하지 않습니다.')
        values = {key: secrets.token_hex(32) for key in ('FOREST_ARENA_DB_ADMIN_PASSWORD', 'FOREST_ARENA_DB_APP_PASSWORD', 'FOREST_ARENA_TOKEN_SECRET', 'FOREST_ARENA_SERVICE_TOKEN')}
    values.update(FOREST_ARENA_DEMO_IP=address, FOREST_ARENA_ALLOWED_CIDR=cidr)
    ENV.parent.mkdir(parents=True, exist_ok=True)
    fd = os.open(ENV, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, 'w') as out:
        out.write(''.join(f'{key}={value}\n' for key, value in values.items()))
    ENV.chmod(0o600)
    return values


def sql(query):
    return compose('exec', '-T', 'db', 'psql', '-U', 'forest_arena_admin', '-d', 'forest_arena_demo', '-v', 'ON_ERROR_STOP=1', '-At', input=query, text=True, capture_output=True).stdout.strip()


def backup():
    directory = ROOT / 'database/demo-backups'
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / f'demo-{time.time_ns()}.dump'
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as out:
        compose('exec', '-T', 'db', 'pg_dump', '-U', 'forest_arena_admin', '-d', 'forest_arena_demo', '-Fc', stdout=out)
    print('demo-server: DB 백업', path.name)


def migrate():
    ledger = sql("SELECT to_regclass('infra.schema_migrations') IS NOT NULL;") == 't'
    if ledger:
        guard = sql('SELECT environment_name FROM infra.environment_guard WHERE singleton;')
        if guard != 'verification':
            raise ValueError('별도 데모 DB 표식이 맞지 않습니다. 중단합니다.')
    pending = []
    for path in sorted((ROOT / 'database/migrations').glob('*.sql')):
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        old = sql(f"SELECT checksum_sha256 FROM infra.schema_migrations WHERE migration_name='{path.name}';") if ledger else ''
        if old and old != digest:
            raise ValueError('이미 적용한 migration 파일의 확인값이 다릅니다: ' + path.name)
        if not old:
            pending.append((path, digest))
    if ledger and pending:
        backup()
    for path, digest in pending:
        sql("BEGIN;\n" + path.read_text() + f"\nINSERT INTO infra.schema_migrations VALUES ('{path.name}', '{digest}', now());\nCOMMIT;")
        print('demo-server: 적용', path.name)
    if not ledger:
        sql("INSERT INTO infra.environment_guard(singleton,environment_name) VALUES(true,'verification');")


def alive(pid_path=PID):
    if not pid_path.exists():
        return False
    try:
        process_id = int(pid_path.read_text())
        os.kill(process_id, 0)
        command = subprocess.check_output(['ps', '-p', str(process_id), '-o', 'command='], text=True).strip()
        return str(ROOT) in command
    except (ValueError, ProcessLookupError, subprocess.CalledProcessError):
        return False


def stop():
    for pid_path in (PID, API_PID):
        if alive(pid_path):
            os.kill(int(pid_path.read_text()), signal.SIGTERM)
            for _ in range(50):
                if not alive(pid_path): break
                time.sleep(.1)
        pid_path.unlink(missing_ok=True)
    if ENV.exists(): compose('stop', 'db')
    print('demo-server: 중지됨. DB 볼륨은 보존됩니다.')


def start():
    if alive() or alive(API_PID):
        raise ValueError('이미 실행 중입니다. status 또는 stop을 사용하세요.')
    for command in ('godot', 'docker', 'node', 'npm'):
        if not shutil.which(command):
            raise ValueError(command + ' 실행 파일이 필요합니다.')
    run(['docker', 'version'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    values = setup()
    compose('up', '--detach', '--wait', 'db')
    migrate()
    STATE.mkdir(parents=True, exist_ok=True)
    api_directory = ROOT / 'server/api'
    if not (api_directory / 'node_modules').exists():
        subprocess.run(['npm', 'ci'], cwd=api_directory, check=True)
    subprocess.run(['npm', 'run', 'build'], cwd=api_directory, check=True)
    api_env = os.environ | {
        'FOREST_ARENA_API_HOST': values['FOREST_ARENA_DEMO_IP'], 'FOREST_ARENA_API_PORT': '3001',
        'FOREST_ARENA_DEMO_MODE': 'true', 'FOREST_ARENA_ALLOWED_CIDR': values['FOREST_ARENA_ALLOWED_CIDR'],
        'FOREST_ARENA_TOKEN_SECRET': values['FOREST_ARENA_TOKEN_SECRET'],
        'FOREST_ARENA_SERVICE_TOKEN': values['FOREST_ARENA_SERVICE_TOKEN'],
        'DATABASE_URL': 'postgresql://forest_arena_app:' + values['FOREST_ARENA_DB_APP_PASSWORD'] + '@127.0.0.1:55433/forest_arena_demo',
    }
    with API_LOG.open('w') as out:
        api_process = subprocess.Popen(['node', str(api_directory / 'dist/src/server.js')], cwd=api_directory, env=api_env, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
    API_PID.write_text(str(api_process.pid))
    ready = False
    for _ in range(80):
        if api_process.poll() is not None: break
        try:
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            with opener.open('http://' + values['FOREST_ARENA_DEMO_IP'] + ':3001/health/ready', timeout=1) as response:
                ready = response.status == 200
            if ready: break
        except (OSError, urllib.error.URLError): pass
        time.sleep(.1)
    if not ready:
        api_process.terminate()
        API_PID.unlink(missing_ok=True)
        raise ValueError('API가 준비되지 않았습니다. logs로 원인을 확인하세요.')
    env = os.environ | {
        'FOREST_ARENA_LAN_PORT': '7778',
        'FOREST_ARENA_LAN_BIND_HOST': values['FOREST_ARENA_DEMO_IP'],
        'FOREST_ARENA_LAN_ADVERTISED_WS_URL': 'ws://' + values['FOREST_ARENA_DEMO_IP'] + ':7778',
        'FOREST_ARENA_LAN_API_URL': 'http://' + values['FOREST_ARENA_DEMO_IP'] + ':3001',
        'FOREST_ARENA_API_BASE_URL': 'http://' + values['FOREST_ARENA_DEMO_IP'] + ':3001',
        'FOREST_ARENA_SERVICE_TOKEN': values['FOREST_ARENA_SERVICE_TOKEN'],
        'FOREST_ARENA_ALLOWED_CIDR': values['FOREST_ARENA_ALLOWED_CIDR'],
    }
    command = ['godot', '--headless', '--path', str(ROOT)]
    if (ROOT / 'server.pck').exists():
        command += ['--main-pack', str(ROOT / 'server.pck')]
    command += ['res://server/game/lan_game_server.tscn']
    with LOG.open('w') as out:
        process = subprocess.Popen(command, cwd=ROOT, env=env, stdout=out, stderr=subprocess.STDOUT, start_new_session=True)
    PID.write_text(str(process.pid))
    for _ in range(80):
        text = LOG.read_text(errors='replace')
        ready = [line for line in text.splitlines() if line.startswith('FOREST_ARENA_LAN_READY ')]
        if ready:
            print(ready[-1])
            print('demo-server: 공유기 외부 포트 전달을 끄고 같은 네트워크에서 접속하세요.')
            return
        if process.poll() is not None:
            PID.unlink(missing_ok=True)
            api_process.terminate()
            API_PID.unlink(missing_ok=True)
            raise ValueError('LAN 서버 실행 실패. logs로 원인을 확인하세요.')
        time.sleep(.1)
    process.terminate()
    PID.unlink(missing_ok=True)
    api_process.terminate()
    API_PID.unlink(missing_ok=True)
    raise ValueError('8초 내 LAN 서버가 준비되지 않았습니다.')


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('command', choices=['start', 'stop', 'status', 'logs', 'backup'])
    args = parser.parse_args()
    if args.command == 'start': start()
    elif args.command == 'stop': stop()
    elif args.command == 'status':
        print('demo-server:', '실행 중' if alive() else '중지됨')
        if ENV.exists(): compose('ps')
    elif args.command == 'logs':
        for log in (LOG, API_LOG):
            if log.exists(): print('\n'.join(log.read_text(errors='replace').splitlines()[-40:]))
    elif args.command == 'backup': backup()


if __name__ == '__main__':
    try:
        main()
    except (ValueError, subprocess.CalledProcessError, OSError) as error:
        # Subprocess args may contain sensitive values; never print the exception.
        print('demo-server: 작업 실패. 입력 주소와 도구・로그를 확인하세요.' if not isinstance(error, ValueError) else 'demo-server: ' + str(error), file=sys.stderr)
        sys.exit(1)
