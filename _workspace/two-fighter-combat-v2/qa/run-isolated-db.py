#!/usr/bin/env python3
"""Owned temporary PostgreSQL/API fixture; never reads development credentials."""
import json
import os
from pathlib import Path
import secrets
import shutil
import socket
import subprocess
import time
import urllib.request

ROOT = Path(__file__).resolve().parents[3]
QA = ROOT / '_workspace/two-fighter-combat-v2/qa'
os.chdir(ROOT)
PROFILE = 'fa-two-fighter-db-qa'
CONTAINER = 'fa-two-fighter-db-qa'
DOCKER = ['docker', '--host', f'unix://{Path.home()}/.colima/{PROFILE}/docker.sock']
def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1', 0))
        return sock.getsockname()[1]
db_port, api_port = free_port(), free_port()
env = os.environ.copy()
env.update(POSTGRES_USER='forest_arena_qa_owner', POSTGRES_PASSWORD=secrets.token_hex(24), POSTGRES_DB='forest_menu_qa_two_fighter_dev')
app_password = secrets.token_hex(24)
env.update(DATABASE_URL=f'postgresql://forest_arena_app:{app_password}@127.0.0.1:{db_port}/{env["POSTGRES_DB"]}',
    FOREST_ARENA_QA_ADMIN_DATABASE_URL=f'postgresql://{env["POSTGRES_USER"]}:{env["POSTGRES_PASSWORD"]}@127.0.0.1:{db_port}/{env["POSTGRES_DB"]}',
    FOREST_ARENA_API_URL=f'http://127.0.0.1:{api_port}', FOREST_ARENA_API_HOST='127.0.0.1', FOREST_ARENA_API_PORT=str(api_port),
    FOREST_ARENA_TOKEN_SECRET=secrets.token_hex(32), FOREST_ARENA_SERVICE_TOKEN=secrets.token_hex(32),
    FOREST_ARENA_PROFILE_RUN_ID=f'two-fighter-{int(time.time())}-{os.getpid()}')
env.update(FOREST_ARENA_PROFILE_REPORT=f'/private/tmp/forest-db-profile-{env["FOREST_ARENA_PROFILE_RUN_ID"]}.json',
    FOREST_ARENA_QA_API_URL=env['FOREST_ARENA_API_URL'], FOREST_ARENA_QA_DATABASE_URL=env['DATABASE_URL'],
    FOREST_ARENA_QA_SERVICE_TOKEN=env['FOREST_ARENA_SERVICE_TOKEN'])
results = []
api = None
container_started = False
def run(label, args, input=None, timeout=180):
    with (QA/(label+'.log')).open('w') as log:
        result = subprocess.run(args, input=input, text=True, env=env, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
    results.append({'name':label, 'exit_code':result.returncode})
    print(f'{label}: exit={result.returncode}', flush=True)
    return result.returncode
def sql(text, label):
    code = run(label, DOCKER+['exec','-i',CONTAINER,'psql','-X','--set','ON_ERROR_STOP=1','-U',env['POSTGRES_USER'],'-d',env['POSTGRES_DB']], input=text)
    if code: raise RuntimeError('SQL fixture preparation failed: '+label)
try:
    if run('db-pull',DOCKER+['pull','postgres:18.6-alpine3.23'],timeout=300): raise RuntimeError('PostgreSQL image unavailable')
    if run('db-container-start',DOCKER+['run','--detach','--name',CONTAINER,'--label','forest-arena.qa=two-fighter-combat-v2','--restart=no','--tmpfs','/var/lib/postgresql:rw,size=536870912','-p',f'127.0.0.1:{db_port}:5432','-e','POSTGRES_USER','-e','POSTGRES_PASSWORD','-e','POSTGRES_DB','postgres:18.6-alpine3.23']): raise RuntimeError('Owned DB failed to start')
    container_started = True
    for _ in range(60):
        ready=subprocess.run(DOCKER+['exec',CONTAINER,'pg_isready','-U',env['POSTGRES_USER'],'-d',env['POSTGRES_DB']],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        if ready.returncode==0: break
        time.sleep(1)
    else: raise RuntimeError('Owned DB did not become ready')
    sql(f"CREATE ROLE forest_arena_app LOGIN NOSUPERUSER NOCREATEDB NOCREATEROLE NOINHERIT PASSWORD '{app_password}';",'db-role')
    for path in sorted((ROOT/'database/migrations').glob('*.sql')): sql(path.read_text(),'db-'+path.stem)
    sql("INSERT INTO infra.environment_guard(environment_name) VALUES('verification');",'db-environment-guard')
    if run('db-profile-catalog',['godot','--headless','--path','.','--script','res://tools/forest_arena/profile_catalog.gd']): raise RuntimeError('Catalog export failed')
    if run('db-api-build',['npm','--prefix','server/api','run','build']): raise RuntimeError('API build failed')
    api_log=(QA/'db-api-server.log').open('w')
    api=subprocess.Popen(['node','server/api/dist/src/server.js'],env=env,stdout=api_log,stderr=subprocess.STDOUT)
    for _ in range(60):
        try:
            with urllib.request.urlopen(env['FOREST_ARENA_API_URL']+'/health/ready',timeout=1) as response:
                if response.status==200: break
        except Exception: pass
        time.sleep(.5)
    else: raise RuntimeError('Owned API did not become ready')
    print('Owned API and PostgreSQL ready on dedicated loopback ports',flush=True)
    run('db-profile-game-write',['godot','--headless','--path','.','--script','res://tests/db_profile_runtime.gd'])
    run('db-profile-game-restore',['godot','--headless','--path','.','--script','res://tests/db_profile_runtime.gd','--','--restore'])
    run('db-profile-api-runtime',['node','server/api/dist/tests/profile_runtime.js'])
    run('db-selection-check',['node',str(QA/'db-selection-check.mjs')])
    menu_report=ROOT/'_workspace/premium-menu-features-v01/qa-app-api-report.json'
    original_report=menu_report.read_bytes() if menu_report.exists() else None
    menu_report.parent.mkdir(parents=True,exist_ok=True)
    try:
        run('db-menu-features-app-api',['godot','--headless','--path','.','--script','res://tests/menu_features_app_api.gd'],timeout=240)
        if menu_report.exists(): (QA/'db-menu-features-app-api-report.json').write_bytes(menu_report.read_bytes())
    finally:
        if original_report is None: menu_report.unlink(missing_ok=True)
        else: menu_report.write_bytes(original_report)
    game_report=Path(env['FOREST_ARENA_PROFILE_REPORT'])
    if game_report.exists(): (QA/'db-profile-game-sql-report.json').write_bytes(game_report.read_bytes())
    sql('SELECT environment_name FROM infra.environment_guard; SELECT count(*) AS profiles FROM app.player_profiles; SELECT count(*) AS actions FROM app.profile_requests;','db-final-counts')
except Exception as error:
    print(type(error).__name__+': '+str(error),flush=True)
    results.append({'name':'fixture-orchestration','exit_code':1})
finally:
    if api is not None:
        api.terminate()
        try: api.wait(timeout=15)
        except subprocess.TimeoutExpired: api.kill();api.wait()
    if container_started:
        run('db-container-remove',DOCKER+['rm','--force',CONTAINER])
    # Remove only this run's temporary Godot credentials, preserving ordinary user files.
    godot_user=Path.home()/'Library/Application Support/Godot/app_userdata/Forest Arena'
    for suffix in ['', '-fresh']:
        fixture=godot_user/('db-test-'+env['FOREST_ARENA_PROFILE_RUN_ID']+suffix)
        if fixture.is_dir(): shutil.rmtree(fixture)
    Path(env['FOREST_ARENA_PROFILE_REPORT']).unlink(missing_ok=True)
    (QA/'db-isolated-results.json').write_text(json.dumps({'container':CONTAINER,'colima_profile':PROFILE,'database':env['POSTGRES_DB'],'profile_run_id':env['FOREST_ARENA_PROFILE_RUN_ID'],'db_port':db_port,'api_port':api_port,'results':results,'physical_device':'not_run'},indent=2)+'\n')
raise SystemExit(0 if all(item['exit_code']==0 for item in results) else 1)
