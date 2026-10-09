#!/usr/bin/env python3
"""Create a versioned demo bundle from an explicit allowlist; no credentials."""
import hashlib
import json
from pathlib import Path
import shutil
import zipfile
ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'build/demo'
VERSION = '0.1.0-demo'


def main():
    apk = ROOT / 'build/android/ForestArena-demo.apk'
    pck = OUT / 'server.pck'
    for path in (apk, pck):
        if not path.is_file(): raise SystemExit('데모 APK와 server.pck를 먼저 생성하세요.')
    entries = {'ForestArena-demo.apk': apk, 'server/server.pck': pck}
    for pattern in ('server/api/src/**', 'database/migrations/*.sql', 'database/init/*.sh'):
        for path in ROOT.glob(pattern):
            if path.is_file(): entries['server/' + str(path.relative_to(ROOT))] = path
    for name in ('server/api/package.json', 'server/api/package-lock.json', 'server/api/tsconfig.json', 'database/compose.demo.yml', 'scripts/demo-server.sh', 'tools/forest_arena/demo_server.py', 'tools/forest_arena/demo_firewall.py'):
        entries['server/' + name] = ROOT / name
    entries['DEMO_README.md'] = ROOT / 'docs/gameplay/demo-install.md'
    entries['server/project.godot'] = ROOT / 'project.godot'
    manifest = {'version': VERSION, 'protocol_version': 2, 'package_id': 'com.forestarena.welllbeing', 'godot': '4.7.1', 'files': {name: hashlib.sha256(path.read_bytes()).hexdigest() for name, path in entries.items()}}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2, ensure_ascii=False)+'\n')
    bundle = OUT / f'ForestArena-{VERSION}.zip'
    with zipfile.ZipFile(bundle, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name, path in sorted(entries.items()): archive.write(path, name)
        archive.writestr('manifest.json', json.dumps(manifest, indent=2, ensure_ascii=False)+'\n')
    print('데모 묶음:', bundle)
    print('SHA-256:', hashlib.sha256(bundle.read_bytes()).hexdigest())


if __name__ == '__main__': main()
