"""제작자가 확대 원화를 직접 보고 표시한 좌표를 보존한다. 원화 수정 없음."""
from pathlib import Path
import json,hashlib
from PIL import Image
base=Path(__file__).resolve().parent
# raw nominal cell-relative pixels, visually annotated; not rescaled 128-cell coordinates.
hand={
 'attack_heavy_up-r02':[(272,128),(211,151),(240,194),(226,186),(278,136),(265,124),(271,107),(253,39),(283,67),(281,101),(267,116),(261,137),(266,129),(208,151),(250,188),(225,176)],
 'attack_air_heavy-r02':[(267,144),(293,201),(283,198),(270,213),(283,63),(268,30),(267,45),(255,34),(271,102),(273,127),(267,130),(258,175),(271,139),(285,154),(267,166),(263,202)],
 'attack_air_light-r01':[(207,163),(194,158),(218,160),(138,87),(331,160),(350,165),(362,166),(294,182),(223,165),(233,157),(226,169),(217,167),(221,152),(222,155),(234,155),(226,160)],
 'special_side-partA-r02':[(154,171),(218,184),(208,186),(217,194),(163,138),(157,148),(296,169),(149,153),(292,151),(246,151),(145,150),(252,170),(144,135),(147,130),(231,156),(145,135)],
 'special_side-partB-r02':[(169,150),(150,163),(216,147),(202,163),(183,119),(308,175),(335,168),(265,180),(224,161),(237,165),(221,174),(216,173),(230,157),(224,160),(226,159),(225,168)]}
tips={
 'attack_heavy_up-r02':{7:(291,8),8:(313,28)},
 'attack_air_heavy-r02':{4:(309,36),5:(294,7),6:(304,20),7:(286,12)},
 'attack_air_light-r01':{4:(370,182),5:(395,176),6:(402,181),7:(339,204)},
 'special_side-partA-r02':{},
 'special_side-partB-r02':{5:(351,174),6:(362,178),7:(301,188)}}
for name,points in hand.items():
 p=base/(name+'.png');im=Image.open(p).convert('RGBA');w,h=im.size;cw=w/4;ch=h/4;frames=[];heavy=name.startswith('attack_heavy') or name.startswith('attack_air_heavy');partB='partB' in name
 for f,point in enumerate(points):
  anchors={'claw_hand':list(point)};omissions={};phase='startup' if f<4 else ('active' if f<8 else 'recovery')
  if name.startswith('special_side'):
   mf=f+16 if partB else f;phase='startup' if mf<4 else ('travel' if mf<20 else ('strike' if mf<24 else 'recovery'))
  else:mf=f
  if f in tips[name]:anchors['claw_tip']=list(tips[name][f])
  else:omissions['claw_tip']='금속 발톱이 접혀 있거나 주먹/다른 손가락과 겹쳐 중앙 발톱의 실제 끝을 구별할 수 없어 생략했다. 손 기준점으로 발톱 끝을 만들어 내지 않는다.'
  if heavy:
   obs='화면 오른쪽의 먼 X 소매 팔에 연결된 손을 표시했다. 가까운 흰 줄 소매 팔은 몸 앞 가드에 남는다.'
   if f<4:obs+=' 먼 손을 아래로 준비하는 구간이다.'
   elif f<8:obs+=' 같은 먼 팔이 위로 올라가는 구간이다.'
   else:obs+=' 같은 먼 팔을 접어 회수하는 구간이다.'
  elif name=='attack_air_light-r01':obs='가까운 흰 줄 소매 왼팔의 손을 표시했다. 두 발을 든 채 이 팔 하나를 전방으로 뻗었다 회수한다.'
  else:
   obs='기본 우향 원화의 가까운 흰 줄 소매 팔 손을 표시했다. 게임의 facing/flip_h 반전 전에 쓰는 원화 좌표다.'
   obs+= ' 단 한 번 할퀴는 구간이다.' if phase=='strike' else ' 이 그림은 타격 전 이동 또는 타격 뒤 회복이며 자체 타격 효과를 요구하지 않는다.'
  frames.append(dict(frame_index=f,motion_frame_index=mf,phase=phase,cell={'column':f%4,'row':f//4,'origin':[f%4*cw,f//4*ch],'width':cw,'height':ch},anchors=anchors,omitted_anchors=omissions,visual_observation=obs,reviewed_previews=[f'anchor-diagnostics/{name}-whole-f{f//4*4:02d}-{f//4*4+3:02d}.png',f'anchor-diagnostics/{name}-marked-f{f//4*4:02d}-{f//4*4+3:02d}.png']))
 data={'schema_version':1,'character_id':'nabi','motion':'special_side' if name.startswith('special_side') else name.rsplit('-r',1)[0],'source_png':name+'.png','source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'source_size':[w,h],'raw_grid':{'columns':4,'rows':4,'cell_width':cw,'cell_height':ch},'frame_count':16,'motion_frame_count':32 if name.startswith('special_side') else 16,'base_facing':'right','coordinate_system':'원시 PNG 4×4 격자 셀 왼쪽 위 기준 픽셀. x 오른쪽, y 아래. source_absolute=cell.origin+anchor. 셀을 넘는 온전한 손/발톱은 셀 폭을 넘는 좌표도 허용한다. 128셀 좌표가 아니다.','anchor_meaning':{'claw_hand':'공격하는 팔에 연결된 실제 장갑 손/주먹의 손바닥 중심 부근. 몸통이나 효과 중심이 아니다.','claw_tip':'펼친 발톱 부채의 가운데 긴 보라색 발톱으로 읽히는 실제 바깥 끝. 그림만으로 해부학적 중지까지 확정한 좌표는 아니다. 확대판에서 끝을 구별할 수 있을 때만 기록하며 접힘/가림으로 불명확하면 키를 생략한다.'},'annotation_method':'원화 전 그림을 셀 좌표 눈금이 있는 확대판으로 직접 확인한 제작자 시각 주석. 좌표는 수동 판독 근삿값이며 원화나 전투 판정을 바꾸지 않는다.','precision_limit':'수동 눈금 판독으로 원화 약 ±5px의 오차가 남을 수 있다. 포장 후 실제 소형 표시 및 손/발톱 효과 접속 검증이 필요하다.','source_review':{'reviewer':'nabi_anchor_finish','reviewed_frame_count':16,'method':'80프레임 전체의 손 표시판 20장과 visible-claws-closeup 4장을 직접 눈으로 확인했다. 효과 연결이나 실제 게임 재생 통과를 의미하지 않는다.','visible_claw_closeups':[f'anchor-diagnostics/visible-claws-closeup-{n}.png' for n in range(1,5)]},'review_status':'source annotation only; independent runtime VFX QA pending; explicit user approval pending','frames':frames}
 (base/(name+'.anchors.json')).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
 print(name,len(frames),'tip visible',len(tips[name]))
