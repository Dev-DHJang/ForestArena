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
import re
import struct
import subprocess
import wave
from pathlib import Path
import numpy as np
from serve_audio_v02_preview import PreviewHandler
from audio_v02_sfx import SPECS, SR, effect
from generate_audio_v02_preview import SOUNDFONT_SHA256, PACKAGE_SHA256, FONT_URL, loudness, read_wav

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
        programs, pans = [], []
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
                elif event & 240 == 176 and pitch == 10:
                    pans.append((tick, event & 15, value))
            elif event & 240 == 192:
                programs.append((tick, event & 15, track[pos])); pos += 1
            else:
                raise ValueError(f'{path}: unexpected MIDI status {event}')
        require(ended, f'{path}: missing MIDI end')
        if index == 0:
            require(tempo == round(60_000_000/score['tempo_bpm']), f'{path}: MIDI tempo differs from score')
        else:
            source = score['tracks'][index-1]
            require(programs == [(0, source['channel'], source['program'])] and pans == [(0, source['channel'], source['pan'])], f'{path}: MIDI instrument/pan differs from score')
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


def verify_feedback_revision(root, out, baseline):
    """Check requested r02 changes without treating arrangement as listening approval."""
    manifest = json.loads((out/'manifest.json').read_text())
    require(manifest.get('revision') == 2 and set(manifest.get('feedback', {})) == {'ui_click','hit_heavy','lobby','battle'}, 'Expected r02 revision/feedback inventory')
    require('r02' in (out/'preview.html').read_text(), 'Preview missing latest r02 label')
    scores = {name: json.loads((out/f'source/music/{name}/score.json').read_text()) for name in ('lobby','battle')}
    require(all(score.get('revision') == 2 for score in scores.values()), 'Expected r02 music scores')
    lobby = {track['id']: track for track in scores['lobby']['tracks']}
    require(lobby['lead']['program'] == 0 and lobby['piano']['program'] == 0, 'r02 lobby needs piano melody and left-hand part')
    require(lobby['lead']['notes'] and lobby['piano']['notes'], 'r02 piano melody/left hand empty')
    require(lobby['lead']['gain'] > max(t['gain'] for key,t in lobby.items() if key != 'lead'), 'r02 piano melody gain should lead the arrangement')
    for bar in range(scores['lobby']['bars']):
        left = [n for n in lobby['piano']['notes'] if bar*4 <= n['beat'] < (bar+1)*4]
        require(len(left) >= 4 and min(n['pitch'] for n in left) < 60, f'r02 lobby left-hand accompaniment bar {bar}')
    battle = {track['id']: track for track in scores['battle']['tracks']}
    require(scores['battle']['key'] == 'A minor' and battle['strings']['program'] == 44 and battle['counter']['program'] == 42 and battle['lead']['program'] == 60, 'r02 battle minor/tremolo/cello/horn instrumentation')
    chords, bass_roots = [], []
    for bar in range(scores['battle']['bars']):
        counter = [n for n in battle['counter']['notes'] if bar*4 <= n['beat'] < (bar+1)*4]
        require(len(counter) == 8, f'r02 battle eight-note cello pulse bar {bar}')
        times = sorted(n['beat'] for n in counter)
        require(all(abs(b-a-.5) < .001 for a,b in zip(times,times[1:])), f'r02 cello eighth-note spacing bar {bar}')
        require(max(n['pitch'] for n in counter) <= 65 and max(n['length'] for n in counter) <= .4, f'r02 cello low/short pulse bar {bar}')
        harmonic = battle['strings']['notes'] + battle['bass']['notes']
        chords.append({n['pitch']%12 for n in harmonic if bar*4 <= n['beat'] < (bar+1)*4})
        bass_roots.append({n['pitch']%12 for n in battle['bass']['notes'] if bar*4 <= n['beat'] < (bar+1)*4})
    require(any({9,0,4} <= chord for chord in chords), 'r02 battle missing A minor harmony')
    require(any({11,2,5} <= chord for chord in chords), 'r02 battle missing diminished preparation')
    require(any({4,8,11,2} <= chord for chord in chords), 'r02 battle missing E7 tension')
    # Am/G contains C/E/G as a subset but is a minor pedal, not a C-root lift.
    require(not any(0 in bass and {0,4,7} <= chord for chord,bass in zip(chords,bass_roots)), 'r02 battle unexpectedly retains C-root major lift')
    old_battle = json.loads(subprocess.check_output(['git','show',f'{baseline}:assets/audio/v02-preview/source/music/battle/score.json'],cwd=root))
    old_tracks = {t['id']: t for t in old_battle['tracks']}
    require(battle['drums']['gain'] > old_tracks['drums']['gain'] and battle['bass']['gain'] > old_tracks['bass']['gain'], 'r02 battle drum/bass emphasis did not increase')
    require(max(n['velocity'] for n in battle['drums']['notes'] if n['pitch'] == 36) > max(n['velocity'] for n in old_tracks['drums']['notes'] if n['pitch'] == 36), 'r02 bass-drum attack not strengthened')
    for name in (set(SPECS)-{'hit_light'}):
        paths = [f'source/sfx/{name}.wav', f'comparison/{name}_v02.wav']
        if name not in ('ui_click','hit_heavy'): paths.append(f'comparison/{name}_v01.wav')
        for relative in paths:
            old = subprocess.check_output(['git','show',f'{baseline}:assets/audio/v02-preview/{relative}'],cwd=root)
            same = (out/relative).read_bytes() == old
            require(same == (name not in ('ui_click','hit_heavy')), f'r02 unexpected SFX change/preservation: {relative}')
    print(f'PASS: r02 piano lead/left hand, minor/E7/diminished pulse arrangement, changed click/hit and four unchanged SFX against {baseline}.')


def verify_feedback_r03(root, out, baseline):
    """Validate structural variety and requested SFX changes, not perceived quality."""
    manifest = json.loads((out/'manifest.json').read_text())
    require(manifest.get('revision') == 3 and set(manifest.get('feedback', {})) == {'hit_light','hit_heavy','guard_break','lobby','battle'}, 'Expected r03 manifest revision/feedback inventory')
    require('r03' in (out/'preview.html').read_text(), 'Preview missing latest r03 label')
    scores = {name: json.loads((out/f'source/music/{name}/score.json').read_text()) for name in ('lobby','battle')}
    for name, score in scores.items():
        require(score.get('revision') == 3 and score['duration_seconds'] == 60, f'{name}: r03 score scope')
        sections = score.get('sections', [])
        require(len(sections) == 4 and len({s['name'] for s in sections}) == 4, f'{name}: four named sections')
        cursor = 0
        for section in sections:
            require(section['start_bar'] == cursor and section['end_bar'] > cursor, f'{name}: section gap/overlap/empty')
            cursor = section['end_bar']
        require(cursor == score['bars'] and abs(score['bars']*4*60/score['tempo_bpm']-60) < .0001, f'{name}: sections do not cover 60-second score')
        tracks = {track['id']: track for track in score['tracks']}
        half_beats = score['bars']*2
        def phrase_signature(notes, start, end):
            # Ignore velocity and tiny human timing offsets: random jitter is not a new phrase.
            return sorted((round((n['beat']-start)*16), round(n['length']*20), n['pitch']) for n in notes if start <= n['beat'] < end)
        lead = tracks['lead']['notes']
        require(phrase_signature(lead,0,half_beats) != phrase_signature(lead,half_beats,2*half_beats), f'{name}: lead is an identical copied half')
        profiles = []
        for section in sections:
            a,b = section['start_bar']*4, section['end_bar']*4
            profiles.append(tuple(round(sum(a <= n['beat'] < b for n in track['notes'])/(b-a),3) for track in score['tracks']))
        require(len(set(profiles)) >= 3, f'{name}: section instrumentation density lacks contrast')
        require(any(max(row[i] for row in profiles)-min(row[i] for row in profiles) >= .25 for i in range(len(score['tracks']))), f'{name}: density contrast only trivial')
    lobby = {track['id']: track for track in scores['lobby']['tracks']}
    require(lobby['lead']['program'] == lobby['piano']['program'] == 0 and lobby['lead']['notes'] and lobby['piano']['notes'], 'r03 lobby piano melody/left hand')
    require(lobby['lead']['gain'] > max(t['gain'] for key,t in lobby.items() if key != 'lead'), 'r03 piano melody no longer leads arrangement')
    require(min(n['pitch'] for n in lobby['piano']['notes']) < 60, 'r03 piano left hand lacks low register')
    left_patterns = []
    for bar in range(scores['lobby']['bars']):
        notes = [n for n in lobby['piano']['notes'] if bar*4 <= n['beat'] < (bar+1)*4]
        if notes: left_patterns.append(tuple(sorted((round((n['beat']-bar*4)*16),round(n['length']*20)) for n in notes)))
    require(len(set(left_patterns)) >= 3, 'r03 piano left-hand rhythm/duration patterns still uniform')
    battle = {track['id']: track for track in scores['battle']['tracks']}
    require(scores['battle']['key'] == 'A minor' and battle['counter']['program'] == 42 and battle['strings']['program'] == 44 and battle['lead']['program'] == 60, 'r03 battle minor/cello character')
    chords, counts = [], []
    for bar in range(scores['battle']['bars']):
        counter = [n for n in battle['counter']['notes'] if bar*4 <= n['beat'] < (bar+1)*4]
        counts.append(len(counter))
        harmonic = battle['strings']['notes'] + battle['bass']['notes']
        chords.append({n['pitch']%12 for n in harmonic if bar*4 <= n['beat'] < (bar+1)*4})
    require(any({9,0,4} <= chord for chord in chords) and any({11,2,5} <= chord for chord in chords) and any({4,8,11,2} <= chord for chord in chords), 'r03 battle lost minor/diminished/E7 tension vocabulary')
    require(max(counts) >= 6 and len(set(counts)) >= 2, 'r03 cello pulse lacks repetition/section variation')
    require(np.median([n['pitch'] for n in battle['counter']['notes']]) <= 65, 'r03 cello pulse no longer low register')
    preserved = {'ui_click','jump','hit_heavy','myo-ryung_special_up','ja-hyun_ultimate'}
    for name in preserved:
        for relative in (f'source/sfx/{name}.wav',f'comparison/{name}_v01.wav',f'comparison/{name}_v02.wav'):
            old = subprocess.check_output(['git','show',f'{baseline}:assets/audio/v02-preview/{relative}'],cwd=root)
            require((out/relative).read_bytes() == old, f'r03 preserved SFX changed: {relative}')
    for relative in ('source/sfx/guard_break.wav','comparison/guard_break_v02.wav'):
        old = subprocess.check_output(['git','show',f'{baseline}:assets/audio/v02-preview/{relative}'],cwd=root)
        require((out/relative).read_bytes() != old, f'r03 metallic guard-break revision missing: {relative}')
    require('hit_light' in SPECS and (out/'source/sfx/hit_light.wav').is_file(), 'r03 light-impact fixture missing')
    require((out/'source/sfx/hit_light.wav').read_bytes() != (out/'source/sfx/hit_heavy.wav').read_bytes(), 'r03 light/heavy impacts identical')
    print(f'PASS: r03 60-second sections/phrase and accompaniment variety, retained tension, five unchanged SFX, revised guard and new light impact against {baseline}.')



def verify_selection(root, out, baseline):
    """Record four explicit A preferences without expanding them into full approval."""
    manifest = json.loads((out/'manifest.json').read_text())
    names = set(SPECS) | {'lobby','battle'}
    confirmed = {'lobby','battle','jump','myo-ryung_special_up'}
    selection = manifest.get('candidate_selection', [])
    require(len(selection) == 9 and {entry['name'] for entry in selection} == names, 'Selection inventory/duplicates')
    require(manifest['human_listening_approved'] is False and manifest['runtime_connected'] is False, 'Partial preference expanded into full approval/runtime change')
    for entry in selection:
        expected_version = 'v01' if entry['name'] in confirmed else 'v02'
        require(entry['version'] == expected_version and entry['preference_confirmed'] is (entry['name'] in confirmed), f"Incorrect preference: {entry['name']}")
        require(entry['source'] == f"comparison/{entry['name']}_{expected_version}.wav" and (out/entry['source']).is_file(), f"Incorrect selected source: {entry['name']}")
    retained = [path for path in out.rglob('*') if path.is_file() and (path.suffix in ('.wav','.mid') or path.name == 'score.json')]
    original_paths = subprocess.check_output(['git','ls-tree','-r','--name-only',baseline,'--','assets/audio/v02-preview'],cwd=root,text=True).splitlines()
    original_paths = {p for p in original_paths if p.endswith(('.wav','.mid','/score.json'))}
    current_paths = {'assets/audio/v02-preview/'+path.relative_to(out).as_posix() for path in retained}
    require(current_paths == original_paths, 'Selection changed musical artifact inventory')
    for path in retained:
        old = subprocess.check_output(['git','show',f'{baseline}:assets/audio/v02-preview/{path.relative_to(out).as_posix()}'],cwd=root)
        require(path.read_bytes() == old, f'Selection unexpectedly changed audio/score: {path}')
    preview = (out/'preview.html').read_text()
    ui_entries = re.findall(r"\{id:'([^']+)',selectedVersion:'(v0[12])',preferenceConfirmed:(true|false),", preview)
    require(len(ui_entries) == 9 and {row[0] for row in ui_entries} == names, 'UI selection inventory/duplicates')
    for name, version, preference in ui_entries:
        require(version == ('v01' if name in confirmed else 'v02') and (preference == 'true') == (name in confirmed), f'UI selection differs from manifest: {name}')
    require("track.selectedVersion==='v01'?'A · 이전 v01':'B · r03'" in preview and "track.preferenceConfirmed?'청취 선호 반영':'현재 후보 · 확인 전'" in preview and 'version===track.selectedVersion' in preview, 'Missing distinct selection label/display branches')
    require(manifest.get('selection_feedback', {}).get('whole_set_approved') is False, 'Selection feedback claims whole-set approval')
    require('묘령 · 위 특수기' in preview and '게임에 미연결' in preview and '청취 방향 확인 전' in preview, 'Selection scope/status labels')
    print(f'PASS: four confirmed A preferences/five unconfirmed B candidates, unchanged WAV/MIDI/scores against {baseline}, no full approval/runtime claim.')

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', type=Path, default=ROOT)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--http-only', action='store_true', help='Only test preview HTTP server on loopback')
    parser.add_argument('--skip-http', action='store_true', help='Signal/file checks only; explicitly skip HTTP check')
    parser.add_argument('--feedback-baseline-ref', help='Check current r02/r03 feedback against a previous preview Git ref')
    parser.add_argument('--selection-baseline-ref', help='Check selected candidate metadata and unchanged audio/score artifacts against a preview Git ref')
    parser.add_argument('--baseline-ref', default=None, help='Optional Git ref for unchanged runtime/v01 audit')
    args = parser.parse_args()
    if not args.skip_http: verify_http_server()
    if args.http_only: return
    root = args.project_root.resolve()
    out = (args.output or root/'assets/audio/v02-preview').resolve()
    manifest = json.loads((out/'manifest.json').read_text())
    require(manifest['version'] == 2 and manifest['stage'] == 'listening_preview', 'Not a v02 listening preview')
    require(manifest['runtime_connected'] is False and manifest['human_listening_approved'] is False, 'Preview must not claim runtime connection/human approval')
    revision = int(manifest.get('revision', 1))
    require(revision in (1,2,3), 'Unknown preview revision')
    music_seconds = 60 if revision == 3 else 30
    expected_sfx = set(SPECS) if revision == 3 else set(SPECS)-{'hit_light'}
    require(len(expected_sfx) == (7 if revision == 3 else 6), 'Expected SFX scope')
    expected_names = expected_sfx | {'lobby','battle'}
    require({c['name'] for c in manifest['comparisons']} == expected_names and len(manifest['comparisons']) == len(expected_names), 'Comparison pair scope/duplicates')
    require({s['name'] for s in manifest['sfx']} == expected_sfx and len(manifest['sfx']) == len(expected_sfx), 'SFX scope/duplicates')
    expected = {'preview.html', 'licenses/FluidR3-COPYRIGHT.txt'}
    expected |= {f'comparison/{name}_{v}.wav' for name in expected_names for v in ('v01', 'v02')}
    expected |= {f'source/sfx/{name}.wav' for name in expected_sfx}
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
    for name in expected_names:
        require("id:'"+name+"'" in preview, f'Preview missing {name}')
    require("comparison/'+track.id+'_'+version+'.wav'" in preview and 'playRequestSerial' in preview, 'Preview links/request cancellation')
    require('게임에 미연결' in preview and '청취 방향 확인 전' in preview, 'Preview status labels')
    require(not any(p.suffix == '.sf2' for p in out.rglob('*')), 'SoundFont unexpectedly bundled')
    for name in expected_sfx:
        duration = SPECS[name][0]
        actual = pcm(out/f'source/sfx/{name}.wav', duration, 1, True)
        expected_pcm = np.rint(effect(name)*32767).astype('<i2').astype(np.float64)/32768
        require(np.array_equal(actual, expected_pcm), f'{name}: source differs from fixed-seed SFX generator')
    for name in ('lobby', 'battle'):
        score = json.loads((out/f'source/music/{name}/score.json').read_text())
        require(score['name'] == name and score['duration_seconds'] == music_seconds and score['loop'] is False, f'{name}: score preview scope')
        require(len(score['tracks']) == 9 and {t['id'] for t in score['tracks']} == STEMS, f'{name}: nine instrument stems')
        midi_notes(out/f'source/music/{name}/score.mid', score)
        for stem in STEMS: pcm(out/f'source/music/{name}/{stem}.wav', music_seconds+2, 2)
        pcm(out/f'source/music/{name}_mix.wav', music_seconds, 2, True)
    for entry in manifest['comparisons']:
        name = entry['name']; music = name in ('lobby', 'battle')
        duration = music_seconds if music else SPECS[name][0]
        require(entry['music'] == music and entry['duration_seconds'] == duration, f'{name}: pair metadata')
        old = read_wav(root/'assets/audio/v01/source'/f'{name}.wav')
        if music:
            old = old[:music_seconds*SR].copy()
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
    if args.feedback_baseline_ref:
        if revision == 3:
            verify_feedback_r03(root, out, args.feedback_baseline_ref)
        else:
            verify_feedback_revision(root, out, args.feedback_baseline_ref)
    if args.selection_baseline_ref:
        verify_selection(root, out, args.selection_baseline_ref)
    if args.baseline_ref is not None:
        protected = ['forest_arena', 'scripts', 'project.godot', 'assets/audio/v01']
        diff = subprocess.check_output(['git','diff','--name-only',args.baseline_ref,'--',*protected],cwd=root,text=True).strip()
        untracked = subprocess.check_output(['git','ls-files','--others','--exclude-standard','--',*protected],cwd=root,text=True).strip()
        require(not diff and not untracked, f'Runtime/v01 changed since {args.baseline_ref}: {diff} {untracked}')
        print(f'PASS: optional runtime/v01 unchanged audit against {args.baseline_ref}.')
    else:
        print('Runtime/v01 Git baseline audit not requested; use --baseline-ref to check a chosen ref.')
    require((root/'assets/audio/.gdignore').is_file(), 'Preview source not excluded from Godot import/export')
    print(f'PASS: {len(expected_names)} pairs, source/mix/stems/MIDI, inventory, provenance, fades, real loudness/true peak, and Godot import/export exclusion.')
    print('Not established: human listening approval, reference-level timbre/arrangement, full-track loops, or Android output.')


if __name__ == '__main__':
    main()
