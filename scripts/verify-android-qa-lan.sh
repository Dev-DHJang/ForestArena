#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
python3 - <<'PY'
import os
from pathlib import Path
import select
import shutil
import socket
import subprocess
import sys
import tempfile
import time
sys.path.insert(0, str(Path('tools/forest_arena').resolve()))
from android_fleet import LanServer
servers=[]
client=None
with tempfile.TemporaryDirectory(prefix='forest-arena-qa-lan-') as folder:
    reserved=[]
    try:
        # Reserve all ports together so the two servers/APIs cannot share one.
        for _ in range(4):
            sock=socket.socket();sock.bind(('127.0.0.1',0));reserved.append(sock)
        ports=[sock.getsockname()[1] for sock in reserved]
        for sock in reserved:sock.close()
        env=os.environ.copy()
        godot=shutil.which('godot') or 'godot'
        for pair in range(2):
            server=LanServer('127.0.0.1','127.0.0.0/8',ports[pair*2],ports[pair*2+1],Path(folder)/str(pair),godot,'qa-isolation')
            servers.append(server);server.start()
            prefix=f'FOREST_ARENA_QA_ISOLATION_{pair}_'
            env[prefix+'WS']=f'ws://127.0.0.1:{server.port}'
            for role in ('HOST','GUEST'):
                _status,auth=server.fixture.route('POST','/v1/auth/guest',{}, {})
                status,_=server.fixture.route('PATCH','/v1/guest/profile',{'Authorization':'Bearer '+auth['access_token']},{'nickname':f'QA_{pair}_{role}'})
                assert status==200
                env[prefix+role]=auth['access_token']
        client=subprocess.Popen([godot,'--headless','--path',str(Path.cwd()),'res://tests/android_qa_lan_isolation.tscn'],env=env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
        deadline=time.monotonic()+25
        lines=[]
        stopped=False
        while time.monotonic()<deadline:
            ready,_,_=select.select([client.stdout],[],[],.25)
            if ready:
                line=client.stdout.readline().decode(errors='replace')
                if line:
                    lines.append(line)
                    if 'ANDROID_QA_ISOLATION_STOP_A' in line:
                        servers[0].process.terminate();servers[0].process.wait(timeout=5);stopped=True
            if client.poll() is not None:
                lines.append(client.stdout.read().decode(errors='replace'));break
        else:
            client.kill();client.wait();raise RuntimeError('isolation test timeout')
        output=''.join(lines)
        print(output,end='')
        if not stopped or client.returncode or 'ANDROID_QA_LAN_ISOLATION: PASS' not in output or 'SCRIPT ERROR' in output or 'ERROR:' in output:
            raise RuntimeError('dual LAN isolation failed')
        print('verify-android-qa-lan: PASS (two independent loopback servers; fixture auth only)')
    finally:
        if client and client.poll() is None:client.kill();client.wait()
        for server in reversed(servers):server.close()
PY
