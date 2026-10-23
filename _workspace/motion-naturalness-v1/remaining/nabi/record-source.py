from pathlib import Path
import sys,shutil,hashlib,json
from PIL import Image
base=Path(__file__).resolve().parent
motion,src=sys.argv[1:3];version=sys.argv[3] if len(sys.argv)>3 else 'r01'
dst=base/f'{motion}-{version}.png';shutil.copy2(src,dst)
im=Image.open(dst).convert('RGBA');a=im.getchannel('A');w,h=im.size
edge={side:sum(1 for x in crop.getdata() if x>=32) for side,crop in {'top':a.crop((0,0,w,1)),'bottom':a.crop((0,h-1,w,h)),'left':a.crop((0,0,1,h)),'right':a.crop((w-1,0,w,h))}.items()}
meta=dict(motion=motion,version=version,builtin_generated_source=src,path=str(dst),sha256=hashlib.sha256(dst.read_bytes()).hexdigest(),size=[w,h],mode=im.mode,alpha_range=list(a.getextrema()),source_grid=[4,8 if motion=='special_side' else 4],frame_count=32 if motion=='special_side' else 16,prompt_path=str(base/f'{motion}-{version}-prompt.txt'),rights='Original Forest Arena character, generated with built-in OpenAI imagegen. No external stock.',user_approval='pending',independent_qa='pending',opaque_outer_edge_pixels=edge,references=['approved-idle-reference.png','assets/character/nabi/concept/nabi-concept-v01.png'])
(base/f'{motion}-{version}-source.json').write_text(json.dumps(meta,ensure_ascii=False,indent=2)+'\n')
print(motion,im.size,'opaque outer edge',edge)
