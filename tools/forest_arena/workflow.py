#!/usr/bin/env python3
"""Small worktree-local safeguards shared by verification and Android export."""
from __future__ import annotations

import argparse
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import socket
import signal
import threading
import subprocess
import sys
import uuid

TOKEN_ENV = 'FOREST_ARENA_OPERATION_TOKEN'
PATH_ENV = 'FOREST_ARENA_OPERATION_LOCK'
STAMP_NAME = '.forest-arena-install.json'


class OperationBusy(RuntimeError):
    pass


def _git(root: Path, *args: str) -> str:
    return subprocess.check_output(['git', '-C', str(root), *args], text=True, stderr=subprocess.DEVNULL).strip()


def lock_path(root: Path) -> Path:
    # --absolute-git-dir is different for every linked worktree, unlike --git-common-dir.
    return Path(_git(root, 'rev-parse', '--absolute-git-dir')) / 'forest-arena-operation.lock'


def _owner(file) -> dict:
    try:
        file.seek(0)
        return json.load(file)
    except (ValueError, OSError):
        return {}


def _alive(pid: int) -> bool:
    try:
        os.kill(pid, 0)
        return True
    except (ProcessLookupError, ValueError, TypeError):
        return False
    except PermissionError:
        return True


@contextmanager
def operation_lock(root: Path | str):
    """Fail promptly on another writer, but let a locked runner call guarded scripts."""
    root = Path(root).resolve()
    path = lock_path(root)
    with path.open('a+', encoding='utf-8') as file:
        owner = _owner(file)
        inherited = (os.environ.get(PATH_ENV) == str(path)
                     and bool(os.environ.get(TOKEN_ENV))
                     and os.environ.get(TOKEN_ENV) == owner.get('token')
                     and _alive(owner.get('pid')))
        try:
            fcntl.flock(file, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            if inherited:
                yield owner
                return
            owner = _owner(file)
            raise OperationBusy('다른 검사·내보내기가 같은 작업 폴더를 사용 중입니다: '
                                + json.dumps({k: owner.get(k) for k in ('pid', 'root', 'command', 'started_utc')}, ensure_ascii=False))
        # If a copied environment outlives its parent lock, acquire a fresh lock instead.
        previous = {key: os.environ.get(key) for key in (TOKEN_ENV, PATH_ENV)}
        owner = {'pid': os.getpid(), 'root': str(root), 'command': sys.argv,
                 'started_utc': datetime.now(timezone.utc).isoformat(), 'token': uuid.uuid4().hex}
        file.seek(0)
        file.truncate()
        json.dump(owner, file, ensure_ascii=False)
        file.flush()
        os.environ[TOKEN_ENV] = owner['token']
        os.environ[PATH_ENV] = str(path)
        try:
            yield owner
        finally:
            for key, value in previous.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
            fcntl.flock(file, fcntl.LOCK_UN)


def node_fingerprint(root: Path | str) -> dict:
    folder = Path(root).resolve() / 'server/api'
    return {
        'package_sha256': hashlib.sha256((folder / 'package.json').read_bytes()).hexdigest(),
        'lock_sha256': hashlib.sha256((folder / 'package-lock.json').read_bytes()).hexdigest(),
        'node': subprocess.check_output(['node', '--version'], text=True).strip(),
        'npm': subprocess.check_output(['npm', '--version'], text=True).strip(),
        'node_runtime': subprocess.check_output(['node', '-p', 'process.platform + "/" + process.arch'], text=True).strip(),
        'platform': platform.system(), 'machine': platform.machine(),
    }


def node_modules_healthy(root: Path | str) -> bool:
    folder = Path(root).resolve() / 'server/api'
    if not (folder / 'node_modules/.package-lock.json').is_file():
        return False
    result = subprocess.run(['npm', '--prefix', str(folder), 'ls', '--depth=0', '--json'],
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return result.returncode == 0


def ensure_node(root: Path | str) -> bool:
    """Install only when the inputs/runtime changed or installed packages are incomplete."""
    root = Path(root).resolve()
    with operation_lock(root):
        fingerprint = node_fingerprint(root)
        folder = root / 'server/api'
        stamp = folder / 'node_modules' / STAMP_NAME
        try:
            current = json.loads(stamp.read_text())
        except (OSError, ValueError):
            current = None
        if current == fingerprint and node_modules_healthy(root):
            print('Node 의존성: 기존 정상 설치 재사용')
            return False
        stamp.unlink(missing_ok=True)
        subprocess.run(['npm', '--prefix', str(folder), 'ci', '--prefer-offline', '--no-audit', '--no-fund'], check=True)
        if not node_modules_healthy(root):
            raise RuntimeError('npm ci 후 설치 검사가 실패했습니다. 정상 설치 표시를 남기지 않습니다.')
        temporary = stamp.with_suffix('.tmp')
        temporary.write_text(json.dumps(fingerprint, indent=2) + '\n')
        temporary.replace(stamp)
        print('Node 의존성: 변경된 입력에 맞춰 설치 완료')
        return True


def choose_loopback_ports(count: int = 1, exclude=()) -> list[int]:
    """Reserve together while choosing, avoiding occupied or explicitly assigned ports."""
    if count < 1 or count > 32:
        raise ValueError('port count must be between 1 and 32')
    held, ports = [], []
    excluded = set(exclude)
    try:
        for _ in range(count):
            while True:
                candidate = socket.socket()
                candidate.bind(('127.0.0.1', 0))
                port = candidate.getsockname()[1]
                held.append(candidate)
                if port not in excluded:
                    ports.append(port)
                    break
        return ports
    finally:
        for candidate in held:
            candidate.close()


def status(root: Path | str) -> dict:
    root = Path(root).resolve()
    base = _git(root, 'merge-base', 'HEAD', 'origin/develop')
    changed = subprocess.check_output(['git', '-C', str(root), 'status', '--porcelain', '-z']).split(b'\0')
    return {'root': str(root), 'branch': _git(root, 'branch', '--show-current'),
            'head': _git(root, 'rev-parse', 'HEAD'), 'develop_base': base,
            'behind_ahead': _git(root, 'rev-list', '--left-right', '--count', 'origin/develop...HEAD').split(),
            'status_entries': sum(bool(item) for item in changed), 'operation_lock': str(lock_path(root))}


def run_process(command, *, cwd=None, env=None, stdout=None, stderr=None, timeout=None, own_group=True):
    """End a timed-out/interrupted operation's whole process group before unlocking."""
    process = subprocess.Popen(command, cwd=cwd, env=env, stdout=stdout, stderr=stderr,
                               start_new_session=own_group)
    previous = None
    if own_group and threading.current_thread() is threading.main_thread():
        previous = signal.getsignal(signal.SIGTERM)
        def interrupted(_signal, _frame):
            raise KeyboardInterrupt('operation terminated')
        signal.signal(signal.SIGTERM, interrupted)
    try:
        return subprocess.CompletedProcess(command, process.wait(timeout=timeout))
    except BaseException:
        if own_group:
            try: os.killpg(process.pid, signal.SIGTERM)
            except ProcessLookupError: pass
        else:
            process.terminate()
        try: process.wait(timeout=2)
        except subprocess.TimeoutExpired:
            pass
        if own_group:
            try: os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError: pass
        elif process.poll() is None:
            process.kill()
        process.wait()
        raise
    finally:
        if previous is not None: signal.signal(signal.SIGTERM, previous)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default=str(Path(__file__).resolve().parents[2]))
    commands = parser.add_subparsers(dest='action', required=True)
    run = commands.add_parser('run')
    run.add_argument('command', nargs=argparse.REMAINDER)
    commands.add_parser('ensure-node')
    commands.add_parser('status')
    ports = commands.add_parser('ports')
    ports.add_argument('--count', type=int, default=1)
    ports.add_argument('--exclude', type=int, action='append', default=[])
    args = parser.parse_args(argv)
    try:
        if args.action == 'ports':
            print(' '.join(map(str, choose_loopback_ports(args.count, args.exclude))))
        elif args.action == 'status':
            print(json.dumps(status(args.root), ensure_ascii=False, indent=2))
        elif args.action == 'ensure-node':
            ensure_node(args.root)
        else:
            command = args.command[1:] if args.command[:1] == ['--'] else args.command
            if not command:
                parser.error('run requires a command after --')
            with operation_lock(args.root) as owner:
                return run_process(command, cwd=args.root, own_group=owner['pid'] == os.getpid()).returncode
    except OperationBusy as error:
        print(str(error), file=sys.stderr)
        return 75
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
