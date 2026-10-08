#!/usr/bin/env python3
"""Rebuild Forest Arena v01 original, sample-free audio (Python + NumPy + ffmpeg)."""
from __future__ import annotations
import argparse, hashlib, html, json, subprocess, wave
from pathlib import Path
import numpy as np

SR = 44100
SEED = 20261008
ROOT = Path(__file__).resolve().parents[2]
RUNTIME = ROOT / 'forest_arena/assets/audio/v01'
SOURCE = ROOT / 'assets/audio/v01/source'
BASE = ['ui_click','ui_back','ui_select','ui_confirm','ui_error','jump','land','dash','evade','respawn','swing_light','swing_heavy','hit_light','hit_heavy','guard_hit','guard_break','charge_start','charge_ready','match_start','ring_out','victory','defeat','draw','special_hit','ultimate_hit']
CHARACTERS = ['ja-hyun','myo-ryung','nabi','yu-ran']
MOVES = ['special_neutral','special_side','special_up','special_down','ultimate']
NAMES = BASE + [f'{c}_{m}' for c in CHARACTERS for m in MOVES]

def midi(n): return 440 * 2 ** ((n-69)/12)
def envelope(t, duration, attack=.008, release=.05):
    return np.minimum(t/attack,1)*np.minimum((duration-t)/release,1).clip(0,1)

def voice(kind, note, duration, rng):
    t = np.arange(round(duration*SR))/SR
    f = midi(note)
    phase = 2*np.pi*f*t
    env = envelope(t,duration,.018 if kind=='flute' else .004,.09)
    if kind=='flute':
        p = phase + .018*np.sin(2*np.pi*5*t)
        x = np.sin(p)+.23*np.sin(2*p)+.06*np.sin(3*p)
        x += .025*rng.standard_normal(len(t))
    elif kind=='pluck':
        x = sum(np.sin(phase*h+.13*h)*np.exp(-t*(2.8+h*.8)) / h**1.5 for h in range(1,7))
    elif kind=='marimba':
        x = np.sin(phase)*np.exp(-t*5)+.32*np.sin(phase*3.99)*np.exp(-t*16)
    elif kind=='strings':
        x = sum(np.sin(phase*h+ .015*np.sin(t*19+h))/h**1.6 for h in range(1,6))
        env = envelope(t,duration,.14,.28)
    elif kind=='bass':
        x = np.sin(phase)*np.exp(-t*1.8)+.2*np.sin(phase*2)*np.exp(-t*4)
    else:
        x = np.sin(phase)*np.exp(-t*8)
    return (x*env).astype(np.float32)

def add(track, sound, seconds, gain=1., pan=0., wrap=False):
    start = round(seconds*SR)
    sound = np.asarray(sound,dtype=np.float32)*gain
    if track.ndim==2 and sound.ndim==1:
        sound = sound[:,None]*np.array([np.sqrt((1-pan)/2),np.sqrt((1+pan)/2)],np.float32)
    if wrap:
        first = min(len(sound),len(track)-start)
        track[start:start+first] += sound[:first]
        if first<len(sound): track[:len(sound)-first] += sound[first:]
    elif start<len(track):
        size = min(len(sound),len(track)-start)
        track[start:start+size] += sound[:size]

def percussion(kind,rng):
    dur = .22 if kind=='kick' else .13
    t = np.arange(round(dur*SR))/SR
    noise = rng.standard_normal(len(t))
    if kind=='kick': return np.sin(2*np.pi*(62*t+5*(1-np.exp(-t*22))))*np.exp(-t*23)*envelope(t,dur,.002,.01)
    high = noise-np.roll(noise,1)
    return high*np.exp(-t*(45 if kind=='shaker' else 25))*.2*envelope(t,dur,.002,.01)

def music(battle=False):
    rng=np.random.default_rng(SEED+int(battle))
    tempo=128 if battle else 96
    bars=48 if battle else 32
    beat=60/tempo
    duration=bars*4*beat
    track=np.zeros((round(duration*SR),2),np.float32)
    # D major / B minor / G major / A major, a shared original eight-bar motif.
    chords=[(50,62,66,69),(47,59,62,66),(43,55,59,62),(45,57,61,64)]
    motif=[[74,78,81,78,76,74],[73,74,78,76,74,71],[71,74,79,78,74,71],[73,76,81,78,76,73],
           [74,78,81,86,81,78],[78,81,83,81,78,74],[79,78,74,71,74,78],[76,73,69,73,76,81]]
    positions=[0,.75,1.5,2,2.75,3.5]
    for bar in range(bars):
        chord=chords[(bar//2)%4]
        section=(bar//8)%4
        origin=bar*4*beat
        # Sustained warm section under plucked arpeggios; tails wrap at loop boundary.
        for note in chord[1:]:
            add(track,voice('strings',note,4*beat+.35,rng),origin,.036,(-.3 if note%2 else .3),True)
        for step in range(8):
            note=chord[1+step%3]+(12 if step in (3,7) else 0)
            add(track,voice('pluck',note,beat*.85,rng),origin+step*.5*beat,.105 if battle else .09,(-.5 if step%2 else .5),True)
        for b in range(4):
            add(track,voice('bass',chord[0]+(7 if b==3 else 0),beat*.75,rng),origin+b*beat,.11,0,True)
            if battle or b%2==0:
                add(track,percussion('kick',rng),origin+b*beat,.19 if battle else .08,0,True)
            if b%2==1: add(track,percussion('clap',rng),origin+b*beat,.27 if battle else .12,.08,True)
            for half in (0,.5): add(track,percussion('shaker',rng),origin+(b+half)*beat,.16 if battle else .08,.65,True)
        for i,note in enumerate(motif[bar%8]):
            # B section moves to wooden mallets, with an upper flute response.
            kind='marimba' if section==2 else 'flute'
            octave=12 if battle and section==3 else 0
            add(track,voice(kind,note+octave,beat*(.65 if i<5 else .45),rng),origin+positions[i]*beat,.13,-.15,True)
            if battle and section in (1,3):
                add(track,voice('marimba',note-12,.4,rng),origin+positions[i]*beat,.09,.35,True)
    # Deterministic early reflections (circular delay maintains seamless loop).
    track += .16*np.roll(track,round(.113*SR),axis=0)[:,::-1] + .08*np.roll(track,round(.227*SR),axis=0)
    track -= track.mean(axis=0)
    track *= .70/max(float(np.max(np.abs(track))),1e-9)
    return track, {'duration_seconds':duration,'tempo_bpm':tempo,'bars':bars,'meter':'4/4','key':'D major','loop':True}

def effect(name):
    rng=np.random.default_rng(SEED+int.from_bytes(hashlib.sha256(name.encode()).digest()[:4],'little'))
    dur=.22
    if name in ('victory','defeat','draw','match_start','respawn'): dur=1.35
    elif name.endswith('ultimate') or name=='ultimate_hit': dur=1.15
    elif name.startswith(tuple(CHARACTERS)) or name in ('ring_out','guard_break','charge_ready'): dur=.65
    elif name in ('swing_heavy','charge_start','special_hit'): dur=.38
    t=np.arange(round(dur*SR))/SR
    out=np.zeros(len(t),np.float32)
    def chime(notes, spacing=.06, gain=.22):
        for i,n in enumerate(notes): add(out,voice('marimba',n,dur-i*spacing,rng),i*spacing,gain)
    def sweep(f0,f1,gain=.3,decay=8):
        phase=2*np.pi*(f0*t+(f1-f0)*t*t/(2*dur))
        out[:] += gain*(np.sin(phase)+.16*np.sin(phase*2))*np.exp(-decay*t)*envelope(t,dur,.005,.04)
    def air(gain=.2,decay=12):
        noise=rng.standard_normal(len(t))
        # Short smoothed noise textures, without external samples.
        smooth=np.convolve(noise,np.ones(9)/9,mode='same')
        out[:] += smooth*gain*np.exp(-decay*t)*envelope(t,dur,.01,.04)
    if name.startswith('ui_'):
        notes={'ui_click':[86],'ui_select':[81,86],'ui_back':[81,74],'ui_confirm':[74,78,81],'ui_error':[66,65]}[name]
        chime(notes,.045,.3)
        air(.03,35)
    elif name in ('victory','defeat','draw','match_start','respawn'):
        notes={'victory':[74,78,81,86],'defeat':[74,71,66,62],'draw':[74,76,74],'match_start':[69,74,81],'respawn':[74,81,86]}[name]
        chime(notes,.16,.3)
        if name=='match_start': sweep(180,90,.18,12)
    elif name in ('hit_light','hit_heavy','special_hit','ultimate_hit','land','guard_hit','guard_break'):
        heavy=name in ('hit_heavy','ultimate_hit','guard_break')
        sweep(180 if heavy else 310,45 if heavy else 90,.42,18 if heavy else 30)
        air(.65 if heavy else .4,16 if heavy else 30)
        if name.startswith('guard'): chime([83,90,95] if name=='guard_break' else [86,93],.028,.12)
        if name in ('special_hit','ultimate_hit'): chime([74,81,86],.07,.19)
    elif name in ('jump','dash','evade','swing_light','swing_heavy','ring_out','charge_start','charge_ready'):
        down=name in ('ring_out','swing_heavy')
        sweep(650 if down else 170,90 if down else 900,.16,5)
        air(.6 if 'swing' in name else .25,8)
        if name=='charge_ready': chime([81,86,90],.08,.24)
    else:
        char,move=next((c,name[len(c)+1:]) for c in CHARACTERS if name.startswith(c+'_'))
        index=CHARACTERS.index(char)
        # Quick wooden rush / bright aerial bell / sharp claw scrape / rolling mist-tail.
        roots=[69,81,74,62]
        rise={'special_neutral':2,'special_side':7,'special_up':12,'special_down':-7,'ultimate':19}[move]
        sweep(midi(roots[index]),midi(roots[index]+rise),.22,5)
        air([.27,.13,.52,.35][index], [14,10,22,6][index])
        notes=[roots[index],roots[index]+7,roots[index]+12]
        if move=='ultimate': notes += [roots[index]+19,roots[index]+24]
        chime(notes,.055 if index!=3 else .09,.16 if index!=2 else .09)
        if index==2:
            for offset in (.02,.08): add(out,percussion('clap',rng),offset,.7)
        if index==3: out[:]+= .12*np.sin(2*np.pi*90*t)*np.sin(2*np.pi*7*t)*np.exp(-t*5)*envelope(t,dur,.02,.1)
    out-=out.mean()
    out*=envelope(t,dur,.002,.025)
    peak=float(np.max(np.abs(out)))
    out*= (.62 if name.startswith('ui_') else .76)/max(peak,1e-9)
    return out

def write_wav(path,data):
    path.parent.mkdir(parents=True,exist_ok=True)
    pcm=np.rint(np.clip(data,-.999,.999)*32767).astype('<i2')
    with wave.open(str(path),'wb') as f:
        f.setnchannels(1 if data.ndim==1 else data.shape[1]); f.setsampwidth(2); f.setframerate(SR); f.writeframes(pcm.tobytes())

def checksum(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--project-root',type=Path,default=ROOT)
    args=parser.parse_args()
    global RUNTIME,SOURCE
    root=args.project_root.resolve(); RUNTIME=root/'forest_arena/assets/audio/v01'; SOURCE=root/'assets/audio/v01/source'
    SOURCE.mkdir(parents=True,exist_ok=True); RUNTIME.mkdir(parents=True,exist_ok=True)
    entries=[]
    for name,battle in [('lobby',False),('battle',True)]:
        audio,details=music(battle); master=SOURCE/f'{name}.wav'; target=RUNTIME/f'{name}.ogg'
        write_wav(master,audio)
        subprocess.run(['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(master),'-c:a','vorbis','-strict','experimental','-q:a','5','-map_metadata','-1','-fflags','+bitexact',str(target)],check=True)
        entries.append({'name':name,'asset_id':f'fa.audio.{name}','runtime':str(target.relative_to(root)),'source':str(master.relative_to(root)),'channels':2,**details,'sha256':checksum(target),'source_sha256':checksum(master)})
        print(f'Generated {name}: {details["duration_seconds"]:.1f}s')
    for name in NAMES:
        audio=effect(name); target=RUNTIME/f'{name}.wav'; master=SOURCE/f'{name}.wav'
        write_wav(target,audio); write_wav(master,audio)
        entries.append({'name':name,'asset_id':f'fa.audio.{name}','runtime':str(target.relative_to(root)),'source':str(master.relative_to(root)),'duration_seconds':len(audio)/SR,'channels':1,'loop':False,'sha256':checksum(target),'source_sha256':checksum(master)})
    manifest={'version':1,'generated_date':'2026-10-08','sample_rate_hz':SR,'pcm_bits':16,'generator':'tools/forest_arena/generate_audio_v01.py','generator_sha256':checksum(Path(__file__)),'seed':SEED,'source_url':None,'rights':{'method':'Original algorithmic composition and signal synthesis; no external samples, melodies, recordings or voice.','usage_basis':'Project-authored original code and synthesized recordings; no third-party audio license required.','external_assets':False,'human_listening_verified':False},'generation':{'numpy_version':np.__version__,'ffmpeg_version':subprocess.check_output(['ffmpeg','-version'],text=True).splitlines()[0],'instruments':['harmonic woodwind','decaying plucked strings','inharmonic wooden mallets','sustained strings','bass','synthesized skin drum and shaker'],'quality_limit':'Synthetic instruments; automated signal checks do not establish perceived mix quality or Android device suitability.'},'assets':entries}
    (root/'assets/audio/v01/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    rows='\n'.join(f'<li><strong>{html.escape(e["name"])}</strong> · {e["duration_seconds"]:.2f}s <audio controls preload="none" {"loop" if e["loop"] else ""} src="../../../{e["runtime"]}"></audio></li>' for e in entries)
    (root/'assets/audio/v01/preview.html').write_text('<!doctype html><html lang="ko"><meta charset="utf-8"><title>Forest Arena 사운드 v01 미리듣기</title><style>body{font:16px system-ui;max-width:1000px;margin:40px auto;background:#edf5ef;color:#183b2c}li{padding:12px;margin:6px;background:white;border-radius:8px;display:flex;align-items:center;justify-content:space-between}audio{width:380px}</style><h1>Forest Arena 사운드 v01</h1><p>독창적인 작곡·합성 음원. 음악은 반복 재생합니다. 자동 신호 검사와 별개로 사람이 소리의 균형을 확인해야 합니다.</p><ol>'+rows+'</ol></html>')
    print(f'Generated {len(entries)} assets; manifest and labelled preview saved.')
if __name__=='__main__': main()
