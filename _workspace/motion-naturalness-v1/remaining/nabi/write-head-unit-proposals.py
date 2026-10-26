"""전체 키 대신 승인 모델의 귀-턱 머리 단위에 맞출 초기 균일 배율 제안."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib,math,importlib.util
base=Path(__file__).resolve().parent
s=importlib.util.spec_from_file_location('motion_split',base.parents[1]/'split-figures.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
landmarks={
'idle-r02':(0,[214,12],[252,146]),'guard-r01':(0,[169,26],[205,143]),'hitstun-r01':(0,[55,126],[164,174]),'launch-r01':(0,[149,69],[210,163]),'knock_down-r01':(0,[108,43],[192,137]),'wake_up-r01':(15,[171,51],[210,165]),'death-r02':(0,[215,51],[262,169]),'ring_out-r02':(0,[106,69],[183,165]),'spawn-r01':(0,[215,12],[248,131]),'attack_heavy_up-r02':(0,[174,9],[218,136]),'attack_air_light-r01':(0,[232,6],[270,145]),'attack_air_heavy-r02':(0,[184,13],[236,136]),'special_side-partA-r02':(0,[235,23],[280,149]),'special_side-partB-r02':(0,[282,43],[322,160])}
rows=[];shots=[]
for name,(f,ear,chin) in landmarks.items():
 p=base/(name+'.png');im=Image.open(p).convert('RGBA');w,h=im.size;cw,ch=w/4,h/4;ox,oy=f%4*cw,f//4*ch;unit=math.dist(ear,chin);scale=41.5/unit
 row=dict(source_png=name+'.png',source_sha256=hashlib.sha256(p.read_bytes()).hexdigest(),frame_index=f,source_size=[w,h],raw_cell_size=[cw,ch],near_ear_tip_cell=ear,chin_cell=chin,source_head_unit_pixels=round(unit,3),recommended_uniform_source_to_world_scale=round(scale,4),target_head_unit_world_pixels=41.5,precision='원화 수동 눈금 판독 약 ±5px. 이 값은 표시 크기 초기 제안이고 실제 승인 이동/연계와 대조 전에는 확정하지 않는다.')
 rows.append(row);figures,_=m.split_figures(im,4,4);crop,bounds=figures[f];sc=min(390/crop.width,335/crop.height);shot=Image.new('RGB',(450,420),'#252831');d=ImageDraw.Draw(shot);shown=crop.resize((round(crop.width*sc),round(crop.height*sc)));shot.paste(shown,(25,45),shown)
 d.text((20,8),f'{name} F{f} | proposed {scale:.3f}',fill='white')
 pts=[]
 for label,point,color in [('ear',ear,'#ffe050'),('chin',chin,'#50e8ff')]:
  x=25+(point[0]+ox-bounds[0])*sc;y=45+(point[1]+oy-bounds[1])*sc;pts.append((x,y));d.ellipse((x-4,y-4,x+4,y+4),outline=color,width=2);d.text((x+5,y),label+str(point),fill=color)
 d.line((*pts[0],*pts[1]),fill='white',width=1);d.text((20,393),f'ear-chin {unit:.1f}px -> 41.5 world px',fill='white');shots.append(shot)
for page in range((len(shots)+3)//4):
 b=Image.new('RGB',(900,840),'#252831')
 for j,shot in enumerate(shots[page*4:page*4+4]):b.paste(shot,(j%2*450,j//2*420))
 b.save(base/'anchor-diagnostics'/f'head-unit-marked-{page+1}.png')
data={'kind':'presentation-only source head-unit scale proposal','reference':'승인 idle의 가까운 귀 끝(56,37)→턱(72,76)은 약42.2px. 승인 run 원화(440,42)→(539,280)에 기존 균일배율0.157706을 적용하면 약40.7px. 두 승인 표시 사이 기준41.5px를 초기 목표로 쓴다.','reference_preview':['anchor-diagnostics/approved-idle-native.png','anchor-diagnostics/approved-run-source.png'],'method':'각 모션 전체에 하나의 균일 배율을 사용한다. 모든 자세의 전체 키를 idle 높이로 맞추지 않는다. 귀-턱 직선거리를 써서 기울어진 머리를 수직 키로 잘못 줄이지 않는다.','limitations':['손으로 선택한 한 프레임 기준이므로 전 프레임 머리 크기 안정성 검증과 실제 전환 검증을 대신하지 않는다.','웨이크업은 누운 첫 그림보다 비교 가능한 마지막 준비자세 F15를 측정했다.','특수 PART A/B는 원시 해상도와 머리 단위가 달라 각각 균일 배율을 제안한다. 두 부분 연결이 자연스러운지 실제 게임에서 확인해야 한다.','카메라 줌과 SpriteFrames 표시 배율을 이중 적용하지 않는다. 기존 포장 배율과 presentation_scale을 곱한 실제 source→world 배율과 비교한다.'],'sources':rows}
(base/'head-unit-proposals.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
print('\n'.join(r['source_png']+' '+str(r['recommended_uniform_source_to_world_scale']) for r in rows))
