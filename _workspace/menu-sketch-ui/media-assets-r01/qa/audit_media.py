#!/usr/bin/env python3
"""Independent MENU09 media file audit; does not modify production files."""
from pathlib import Path
import hashlib,json,re,subprocess
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[4]
P=ROOT/'_workspace/menu-sketch-ui/media-assets-r01'
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
base=json.loads((P/'qa/source-baseline.json').read_text())
source_errors=[path for path,digest in base['sha256'].items() if not (ROOT/path).exists() or sha(ROOT/path)!=digest]
expected=json.loads((P/'qa/expected-slots.json').read_text())
images=json.loads((P/'images/manifest.json').read_text())
vm=json.loads((P/'video/manifest.json').read_text())
slots=[r['slot'] for r in images]+[r['slot'] for r in vm['videos']]
assert len(slots)==29 and len(set(slots))==29
assert set(slots)=={r['slot'] for r in expected['slots']}
results=[]
for r in vm['videos']:
 f=ROOT/r['file'];assert f.is_file() and sha(f)==r['sha256']
 probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_streams','-show_format','-of','json',str(f)]))
 vs=[x for x in probe['streams'] if x['codec_type']=='video'];assert len(vs)==1
 stream=vs[0];assert (stream['width'],stream['height'])==(1280,720) and stream['codec_name']=='h264'
 assert stream['pix_fmt']=='yuv420p' and stream['r_frame_rate']=='60/1'
 assert not [x for x in probe['streams'] if x['codec_type']=='audio']
 subprocess.run(['ffmpeg','-v','error','-i',str(f),'-f','null','-'],check=True,capture_output=True)
 sources=[]
 for s in r.get('source',[]):
  t=ROOT/s['sprite_frames'];assert sha(t)==s['sprite_frames_sha256'];text=t.read_text()
  fps=float(re.search(r'"speed": ([0-9.]+)',text)[1]);assert fps==s['source_fps']
  frames=re.findall(r'\{"duration": ([0-9.]+), "texture": SubResource\("([^\"]+)"\)\}',text)
  assert len(frames)==len(s['frames'])
  assert [a[1] for a in frames]==[a['sub_resource'] for a in s['frames']]
  assert [float(a[0]) for a in frames]==[a['duration_weight'] for a in s['frames']]
  for sheet in s['sheets']: assert sha(ROOT/sheet['path'])==sheet['sha256']
  sources.append({'motion':s['motion_id'],'frames':len(frames),'fps':fps,'sha_match':True})
 poster=ROOT/r['poster'];assert sha(poster)==r['poster_sha256']
 assert Image.open(poster).size==(1280,720)
 results.append({'slot':r['slot'],'sha256':sha(f),'width':stream['width'],'height':stream['height'],'codec':stream['codec_name'],'duration':float(probe['format']['duration']),'frames':int(stream['nb_frames']),'source':sources,'decode':'pass'})
 # Independent contact sheet decoded from final MP4, not producer renderer.
 duration=float(probe['format']['duration']);out=Image.new('RGB',(1280,2*210),'#10241c');draw=ImageDraw.Draw(out)
 for i in range(8):
  sec=min(duration-1/60,i*(duration-1/60)/7)
  png=P/'qa'/(f.stem+f'-decoded-{i}.png')
  subprocess.run(['ffmpeg','-v','error','-y','-ss',str(sec),'-i',str(f),'-frames:v','1','-vf','scale=320:180',str(png)],check=True,capture_output=True)
  im=Image.open(png);x,y=i%4*320,i//4*210;out.paste(im,(x,y));draw.text((x+8,y+182),f'{sec:.3f}s',fill='#d8e4cb');png.unlink()
 out.save(P/'qa'/(f.stem+'-decoded-timeline.png'))
result={'status':'pass' if not source_errors else 'fix','source_baseline_count':base['count'],'source_errors':source_errors,'expected_slots':29,'image_slots':len(images),'videos':results}
(P/'qa/automated-audit.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print(json.dumps({'status':result['status'],'unchanged_sources':base['count']-len(source_errors),'image_slots':len(images),'videos':len(results)},ensure_ascii=False))
