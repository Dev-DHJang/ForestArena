#!/usr/bin/env python3
import argparse,json
from pathlib import Path
ap=argparse.ArgumentParser(); ap.add_argument('--project-root',default='.'); args=ap.parse_args(); root=Path(args.project_root).resolve()
regp=root/'forest_arena/data/resource_registry.json'
if not regp.exists(): raise SystemExit('registry not found')
r=json.loads(regp.read_text(encoding='utf-8')); errs=[]
assets=r.get('assets',[]); ids=[]
for a in assets:
    ids.append(a.get('id',''))
    if a.get('quality_dependent'):
        v=a.get('variants',{})
        if set(v)!={'high','medium','low'}: errs.append(a['id']+': variants')
        paths=v.values()
    else: paths=[a.get('path','')]
    for p in paths:
        if not p.startswith('res://forest_arena/'): errs.append(a['id']+': bad path '+p); continue
        if not (root/p.replace('res://','')).exists(): errs.append(a['id']+': missing '+p)
if len(ids) != len(set(ids)): errs.append('duplicate logical asset ID')
if any(not asset_id for asset_id in ids): errs.append('empty logical asset ID')
quality_count=sum(1 for a in assets if a.get('quality_dependent'))
if r.get('logical_asset_count') != len(assets): errs.append('logical_asset_count metadata mismatch')
if r.get('quality_dependent_count') != quality_count: errs.append('quality_dependent_count metadata mismatch')
if (root/'project.godot').exists():
    txt=(root/'project.godot').read_text(encoding='utf-8',errors='ignore'); line='ForestArenaResources="*res://forest_arena/scripts/forest_arena_resource_manager.gd"'
    if line not in txt: errs.append('autoload missing')
if errs:
    print('FAILED'); [print(' -',e) for e in errs]; raise SystemExit(1)
print(f"OK: {len(assets)} logical assets")
print(f"Quality-dependent assets: {quality_count} (high/medium/low)")
