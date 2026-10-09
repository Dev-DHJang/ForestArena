#!/usr/bin/env python3
"""Validate the exact approved nine-version mix and four runtime replacements."""
from __future__ import annotations
import argparse
import json
import subprocess
from pathlib import Path
from verify_audio_v02_preview import pcm, require, sha, ROOT
from audio_v02_sfx import SPECS

PREVIOUS = {'lobby','battle','jump','hit_heavy','myo-ryung_special_up'}
NEW = {'ui_click','hit_light','guard_break','ja-hyun_ultimate'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', type=Path, default=ROOT)
    parser.add_argument('--baseline-ref', help='Optional complete registry and audio-policy audit against integration baseline')
    args = parser.parse_args()
    root = args.project_root.resolve()
    manifest = json.loads((root/'assets/audio/v02-selected/manifest.json').read_text())
    require(manifest['status'] == 'user_approved' and manifest['approval_scope'] == 'nine_listed_previews', 'Wrong approval scope/status')
    require(manifest['runtime_connected'] is True and manifest['android_verified'] is False, 'Runtime/device verification claims')
    require(set(manifest['replacements']) == NEW and len(manifest['replacements']) == 4, 'Wrong replacement inventory')
    preview = json.loads((root/'assets/audio/v02-preview/manifest.json').read_text())
    preview_files = {e['path']:e for e in preview['files']}
    selections = manifest['selection']
    require(len(selections) == 9 and {e['name'] for e in selections} == PREVIOUS | NEW, 'Wrong approved selection inventory/duplicates')
    original = json.loads((root/'assets/audio/v01/manifest.json').read_text())
    originals = {e['name']:e for e in original['assets']}
    require(len(originals) == len(original['assets']) == 47, 'Original audio inventory')
    for entry in originals.values():
        require(sha(root/entry['runtime']) == entry['sha256'] and sha(root/entry['source']) == entry['source_sha256'], f"v01 preservation failed: {entry['name']}")
    registry = json.loads((root/'forest_arena/data/resource_registry.json').read_text())
    audio = {e['id']:e for e in registry['assets'] if e.get('category') == 'audio'}
    require(len(audio) == sum(e.get('category') == 'audio' for e in registry['assets']) == 47, 'Registry audio count/duplicates')
    require(set(audio) == {e['asset_id'] for e in originals.values()}, 'Registry audio ID scope')
    for name, old in originals.items():
        expected = f'forest_arena/assets/audio/v02-selected/{name}.wav' if name in NEW else old['runtime']
        require(audio[old['asset_id']]['path'] == 'res://'+expected and audio[old['asset_id']]['quality_dependent'] is False, f'Wrong logical runtime path: {name}')
    for entry in selections:
        name = entry['name']; old = originals[name]; new = name in NEW
        require(entry['version'] == ('v02' if new else 'v01') and entry['logical_id'] == old['asset_id'], f'Incorrect version/ID: {name}')
        require(entry['revision'] == (3 if new else 1), f'Incorrect revision: {name}')
        expected_source = f'assets/audio/v02-preview/source/sfx/{name}.wav' if new else old['source']
        expected_runtime = f'forest_arena/assets/audio/v02-selected/{name}.wav' if new else old['runtime']
        expected_audition = f'assets/audio/v02-preview/comparison/{name}_{"v02" if new else "v01"}.wav'
        require((entry['source'],entry['runtime'],entry['audition']) == (expected_source,expected_runtime,expected_audition), f'Incorrect source/runtime/audition: {name}')
        audition_record = preview_files[f'comparison/{name}_{"v02" if new else "v01"}.wav']
        require(entry['audition_sha256'] == audition_record['sha256'], f'{name}: audition is not the recorded approved comparison')
        for field in ('source','runtime','audition'):
            require(sha(root/entry[field]) == entry[field+'_sha256'], f'{name}: {field} hash')
        if new:
            require((root/expected_source).read_bytes() == (root/expected_runtime).read_bytes(), f'{name}: runtime is not exact raw source PCM')
            require(entry['source_sha256'] == preview_files[f'source/sfx/{name}.wav']['sha256'], f'{name}: source differs from preview inventory')
            require(entry['loop'] is False and entry['channels'] == 1 and entry['duration_seconds'] == SPECS[name][0], f'{name}: SFX loop/channel/duration metadata')
            pcm(root/expected_runtime, entry['duration_seconds'], 1, True)
        else:
            require(entry['loop'] is old['loop'] and entry['channels'] == old['channels'] and entry['duration_seconds'] == old['duration_seconds'], f'{name}: changed v01 loop/duration/channel')
    actual_runtime = {p.name for p in (root/'forest_arena/assets/audio/v02-selected').iterdir() if p.is_file() and p.suffix != '.import'}
    require(actual_runtime == {name+'.wav' for name in NEW}, 'Unexpected runtime replacement files')
    generator = manifest['generator']
    require(sha(root/generator['path']) == generator['sha256'], 'Selected manifest generator hash')
    rights = json.dumps(manifest['rights'], ensure_ascii=False).lower()
    require('original' in rights and ('sample-free' in rights or 'no external' in rights or 'no third-party' in rights), 'Missing selected SFX provenance/rights')
    require((root/'assets/audio/.gdignore').is_file(), 'Production sources exposed to Godot import')
    if args.baseline_ref:
        base = args.baseline_ref
        old_registry = json.loads(subprocess.check_output(['git','show',f'{base}:forest_arena/data/resource_registry.json'],cwd=root))
        expected_registry = json.loads(json.dumps(old_registry))
        for entry in expected_registry['assets']:
            if entry['id'] in {'fa.audio.'+name for name in NEW}:
                entry['path'] = 'res://forest_arena/assets/audio/v02-selected/'+entry['id'].removeprefix('fa.audio.')+'.wav'
        require(registry == expected_registry, 'Registry changed beyond the four approved paths')
        for relative in ('forest_arena/data/audio_events_v01.json','scripts/audio_director.gd','assets/audio/v01/manifest.json'):
            old = subprocess.check_output(['git','show',f'{base}:{relative}'],cwd=root)
            require((root/relative).read_bytes() == old, f'Changed event gain/bus/lifecycle or original metadata: {relative}')
        print(f'PASS: optional complete registry four-path-only and unchanged audio-policy audit against {base}.')
    print('PASS: nine approved versions; four raw-source PCM replacements; 47 stable audio IDs; v01 masters/runtime preserved; BGM 80/90-second loops and other 38 unchanged paths.')
    print('Not established: physical Android output, output routing/lifecycle on device, or eight-player listening mix.')


if __name__ == '__main__':
    main()
