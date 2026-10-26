import hashlib,json,subprocess
from pathlib import Path
from PIL import Image,ImageDraw
root=Path(__file__).resolve().parents[4]
base=root/"_workspace/nabi-claw-vfx-v2";out=base/"qa/independent-visual-r02";records=[]
for label in ["normal","mirror-small"]:
 folder=root/("_workspace/motion-naturalness-v1/qa/remaining-live-r11/nabi-attacks-"+label)
 reportpath=folder/"state-report.json";report=json.loads(reportpath.read_text());archive=json.loads((folder/"raw-archive.json").read_text())
 assert not report["errors"] and len(report["scenarios"])==4
 assert archive["capture_report_sha256"]==hashlib.sha256(reportpath.read_bytes()).hexdigest()
 assert "ERROR:" not in folder.with_suffix(".log").read_text()
 assert all(hashlib.sha256((root/f).read_bytes()).hexdigest()==h for f,h in report["sources"].items())
 for scene in report["scenarios"]:
  row=next(a for a in archive["clips"] if a["clip"]==scene["name"]);movie=folder/row["archive"]
  assert hashlib.sha256(movie.read_bytes()).hexdigest()==row["archive_sha256"]
  proc=subprocess.Popen(["ffmpeg","-v","error","-i",str(movie),"-pix_fmt","rgba","-f","rawvideo","-"],stdout=subprocess.PIPE)
  sha=hashlib.sha256();md5=[];size=1280*720*4;pages=[];selected=[]
  sheet=None
  for tick in range(120):
   data=proc.stdout.read(size);assert len(data)==size
   sha.update(data);md5.append(hashlib.md5(data).hexdigest());im=Image.frombytes("RGBA",(1280,720),data).convert("RGB")
   if tick%40==0:sheet=Image.new("RGB",(1480,2870),(16,28,30))
   crop=im.crop((470,170,840,435));slot=tick%40;x=(slot%4)*370;y=(slot//4)*287
   sheet.paste(crop,(x,y+22));draw=ImageDraw.Draw(sheet);s=scene["states"][tick];frame=s["drawn"][0]["frame"];state=s["match"]["fighters"][0]["state"]
   draw.text((x+5,y+4),f"{scene['name']} t{tick} f{frame} {state}",fill="white")
   if tick%40==39:
    p=out/f"{label}__{scene['name']}__all-{tick//40+1}.jpg";sheet.save(p,quality=92);pages.append(str(p.relative_to(root)))
   if state=="ATTACK_ACTIVE" or (state=="ATTACK_RECOVERY" and s["match"]["fighters"][0]["attack_phase_tick"]<4):
    selected.append((tick,frame,crop.copy()))
  assert not proc.stdout.read(1) and proc.wait()==0
  assert md5==row["rgba_md5"] and sha.hexdigest()==row["source_raw_sha256"]
  # Detailed active/recovery pixels supplement every-tick boards.
  unique=[];seen=set()
  for item in selected:
   if item[1] not in seen:seen.add(item[1]);unique.append(item)
  if unique:
   detail=Image.new("RGB",(1110,287*((len(unique)+2)//3)),(16,28,30));draw=ImageDraw.Draw(detail)
   for i,(tick,frame,crop) in enumerate(unique):
    x=(i%3)*370;y=(i//3)*287;detail.paste(crop,(x,y+22));draw.text((x+5,y+4),f"{scene['name']} t{tick} f{frame}",fill="white")
   detail.save(out/f"{label}__{scene['name']}__active-details.jpg",quality=95)
  poses=sorted({s["drawn"][0]["frame"] for s in scene["states"] if s["drawn"][0]["shown_motion"] in ["attack_heavy_up","attack_air_heavy","attack_air_light","special_side"]})
  records.append({"label":label,"clip":scene["name"],"all_120_rgba_md5_match":True,"raw_sha256_match":True,"archive_sha256":row["archive_sha256"],"preview_sha256":hashlib.sha256((folder/(scene["name"]+".mp4")).read_bytes()).hexdigest(),"render_log_no_errors":True,"pose_indices":poses,"boards":pages,"sources":report["sources"]})
(out/"capture-verification.json").write_text(json.dumps({"records":records,"rgba_frames_verified":960,"head_note":"boards crop actual pixels around camera-followed player; not source repaint or synthetic phases"},ensure_ascii=False,indent=2)+"\n")
print("INDEPENDENT_CAPTURE_VERIFICATION: PASS 8 clips / 960 RGBA frames")
