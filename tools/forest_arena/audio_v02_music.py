#!/usr/bin/env python3
"""Original 30-second listening sketches rendered with FluidR3 GM / FluidSynth."""
from __future__ import annotations
import ctypes as C
import ctypes.util
import hashlib
import json
import struct
import wave
from pathlib import Path
import numpy as np

SR = 44100
SOUNDFONT_SHA256 = '74594e8f4250680adf590507a306655a299935343583256f3b722c48a1bc1cb0'


def write_wav(path, audio):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    x = np.asarray(audio)
    if np.max(np.abs(x)) >= 1:
        raise ValueError(f'Clipping before PCM conversion: {path}')
    with wave.open(str(path), 'wb') as f:
        f.setnchannels(1 if x.ndim == 1 else x.shape[1])
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(np.rint(x * 32767).astype('<i2').tobytes())


def note(track, beat, length, pitch, velocity=70):
    if pitch is not None:
        track['notes'].append({'beat': round(beat, 5), 'length': round(length, 5),
                               'pitch': pitch, 'velocity': int(velocity)})


def score(battle=False):
    """Composed here, without transcription or use of reference-song note data."""
    rng = np.random.default_rng(20261009 + battle)
    bpm, bars = (128, 16) if battle else (96, 12)
    specs = [
        ('lead', 60 if battle else 0, 64, .82 if battle else 1.05, '호른 주선율' if battle else '피아노 주선율'),
        ('answer', 68 if battle else 73, 74, .33 if battle else .20, '오보에' if battle else '플루트 응답'),
        ('strings', 44 if battle else 48, 48, .60 if battle else .28, '트레몰로 현악' if battle else '현악 받침'),
        ('counter', 42, 76, .66 if battle else .22, '첼로 반복 리듬' if battle else '첼로 대선율'),
        ('harp', 46, 38, .28 if battle else .19, '하프'),
        ('piano', 0, 52, .50 if battle else .64, '피아노 저음 강조' if battle else '피아노 왼손 반주'),
        ('bass', 43, 64, .82 if battle else .34, '더블베이스'),
        ('horn', 60, 57, .45 if battle else .08, '프렌치 호른'),
        ('drums', 0, 64, .65 if battle else .07, '저음 북·타악'),
    ]
    tracks = [{'id': name, 'program': program, 'pan': pan, 'gain': gain,
               'instrument': label, 'channel': 9 if name == 'drums' else i,
               'notes': []} for i, (name, program, pan, gain, label) in enumerate(specs)]
    by = {t['id']: t for t in tracks}
    if battle:
        # Minor pedal, diminished preparation and E7 pull; no C-major lift.
        harmony = [(45,[57,60,64]),(43,[57,60,64]),(41,[57,60,65]),(40,[56,59,62]),
                   (38,[57,62,65]),(47,[59,62,65]),(40,[56,59,62]),(45,[57,60,64]),
                   (45,[57,60,64]),(41,[57,60,65]),(38,[57,62,65]),(40,[56,59,62]),
                   (47,[59,62,65]),(40,[56,59,62]),(40,[56,59,62]),(45,[57,60,64])]
        phrases = [
            [(0,.55,76),(.75,.25,76),(1.5,.4,72),(2,.75,71),(3,.55,69)],
            [(0,.55,72),(.75,.25,71),(1.5,.5,69),(2.5,.85,76)],
            [(0,.55,77),(.75,.25,76),(1.5,.4,72),(2.25,.4,71),(3,.65,69)],
            [(0,.55,71),(.75,.25,68),(1.5,.5,74),(2.5,.85,76)],
            [(0,.55,74),(.75,.25,74),(1.5,.5,77),(2.25,.4,76),(3,.55,74)],
            [(0,.55,71),(.75,.25,74),(1.5,.45,77),(2.5,.75,74)],
            [(0,.55,76),(.75,.25,74),(1.5,.45,71),(2.5,.85,68)],
            [(0,1.25,69),(2,.4,72),(2.75,.75,76)],
            [(0,.55,81),(.75,.25,79),(1.5,.5,76),(2.25,.4,72),(3,.55,71)],
            [(0,.55,77),(.75,.25,76),(1.5,.5,72),(2.5,.85,69)],
            [(0,.55,74),(.75,.25,77),(1.5,.5,76),(2.5,.85,74)],
            [(0,.55,71),(.75,.25,68),(1.5,.5,74),(2.5,.85,76)],
            [(0,.55,77),(.75,.25,74),(1.5,.5,71),(2.5,.85,74)],
            [(0,.55,76),(.75,.25,74),(1.5,.5,71),(2.5,.85,68)],
            [(0,.55,71),(.75,.25,74),(1.5,.5,76),(2.25,.4,74),(3,.55,68)],
            [(0,2.8,69)],
        ]
    else:
        # G major / relative E minor, a 12-bar miniature with intro and cadence.
        harmony = [(43,[55,59,62]),(38,[54,57,62]),(43,[55,59,62]),(40,[55,59,64]),
                   (36,[55,60,64]),(38,[54,57,62]),(43,[55,59,62]),(40,[55,59,64]),
                   (36,[55,60,64]),(45,[57,60,64]),(38,[54,57,62]),(43,[55,59,62])]
        phrases = [[(0,1,67),(1.5,.5,71),(2.5,1,74)],[(0,1.3,69),(2,.5,66),(2.75,.75,62)],
            [(0,1.4,71),(1.75,.5,74),(2.5,1,69)],
            [(0,1,67),(1.25,.5,71),(2,1.6,76)],
            [(0,1.5,72),(2,.5,71),(2.75,.8,67)],
            [(0,.75,66),(1,.5,69),(2,1.6,74)],
            [(0,1,71),(1.25,.5,74),(2,1,79),(3.25,.5,78)],
            [(0,1.75,76),(2.25,.5,74),(3,.65,71)],
            [(0,.75,72),(1,.5,76),(2,1.5,79)],
            [(0,1.5,76),(2,.5,72),(3,.7,69)],
            [(0,.75,69),(1,.5,66),(2,1.5,62)],
            [(0,2.8,67)],
        ]
    for bar, (root, chord) in enumerate(harmony):
        origin = 4 * bar
        intensity = (.88 + .12 * np.sin(bar * .7)) if battle else (.72 if bar < 2 else .91 + .09*np.sin(bar))
        for i, p in enumerate(chord):
            note(by['strings'], origin + i*.012, 3.82, p+12,
                 int((57 if battle else 49)*intensity) + i*2)
        # Repeated low strings add urgency; lobby leaves space around the piano.
        if battle:
            for step in range(8):
                pitch=chord[[0,0,2,0,1,0,2,1][step]]
                note(by['counter'],origin+step*.5+.008,.32,pitch,78 if step%2==0 else 65)
        elif bar >= 2:
            note(by['counter'], origin+.04, 1.8, chord[0], 55 if battle else 48)
            note(by['counter'], origin+2.03, 1.72, chord[1], 51 if battle else 45)
        steps = 8 if battle or bar % 4 != 3 else 4
        for step in range(steps):
            p = chord[[0,1,2,1,0,2,1,2][step]] + (12 if step in (2,5) else 0)
            offset = float(rng.uniform(-.008,.008))
            note(by['harp'], max(0,origin+step*(4/steps)+offset), .76, p+12,
                 int((58 if step%2==0 else 45)*intensity)+int(rng.integers(-3,4)))
        for b in ([0,.75,1.5,2,2.75,3.5] if battle else [0,2]):
            note(by['bass'], origin+b, .65 if battle else 1.6, root-12,
                 83 if battle and b in (0,2) else 68 if battle else 50)
        if battle:
            for b in (0,1.5,2.75):
                note(by['piano'],origin+b,.42,root,70 if b==0 else 57)
        else:
            for step in range(6):
                p=([root]+chord+[chord[2]+12,chord[1]])[step]
                note(by['piano'],origin+[0,.5,1,2,2.5,3][step]+.012,1.25,p,58 if step in (0,3) else 48)
        for start, length, p in phrases[bar]:
            v = int((91 if battle else 87)*intensity) + int(rng.integers(-4,5))
            note(by['lead'], origin+start+.013, length*(.82 if battle else .96), p, v)
            if not battle and bar in (6,8) and start==0:
                note(by['lead'],origin+start+.018,length*.88,p-12,v-16)
        if bar in ([3,7,11] if battle else [1,5,7,9]):
            for start, p in [(2.55,chord[1]+24),(3.2,chord[2]+12)]:
                note(by['answer'], origin+start, .56, p, 63 if battle else 54)
        if (battle and bar in (0,4,8,12,14,15)) or (not battle and bar in (8,10,11)):
            note(by['horn'],origin+.02,3.4,chord[1],58 if battle else 43)
            note(by['horn'],origin+.025,3.35,chord[2],51 if battle else 38)
        # GM percussion: low orchestral bass drum, side stick, brushes/shakers.
        if battle:
            for b in (0,1.5,2,2.75): note(by['drums'],origin+b,.18,36,91 if b==0 else 72)
            for b in (1,3): note(by['drums'],origin+b+.006,.12,38,66)
            for step in range(8): note(by['drums'],origin+step*.5,.10,42,37 if step%2 else 49)
            if bar in (3,7,11,14):
                for step in range(4): note(by['drums'],origin+3+step*.25,.08,42,41+step*4)
            if bar in (3,7,11,14):
                for step in range(3): note(by['drums'],origin+3+step/3,.14,45+step*2,50+step*6)
        elif bar >= 2:
            note(by['drums'],origin,.17,36,42)
            for b in (1,3): note(by['drums'],origin+b,.10,42,30)
    return {'version':2,'revision':2,'name':'battle' if battle else 'lobby','tempo_bpm':bpm,'bars':bars,
            'meter':'4/4','key':'A minor' if battle else 'G major','duration_seconds':30,
            'loop':False,'seed':20261009+int(battle),'tracks':tracks}


def _vlq(value):
    data=[value & 127]
    while value>>7:
        value>>=7
        data.insert(0,(value&127)|128)
    return bytes(data)


def write_midi(path, data):
    tempo=round(60_000_000/data['tempo_bpm'])
    header=b'\0\xff\x51\x03'+tempo.to_bytes(3,'big')+b'\0\xff\x58\x04\x04\x02\x18\x08\0\xff\x2f\0'
    chunks=[b'MTrk'+struct.pack('>I',len(header))+header]
    for track in data['tracks']:
        ch=track['channel']; events=[(0,bytes([0xc0|ch,track['program']])),(0,bytes([0xb0|ch,10,track['pan']]))]
        for n in track['notes']:
            a=round(n['beat']*480); b=round((n['beat']+n['length'])*480)
            events.extend([(a,bytes([0x90|ch,n['pitch'],n['velocity']])),(b,bytes([0x80|ch,n['pitch'],0]))])
        events.sort(key=lambda e:(e[0],0 if e[1][0]&0xf0==0x80 else 1))
        stream=bytearray();prev=0
        for tick,event in events:
            stream.extend(_vlq(tick-prev)+event);prev=tick
        stream.extend(_vlq(max(0,data['bars']*4*480-prev))+b'\xff\x2f\0')
        chunks.append(b'MTrk'+struct.pack('>I',len(stream))+stream)
    Path(path).write_bytes(b'MThd'+struct.pack('>IHHH',6,1,len(chunks),480)+b''.join(chunks))


class Renderer:
    def __init__(self, soundfont, library=None):
        libpath=library or ctypes.util.find_library('fluidsynth')
        if not libpath:
            raise RuntimeError('FluidSynth shared library not found; install official fluidsynth package.')
        self.lib=C.CDLL(str(libpath));self.soundfont=str(soundfont)
        signatures={
            'new_fluid_settings':(C.c_void_p,[]),
            'delete_fluid_settings':(None,[C.c_void_p]),
            'fluid_settings_setnum':(C.c_int,[C.c_void_p,C.c_char_p,C.c_double]),
            'fluid_settings_setint':(C.c_int,[C.c_void_p,C.c_char_p,C.c_int]),
            'new_fluid_synth':(C.c_void_p,[C.c_void_p]),
            'delete_fluid_synth':(None,[C.c_void_p]),
            'fluid_synth_sfload':(C.c_int,[C.c_void_p,C.c_char_p,C.c_int]),
            'fluid_synth_noteon':(C.c_int,[C.c_void_p,C.c_int,C.c_int,C.c_int]),
            'fluid_synth_noteoff':(C.c_int,[C.c_void_p,C.c_int,C.c_int]),
            'fluid_synth_cc':(C.c_int,[C.c_void_p,C.c_int,C.c_int,C.c_int]),
            'fluid_synth_program_change':(C.c_int,[C.c_void_p,C.c_int,C.c_int]),
            'fluid_synth_write_float':(C.c_int,[C.c_void_p,C.c_int,C.c_void_p,C.c_int,C.c_int,C.c_void_p,C.c_int,C.c_int]),
        }
        for name,(ret,args) in signatures.items():
            fn=getattr(self.lib,name);fn.restype=ret;fn.argtypes=args

    def render(self, track, tempo, duration=32):
        l=self.lib;settings=l.new_fluid_settings();synth=None
        try:
            for key,value in [('synth.sample-rate',SR),('synth.gain',.5)]:
                if l.fluid_settings_setnum(settings,key.encode(),value)!=0:
                    raise RuntimeError(f'FluidSynth setting failed: {key}')
            for key,value in [('synth.reverb.active',0),('synth.chorus.active',0),('synth.cpu-cores',1)]:
                if l.fluid_settings_setint(settings,key.encode(),value)!=0:
                    raise RuntimeError(f'FluidSynth setting failed: {key}')
            synth=l.new_fluid_synth(settings)
            if not synth or l.fluid_synth_sfload(synth,self.soundfont.encode(),1)<0:
                raise RuntimeError('SoundFont load failed')
            ch=track['channel'];l.fluid_synth_program_change(synth,ch,track['program'])
            l.fluid_synth_cc(synth,ch,10,track['pan'])
            l.fluid_synth_cc(synth,ch,91,0);l.fluid_synth_cc(synth,ch,93,0)
            total=round(duration*SR);audio=np.zeros((total,2),np.float32)
            events=[]
            for n in track['notes']:
                a=round(n['beat']*60/tempo*SR); b=round((n['beat']+n['length'])*60/tempo*SR)
                events.extend([(a,1,n['pitch'],n['velocity']),(b,0,n['pitch'],0)])
            events.sort();cursor=0
            def draw(end):
                nonlocal cursor
                end=min(end,total)
                while cursor<end:
                    count=min(4096,end-cursor);left=np.empty(count,np.float32);right=np.empty(count,np.float32)
                    code=l.fluid_synth_write_float(synth,count,left.ctypes.data,0,1,right.ctypes.data,0,1)
                    if code!=0: raise RuntimeError('FluidSynth render failed')
                    audio[cursor:cursor+count,0]=left;audio[cursor:cursor+count,1]=right;cursor+=count
            for frame,on,pitch,velocity in events:
                draw(frame)
                code=l.fluid_synth_noteon(synth,ch,pitch,velocity) if on else l.fluid_synth_noteoff(synth,ch,pitch)
                if on and code!=0: raise RuntimeError(f'FluidSynth note-on failed: {track["id"]}, {pitch}')
            draw(total)
            return audio
        finally:
            if synth: l.delete_fluid_synth(synth)
            l.delete_fluid_settings(settings)


def generate(soundfont, output_dir, library=None):
    soundfont=Path(soundfont)
    if hashlib.sha256(soundfont.read_bytes()).hexdigest()!=SOUNDFONT_SHA256:
        raise ValueError('Expected pinned FluidR3_GM.sf2; soundfont SHA256 mismatch')
    output_dir=Path(output_dir);output_dir.mkdir(parents=True,exist_ok=True)
    renderer=Renderer(soundfont,library);results=[]
    for battle in (False,True):
        data=score(battle);name=data['name'];folder=output_dir/name;folder.mkdir(exist_ok=True)
        (folder/'score.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
        write_midi(folder/'score.mid',data)
        mix=np.zeros((32*SR,2),np.float32)
        for track in data['tracks']:
            rendered=renderer.render(track,data['tempo_bpm'])*track['gain']
            write_wav(folder/f'{track["id"]}.wav',rendered)
            mix+=rendered
        # Fixed stereo room reflections; no randomized rendering or hidden plugins.
        room=np.zeros_like(mix)
        for delay,gain in [(.037,.13),(.071,.11),(.113,.09),(.179,.075),(.251,.06),(.337,.045),(.457,.032),(.613,.02)]:
            d=round(delay*SR);room[d:]+=mix[:-d,::-1]*gain
        mix+=room
        mix=mix[:30*SR]
        # Preview excerpts have deliberate fades, rather than pretending to be loops.
        mix[:round(.025*SR)]*=np.linspace(0,1,round(.025*SR))[:,None]
        mix[-round(.65*SR):]*=np.linspace(1,0,round(.65*SR))[:,None]
        mix-=mix.mean(axis=0)
        mix*=min(1.,.85/max(float(np.max(np.abs(mix))),1e-9))
        mix[0]=0;mix[-1]=0
        write_wav(output_dir/f'{name}_mix.wav',mix)
        results.append({'name':name,'duration_seconds':30,'tempo_bpm':data['tempo_bpm'],
                        'key':data['key'],'bars':data['bars'],'stems':len(data['tracks'])})
    return results
