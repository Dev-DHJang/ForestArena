"""Candidate-only deterministic cell layout conversion. No painting or runtime registration."""
from pathlib import Path
import subprocess
import argparse
parser=argparse.ArgumentParser()
parser.add_argument('character',choices=['ja-hyun','nabi'])
parser.add_argument('motion')
parser.add_argument('source')
parser.add_argument('--version',default='r01')
args=parser.parse_args()
base=Path(__file__).resolve().parent/'candidates'/args.character
source=base/args.source
out=base/(args.motion+'_'+args.version+'_cells');out.mkdir(exist_ok=False)
subprocess.run(['magick',str(source),'-crop','4x4@','+repage','-resize','122x122','-gravity','center','-background','none','-extent','128x128',str(out/'cell-%02d.png')],check=True)
cells=sorted(out.glob('cell-*.png'));assert len(cells)==16
sheet=base/(args.motion+'_16f_'+args.version+'.png')
subprocess.run(['magick',*[str(c) for c in cells],'+append',str(sheet)],check=True)
for p in cells:p.unlink()
out.rmdir()
tex='res://'+sheet.relative_to(Path(__file__).resolve().parents[2]).as_posix()
lines=['[gd_resource type="SpriteFrames" load_steps=18 format=3]','',f'[ext_resource type="Texture2D" path="{tex}" id="1"]']
for i in range(16):lines +=['',f'[sub_resource type="AtlasTexture" id="Frame_{i}"]','atlas = ExtResource("1")',f'region = Rect2({i*128}, 0, 128, 128)']
lines +=['','[resource]','animations = [{','"frames": ['+', '.join('{"duration": 1.0, "texture": SubResource("Frame_%d")}'%i for i in range(16))+'],','"loop": false,',f'"name": &"{args.motion}",','"speed": 12.0','}]']
(base/(args.motion+'_'+args.version+'.tres')).write_text('\n'.join(lines)+'\n')
print(sheet)
