#!/usr/bin/env python3
"""Independent ADR-033 API and Godot checks on a disposable QA-only database.

The normal development environment and sessions are never sourced. Secrets stay
in child-process environments, never in commands or report files.
"""
from __future__ import annotations
import argparse,json,os,secrets,socket,subprocess,time,urllib.request,uuid
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]

def free_port():
    with socket.socket() as sock:
        sock.bind(('127.0.0.1',0)); return sock.getsockname()[1]

def wait_ready(base):
    for _ in range(100):
        try:
            with urllib.request.urlopen(base+'/health/ready',timeout=1) as r:
                if r.status==200:return
        except Exception:time.sleep(.15)
    raise RuntimeError('QA API readiness timeout')

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--app',action='store_true',help='Also run the actual Godot service/API integration after black-box checks')
    parser.add_argument('--skip-api',action='store_true',help='Target the actual Godot client after an unchanged backend already passed black-box checks')
    parser.add_argument('--native-app',action='store_true',help='Render connected actual-API Godot menus in a native window')
    parser.add_argument('--skip-build',action='store_true',help='Use producer-built dist output after coordination')
    args=parser.parse_args()
    suffix=uuid.uuid4().hex[:12]; name='forest-menu-qa-'+suffix; database='forest_menu_qa_'+suffix
    folder=ROOT/'_workspace/premium-menu-features-v01';folder.mkdir(parents=True,exist_ok=True)
    password=secrets.token_urlsafe(24); api=None;api_log=None
    environment={**os.environ,'POSTGRES_PASSWORD':password,'POSTGRES_DB':database}
    run=lambda command,**kw:subprocess.run(command,check=True,cwd=ROOT,**kw)
    result={'run_id':suffix,'database':database,'kind':'isolated_desktop_qa','physical_android':'not_run','checks':[]}
    try:
        run(['docker','run','--rm','-d','--name',name,'-e','POSTGRES_PASSWORD','-e','POSTGRES_DB','-p','127.0.0.1::5432','postgres:18.6-alpine3.23'],env=environment,stdout=subprocess.DEVNULL)
        for _ in range(100):
            if subprocess.run(['docker','exec',name,'pg_isready','-h','127.0.0.1','-U','postgres'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL).returncode==0:break
            time.sleep(.2)
        else:raise RuntimeError('QA database startup timeout')
        port=subprocess.check_output(['docker','port',name,'5432/tcp'],text=True).strip().rsplit(':',1)[1]
        run(['docker','exec','-i',name,'psql','-U','postgres','-d',database,'-v','ON_ERROR_STOP=1'],input=b'CREATE ROLE forest_arena_app;',stdout=subprocess.DEVNULL)
        for migration in sorted((ROOT/'database/migrations').glob('*.sql')):
            run(['docker','exec','-i',name,'psql','-U','postgres','-d',database,'-v','ON_ERROR_STOP=1'],input=migration.read_bytes(),stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        api_port=free_port();base=f'http://127.0.0.1:{api_port}';db_url=f'postgresql://postgres:{password}@127.0.0.1:{port}/{database}';service=secrets.token_hex(32)
        environment={**os.environ,'DATABASE_URL':db_url,'FOREST_ARENA_API_HOST':'127.0.0.1','FOREST_ARENA_API_PORT':str(api_port),'FOREST_ARENA_API_URL':base,'FOREST_ARENA_TOKEN_SECRET':secrets.token_hex(32),'FOREST_ARENA_SERVICE_TOKEN':service,'FOREST_ARENA_DEMO_MODE':'false','FOREST_ARENA_QA_DATABASE_URL':db_url,'FOREST_ARENA_QA_API_URL':base,'FOREST_ARENA_QA_SERVICE_TOKEN':service,'FOREST_ARENA_QA_REPORT':str(folder/'qa-api-report.json')}
        if not args.skip_build:run(['npm','--prefix','server/api','run','build'],stdout=subprocess.DEVNULL)
        api_log=(folder/'qa-api-server.log').open('w')
        api=subprocess.Popen(['node','server/api/dist/src/server.js'],cwd=ROOT,env=environment,stdout=api_log,stderr=api_log)
        wait_ready(base)
        result['blackbox_skipped']=args.skip_api
        if not args.skip_api:
            check=subprocess.run(['node','tests/menu_features_api.mjs'],cwd=ROOT,env=environment)
            result['checks'].append({'name':'independent-blackbox-api','exit_code':check.returncode})
        with urllib.request.urlopen(base+'/v1/service') as response:before=json.load(response)['service_id']
        api.terminate();api.wait(timeout=10)
        api=subprocess.Popen(['node','server/api/dist/src/server.js'],cwd=ROOT,env=environment,stdout=api_log,stderr=api_log);wait_ready(base)
        with urllib.request.urlopen(base+'/v1/service') as response:after=json.load(response)['service_id']
        result['checks'].append({'name':'api-process-restart-service-id','pass':before==after})
        if args.app or args.native_app:
            with (folder/'qa-app-api.log').open('w') as output:
                command=['godot']+([] if args.native_app else ['--headless'])+['--path','.','--script','res://tests/menu_features_app_api.gd']
                if args.native_app:command+=['--','--ui-capture-connected']
                app=subprocess.run(command,cwd=ROOT,env=environment,stdout=output,stderr=subprocess.STDOUT,timeout=180)
            result['checks'].append({'name':'actual-godot-client-api','exit_code':app.returncode})
        result['status']='pass' if all(c.get('pass',c.get('exit_code')==0) for c in result['checks']) else 'fail'
    except Exception as error:
        result['status']='fail';result['error']=type(error).__name__+': '+str(error).replace(password,'[redacted]')
    finally:
        if api:
            api.terminate()
            try:api.wait(timeout=10)
            except subprocess.TimeoutExpired:api.kill();api.wait()
        if api_log:api_log.close()
        subprocess.run(['docker','rm','-f',name],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        (folder/'qa-isolated-runtime.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
        print('MENU_FEATURES_INDEPENDENT_ISOLATION: '+result['status'].upper())
    return 0 if result['status']=='pass' else 1
if __name__=='__main__':raise SystemExit(main())
