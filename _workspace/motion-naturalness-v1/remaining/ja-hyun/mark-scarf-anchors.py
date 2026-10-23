"""Human-selected source attachment points; overlays are diagnostics only."""
from pathlib import Path
from PIL import Image,ImageDraw
import hashlib,json
ROOT=Path(__file__).resolve().parents[4];BASE=Path(__file__).resolve().parent
# These points were selected by looking at original source cloth/hand junctions.
# They are NOT calculated from the attack hitbox or a past 16-frame motion.
air_light_root=[[192,138],[519,139],[835,148],[1142,154],[198,447],[513,450],[826,453],[1138,445],[188,772],[507,775],[823,776],[1139,776],[167,1084],[496,1088],[813,1089],[1135,1088]]
air_heavy_hand=[[122,99],[465,83],[831,82],[1105,70],[170,429],[497,431],[850,569],[1148,568],[221,860],[535,806],[850,795],[1114,701],[195,990],[482,995],None,None]
heavy_original_root={0:[204,210],1:[522,210],2:[837,213],3:[1135,213],8:[187,784],9:[442,779],10:[825,793],11:[1137,793],12:[168,1089],13:[506,1090],14:[821,1093],15:[1139,1091]}
heavy_quarter_root=[[331,330],[975,332],[333,937],[1010,946]]
sweep_a_root=[[180,149],[506,154],[817,151],[1136,155],[182,470],[508,472],[796,477],[1133,480],[177,772],[497,775],[805,775],[1127,775],[171,1071],[494,1071],[807,1074],[1137,1083]]
sweep_a_tips=[[[29,172],[99,218]],[[468,220],[540,208]],[[810,204],[893,211]],[[1190,190],[1223,188]],[[23,387],None],[[374,381],[575,330]],[[755,319],[902,402]],[[1081,321],[1227,459]],[[144,632],[247,680]],[[631,764],[634,815]],[[941,754],[951,835]],[[984,775],[1217,875]],[None,[214,1154]],[[375,1110],[551,1145]],[[671,1085],None],[[985,1094],[1019,1136]]]
sweep_b_root=[[179,175],[489,175],[785,184],[1103,184],[175,487],[468,492],[776,492],[1093,487],[184,801],[495,794],[800,801],[1112,808],[182,1097],[509,1094],[803,1094],[1115,1093]]
sweep_b_tips=[[[36,157],[253,248]],[[598,235],[570,251]],[[785,21],[909,142]],[[1086,26],[1228,166]],[[314,458],[309,522]],[[620,493],[617,546]],[[650,438],[955,447]],[[956,412],[1240,440]],[[23,771],[304,798]],[[615,818],[606,869]],[[930,832],[941,859]],[[960,835],[1007,880]],[[49,1100],[80,1123]],[[367,1098],[395,1124]],[[654,1094],[688,1125]],[[968,1104],[998,1126]]]

def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def local(point,origin):return None if point is None else [round(point[0]-origin[0],3),round(point[1]-origin[1],3)]
def record(motion,path,root_points=None,hand_points=None,tip_points=None,global_start=0,columns=4,rows=4):
 im=Image.open(path);cw=im.width/columns;ch=im.height/rows;frames=[]
 for i in range(columns*rows):
  origin=[i%columns*cw,i//columns*ch];f={'frame_index':global_start+i,'source_frame_index':i,'source_cell_origin':origin}
  if root_points is not None:f['scarf_root']=local(root_points[i],origin)
  if hand_points is not None:f['scarf_hand']=local(hand_points[i],origin)
  if tip_points is not None:f['scarf_tips']=[local(p,origin) for p in tip_points[i]]
  if hand_points is not None and hand_points[i] is None:f['unresolved']='The scarf is released in recovery; no visible cloth-gripping hand at this pose. Do not invent a cloth junction.'
  if tip_points is not None and any(p is None for p in tip_points[i]):f['unresolved']='One scarf tail hem is occluded behind the arm/body; a second distinct endpoint cannot be visually fixed from this drawing.'
  frames.append(f)
 d={'character_id':'ja-hyun','motion':motion,'status':'manual source points; pending independent attachment and motion QA','coordinate_space':'source cell-local pixels, cell top-left=(0,0), not atlas-normalized; points may be outside a nominal cell where a complete pose crosses a grid boundary','source_path':str(path.relative_to(ROOT)),'source_sha256':sha(path),'source_grid':[columns,rows],'source_cell_size':[cw,ch],'method':'manual visual choice on current newly generated cloth/hand; no reuse of old frame anchors; hidden anatomical neck junction indicated where the collar occludes cloth','frames':frames}
 out=BASE/(path.stem+'.anchors.json');out.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
 # Source image with exact chosen points for later independent visual inspection.
 overlay=im.copy();draw=ImageDraw.Draw(overlay)
 for f in frames:
  origin=f['source_cell_origin']
  for key,color in [('scarf_root',(255,80,80,255)),('scarf_hand',(50,255,80,255))]:
   point=f.get(key)
   if point is not None:
    x,y=point[0]+origin[0],point[1]+origin[1];draw.ellipse((x-5,y-5,x+5,y+5),outline=color,width=2)
  for point in f.get('scarf_tips',[]):
   if point is not None:
    x,y=point[0]+origin[0],point[1]+origin[1];draw.ellipse((x-5,y-5,x+5,y+5),outline=(255,230,40,255),width=2)
 overlay.save(BASE/(path.stem+'.anchors-preview.png'))
 print(out.name,'unresolved',sum('unresolved' in f for f in frames))
 return d
record('attack_air_light',BASE/'attack_air_light-r01.png',root_points=air_light_root)
record('attack_air_heavy',BASE/'attack_air_heavy-r01.png',hand_points=air_heavy_hand)
layout=json.loads((BASE/'special_neutral-r02-combined.json').read_text());heavy_points=[]
for item in layout['source_frame_mapping']:
 frame=item['frame'];point=heavy_quarter_root[frame-4] if 4<=frame<=7 else heavy_original_root[frame]
 box=item['source_box'];factor=item['whole_figure_uniform_scale'];dest=item['destination_top_left']
 heavy_points.append([dest[0]+(point[0]-box[0])*factor,dest[1]+(point[1]-box[1])*factor])
record('special_neutral',BASE/'special_neutral-r02-combined.png',root_points=heavy_points)
a=record('special_scarf_sweep',BASE/'special_scarf_sweep-part-a-r01.png',root_points=sweep_a_root,tip_points=sweep_a_tips)
b=record('special_scarf_sweep',BASE/'special_scarf_sweep-part-b-r01.png',root_points=sweep_b_root,tip_points=sweep_b_tips,global_start=16)
(BASE/'scarf-anchors-index.json').write_text(json.dumps({'character_id':'ja-hyun','status':'pending independent QA; unresolved source keys must not be silently replaced','files':['attack_air_light-r01.anchors.json','attack_air_heavy-r01.anchors.json','special_neutral-r02-combined.anchors.json','special_scarf_sweep-part-a-r01.anchors.json','special_scarf_sweep-part-b-r01.anchors.json'],'unresolved':[{'motion':'attack_air_heavy','frames':[14,15],'key':'scarf_hand','reason':'cloth released during recovery; no visible grip'},{'motion':'special_scarf_sweep','frames':[4,12,14],'key':'one scarf_tips point','reason':'second hem occluded'}]},ensure_ascii=False,indent=2)+'\n')
