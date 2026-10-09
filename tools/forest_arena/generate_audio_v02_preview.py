#!/usr/bin/env python3
"""Build listening previews and level-matched v01/v02 comparisons, without runtime changes."""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path
import numpy as np
from audio_v02_music import SR, SOUNDFONT_SHA256, generate as generate_music, write_wav
from audio_v02_sfx import generate as generate_sfx

ROOT=Path(__file__).resolve().parents[2]
DEFAULT_OUTPUT=ROOT/'assets/audio/v02-preview'
NAMES=['lobby','battle','ui_click','jump','hit_heavy','guard_break','myo-ryung_special_up','ja-hyun_ultimate']
FONT_URL='https://deb.debian.org/debian/pool/main/f/fluid-soundfont/fluid-soundfont-gm_3.1-5.3_all.deb'
PACKAGE_SHA256='6f531493ac4e4d9772fd96b2488ea1790af81c196135fbdd25997da0781fc60e'


def sha(path): return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def read_wav(path):
    with wave.open(str(path),'rb') as f:
        if f.getframerate()!=SR or f.getsampwidth()!=2:
            raise ValueError(f'Expected 44100 Hz PCM16: {path}')
        channels=f.getnchannels()
        data=np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(np.float64)/32768
    return data if channels==1 else data.reshape(-1,channels)


def loudness(audio, is_music):
    # Very short one-shot effects need a repeated-event measurement to avoid -inf.
    # Both versions use the same 250 ms gap and number of repeats.
    measured=audio
    if not is_music:
        gap=np.zeros((round(.25*SR),)+audio.shape[1:])
        unit=np.concatenate([audio,gap])
        measured=np.concatenate([unit]*max(4,math.ceil(4*SR/len(unit))))
    with tempfile.TemporaryDirectory(prefix='fa-audio-measure-') as temp:
        path=Path(temp)/'measure.wav';write_wav(path,measured)
        result=subprocess.run(['ffmpeg','-hide_banner','-nostats','-i',str(path),'-af',
            'loudnorm=I=-18:TP=-2:LRA=11:print_format=json','-f','null','-'],capture_output=True,text=True,check=True)
    values,_=json.JSONDecoder().raw_decode(result.stderr[result.stderr.rfind('{'):])
    return {key:float(values['input_'+key]) for key in ['i','tp','lra','thresh']}


def match_pair(old, new, is_music):
    stats=[loudness(x,is_music) for x in (old,new)]
    target=-18. if is_music else -22.
    if any(not math.isfinite(s['i']) or not math.isfinite(s['tp']) for s in stats):
        raise ValueError('Unmeasurable listening comparison')
    # Lower the common target if either version would exceed -2 dB true peak.
    target=min([target]+[s['i']-2.1-s['tp'] for s in stats])
    result=[]
    for audio,s in zip((old,new),stats):
        gain=10**((target-s['i'])/20)
        result.append(audio*gain)
    return result,{'method':'EBU R128 integrated' if is_music else 'EBU R128 repeated events, 250 ms gap, at least 4 s',
                   'target_lufs':round(target,2),'before':stats}


def generate(soundfont, output=DEFAULT_OUTPUT, library=None, skip_music=False):
    output=Path(output).resolve();output.mkdir(parents=True,exist_ok=True)
    (output/'comparison').mkdir(exist_ok=True)
    if output!=DEFAULT_OUTPUT.resolve():
        for name in ['preview.html','licenses/FluidR3-COPYRIGHT.txt']:
            dst=output/name;dst.parent.mkdir(parents=True,exist_ok=True)
            shutil.copyfile(DEFAULT_OUTPUT/name,dst)
    if not skip_music:
        generate_music(soundfont,output/'source/music',library)
    sfx=generate_sfx(output/'source/sfx')
    # Avoid machine-specific absolute paths in the portable asset inventory.
    for entry in sfx: entry['source']=str(Path(entry['source']).relative_to(output))
    comparisons=[]
    for name in NAMES:
        is_music=name in ('lobby','battle')
        old=read_wav(ROOT/'assets/audio/v01/source'/f'{name}.wav')
        if is_music:
            old=old[:30*SR].copy()
            old[:round(.025*SR)]*=np.linspace(0,1,round(.025*SR))[:,None]
            old[-round(.65*SR):]*=np.linspace(1,0,round(.65*SR))[:,None]
            source=output/'source/music'/f'{name}_mix.wav'
        else: source=output/'source/sfx'/f'{name}.wav'
        new=read_wav(source)
        pair,metrics=match_pair(old,new,is_music)
        actual=[]
        for version,audio in zip(('v01','v02'),pair):
            path=output/'comparison'/f'{name}_{version}.wav';write_wav(path,audio)
            actual.append(loudness(read_wav(path),is_music))
        metrics['after']=actual
        if abs(actual[0]['i']-actual[1]['i'])>.3:
            raise ValueError(f'Comparison loudness mismatch: {name}')
        comparisons.append({'name':name,'duration_seconds':len(new)/SR,'music':is_music,'matching':metrics})
        print(f'{name}: comparison {actual[0]["i"]:.2f}/{actual[1]["i"]:.2f} LUFS',flush=True)
    files=[]
    for path in sorted(output.rglob('*')):
        if path.is_file() and path.name not in ['manifest.json','README.md']:
            record={'path':path.relative_to(output).as_posix(),'sha256':sha(path),'bytes':path.stat().st_size}
            if path.suffix=='.wav':
                with wave.open(str(path),'rb') as f:
                    record.update(sample_rate_hz=f.getframerate(),channels=f.getnchannels(),pcm_bits=f.getsampwidth()*8,
                                  duration_seconds=f.getnframes()/f.getframerate())
            files.append(record)
    manifest={'version':2,'revision':2,'feedback':{'ui_click':'딸각, mechanical two-contact click','hit_heavy':'퍽, short low-body thud','lobby':'Piano-led melody and left-hand accompaniment','battle':'More tension: minor/diminished/E7, cello ostinato, horns and heavier drums'},'stage':'listening_preview','runtime_connected':False,'human_listening_approved':False,
       'reference':{'url':'https://www.youtube.com/watch?v=paAK7Q_AAlo','title':'MapleStory OST - Title Theme (Uncompressed)',
                    'use':'Quality reference supplied by user; no audio, melody transcription or recording copied.'},
       'rights':{'composition':'Original project-authored score and procedural SFX.',
                'music_samples':'FluidR3 GM; MIT; full notices in licenses/FluidR3-COPYRIGHT.txt',
                'sfx':'Original sample-free synthesis; no third-party recordings; no voices.'},
       'soundfont':{'name':'FluidR3_GM.sf2','sha256':SOUNDFONT_SHA256,'package_url':FONT_URL,'package_sha256':PACKAGE_SHA256,
                    'license_file':'licenses/FluidR3-COPYRIGHT.txt','bundled':False},
       'toolchain':{'numpy':np.__version__,'fluidsynth':subprocess.run(['fluidsynth','--version'],capture_output=True,text=True,check=True).stdout.splitlines()[0],
                    'ffmpeg':subprocess.run(['ffmpeg','-version'],capture_output=True,text=True,check=True).stdout.splitlines()[0],
                    'settings':{'sample_rate_hz':SR,'synth_gain':.5,'reverb':False,'chorus':False,'cpu_cores':1,
                                'room_reflections_seconds':[.037,.071,.113,.179,.251,.337,.457,.613],
                                'preview_fade_in_seconds':.025,'preview_fade_out_seconds':.65}},
       'generators':[{ 'path':f'tools/forest_arena/{name}','sha256':sha(ROOT/'tools/forest_arena'/name)}
                     for name in ['audio_v02_music.py','audio_v02_sfx.py','generate_audio_v02_preview.py']],
       'comparisons':comparisons,'sfx':sfx,'files':files,
       'limits':['Listening preview, not a loop or complete 80/90 second track.','Automatic signal checks cannot establish reference-level perceived quality.',
                 'Human audition and physical Android output not yet verified.']}
    (output/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    return manifest


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--soundfont',type=Path,required=True)
    parser.add_argument('--fluidsynth-library')
    parser.add_argument('--output',type=Path,default=DEFAULT_OUTPUT)
    parser.add_argument('--skip-music',action='store_true',help='Rebuild comparisons using existing rendered music stems.')
    args=parser.parse_args()
    # Even comparison-only refresh validates the intended sample-library identity.
    if sha(args.soundfont)!=SOUNDFONT_SHA256: parser.error('SoundFont SHA256 mismatch')
    manifest=generate(args.soundfont,args.output,args.fluidsynth_library,args.skip_music)
    print(f'Preview ready: {len(manifest["comparisons"])} pairs; {len(manifest["files"])} source/comparison files')


if __name__=='__main__': main()
