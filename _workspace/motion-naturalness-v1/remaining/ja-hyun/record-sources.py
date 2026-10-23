from pathlib import Path
from PIL import Image
import hashlib,json,importlib.util
ROOT=Path(__file__).resolve().parents[4];BASE=Path(__file__).resolve().parent;TOPIC=ROOT/'_workspace/motion-naturalness-v1'
files={'idle-r01':'6a09b959-ff04-41d6-acd4-31731873887d','idle-r02':'dc40fda9-342e-47f8-ab7f-e610544ef306','guard-r01':'4e2ab991-5011-4c36-aeae-8f49645e72d9','hitstun-r01':'6e1d8811-a073-4c43-a398-297c11d55aac','launch-r01':'eb44999d-a777-4ffe-87ba-1813e4871694','knock_down-r01':'2166ce5e-3f20-4f8e-a5a5-70bdb2e32a03','wake_up-r01':'a02b97b3-ee6f-4541-915a-03a6594eaa1c','death-r01':'1aff0bb1-71b5-41d1-ba91-e19402534c8e','ring_out-r01':'b4ef8855-0b00-45c7-8f63-6c459f1f1ad7','spawn-r01':'ecfb2af9-3f77-47d0-9c20-1644e60d05a1','attack_air_light-r01':'af45fcfc-2ea4-4fb0-929e-ddf7f6eab8b0','attack_air_heavy-r01':'4d8b2936-2938-49dd-8a8c-e87cde792204','special_neutral-r01':'70644525-6f56-4ac5-bcbf-1d6fb189ae6b','special_neutral-impact-quarter-r02':'0fe1fa5f-2dcc-4f44-9143-ed97a5f1ae5e','special_scarf_sweep-part-a-r01':'262d2130-c221-48f4-b067-fc59fba21a7d','special_scarf_sweep-part-b-r01':'380f55b1-4030-4222-821e-68d4ff60d78b'}
# Preserve exact saved built-in path; the idle-r02 UUID contains ab7b.
files['idle-r02']='dc40fda9-342e-47f8-ab7b-e610544ef306'
spec=importlib.util.spec_from_file_location('split_figures',TOPIC/'split-figures.py');mod=importlib.util.module_from_spec(spec);spec.loader.exec_module(mod)
for stem,uuid in files.items():
 p=BASE/(stem+'.png');im=Image.open(p);n=2 if 'quarter' in stem else 4
 alpha=im.getchannel('A');w,h=im.size;edges=[sum(v>=32 for v in alpha.crop(b).getdata()) for b in [(0,0,1,h),(0,0,w,1),(w-1,0,w,h),(0,h-1,w,h)]]
 try:poses,_=mod.split_figures(im,n,n);sep={'status':'pass','complete_figures':len(poses)}
 except ValueError as e:sep={'status':'fix','reason':str(e)}
 motion=stem.split('-r0')[0].split('-part-')[0].split('-impact-')[0]
 d={'character_id':'ja-hyun','motion':motion,'source_label':stem,'status':'pending independent QA and explicit user approval','frame_count':n*n,'source_grid':[n,n],'source_png':str(p.relative_to(ROOT)),'source_png_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'source_dimensions':list(im.size),'source_generator':'builtin image_gen','generated_at':'2026-10-23','original_generated_path':'/Users/jdh/.codex/generated_images/01a166af-68f7-7fa1-b294-2fd7afd419ab/exec-'+uuid+'.png','prompt_path':str((BASE/(stem+'.prompt.txt')).relative_to(ROOT)),'references':['_workspace/motion-naturalness-v1/drafts/ja-hyun/approved-idle-single-reference.png','_workspace/motion-naturalness-v1/drafts/ja-hyun/punch-r03-model-reference.png'],'rights_basis':'new builtin-generated artwork derived only from project-approved character references; not third-party stock; publication still pending user approval','changes':'newly drawn whole poses; no semantic Python editing; runtime untouched','source_checks':{'outer_edge_alpha32_pixels':edges,'whole_figure_separation':sep},'proposed_common_source_to_cell_scale':.285}
 if stem=='idle-r01':d['status']='rejected source edge clipping; replaced by idle-r02'
 if stem=='special_neutral-r01':d['status']='partial source only; connected F6/F7 replaced in special_neutral-r02-combined'
 if stem=='special_neutral-impact-quarter-r02':d['quarter_uniform_scale_before_common_pack']=.58
 if stem=='wake_up-r01':d['references'].append('_workspace/motion-naturalness-v1/remaining/ja-hyun/knock_down-r01.png')
 if stem in ['special_neutral-impact-quarter-r02','special_scarf_sweep-part-b-r01']:d['references'].append('_workspace/motion-naturalness-v1/remaining/ja-hyun/'+('special_neutral-r01.png' if 'quarter' in stem else 'special_scarf_sweep-part-a-r01.png'))
 (BASE/(stem+'.json')).write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n')
selected=[]
for name in ['idle','guard','hitstun','launch','knock_down','wake_up','death','ring_out','spawn','attack_air_light','attack_air_heavy','special_neutral','special_scarf_sweep']:
 if name=='special_scarf_sweep':source=['special_scarf_sweep-part-a-r01.png','special_scarf_sweep-part-b-r01.png'];count=32
 else:source=[name+('-r02.png' if name=='idle' else '-r02-combined.png' if name=='special_neutral' else '-r01.png')];count=16
 selected.append({'motion':name,'source_files':[str((BASE/f).relative_to(ROOT)) for f in source],'frame_count':count,'phase_frame_counts':{'special_neutral':[5,3,8],'attack_air_light':[4,3,9],'attack_air_heavy':[5,3,8],'special_scarf_sweep':[4,20,8]}.get(name),'status':'pending independent QA and explicit user approval'})
(BASE/'sources-index.json').write_text(json.dumps({'character_id':'ja-hyun','proposed_common_source_to_cell_scale':.285,'scale_policy':'preserve one head/face unit; whole-motion uniform scale; never normalize total standing/crouching/lying height','selected_motions':selected},ensure_ascii=False,indent=2)+'\n')
print('recorded',len(files),'sources;',len(selected),'motions')
