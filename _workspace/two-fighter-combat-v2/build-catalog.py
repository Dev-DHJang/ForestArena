from pathlib import Path
import json,hashlib
ROOT=Path(__file__).resolve().parents[2];BASE=Path(__file__).resolve().parent
manifest=json.loads((ROOT/'assets/character/manifest.json').read_text())['assets']
layout=json.loads((BASE/'candidate-layout.json').read_text())
new={(r['character_id'],r['motion']):r for r in layout}
base_actions={
'idle':'중립 대기 호흡과 작은 체중 이동. 공격·피격으로 보이지 않는다.',
'run':'전진 달리기. 발 교대와 체중 이동이 이어지고 루프가 튀지 않는다.',
'jump':'상승·정점·하강을 구분한다. 실제 착지 전에는 지면을 딛는 착지 자세를 보이지 않는다.',
'guard':'두 손 또는 팔로 몸 앞을 방어한다. 공격·피하기로 보이지 않는다.',
'hitstun':'맞은 순간 반응과 짧은 경직을 구분한다. 스스로 공격하지 않는다.',
'launch':'공중으로 밀려난 수동 피격 자세이며 도약 준비와 구별한다.',
'knock_down':'넘어져 쓰러진 피격자 자세를 유지한다.',
'wake_up':'쓰러짐에서 다시 몸을 세워 일어나는 회복이다.',
'death':'마지막 기회 소진 시 사망·탈락을 표현한다.',
'ring_out':'경기장 밖으로 밀려난 장외 탈락으로 자발적 공격과 구분한다.',
'spawn':'새 기회로 등장한 뒤 준비 자세가 된다.'}
attack_actions={
('ja-hyun','attack_light_combo_01'):'왼손 전방 펀치. 지상 약1과 약3은 같은 손이다. 준비→전방 단타→회복.',
('ja-hyun','attack_light_combo_02'):'반대 오른손 전방 펀치. 왼손 첫타와 사용 손을 구분한다.',
('ja-hyun','attack_light_combo_04'):'한 발로 버티고 다른 발을 전방으로 펼치는 강한 킥. 목도리 공격이 아닌 약4 다운 마무리.',
('ja-hyun','special_neutral'):'긴 목도리를 전방으로 내민 뒤 당기는 단타 강공격. 별도 리본 효과로180 리치와 끌기를 표현한다.',
('ja-hyun','attack_air_light'):'발을 딛지 않은 공중 단타 펀치와 긴 목도리 리치. 새 점프·공격 잠금은 피해자에게 적용한다.',
('ja-hyun','attack_air_heavy'):'공중에서 목도리를 머리 위에서 아래로 내려치는 단타. 시전자는 공중에 남고 피해자가 급강하한다.',
('ja-hyun','special_scarf_sweep'):'좌·우·위 세 방향 목도리 휘두르기1초. 전역6tick마다10회이며 앞9회끌기·마지막밀기. 별도 리본 효과와 대조한다.',
('nabi','attack_light_combo_01'):'왼손으로 전방 할퀴기. 첫 약공격 준비→앞으로 단타→회복.',
('nabi','attack_light_up'):'오른손을 아래에서 위로 할퀴는 지상 약2. 반대손은 방어하고 양손X나점프어퍼와구별한다.',
('nabi','attack_light_combo_02'):'두 손을 교차한 뒤 양쪽으로 벌려 X자 할퀴는 약3 다운 마무리.',
('nabi','attack_heavy_up'):'지상에서 한 팔 어퍼로 상대를 위로 띄우는 단타. 차지나 복수 타격이 아니다.',
('nabi','attack_air_light'):'발을 딛지 않은 공중 단타 할퀴기. 긴 전방 리치와 피해자 추가 행동 제한을 표현한다.',
('nabi','attack_air_heavy'):'공중에서 동일한 한 팔을 아래에서 위로 올려치는 단타. 반대팔은 몸 앞에 유지하고 시전자는 스스로 낙하하지 않는다.',
('nabi','special_side'):'낮은 전진 돌파(run)→첫 적 뒤 고정 종점에서 상대를 향해 돌아서 단 한번 할퀴기→정지. 자동 추적하지 않는다.'}
rows=[]
for cid in ['ja-hyun','nabi']:
 motions=list(base_actions)+[motion for character,motion in attack_actions if character==cid]
 for motion in motions:
  expected=base_actions.get(motion,attack_actions.get((cid,motion)))
  if (cid,motion) in new:
   r=new[cid,motion];row={'type':'animation-candidate','character_id':cid,'visual_state_id':motion,'path':r['path'],'sprite_frames_path':r['sprite_frames_path'],'fps':12,'loop':False,'presentation_scale':r['presentation_scale'],'foot_pivot_y':r['foot_pivot_y'],'phase_frame_ranges':[[0,4],[4,10],[10,16]]}
   if motion=='special_scarf_sweep':row['phase_frame_ranges']=[[0,4],[4,13],[13,16]]
  else:
   row=next(dict(r) for r in manifest if r.get('type')=='animation-runtime' and r.get('character_id')==cid and r.get('visual_state_id')==motion)
   row['reuse_approved_runtime']=True
  row['expected_action']=expected;row['action_source']='_workspace/two-fighter-combat-v2/02_motion_expectations.md';rows.append(row)
paths={'ja-hyun':'assets/combat/movesets/two_fighter_ja_hyun_moveset.tres','nabi':'assets/combat/movesets/two_fighter_nabi_moveset.tres'}
doc={'schema_version':1,'kind':'motion-candidates','approval_status':'pending','attack_sources':list(paths.values()),'character_movesets':paths,'assets':rows}
cat=BASE/'candidate-catalog.json';cat.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n')
scope={'schema_version':1,'kind':'candidate-motion-review','catalog_sha256':hashlib.sha256(cat.read_bytes()).hexdigest(),'motions':[{'character_id':r['character_id'],'motion':r['visual_state_id']} for r in rows]}
p=BASE/'candidate-scope.json';p.write_text(json.dumps(scope,ensure_ascii=False,indent=2)+'\n');(BASE/'candidate-scope.sha256').write_text(hashlib.sha256(p.read_bytes()).hexdigest()+'\n')
print(len(rows),'active motions; candidates',len(new))
