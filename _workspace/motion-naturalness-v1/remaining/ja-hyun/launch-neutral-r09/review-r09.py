from PIL import Image,ImageDraw,ImageOps
from pathlib import Path
import json,hashlib
D=Path(__file__).parent;R=D.parents[4]
j=json.loads((D/'launch_neutral-r09.json').read_text());atlas=Image.open(D/'launch_16f_neutral-r09.png').convert('RGBA');cells=[atlas.crop((128*i,0,128*(i+1),128)) for i in range(16)]
jump=Image.open(R/'assets/character/ja-hyun/animation/runtime/jump_24f_natural-v02.png').convert('RGBA').crop((1280,0,1408,128))
def render(tile,root,scale,mirror=False,size=(240,220)):
 out=Image.new('RGBA',size,(0,0,0,0));z=tile.resize((round(128*scale),round(128*scale)),Image.Resampling.NEAREST)
 if mirror:z=ImageOps.mirror(z)
 out.alpha_composite(z,(round(size[0]/2-64*scale),round(165-root*scale)));return out
checks={}
for mirror in (False,True):checks['mirror' if mirror else 'normal']=render(cells[15],117,.85,mirror).tobytes()==render(jump,117,.85,mirror).tobytes()
assert all(checks.values())
proof=json.loads((D/'packing-proof-r09.json').read_text());proof['boundary_pixel_comparison_actual']=checks
(D/'packing-proof-r09.json').write_text(json.dumps(proof,ensure_ascii=False,indent=2)+'\n')
# Markers document manual coordinate choices, never feed runtime.
markers=Image.new('RGB',(384*3,440),(70,70,70));d=ImageDraw.Draw(markers)
for n,m in enumerate(proof['new_pose_placements']):
 tile=cells[12+n].resize((384,384),Image.Resampling.NEAREST);markers.paste(tile,(n*384,32),tile)
 for key,color in [('ear_cell','red'),('chin_cell','yellow')]:
  x,y=m[key];x=x*3+n*384;y=y*3+32;d.ellipse((x-5,y-5,x+5,y+5),outline=color,width=2)
 d.text((n*384+8,8),f"F{13+n}: {m['ear_to_chin_world_px']:.2f}world, +/-3cell",fill='white')
markers.save(D/'new-head-markers-r09.png')
# Prototype playback only: no combat fixture, no claim of rendered runtime.
frames=[]
indices=[min(15,int(t/21*16)) for t in range(21)]+[16]*8
for idx in indices:
 tile=jump if idx==16 else cells[idx];root=117 if idx>=15 else 104
 page=Image.new('RGBA',(240,220),(35,38,45,255));page.alpha_composite(render(tile,root,.85));dd=ImageDraw.Draw(page);dd.text((4,4),'POSE PROTOTYPE: '+('jump F11' if idx==16 else 'launch F'+str(idx+1)),fill='white');frames.append(page.convert('RGB').resize((480,440),Image.Resampling.NEAREST))
for filename,duration in [('prototype-normal-r09.gif',17),('prototype-slow-r09.gif',83)]:frames[0].save(D/filename,save_all=True,append_images=frames[1:],duration=duration,loop=0,disposal=2)
# Mirrored origin comparison; same geometry and shared boundary, no extra fit operation.
seq_ja=[(cells[11],104,'F12 old'),(cells[12],104,'F13 new'),(cells[13],104,'F14 new'),(cells[14],104,'F15 new'),(cells[15],117,'F16 shared'),(jump,117,'jump F11')]
b=Image.new('RGB',(1440,660))
for row,bg in enumerate([(245,245,245),(28,30,37),(138,138,138)]):
 for n,(tile,root,label) in enumerate(seq_ja):
  p=Image.new('RGBA',(240,220),bg+(255,));pd=ImageDraw.Draw(p);pd.line((0,165,240,165),fill=(120,150,120,255));pd.line((120,20,120,205),fill=(120,150,120,255));p.alpha_composite(render(tile,root,.85,True));pd.text((8,8),label+' mirror root '+str(root),fill='white' if row==1 else 'black');b.paste(p.convert('RGB'),(n*240,row*220))
b.save(D/'same-origin-mirror-r09.png')
# Nabi evidence uses existing r07 launch and unchanged approved jump.
na=json.loads((R/'_workspace/motion-naturalness-v1/candidates/remaining/nabi/launch_r07-head.json').read_text());a=Image.open(R/na['path']).convert('RGBA');njpath='assets/character/nabi/animation/runtime/jump_24f_natural-v02.png';nj=Image.open(R/njpath).convert('RGBA')
seq=[('launch F5',a.crop((512,0,640,128)),na['presentation_scale'],104),('launch F16',a.crop((1920,0,2048,128)),na['presentation_scale'],104)]+[(f'jump F{i+1}',nj.crop(((i%16)*128,(i//16)*128,(i%16+1)*128,(i//16+1)*128)),1.0,109) for i in [10,11,15]]
board=Image.new('RGB',(240*len(seq),440),(100,100,100))
for row,mirror in enumerate((False,True)):
 for col,(label,tile,scale,root) in enumerate(seq):
  page=Image.new('RGBA',(240,220),(70,70,70,255));pd=ImageDraw.Draw(page);pd.line((120,10,120,219),fill=(120,150,120,255));pd.line((0,165,239,165),fill=(120,150,120,255));page.alpha_composite(render(tile,root,scale,mirror));pd.text((6,6),label+(' mirror' if mirror else ''),fill='white');pd.text((6,23),f'scale {scale:.3f} root {root}',fill='white');board.paste(page.convert('RGB'),(col*240,row*220))
board.save(D/'nabi-launch-jump-same-origin-r09.png')
(D/'nabi-comparison-source-r09.json').write_text(json.dumps({'launch':{'path':na['path'],'sha256':na['sha256'],'presentation_scale':na['presentation_scale'],'root':104},'jump':{'path':njpath,'sha256':hashlib.sha256((R/njpath).read_bytes()).hexdigest(),'presentation_scale':1.0,'root':109},'note':'static pose diagnostic, not gameplay capture; all source poses unchanged'},ensure_ascii=False,indent=2)+'\n')
print('PASS: old12 RGBA, shared boundary normal/mirror pixel equality, diagnostic boards and prototype exports')
