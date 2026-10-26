from pathlib import Path
import hashlib,json
from PIL import Image,ImageDraw
ROOT=Path(__file__).resolve().parent
SETS={
'barrage-a-r02':[
((175,172),(181,205),(196,266)),((486,176),(478,211),(494,275)),((789,171),(745,183),(749,280)),((1113,180),(1070,189),(963,178)),
((220,477),(158,423),(59,411)),((517,486),(494,523),(364,491)),((809,487),(842,510),(996,513)),((1128,481),(1117,555),(1231,502)),
((167,776),(248,737),(202,670)),((501,788),(464,816),(359,761)),((805,782),(837,805),(997,786)),((1112,793),(1093,853),(1222,811)),
((216,1072),(154,1014),(63,986)),((511,1080),(551,1099),(388,1067)),((798,1080),(850,1036),(909,953)),((1111,1085),(1119,1128),(1032,1080))],
'barrage-b-r01':[
((183,181),(210,226),(31,252)),((520,185),(517,138),(388,90)),((817,190),(852,147),(906,61)),((1111,190),(1071,254),(1227,247)),
((183,490),(221,522),(402,523)),((507,498),(528,539),(406,561)),((814,497),(766,445),(665,385)),((1125,509),(1082,576),(1229,501)),
((187,813),(196,739),(151,672)),((504,809),(496,838),(316,777)),((810,811),(855,838),(1004,793)),((1125,815),(1111,847),(1222,897)),
((181,1083),(188,1114),(215,1194)),((498,1087),(490,1143),(515,1209)),((808,1087),None,(802,1184)),((1113,1091),None,(1108,1185))]}
for stem,rows in SETS.items():
 p=ROOT/(stem+'.png'); im=Image.open(p).convert('RGBA'); out=Image.new('RGBA',im.size,(42,42,42,255));out.alpha_composite(im);draw=ImageDraw.Draw(out);cw=im.width/4;ch=im.height/4;frames=[]
 for i,(root,hand,tip) in enumerate(rows):
  root=(root[0],root[1]+25)
  if stem=='barrage-a-r02' and i==9: hand=(477,793)
  if stem=='barrage-a-r02' and i==15: hand=(1114,1107)
  if im.getpixel(tip)[3]<128:
   tx,ty=tip; options=[]
   for yy in range(max(0,ty-20),min(im.height,ty+21)):
    for xx in range(max(0,tx-20),min(im.width,tx+21)):
     rr,gg,bb,aa=im.getpixel((xx,yy))
     if aa>=180 and bb>80 and bb>rr*1.15 and bb>gg*1.05:
      options.append(((xx-tx)**2+(yy-ty)**2,(xx,yy)))
   if options: tip=min(options)[1]
  ox=(i%4)*cw;oy=(i//4)*ch
  local=lambda pt: None if pt is None else [round(pt[0]-ox,2),round(pt[1]-oy,2)]
  frames.append({'frame_index':i,'global_frame_index':i+(16 if stem.endswith('b-r01') else 0),'source_frame_index':i,'source_cell_origin':[ox,oy],'scarf_root':local(root),'scarf_hand':local(hand),'scarf_tips':[local(tip),None],'root_visibility':'collar junction partly occluded; anatomically inferred','secondary_tip_visibility':'not reliably distinguishable; intentionally null'})
  for label,pt,color in [('R',root,'lime'),('H',hand,'yellow'),('T',tip,'cyan')]:
   if pt:
    x,y=pt;draw.ellipse((x-4,y-4,x+4,y+4),outline=color,width=2);draw.text((x+5,y-6),label,fill=color)
  draw.text((ox+8,oy+8),str(i+1+(16 if stem.endswith('b-r01') else 0)),fill='white')
 record={'character_id':'ja-hyun','motion':'special_scarf_sweep','status':'manual source observations; pending independent QA; not approved','coordinate_space':'source cell-local pixels; may cross nominal cell boundary; apply source_cell_origin before connected-figure packing','source_path':str(p.relative_to(ROOT.parent.parent.parent)),'source_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'source_grid':[4,4],'source_cell_size':[cw,ch],'method':'manual visual selection on generated source; low-alpha tips refined to nearest opaque blue fabric within20px; no old-motion anchor reuse; hidden neck junction inferred under collar; second tail intentionally null rather than invented','frames':frames}
 (ROOT/(stem+'.anchors.json')).write_text(json.dumps(record,ensure_ascii=False,indent=2)+'\n');out.convert('RGB').save(ROOT/(stem+'.anchors-preview.png'))
