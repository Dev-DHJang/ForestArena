#!/usr/bin/env python3
"""Check v02 listening artifacts independently; never assert human approval."""
from __future__ import annotations
import argparse
import hashlib
import http.client
from functools import partial
from http.server import ThreadingHTTPServer
import tempfile
import threading
import json
import math
import struct
import subprocess
import wave
from pathlib import Path
import numpy as np
from serve_audio_v02_preview import PreviewHandler
from audio_v02_sfx import SPECS, SR, effect
from generate_audio_v02_preview import NAMES, SOUNDFONT_SHA256, PACKAGE_SHA256, FONT_URL, loudness, read_wav

ROOT = Path(__file__).resolve().parents[2]
STEMS = {'lead', 'answer', 'strings', 'counter', 'harp', 'piano', 'bass', 'horn', 'drums'}


def require(condition, message):
    if not condition:
        raise ValueError(message)


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def midi_notes(path, score):
    raw = path.read_bytes()
    require(raw[:4] == b'MThd' and raw[4:8] == b'\0\0\0\x06', f'{path}: MIDI header')
    fmt, count, division = struct.unpack('>HHH', raw[8:14])
    require((fmt, count, division) == (1, 10, 480), f'{path}: MIDI tracks/timebase')
    cursor = 14
    for index in range(count):
        require(raw[cursor:cursor+4] == b'MTrk', f'{path}: MIDI track chunk')
        length = int.from_bytes(raw[cursor+4:cursor+8], 'big')
        track = raw[cursor+8:cursor+8+length]
        require(len(track) == length, f'{path}: truncated MIDI')
        cursor += 8+length
        pos = tick = 0
        ons, offs, tempo = [], [], None
        ended = False
        while pos < len(track):
            delta = 0
            while True:
                byte = track[pos]; pos += 1
                delta = (delta << 7) | (byte & 127)
                if byte < 128: break
            tick += delta
            event = track[pos]; pos += 1
            if event == 255:
                kind, size = track[pos:pos+2]; pos += 2
                payload = track[pos:pos+size]; pos += size
                if kind == 81: tempo = int.from_bytes(payload, 'big')
                if kind == 47: ended = True
            elif event & 240 in (128, 144, 176):
                pitch, value = track[pos:pos+2]; pos += 2
                if event & 240 == 144 and value:
                    ons.append((tick, event & 15, pitch, value))
                elif event & 240 == 128 or (event & 240 == 144 and not value):
                    offs.append((tick, event & 15, pitch))
            elif event & 240 == 192:
                pos += 1
            else:
                raise ValueError(f'{path}: unexpected MIDI status {event}')
        require(ended, f'{path}: missing MIDI end')
        if index == 0:
            require(tempo == round(60_000_000/score['tempo_bpm']), f'{path}: MIDI tempo differs from score')
        else:
            source = score['tracks'][index-1]
            expected = sorted((round(n['beat']*480), source['channel'], n['pitch'], n['velocity']) for n in source['notes'])
            expected_off = sorted((round((n['beat']+n['length'])*480), source['channel'], n['pitch']) for n in source['notes'])
            require(sorted(ons) == expected and sorted(offs) == expected_off, f'{path}: MIDI notes differ from {source["id"]} score')
    require(cursor == len(raw), f'{path}: trailing MIDI bytes')


def pcm(path, duration, channels, faded=False):
    with wave.open(str(path), 'rb') as f:
        require((f.getframerate(), f.getsampwidth(), f.getnchannels(), f.getcomptype()) == (SR, 2, channels, 'NONE'), f'{path}: PCM format')
        require(f.getnframes() == round(duration*SR), f'{path}: duration')
    data = read_wav(path)
    peak = float(np.max(np.abs(data)))
    rms = float(np.sqrt(np.mean(data**2)))
    require(np.isfinite(data).all() and .0001 < peak < .99 and rms > .00001, f'{path}: silence/nonfinite/clipping')
    require(abs(float(data.mean())) < .003, f'{path}: DC offset')
    if faded:
        require(np.max(np.abs(data[0])) < .0001 and np.max(np.abs(data[-1])) < .0001, f'{path}: boundary fade')
        end_rms = float(np.sqrt(np.mean(data[-round(.003*SR):]**2)))
        require(end_rms < max(.003, rms*.15), f'{path}: abrupt tail')
    return data


def verify_http_server():
    """Real HTTP checks on an ephemeral loopback port, using disposable files."""
    class QuietHandler(PreviewHandler):
        def log_message(self, *args):
            pass
    with tempfile.TemporaryDirectory(prefix='fa-preview-http-') as folder:
        root = Path(folder)/'served'; root.mkdir()
        (root/'comparison').mkdir()
        preview = b'<!doctype html><title>preview fixture</title>'
        (root/'preview.html').write_bytes(preview)
        payload = bytes(range(256))*8
        (root/'comparison/audio.wav').write_bytes(payload)
        external = Path(folder)/'outside.txt'; external.write_bytes(b'not-public-preview-content')
        (root/'outside-link').symlink_to(external)
        server = ThreadingHTTPServer(('127.0.0.1', 0), partial(QuietHandler, directory=str(root)))
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        def request(path, method='GET', byte_range=None):
            connection = http.client.HTTPConnection(*server.server_address, timeout=5)
            try:
                connection.request(method, path, headers={'Range': byte_range} if byte_range else {})
                response = connection.getresponse()
                return response.status, dict(response.getheaders()), response.read()
            finally:
                connection.close()
        try:
            status, headers, body = request('/')
            require(status == 200 and body == preview, 'HTTP preview root')
            status, headers, body = request('/comparison/audio.wav')
            require(status == 200 and body == payload and headers.get('Accept-Ranges') == 'bytes', 'HTTP full audio')
            for value, start, end in [('bytes=0-31',0,31),('bytes=1024-',1024,2047),('bytes=-17',2031,2047),('bytes=2040-3000',2040,2047)]:
                status, headers, body = request('/comparison/audio.wav', byte_range=value)
                require(status == 206 and body == payload[start:end+1], f'HTTP range body: {value}')
                require(headers.get('Content-Range') == f'bytes {start}-{end}/2048' and headers.get('Content-Length') == str(end-start+1), f'HTTP range headers: {value}')
            status, headers, body = request('/comparison/audio.wav', 'HEAD', 'bytes=0-31')
            require(status == 206 and not body and headers.get('Content-Length') == '32' and headers.get('Content-Range') == 'bytes 0-31/2048', 'HTTP ranged HEAD')
            status, headers, body = request('/comparison/audio.wav', 'HEAD')
            require(status == 200 and not body and headers.get('Content-Length') == '2048', 'HTTP full HEAD')
            for value in ('bytes=2048-', 'bytes=32-0'):
                status, headers, body = request('/comparison/audio.wav', byte_range=value)
                require(status == 416 and headers.get('Content-Range') == 'bytes */2048' and not body, f'HTTP unsatisfiable range: {value}')
            require(request('/comparison/audio.wav', byte_range='bytes=-')[0] == 416, 'HTTP malformed range')
            require(request('/comparison/')[0] == 404, 'HTTP directory listing disabled')
            require(request('/outside-link')[0] == 403, 'HTTP outside symlink blocked')
            for path in ('/../outside.txt', '/%2e%2e/outside.txt'):
                status, _, body = request(path)
                require(status in (403,404) and body != external.read_bytes(), 'HTTP external traversal blocked')
            (root/'preview.html').unlink(); (root/'preview.html').symlink_to(external)
            require(request('/')[0] == 403, 'HTTP root-index outside symlink blocked')
            print('PASS: HTTP GET/HEAD/byte ranges/416, directory and external-path boundaries.')
        finally:
            server.shutdown(); server.server_close(); thread.join(timeout=5)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', type=Path, default=ROOT)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--http-only', action='store_true', help='Only test preview HTTP server on loopback')
    parser.add_argument('--skip-http', action='store_true', help='Signal/file checks only; explicitly skip HTTP check')
    parser.add_argument('--baseline-ref', default=None, help='Optional Git ref for unchanged runtime/v01 audit')
    args = parser.parse_args()
    if not args.skip_http: verify_http_server()
    if args.http_only: return
    root = args.project_root.resolve()
    out = (args.output or root/'assets/audio/v02-preview').resolve()
    manifest = json.loads((out/'manifest.json').read_text())
    require(manifest['version'] == 2 and manifest['stage'] == 'listening_preview', 'Not a v02 listening preview')
    require(manifest['runtime_connected'] is False and manifest['human_listening_approved'] is False, 'Preview must not claim runtime connection/human approval')
    require({c['name'] for c in manifest['comparisons']} == set(NAMES) and len(manifest['comparisons']) == 8, 'Expected exactly eight comparison pairs')
    require({s['name'] for s in manifest['sfx']} == set(SPECS) and len(manifest['sfx']) == 6, 'Expected exactly six SFX previews')
    expected = {'preview.html', 'licenses/FluidR3-COPYRIGHT.txt'}
    expected |= {f'comparison/{name}_{v}.wav' for name in NAMES for v in ('v01', 'v02')}
    expected |= {f'source/sfx/{name}.wav' for name in SPECS}
    for name in ('lobby', 'battle'):
        expected |= {f'source/music/{name}_mix.wav', f'source/music/{name}/score.mid', f'source/music/{name}/score.json'}
        expected |= {f'source/music/{name}/{stem}.wav' for stem in STEMS}
    records = manifest['files']
    require(len(records) == len(expected) and {f['path'] for f in records} == expected, 'Manifest file set/duplicates')
    actual_files = {p.relative_to(out).as_posix() for p in out.rglob('*') if p.is_file() and p.name not in ('manifest.json', 'README.md')}
    require(actual_files == expected, 'Unexpected or missing deliverable files')
    for item in records:
        path = out/item['path']
        require(path.is_file() and sha(path) == item['sha256'] and path.stat().st_size == item['bytes'], f'{path}: inventory hash/size')
        if path.suffix == '.wav':
            with wave.open(str(path), 'rb') as f:
                require((item['sample_rate_hz'], item['channels'], item['pcm_bits'], item['duration_seconds']) == (f.getframerate(), f.getnchannels(), f.getsampwidth()*8, f.getnframes()/f.getframerate()), f'{path}: inventory metadata')
    for item in manifest['generators']:
        require(sha(root/item['path']) == item['sha256'], f'{item["path"]}: generator hash')
    require({g['path'] for g in manifest['generators']} == {f'tools/forest_arena/{n}' for n in ('audio_v02_music.py','audio_v02_sfx.py','generate_audio_v02_preview.py')}, 'Generator inventory')
    font = manifest['soundfont']
    require(font['sha256'] == SOUNDFONT_SHA256 and font['package_sha256'] == PACKAGE_SHA256 and font['package_url'] == FONT_URL and font['bundled'] is False, 'Sample library provenance/pin')
    require(font['license_file'] == 'licenses/FluidR3-COPYRIGHT.txt', 'Sample library license path')
    license_text = (out/font['license_file']).read_text()
    for text in ('Frank Wen', 'MIT license', 'Permission is hereby granted', 'The above copyright notice', 'THE SOFTWARE IS PROVIDED'):
        require(text in license_text, f'Missing sample-library notice: {text}')
    require(manifest['reference']['url'] == 'https://www.youtube.com/watch?v=paAK7Q_AAlo', 'Quality reference attribution')
    require('no audio' in manifest['reference']['use'] and 'no voices' in manifest['rights']['sfx'], 'Reference/voice boundary record')
    preview = (out/'preview.html').read_text()
    for name in NAMES:
        require("id:'"+name+"'" in preview, f'Preview missing {name}')
    require("comparison/'+track.id+'_'+version+'.wav'" in preview and 'playRequestSerial' in preview, 'Preview links/request cancellation')
    require('게임에 미연결' in preview and '청취 방향 확인 전' in preview, 'Preview status labels')
    require(not any(p.suffix == '.sf2' for p in out.rglob('*')), 'SoundFont unexpectedly bundled')
    for name, (duration, _) in SPECS.items():
        actual = pcm(out/f'source/sfx/{name}.wav', duration, 1, True)
        expected_pcm = np.rint(effect(name)*32767).astype('<i2').astype(np.float64)/32768
        require(np.array_equal(actual, expected_pcm), f'{name}: source differs from fixed-seed SFX generator')
    for name in ('lobby', 'battle'):
        score = json.loads((out/f'source/music/{name}/score.json').read_text())
        require(score['name'] == name and score['duration_seconds'] == 30 and score['loop'] is False, f'{name}: score preview scope')
        require(len(score['tracks']) == 9 and {t['id'] for t in score['tracks']} == STEMS, f'{name}: nine instrument stems')
        midi_notes(out/f'source/music/{name}/score.mid', score)
        for stem in STEMS: pcm(out/f'source/music/{name}/{stem}.wav', 32, 2)
        pcm(out/f'source/music/{name}_mix.wav', 30, 2, True)
    for entry in manifest['comparisons']:
        name = entry['name']; music = name in ('lobby', 'battle')
        duration = 30 if music else SPECS[name][0]
        require(entry['music'] == music and entry['duration_seconds'] == duration, f'{name}: pair metadata')
        old = read_wav(root/'assets/audio/v01/source'/f'{name}.wav')
        if music:
            old = old[:30*SR].copy()
            old[:round(.025*SR)] *= np.linspace(0,1,round(.025*SR))[:,None]
            old[-round(.65*SR):] *= np.linspace(1,0,round(.65*SR))[:,None]
        new = read_wav(out/(f'source/music/{name}_mix.wav' if music else f'source/sfx/{name}.wav'))
        measured = []
        for version, source in zip(('v01', 'v02'), (old, new)):
            path = out/f'comparison/{name}_{version}.wav'
            data = pcm(path, duration, 2 if music else 1, True)
            gain = float(np.sum(data*source)/np.sum(source*source))
            require(gain > 0 and np.max(np.abs(data-source*gain)) < 2/32768, f'{path}: comparison not a gain-only copy of labeled source')
            stats = loudness(data, music)
            require(all(math.isfinite(v) for v in stats.values()) and stats['tp'] <= -1.9, f'{path}: measured true peak/loudness')
            recorded = entry['matching']['after'][0 if version == 'v01' else 1]
            require(abs(stats['i']-recorded['i']) <= .11 and abs(stats['tp']-recorded['tp']) <= .11, f'{path}: measured metrics differ from manifest')
            measured.append(stats['i'])
        require(abs(measured[0]-measured[1]) <= .3, f'{name}: measured A/B difference exceeds 0.3 LUFS')
        print(f'{name}: independently measured {measured[0]:.2f}/{measured[1]:.2f} LUFS')
    if args.baseline_ref is not None:
        protected = ['forest_arena', 'scripts', 'project.godot', 'assets/audio/v01']
        diff = subprocess.check_output(['git','diff','--name-only',args.baseline_ref,'--',*protected],cwd=root,text=True).strip()
        untracked = subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*protected],cwd=root,text=True).strip()
        require(not diff and not untracked, f'Runtime/v01 changed since {args.baseline_ref}: {diff} {untracked}')
        print(f'PASS: optional runtime/v01 unchanged audit against {args.baseline_ref}.')
    else:
        print('Runtime/v01 Git baseline audit not requested; use --baseline-ref to check a chosen ref.')
    require((root/'assets/audio/.gdignore').is_file(), 'Preview source not excluded from Godot import/export')
    print('PASS: 8 pairs, source/mix/stems/MIDI, inventory, provenance, fades, real loudness/true peak, and Godot import/export exclusion.')
    print('Not established: human listening approval, reference-level timbre/arrangement, full-track loops, or Android output.')


if __name__ == '__main__':
    main()
