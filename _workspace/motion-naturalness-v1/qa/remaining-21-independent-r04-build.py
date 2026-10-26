"""Read-only QA: bind current clips, decode exact frames and arrange observed poses."""
import hashlib,json,subprocess
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[3]
base=root/'_workspace/motion-naturalness-v1/qa'
output=base/'remaining-21-independent-r04';output.mkdir(exist_ok=True)
excluded={('ja-hyun','special_scarf_sweep'),*{('nabi',m) for m in ['attack_air_heavy','attack_air_light','attack_heavy_up','special_side']}}
review=json.loads((base/'remaining-candidate-review-r10-current/motion-review.json').read_text())
targets={(r['character_id'],r['motion']):r for r in review['motions'] if (r['character_id'],r['motion']) not in excluded}
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for b in iter(lambda:f.read(8*1024*1024),b''):h.update(b)
 return h.hexdigest()
coverage={};integrity=[];clips=[]
for folder in ['state-normal','state-mirror-small','ja-attacks-normal','ja-attacks-mirror-small']:
 capture=base/'remaining-live-r11'/folder
 report=json.loads((capture/'state-report.json').read_text())
 assert not report['errors']
 log=capture.with_suffix('.log').read_text();assert 'ERROR:' not in log and 'FAIL' not in log
 receipt=json.loads((capture/'raw-archive.json').read_text())
 assert receipt['capture_report_sha256']==sha(capture/'state-report.json')
 mismatches=[p for p,h in report['sources'].items() if sha(root/p)!=h];assert not mismatches,mismatches
 orientation='mirror-small' if 'mirror' in folder else 'normal'
 for clip in report['scenarios']:
  movie=capture/(clip['name']+'-lossless-rgb.mkv')
  record=next(r for r in receipt['clips'] if r['clip']==clip['name'])
  assert sha(movie)==record['archive_sha256']
  # Stream complete RGBA to hash, retain only small review crops in memory.
  size=1280*720*4; hashes=[];raw_hash=hashlib.sha256(); crops={}
  process=subprocess.Popen(['ffmpeg','-v','error','-i',str(movie),'-pix_fmt','rgba','-f','rawvideo','-'],stdout=subprocess.PIPE)
  for index in range(clip['frame_count']):
   data=process.stdout.read(size);assert len(data)==size
   hashes.append(hashlib.md5(data).hexdigest());raw_hash.update(data)
   im=Image.frombytes('RGBA',(1280,720),data)
   crops[index]=(im.crop((400,140,880,420)).convert('RGB').resize((272,188)),im.crop((320,110,960,430)).convert('RGB').resize((320,186)))
  assert process.stdout.read()==b'' and process.wait()==0
  assert hashes==record['rgba_md5'] and raw_hash.hexdigest()==record['source_raw_sha256']
  integrity.append({'folder':folder,'clip':clip['name'],'frames':len(hashes),'all_rgba_equal':True,'movie_sha256':sha(movie),'sources_match_current':True})
  selected={}
  for index,state in enumerate(clip['states']):
   drawn=state['drawn'][0];key=(clip['character_id'],drawn['shown_motion'])
   if key not in targets:continue
   coverage.setdefault((orientation,*key),set()).add(drawn['frame'])
   selected.setdefault((key,drawn['frame']),index)
  # Full pose coverage, not a claim that every repeated idle tick was viewed.
  for key in sorted({k[0] for k in selected}):
   rows=sorted((f,i) for (k,f),i in selected.items() if k==key)
   board=Image.new('RGB',(4*272,((len(rows)+3)//4)*214),(23,35,40));draw=ImageDraw.Draw(board)
   for n,(frame,index) in enumerate(rows):
    crop=crops[index][0]
    x=(n%4)*272;y=(n//4)*214;board.paste(crop,(x,y));draw.text((x+3,y+190),f'{key[0]}/{key[1]} pose{frame+1} tick{index}',fill='white')
   name=f'{orientation}__{clip["name"]}__{key[1]}.jpg';board.save(output/name,quality=91)
  # Preserve readable transition neighbourhoods in a compact scene board.
  changes=[0,*[i for i in range(1,len(clip['states'])) if clip['states'][i]['drawn'][0]['shown_motion']!=clip['states'][i-1]['drawn'][0]['shown_motion']],len(clip['states'])-1]
  indices=sorted({max(0,min(clip['frame_count']-1,i+d)) for i in changes for d in [-1,0,1]})
  board=Image.new('RGB',(4*320,((len(indices)+3)//4)*211),(23,35,40));draw=ImageDraw.Draw(board)
  for n,index in enumerate(indices):
   crop=crops[index][1]
   x=n%4*320;y=n//4*211;board.paste(crop,(x,y));d=clip['states'][index]['drawn'][0];draw.text((x+3,y+188),f't{index} {d["shown_motion"]} f{d["frame"]+1}',fill='white')
  board.save(output/f'{orientation}__{clip["name"]}__transitions.jpg',quality=91)
  clips.append({'folder':folder,'name':clip['name'],'movie':str(movie.relative_to(root)),'preview':str((capture/(clip['name']+'.mp4')).relative_to(root))})
coverage_json=[{'orientation':o,'character_id':c,'motion':m,'observed_frames_zero_based':sorted(v)} for (o,c,m),v in sorted(coverage.items())]
(output/'independent-integrity.json').write_text(json.dumps({'clips':integrity,'total_frames':sum(r['frames'] for r in integrity),'coverage':coverage_json,'viewing_scope':'Boards show every distinct player pose encountered per scene plus transition neighbourhoods. This does not claim all repeated game ticks were visually inspected.','clips_for_playback':clips},ensure_ascii=False,indent=2)+'\n')
print('PASS',len(integrity),'clips',sum(r['frames'] for r in integrity),'RGBA frames',len(coverage_json),'orientation/motion coverage rows')
