#!/usr/bin/env python3
"""Create one disposable verification PostgreSQL container; leave development DBs alone."""
import json
import argparse
import os
from pathlib import Path
import secrets
import tempfile
import socket
import subprocess
import sys
import time
import uuid
parser=argparse.ArgumentParser()
parser.add_argument("--lan",action="store_true")
parser.add_argument("--godot-profile",action="store_true")
parser.add_argument("--godot-test",action="append",default=[])
parser.add_argument("--skip-build",action="store_true")
args=parser.parse_args()
PROJECT=Path(__file__).resolve().parents[3]
suffix=uuid.uuid4().hex[:12]
name='forest-menu-api-test-'+suffix
database='forest_menu_api_test_'+suffix
password=secrets.token_urlsafe(24)
env={**os.environ,'POSTGRES_PASSWORD':password,'POSTGRES_DB':database}
api=None

def run(args,**kwargs):
    return subprocess.run(args,check=True,**kwargs)

try:
    run(['docker','run','--rm','-d','--name',name,'-e','POSTGRES_PASSWORD','-e','POSTGRES_DB','-p','127.0.0.1::5432','postgres:18.6-alpine3.23'],env=env,stdout=subprocess.DEVNULL)
    for attempt in range(60):
        if subprocess.run(['docker','exec',name,'pg_isready','-h','127.0.0.1','-U','postgres'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0:break
        time.sleep(.5)
    else:raise RuntimeError('isolated PostgreSQL startup timeout')
    port=subprocess.check_output(['docker','port',name,'5432/tcp'],text=True).strip().rsplit(':',1)[1]
    run(['docker','exec','-i',name,'psql','-U','postgres','-d',database,'-v','ON_ERROR_STOP=1'],input=b'CREATE ROLE forest_arena_app;',stdout=subprocess.DEVNULL)
    for migration in sorted((PROJECT/'database/migrations').glob('*.sql')):
        run(['docker','exec','-i',name,'psql','-U','postgres','-d',database,'-v','ON_ERROR_STOP=1'],input=migration.read_bytes(),stdout=subprocess.DEVNULL)
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0));api_port=sock.getsockname()[1]
    api_env={**os.environ,'DATABASE_URL':f'postgresql://postgres:{password}@127.0.0.1:{port}/{database}',
             'FOREST_ARENA_DEMO_MODE':'false','FOREST_ARENA_API_PORT':str(api_port),'FOREST_ARENA_API_HOST':'127.0.0.1',
             'FOREST_ARENA_TOKEN_SECRET':secrets.token_hex(32),'FOREST_ARENA_SERVICE_TOKEN':secrets.token_hex(32),
             'FOREST_ARENA_API_URL':f'http://127.0.0.1:{api_port}'}
    if not args.skip_build:run(['npm','--prefix',str(PROJECT/'server/api'),'run','build'])
    api=subprocess.Popen(['node',str(PROJECT/'server/api/dist/src/server.js')],env=api_env,stdout=subprocess.DEVNULL)
    import urllib.request
    for attempt in range(60):
        try:
            with urllib.request.urlopen(api_env['FOREST_ARENA_API_URL']+'/health/ready',timeout=1) as response:
                if response.status==200:break
        except Exception:time.sleep(.2)
    else:raise RuntimeError('isolated API startup timeout')
    run(['node',str(PROJECT/'server/api/dist/tests/menu_runtime.js')],env=api_env)
    if args.lan:
        lan_started=time.monotonic()
        def http(method,path,token='',payload=None):
            data=None if payload is None else json.dumps(payload).encode()
            req=urllib.request.Request(api_env['FOREST_ARENA_API_URL']+path,data=data,method=method,headers={'content-type':'application/json','authorization':'Bearer '+token})
            with urllib.request.urlopen(req,timeout=5) as response:return json.load(response)
        pair=[]
        for index,prefix in enumerate(('LanHost','LanGuest')):
            identity=http('POST','/v1/auth/guest',payload={})
            http('PATCH','/v1/guest/profile',identity['access_token'],{'nickname':prefix+suffix[:4]})
            pair.append(identity)
        with socket.socket() as sock:
            sock.bind(('127.0.0.1',0));lan_port=sock.getsockname()[1]
        with tempfile.TemporaryDirectory(prefix='forest-lan-api-') as temporary:
            lan_env={**api_env,'FOREST_ARENA_LAN_PORT':str(lan_port),'FOREST_ARENA_LAN_BIND_HOST':'127.0.0.1',
                     'FOREST_ARENA_LAN_ADVERTISED_WS_URL':f'ws://127.0.0.1:{lan_port}',
                     'FOREST_ARENA_LAN_API_URL':api_env['FOREST_ARENA_API_URL'],'FOREST_ARENA_API_BASE_URL':api_env['FOREST_ARENA_API_URL'],
                     'FOREST_ARENA_ALLOWED_CIDR':'127.0.0.0/8','FOREST_ARENA_LAN_OUTBOX_PATH':str(Path(temporary)/'outbox.json'),
                     'FOREST_ARENA_QA_RUN':'menu-lan-'+suffix,
                     'FOREST_ARENA_LAN_RUNTIME_HOST_TOKEN':pair[0]['access_token'],'FOREST_ARENA_LAN_RUNTIME_GUEST_TOKEN':pair[1]['access_token']}
            server_command=['godot','--headless','--path',str(PROJECT),'res://server/game/lan_game_server.tscn']
            lan=None
            verifier=None
            with (PROJECT/'_workspace/premium-menu-features-v01/lan-menu-server.log').open('w') as log:
                def start_lan():
                    child=subprocess.Popen(server_command,env=lan_env,stdout=log,stderr=subprocess.STDOUT)
                    deadline=time.monotonic()+10
                    while time.monotonic()<deadline:
                        if child.poll() is not None:raise RuntimeError('actual LAN server exited; see lan-menu-server.log')
                        try:
                            with socket.create_connection(('127.0.0.1',lan_port),timeout=.2):return child
                        except OSError:time.sleep(.1)
                    child.terminate();child.wait();raise RuntimeError('LAN readiness timeout')
                try:
                    lan=start_lan()
                    verifier=subprocess.Popen(['godot','--headless','--max-fps','120','--path',str(PROJECT),'--script','res://tests/lan_menu_api_runtime.gd'],env=lan_env,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,bufsize=1)
                    for line in verifier.stdout:
                        print(line,end='',flush=True)
                        if line.strip()=='LAN_MENU_API_PAUSE_API':
                            api.terminate();api.wait(timeout=10)
                        elif line.strip()=='LAN_MENU_API_RESTART_SERVER':
                            lan.terminate();lan.wait(timeout=10)
                            lan=start_lan()
                            api=subprocess.Popen(['node',str(PROJECT/'server/api/dist/src/server.js')],env=api_env,stdout=subprocess.DEVNULL)
                    if verifier.wait(timeout=90):raise RuntimeError('actual LAN/API combat integration failed')
                    print('LAN_MENU_API_ELAPSED seconds='+str(round(time.monotonic()-lan_started,1)),flush=True)
                finally:
                    if verifier and verifier.poll() is None:verifier.terminate();verifier.wait(timeout=10)
                    if lan and lan.poll() is None:lan.terminate();lan.wait(timeout=10)
    if args.godot_profile:
        profile_run='menu-isolated-'+suffix
        api_env['FOREST_ARENA_PROFILE_RUN_ID']=profile_run
        api_env['FOREST_ARENA_PROFILE_REPORT']='/private/tmp/forest-db-profile-'+profile_run+'.json'
        run(['godot','--headless','--path',str(PROJECT),'--script','res://tests/db_profile_runtime.gd'],env=api_env)
        run(['godot','--headless','--path',str(PROJECT),'--script','res://tests/db_profile_runtime.gd','--','--restore'],env=api_env)
    for script in args.godot_test:
        run(['godot','--headless','--path',str(PROJECT),'--script',script],env=api_env)
    run(['node',str(PROJECT/'server/api/dist/tests/profile_runtime.js')],env=api_env)
    run(['node',str(PROJECT/'server/api/dist/tests/demo_guest_runtime.js')],env=api_env)
    old_service=json.load(urllib.request.urlopen(api_env['FOREST_ARENA_API_URL']+'/v1/service'))['service_id']
    api.terminate();api.wait(timeout=10)
    api=subprocess.Popen(['node',str(PROJECT/'server/api/dist/src/server.js')],env=api_env,stdout=subprocess.DEVNULL)
    for attempt in range(60):
        try:
            new_service=json.load(urllib.request.urlopen(api_env['FOREST_ARENA_API_URL']+'/v1/service',timeout=1))['service_id']
            break
        except Exception:time.sleep(.2)
    else:raise RuntimeError('isolated API restart timeout')
    assert old_service==new_service
    print('MENU_API_RESTART: PASS (persistent service UUID)')
finally:
    if api:
        api.terminate()
        try:api.wait(timeout=10)
        except subprocess.TimeoutExpired:api.kill();api.wait()
    subprocess.run(['docker','rm','-f',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
