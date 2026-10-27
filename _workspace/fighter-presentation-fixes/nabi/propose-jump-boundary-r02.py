"""Whole-figure boundary reuse proposal; preserves frozen r01 and approved runtime."""
from pathlib import Path
import json,copy,hashlib
from PIL import Image
BASE=Path(__file__).resolve().parent;ROOT=BASE.parents[2];h=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
row=json.loads((BASE/'candidates/jump_body-fit-r01.json').read_text());source=ROOT/row['path'];old=Image.open(source).convert('RGBA');sheet=old.copy();count=24
manifest=json.loads((ROOT/'assets/character/manifest.json').read_text());idle=next(e for e in manifest['assets'] if e.get('character_id')=='nabi' and e.get('visual_state_id')=='idle');idle_scale=idle['presentation_scale']*.92
newscale=row['presentation_scale']*.365/.34
# Move one existing final guard pose to the penultimate slot (not duplicated).
def box(index):return (index%16*128,index//16*128,index%16*128+128,index//16*128+128)
old_final=old.crop(box(23));sheet.paste(old_final,(22%16*128,22//16*128))
# Shared approved idle endpoint: uniformly resize the whole visible figure only.
idle_image=Image.open(ROOT/idle['path']).convert('RGBA').crop((0,0,128,128));bounds=idle_image.getchannel('A').point(lambda a:255 if a>=32 else 0).getbbox();assert bounds
figure=idle_image.crop(bounds);factor=idle_scale/newscale;resized=figure.resize((round(figure.width*factor),round(figure.height*factor)),Image.Resampling.LANCZOS)
x=round(64+(bounds[0]-64)*factor);y=round(row['foot_pivot_y']+(bounds[1]-idle['foot_pivot_y'])*factor)
endpoint=Image.new('RGBA',(128,128));endpoint.alpha_composite(resized,(x,y));sheet.paste(endpoint,(23%16*128,23//16*128))
for i in range(22):assert sheet.crop(box(i)).tobytes()==old.crop(box(i)).tobytes()
assert sheet.crop(box(22)).tobytes()==old_final.tobytes()
assert len({hashlib.sha256(sheet.crop(box(i)).tobytes()).hexdigest() for i in range(24)})==24
png=BASE/'candidates/jump_24f_body-boundary-r02.png';sheet.save(png);tres=BASE/'candidates/jump_body-boundary-r02.tres';text=(ROOT/row['sprite_frames_path'].removeprefix('res://')).read_text();old_path='res://'+row['path'];new_path='res://'+str(png.relative_to(ROOT));assert text.count(old_path)==1;tres.write_text(text.replace(old_path,new_path))
row['path']=str(png.relative_to(ROOT));row['sprite_frames_path']='res://'+str(tres.relative_to(ROOT));row['sha256']=h(png);row['presentation_scale']=newscale;row['conversion']['presentation_scale']=newscale
row['layout_revision']['boundary_revision']={'r01_source_atlas':str(source.relative_to(ROOT)),'r01_source_atlas_sha256':h(source),'uniform_full_motion_world_scale_before':.34,'uniform_full_motion_world_scale_after':.365,'frame_mapping':list(range(22))+[23,'approved-Nabi-idle0 endpoint'],'shared_endpoint_source_png':idle['path'],'shared_endpoint_source_png_sha256':idle['sha256'],'endpoint_whole_figure_fit':factor,'endpoint_target_world_scale':idle_scale,'no_body_part_warp':True,'first22_atlas_cells_byte_preserved':True,'intermediate_frame_duplication':False,'note':'unapproved boundary proposal; native playback and independent QA required'}
# Provenance describes the two actual compositing inputs without posing as a new generation.
row['source_paths']=[str(source.relative_to(ROOT)),idle['path']];row['source_path']=str(source.relative_to(ROOT));row['source_sha256']=h(source);row['source_sheet_sha256']=[h(source),h(ROOT/idle['path'])];row['creation']['version']='nabi-jump-body-boundary-r02';row['creation']['method']='built-in image_gen whole-figure source poses; existing final guard moved once plus approved idle whole-figure boundary reuse, no duplicated fillers or body-part warp';row['creation']['source_inputs']=[{'path':str(source.relative_to(ROOT)),'sha256':h(source)},{'path':idle['path'],'sha256':h(ROOT/idle['path'])}]
p=BASE/'candidates/jump_body-boundary-r02.json';p.write_text(json.dumps(row,ensure_ascii=False,indent=2)+'\n');(BASE/'jump-boundary-proposal-r02.json').write_text(json.dumps(row['layout_revision']['boundary_revision'],indent=2)+'\n')
print('r02 jump boundary proposal',row['presentation_scale'],'endpoint fit',factor,'PNG',h(png))
