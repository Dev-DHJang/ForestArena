#!/usr/bin/env python3
"""Attach this task's executed checks to the 81 preserved design-state mappings."""
from __future__ import annotations
import argparse,csv,hashlib,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
TOPIC=ROOT/'_workspace/premium-menu-features-v01'

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--report',required=True,help='Executed premium_menu_runtime report, relative to project root')
    parser.add_argument('--actual-report',default='_workspace/premium-menu-features-v01/qa-app-api-report.json')
    args=parser.parse_args()
    report_path=ROOT/args.report;report=json.loads(report_path.read_text())
    actual_path=ROOT/args.actual_report;actual=json.loads(actual_path.read_text())
    path=TOPIC/'state-runtime-coverage.json';spec=json.loads(path.read_text())
    rows=report.get('state_coverage',[])
    by_name={x['design_screen']:x for x in rows}
    if len(rows)!=81 or len(by_name)!=81 or len(spec['states'])!=81:raise SystemExit('Exactly 81 unique design-state rows are required')
    native=bool(report.get('native_capture'));kind='실제 Godot 창' if native else 'headless Godot'
    for row in spec['states']:
        checked=by_name.get(row['design_screen'])
        if checked is None:raise SystemExit('Missing executed row: '+row['design_screen'])
        count=int(checked.get('checks',0));passed=bool(checked.get('pass')) and count>0
        scope=checked.get('validation_scope','native controls and local store behavior')
        row['validation_scope']=scope
        row['evidence_report']=args.report
        row['runtime_check']=('pass' if passed else 'fix')+f' · {kind} {count}개 확인'
        if 'fixture' in scope:row['runtime_check']+=' · 서비스 응답 표본, 실제 DB 아님'
        if row['runtime_menu'] in ['mission','social','rank','profile']:
            row['actual_api_evidence']=args.actual_report
    spec.update(executed_states=len(rows),evidence_report=args.report,report_failures=len(report.get('failures',[])),execution_kind='native_window' if native else 'headless',status='pass' if not report.get('failures') and all(x.get('pass') and int(x.get('checks',0))>0 for x in rows) else 'fix',physical_device='not_run',actual_api_status=actual['status'],actual_api_checks=len(actual['checks']),evidence_sha256={args.report:hashlib.sha256(report_path.read_bytes()).hexdigest(),args.actual_report:hashlib.sha256(actual_path.read_bytes()).hexdigest()},note='81행은 설계 상태와 실행 확인의 대응 수다. 서로 다른 81개 서버 데이터나 81개 물리 기기 상호작용을 뜻하지 않는다. 서비스 응답 표본과 실제 HTTP/API 검사 결과를 구분한다.')
    path.write_text(json.dumps(spec,ensure_ascii=False,indent=2)+'\n')
    fields=['design_screen','kind','runtime_menu','params','action','policy','reason','runtime_check']
    with (TOPIC/'state-runtime-coverage.csv').open('w',newline='') as output:
        writer=csv.DictWriter(output,fieldnames=fields);writer.writeheader()
        for row in spec['states']:
            serialized={k:row[k] for k in fields};serialized['params']=json.dumps(serialized['params'],ensure_ascii=False);writer.writerow(serialized)
    print(f'MENU_FEATURES_STATE_COVERAGE: {spec["status"].upper()} ({len(rows)} mapped, {kind}; physical device not run)')
if __name__=='__main__':main()
