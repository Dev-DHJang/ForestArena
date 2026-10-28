#!/usr/bin/env python3
"""Exercise real process locks and isolated npm installation decisions."""
import contextlib
import io
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import time
from urllib.request import Request, urlopen
import unittest
from unittest.mock import patch

from workflow import (OperationBusy, PATH_ENV, TOKEN_ENV, choose_loopback_ports,
                      ensure_node, lock_path, operation_lock)

MODULE = Path(__file__).resolve().parent
CLI = MODULE / 'workflow.py'


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix='forest-workflow-test-')
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name) / 'primary'
        self.root.mkdir()
        subprocess.run(['git', 'init', '-q', str(self.root)], check=True)
        self.env = {key: value for key, value in os.environ.items() if key not in (TOKEN_ENV, PATH_ENV)}

    def holder(self, root=None):
        code = ('import sys; from pathlib import Path; '
                f'sys.path.insert(0,{str(MODULE)!r}); from workflow import operation_lock; '
                f'ctx=operation_lock(Path({str(root or self.root)!r})); ctx.__enter__(); '
                "print('READY',flush=True); sys.stdin.read(); ctx.__exit__(None,None,None)")
        process = subprocess.Popen([sys.executable, '-c', code], env=self.env,
                                   stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        self.addCleanup(lambda: self.stop(process))
        self.assertEqual(process.stdout.readline().strip(), 'READY')
        return process

    @staticmethod
    def stop(process):
        if process.poll() is None:
            process.kill()
            process.wait(timeout=5)
        for stream in (process.stdin, process.stdout, process.stderr):
            if stream:
                stream.close()

    def test_competing_process_fails_with_owner_and_exit_code(self):
        holder = self.holder()
        result = subprocess.run([sys.executable, str(CLI), '--root', str(self.root), 'run', '--', sys.executable, '-c', 'raise SystemExit(19)'], env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 75)
        self.assertIn(str(holder.pid), result.stderr)
        self.assertIn(str(self.root), result.stderr)

    def test_child_can_reenter_and_parent_environment_is_restored(self):
        before = {key: os.environ.get(key) for key in (TOKEN_ENV, PATH_ENV)}
        with operation_lock(self.root):
            result = subprocess.run([sys.executable, str(CLI), '--root', str(self.root), 'run', '--', sys.executable, '-c', "print('nested')"], capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(), 'nested')
            with operation_lock(self.root):
                self.assertTrue(os.environ.get(TOKEN_ENV))
        self.assertEqual({key: os.environ.get(key) for key in before}, before)

    def test_termination_releases_lock_without_removing_lock_file(self):
        holder = self.holder()
        path = lock_path(self.root)
        self.stop(holder)
        self.assertTrue(path.exists())
        with operation_lock(self.root):
            pass

    def test_stale_inherited_environment_acquires_new_lock(self):
        with operation_lock(self.root):
            old = {key: os.environ[key] for key in (TOKEN_ENV, PATH_ENV)}
        with patch.dict(os.environ, old):
            with operation_lock(self.root) as owner:
                self.assertNotEqual(owner['token'], old[TOKEN_ENV])

    def test_two_worktrees_have_independent_locks_and_changes(self):
        subprocess.run(['git', '-C', str(self.root), '-c', 'user.name=Workflow Test', '-c', 'user.email=workflow@example.invalid', 'commit', '--allow-empty', '-qm', 'fixture'], check=True)
        other = Path(self.folder.name) / 'other'
        subprocess.run(['git', '-C', str(self.root), 'worktree', 'add', '-q', '--detach', str(other)], check=True)
        holder = self.holder()
        self.assertNotEqual(lock_path(self.root), lock_path(other))
        with operation_lock(other):
            (other / 'other-change.txt').write_text('other')
        (self.root / 'primary-change.txt').write_text('primary')
        self.assertFalse((self.root / 'other-change.txt').exists())
        self.assertFalse((other / 'primary-change.txt').exists())
        self.assertIsNone(holder.poll())

    def test_port_selection_avoids_occupied_and_explicit_ports(self):
        with socket.socket() as occupied:
            occupied.bind(('127.0.0.1', 0))
            explicit = occupied.getsockname()[1]
            ports = choose_loopback_ports(3, [explicit])
            self.assertEqual(len(set(ports)), 3)
            self.assertNotIn(explicit, ports)
            for port in ports:
                with socket.socket() as check:
                    check.bind(('127.0.0.1', port))

    def test_two_auth_fixtures_use_their_assigned_ports(self):
        fixture = MODULE.parents[1] / 'tests/lan_auth_fixture.py'
        ports = choose_loopback_ports(2)
        for port in ports:
            environment = dict(self.env, FOREST_ARENA_LAN_TEST_API_PORT=str(port))
            process = subprocess.Popen([sys.executable, str(fixture)], env=environment,
                                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            self.addCleanup(lambda process=process: self.stop(process))
            deadline = time.monotonic() + 5
            while True:
                try:
                    request = Request(f'http://127.0.0.1:{port}/internal/v1/lan/auth',
                                      data=b'{"access_token":"host"}',
                                      headers={'x-forest-arena-service-token': 'lan-runtime-test-service'})
                    with urlopen(request, timeout=1) as response:
                        self.assertEqual(json.load(response)['player_id'], 'host')
                    break
                except OSError:
                    if process.poll() is not None or time.monotonic() >= deadline:
                        self.fail('Assigned fixture port did not become available')
                    time.sleep(.02)

    def prepare_npm(self):
        folder = self.root / 'server/api'
        folder.mkdir(parents=True)
        (folder / 'package.json').write_text('{"name":"fixture","version":"1"}')
        (folder / 'package-lock.json').write_text('{"lockfileVersion":3}')
        bin_dir = Path(self.folder.name) / 'bin'
        bin_dir.mkdir()
        node = bin_dir / 'node'
        node.write_text('#!/usr/bin/env python3\nimport os\nprint(os.environ.get("FOREST_TEST_NODE_VERSION","v20.fixture"))\n')
        npm = bin_dir / 'npm'
        npm.write_text('''#!/usr/bin/env python3
import json,os,sys
from pathlib import Path
args=sys.argv[1:]
if args==['--version']:
 print('10.fixture');raise SystemExit
folder=Path(args[args.index('--prefix')+1]);command=args[args.index('--prefix')+2]
if command=='ci':
 with (folder/'calls.txt').open('a') as log:log.write('ci\\n')
 if os.environ.get('FOREST_TEST_NPM_FAIL'):raise SystemExit(9)
 (folder/'node_modules').mkdir(exist_ok=True)
 (folder/'node_modules/.package-lock.json').write_text('{}')
 (folder/'node_modules/broken').unlink(missing_ok=True)
elif command=='ls':
 raise SystemExit(int((folder/'node_modules/broken').exists()))
else:raise SystemExit(10)
''')
        for script in (node, npm):
            script.chmod(0o755)
        return folder, {'PATH': str(bin_dir) + os.pathsep + os.environ['PATH']}

    def test_node_reuses_and_reinstalls_for_inputs_runtime_and_missing_packages(self):
        folder, env = self.prepare_npm()
        with patch.dict(os.environ, env), contextlib.redirect_stdout(io.StringIO()):
            self.assertTrue(ensure_node(self.root))
            self.assertFalse(ensure_node(self.root))
            (folder / 'package-lock.json').write_text('{"lockfileVersion":3,"changed":true}')
            self.assertTrue(ensure_node(self.root))
            with patch.dict(os.environ, {'FOREST_TEST_NODE_VERSION': 'v21.fixture'}):
                self.assertTrue(ensure_node(self.root))
                (folder / 'node_modules/broken').touch()
                self.assertTrue(ensure_node(self.root))
        self.assertEqual((folder / 'calls.txt').read_text().splitlines(), ['ci'] * 4)

    def test_failed_install_does_not_leave_success_stamp(self):
        folder, env = self.prepare_npm()
        with patch.dict(os.environ, env), contextlib.redirect_stdout(io.StringIO()):
            ensure_node(self.root)
            (folder / 'package.json').write_text('{"name":"changed"}')
            with patch.dict(os.environ, {'FOREST_TEST_NPM_FAIL': '1'}):
                with self.assertRaises(subprocess.CalledProcessError):
                    ensure_node(self.root)
        self.assertFalse((folder / 'node_modules/.forest-arena-install.json').exists())


if __name__ == '__main__':
    unittest.main()
