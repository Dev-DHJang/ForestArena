#!/usr/bin/env python3
"""Validate v01 deliverables, hashes, PCM formats, signal health and loop edges."""
from __future__ import annotations
import argparse, hashlib, json, subprocess, wave
from pathlib import Path
import numpy as np
from generate_audio_v01 import BASE, CHARACTERS, MOVES, SR
ROOT=Path(__file__).resolve().parents[2]

def check(condition, message):
    if not condition: raise ValueError(message)
def wav(path):
    with wave.open(str(path),'rb') as f:
        check(f.getsampwidth()==2,f'{path}: expected signed 16-bit PCM')
        check(f.getframerate()==SR,f'{path}: expected 44100 Hz')
        channels=f.getnchannels()
        return np.frombuffer(f.readframes(f.getnframes()),dtype='<i2').astype(np.float32).reshape(-1,channels)/32768

def main():
    parser=argparse.ArgumentParser(); parser.add_argument('--project-root',type=Path,default=ROOT)
    root=parser.parse_args().project_root.resolve()
    manifest=json.loads((root/'assets/audio/v01/manifest.json').read_text())
    expected=set(BASE+[f'{c}_{m}' for c in CHARACTERS for m in MOVES]+['lobby','battle'])
    entries=manifest['assets']; check({e['name'] for e in entries}==expected,'Missing or unexpected sound names')
    check(len(entries)==len(expected),'Duplicate assets')
    check(not manifest['rights']['external_assets'],'Unexpected external source claim')
    generator=root/manifest['generator']
    check(hashlib.sha256(generator.read_bytes()).hexdigest()==manifest['generator_sha256'],'Generator changed: regenerate assets')
    preview=(root/'assets/audio/v01/preview.html').read_text()
    rows=[]
    for e in entries:
        path=root/e['runtime']; source=root/e['source']
        check(path.is_file() and source.is_file(),f'{e["name"]}: missing runtime or source')
        for file,key in [(path,'sha256'),(source,'source_sha256')]:
            check(hashlib.sha256(file.read_bytes()).hexdigest()==e[key],f'{file}: hash mismatch')
        check(e['name'] in preview and '../../../'+e['runtime'] in preview,f'{e["name"]}: missing preview')
        master=wav(source)
        check(master.shape[1]==e['channels'],f'{path}: wrong channels')
        check(abs(len(master)/SR-e['duration_seconds'])<1/SR,f'{path}: wrong master duration')
        if e['loop']:
            check(e['duration_seconds']==(80 if e['name']=='lobby' else 90),'Wrong BGM duration')
            probe=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','stream=codec_name,sample_rate,channels,duration','-of','json',str(path)],text=True))['streams'][0]
            check(probe['codec_name']=='vorbis' and int(probe['channels'])==2 and int(probe['sample_rate'])==SR,f'{path}: incompatible OGG format')
            raw=subprocess.check_output(['ffmpeg','-hide_banner','-loglevel','error','-i',str(path),'-f','f32le','-acodec','pcm_f32le','-'])
            samples=np.frombuffer(raw,dtype='<f4').reshape(-1,2)
            # Codec granule positions must preserve the exact loop duration.
            check(abs(len(samples)/SR-e['duration_seconds'])<.025,f'{path}: decoded length mismatch')
        else:
            samples=wav(path)
            check(np.array_equal(samples,master),f'{path}: runtime differs from PCM master')
        check(np.isfinite(samples).all(),f'{path}: nonfinite samples')
        peak=float(np.max(np.abs(samples))); rms=float(np.sqrt(np.mean(samples**2)))
        check(.05<peak<.99,f'{path}: silence or clipping (peak {peak})')
        check(.008<rms<.4,f'{path}: silent or excessive RMS ({rms})')
        check(abs(float(samples.mean()))<.003,f'{path}: excessive DC offset')
        if e['loop']:
            # Compare seam step with this recording's normal adjacent-sample motion.
            seam=float(np.max(np.abs(samples[-1]-samples[0])))
            normal=float(np.sqrt(np.mean(np.diff(samples,axis=0)**2)))
            check(seam<max(.02,normal*8),f'{path}: audible click risk at seam ({seam})')
            window=SR//20
            first=float(np.sqrt(np.mean(samples[:window]**2)))
            last=float(np.sqrt(np.mean(samples[-window:]**2)))
            check(first>.01 and last>.01,f'{path}: silent loop edge')
            chunks=[float(np.sqrt(np.mean(samples[i:i+SR]**2))) for i in range(0,len(samples)-SR,SR)]
            check(min(chunks)>.015,f'{path}: unexpected silent passage')
            rows.append(f'{e["name"]}: {len(samples)/SR:.2f}s stereo, peak={peak:.3f} RMS={rms:.3f}, seam={seam:.5f}')
        else:
            check(float(np.max(np.abs(samples[:1])))<.001 and float(np.max(np.abs(samples[-1:])))<.003,f'{path}: unfaded SFX boundary')
    for row in rows: print(row)
    print(f'PASS: {len(entries)} audio assets; names, hashes, masters, preview, formats, durations, silence, clipping, DC, SFX fades and BGM decoded loop boundaries.')
    print('Not measured: perceived timbre/mix, human listening, Android output/lifecycle.')
if __name__=='__main__': main()
