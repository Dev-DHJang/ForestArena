"""Diagnostic board only: original whole poses with common .285 scale."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,importlib.util
ROOT=Path(__file__).resolve().parents[4];BASE=Path(__file__).resolve().parent;TOPIC=ROOT/'_workspace/motion-naturalness-v1'
s=importlib.util.spec_from_file_location('split_figures',TOPIC/'split-figures.py');m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
entries=[('approved idle',Image.open(ROOT/'assets/character/ja-hyun/animation/runtime/idle_16f.png').crop((0,0,128,128)),1)]
for d in json.loads((BASE/'sources-index.json').read_text())['selected_motions']:
 p=ROOT/d['source_files'][0];im=Image.open(p);f,_=m.split_figures(im,4,4)
 index=14 if d['motion'] in ['knock_down','death'] else 0
 entries.append((d['motion'],f[index][0],.285))
board=Image.new('RGBA',(160*7,180*2),(33,39,49,255));draw=ImageDraw.Draw(board)
for i,(label,figure,scale) in enumerate(entries):
 x=i%7*160;y=i//7*180
 if scale==1:
  placed=figure
 else:
  placed=figure.resize((round(figure.width*scale),round(figure.height*scale)),Image.Resampling.LANCZOS)
  temp=Image.new('RGBA',(128,128));temp.alpha_composite(placed,((128-placed.width)//2,124-placed.height));placed=temp
 board.alpha_composite(placed,(x+16,y+10));draw.line((x+8,y+134,x+152,y+134),fill=(95,110,120,255));draw.text((x+4,y+147),label,fill='white')
board.convert('RGB').save(BASE/'common-scale-0285-diagnostic-r01.png')
print('diagnostic .285, whole poses only')
