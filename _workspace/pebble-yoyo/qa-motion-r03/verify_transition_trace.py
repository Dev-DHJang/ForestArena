"""32개의 실제 idle→장비 진입/복귀 표시에 두 신발 중점의 열 드리프트가 없는지 검사."""
from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[3];BASE=ROOT/'_workspace/pebble-yoyo';trace=json.loads((BASE/'game-timeline-r03.json').read_text());idle=json.loads((BASE/'motions/nabi/idle/r03/candidate.json').read_text());midpoints=idle['conversion']['two_shoe_midpoint_pixels'];out=[]
assert len(trace['idle_entry_probes'])==32
for p in trace['idle_entry_probes']:
 b=p['before'];a=p['cast'][0];z=p['cast'][-1];assert b['frame']==p['source_idle_frame'];assert a['motion']=='equipment_yoyo_ground' and a['frame']==0;assert z['motion']=='idle'
 def center(s):return s['sprite_x']+(-1 if s['flip_h'] else 1)*(midpoints[s['frame']]-64)*s['scale']
 before=center(b);start=center(a);end=center(z);delta=max(abs(before-start),abs(end-start));assert delta<1e-4,(p['facing'],p['source_idle_frame'],delta)
 out.append({'facing':p['facing'],'idle_frame':p['source_idle_frame'],'before_world_midpoint_x':before,'equipment_entry_midpoint_x':start,'after_world_midpoint_x':end,'max_difference_px':delta})
result={'kind':'numeric check of actual-code trace; does not replace visual QA','status':'pass','trace_sha256':hashlib.sha256((BASE/'game-timeline-r03.json').read_bytes()).hexdigest(),'checks':len(out),'max_shoe_midpoint_difference_px':max(x['max_difference_px'] for x in out),'probes':out}
(BASE/'qa-motion-r03/idle-entry-probes.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n');print('IDLE_ENTRY_TRANSITION_TRACE: PASS,32 probes, maxdiff',result['max_shoe_midpoint_difference_px'])
