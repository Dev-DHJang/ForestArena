#!/usr/bin/env python3
"""Apply the user's fixed nine-item audio decision; retain all other v01 assets."""
from pathlib import Path
import hashlib
import json
import shutil
import wave

ROOT = Path(__file__).resolve().parents[2]
DECISION = {
    'lobby': 'v01', 'battle': 'v01', 'ui_click': 'v02', 'jump': 'v01',
    'hit_light': 'v02', 'hit_heavy': 'v01', 'guard_break': 'v02',
    'myo-ryung_special_up': 'v01', 'ja-hyun_ultimate': 'v02',
}
BASELINE = '8d0591d2c929fedbd95c4b8b40740e877bf379b5'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def apply():
    registry_path = ROOT/'forest_arena/data/resource_registry.json'
    registry = json.loads(registry_path.read_text())
    resources = {item['id']: item for item in registry['assets']}
    selections = []
    for name, version in DECISION.items():
        music = name in ('lobby', 'battle')
        source = ROOT/('assets/audio/v01/source' if version == 'v01' else 'assets/audio/v02-preview/source/sfx')/f'{name}.wav'
        runtime = ROOT/'forest_arena/assets/audio'/('v01' if version == 'v01' else 'v02-selected')/f'{name}.{ "ogg" if music else "wav" }'
        audition = ROOT/'assets/audio/v02-preview/comparison'/f'{name}_{version}.wav'
        if version == 'v02':
            runtime.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, runtime)
        if not runtime.is_file():
            raise ValueError(f'Missing approved runtime: {runtime}')
        resources['fa.audio.'+name]['path'] = 'res://'+runtime.relative_to(ROOT).as_posix()
        with wave.open(str(source), 'rb') as stream:
            duration, channels = stream.getnframes()/stream.getframerate(), stream.getnchannels()
        selections.append({
            'name': name, 'version': version, 'revision': 1 if version == 'v01' else 3,
            'logical_id': 'fa.audio.'+name, 'runtime': runtime.relative_to(ROOT).as_posix(),
            'source': source.relative_to(ROOT).as_posix(), 'audition': audition.relative_to(ROOT).as_posix(),
            'runtime_sha256': sha(runtime), 'source_sha256': sha(source), 'audition_sha256': sha(audition),
            'loop': music, 'duration_seconds': duration, 'channels': channels,
        })
    registry_path.write_text(json.dumps(registry, ensure_ascii=False, indent=2)+'\n')
    manifest = {
        'version': 2, 'status': 'user_approved', 'approval_scope': 'nine_listed_previews',
        'approved_on': '2026-10-09', 'runtime_connected': True, 'android_verified': False,
        'baseline_ref': BASELINE, 'selection': selections,
        'replacements': [name for name, version in DECISION.items() if version == 'v02'],
        'generator': {'path': 'tools/forest_arena/apply_approved_audio_v02.py', 'sha256': sha(Path(__file__))},
        'rights': {'composition': 'Original project-authored v01 music and procedural SFX.',
                   'selected_v02_sfx': 'Original sample-free synthesis; no recordings, voices, or third-party samples.'},
        'playback': 'Existing event gain, buses, priorities, concurrency and lifecycle policy retained. Runtime v02 PCM is the source master; audition differs only by comparison gain.',
        'limits': ['Approval covers the nine named choices, not a v02 replacement of all 47 assets.',
                   'Physical Android audition and lifecycle verification remain deferred.'],
    }
    output = ROOT/'assets/audio/v02-selected'; output.mkdir(parents=True, exist_ok=True)
    (output/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n')
    print('Applied nine approved choices; four v02 PCM replacements, existing v01 loops retained.')


if __name__ == '__main__':
    apply()
