"""Select whole newly drawn figures; preserve original22 extracted figures exactly."""
from PIL import Image
from pathlib import Path
import json,hashlib
BASE=Path(__file__).resolve().parent
orig=Image.open(BASE/'jump-r01-source.png').convert('RGBA');repair=Image.open(BASE/'jump-repair-r02-source.png').convert('RGBA')
rects=[]
for y0,y1,count in [(0,288,6),(288,552,6),(552,798,4)]:
 rects += [[i*256,y0,(i+1)*256,y1] for i in range(count)]
last_edges=[0,230,450,680,920,1115,1305,1536]
landings=[[last_edges[i],798,last_edges[i+1],1024] for i in [0,1,2,3,4,6]]
# Two repaired first-contact/absorption drawings; no regenerated old poses used.
sequence=[('jump-r01-source.png',orig,r) for r in rects]+[('jump-repair-r02-source.png',repair,[1024,552,1270,798]),('jump-repair-r02-source.png',repair,[1270,552,1536,798])]+[('jump-r01-source.png',orig,r) for r in landings]
assert len(sequence)==24
# Body origins are manually inspected hips +62source px virtual leg support for
# airborne poses; grounded frames use the lowest solid shoe on the actual floor.
roots=[(142,297),(400,288),(650,267),(895,250),(1150,246),(1402,236),(145,509),(405,514),(652,514),(900,526),(1152,533),(1400,547),(135,762),(389,759),(646,782),(900,790),None,None,None,None,None,None,None,None]
sheet=Image.new('RGBA',(2400,1600));records=[]
for i,(name,im,rect) in enumerate(sequence):
 cut=im.crop(rect);visible=cut.getchannel('A').point(lambda a:255 if a>=32 else 0).getbbox();assert visible
 box=(rect[0]+visible[0],rect[1]+visible[1],rect[0]+visible[2],rect[1]+visible[3]);figure=im.crop(box)
 root=roots[i]
 if root is None:root=((box[0]+box[2])/2,box[3])
 x=round(200+box[0]-root[0]);y=round(350+box[1]-root[1]);assert 0<=x and x+figure.width<400 and 0<=y and y+figure.height<400,(i,box,root,x,y)
 sheet.paste(figure,(i%6*400+x,i//6*400+y))
 # Whole pixel rectangles remain byte-identical at this composition step.
 restored=sheet.crop((i%6*400+x,i//6*400+y,i%6*400+x+figure.width,i//6*400+y+figure.height))
 assert restored.tobytes()==figure.tobytes()
 records.append({'frame':i,'source':name,'source_rect':rect,'figure_bbox':box,'source_figure_sha256':hashlib.sha256(figure.tobytes()).hexdigest(),'source_origin':root,'placed_xy':[x,y],'preserved_original_figure':name=='jump-r01-source.png'})
p=BASE/'jump-r02-combined-source.png';sheet.save(p)
(BASE/'jump-r02-composition.json').write_text(json.dumps({'kind':'whole-figure-source-layout','source_paths':['jump-r01-source.png','jump-repair-r02-source.png'],'output':p.name,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'frames':records,'original_figures_preserved':22,'new_repair_figures':2,'body_part_warp':False,'uniform_scale_at_composition':1.0,'source_count_correction':'r01 has23 visible figures, not initial22 impression; one redundant lower-row recovery drawing is unselected; r02 repair has25 figures, select24, not assume declared grid count','origins_precision':'manual visual body-origin placement approx +/-3 source px; not anatomical ground truth'},indent=2)+'\n')
print('24 complete figures:22 exact original crop rectangles +2 repaired landing poses; no rescale/warp')
