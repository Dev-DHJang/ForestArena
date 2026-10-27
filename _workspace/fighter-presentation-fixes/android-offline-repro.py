"""Observe the already-installed baseline APK, without changing gameplay values."""
from pathlib import Path
import sys,json,uuid,time,threading,subprocess,struct
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools/forest_arena'))
import android_fleet as f
serial=sys.argv[1];run=uuid.uuid4().hex
out=Path(__file__).resolve().parent/'qa'/('android-offline-'+run);out.mkdir();(out/'.gdignore').touch()
apk=ROOT/'build/android/ForestArena-debug.apk';meta=f.inspect_apk(apk,f.sdk_tool('aapt'))
d=f.DeviceRun(f.ADB(f.sdk_tool('adb'),serial,meta['package']),'S23-Ultra',run,out,meta['activity'],screen_timeout=35,apk_sha256=meta['sha256'])
original=d.adb.original_store_hashes();d.original_hashes=original;d.verify_installed_apk();d.start_logcat()
samples=[];stop=threading.Event();worker=None;record=None
try:
 print('launch baseline APK',flush=True);d.launch()
 d.physical_size=struct.unpack('!II',d.adb.run('exec-out','screencap','-p')[16:24])
 f.require(d.physical_size[0]>d.physical_size[1],'landscape physical display required')
 if d.read().get('screen')=='first':d.tap('자현');d.screen('home')
 d.prepare();d.command('select_config',mode=4,character='ja-hyun',opponent='ja-hyun',accessory='');d.start_match()
 d.command('autoplay',enabled=True)
 def near(s):
  fighters=s.get('snapshot',{}).get('fighters',[])
  return len(fighters)==2 and abs(fighters[0]['position']['x']-fighters[1]['position']['x'])<220 and abs(fighters[0]['position']['y']-fighters[1]['position']['y'])<45
 d.wait(near,timeout=35,label='actual AI navigation reaches the stationary practice opponent')
 d.command('autoplay',enabled=False)
 d.wait(lambda s:d.player(s).get('state') in ('IDLE','RUN') and not d.player(s).get('attack_id') and d.player(s).get('special_cooldown_ticks',0)==0,timeout=10,label='actual grounded neutral and special ready')
 item=d.node(id='touch/attack_special');d.evidence('before-real-special')
 def watch():
  while not stop.is_set():
   s=d.adb.read_state(run)
   if s:samples.append({'observed_monotonic':time.monotonic(),'msec':s.get('msec'),'screen':s.get('screen'),'snapshot':s.get('snapshot',{}),'combat_events':s.get('combat_events',[])})
   stop.wait(.025)
 worker=threading.Thread(target=watch);worker.start()
 remote='/data/local/tmp/fa-special-'+run+'.mp4'
 log=(out/'screenrecord.log').open('wb')
 record=subprocess.Popen([d.adb.executable,'-s',serial,'shell','screenrecord','--size','1280x596','--bit-rate','6000000','--time-limit','8',remote],stdout=log,stderr=subprocess.STDOUT)
 time.sleep(.5);print('real special touch',flush=True);d.tap(id='touch/attack_special',hold_ms=160)
 time.sleep(2.4);stop.set();worker.join(timeout=5);d.read();d.evidence('after-real-special')
 record.wait(timeout=12);log.close();d.adb.run('pull',remote,str(out/'special.mp4'),timeout=20)
 states=[s['snapshot'].get('fighters',[]) for s in samples]
 targets=[x[1] for x in states if len(x)==2]
 observed={'status':'captured; visual diagnosis required','source_apk_sha256':meta['sha256'],'baseline_source':'602b57c9 / merged ece8fe62, prior verified APK; new presentation code not installed','mode':'actual Android offline practice; player Ja vs stationary Ja','navigation':'existing debug AI inputs only until near; disabled before actual touch','snapshot_samples':len(samples),'target_states':sorted({x.get('state','') for x in targets}),'target_draws':sorted({(x.get('presentation',{}).get('shown_motion'),x.get('presentation',{}).get('animation'),x.get('presentation',{}).get('frame')) for x in targets},key=str),'target_hp_min':min((x.get('current_hp',999) for x in targets),default=None),'video_record_exit':record.returncode}
 f.dump_json(out/'samples.json',samples);f.dump_json(out/'observation.json',observed);print(json.dumps(observed,ensure_ascii=False),flush=True)
 d.prepare();d.tap('로비');d.screen('home')
finally:
 stop.set()
 if worker:worker.join(timeout=3)
 if record and record.poll() is None:record.terminate();record.wait(timeout=5)
 d.close();print('evidence',out,flush=True)
