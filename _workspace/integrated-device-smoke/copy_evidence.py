"""기기 주소·serial·인증 값을 가린 사본만 Git용 증거로 만든다. 원본은 유지한다."""
from pathlib import Path
import argparse
import json
import re
import shutil
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'tools/forest_arena'))
from android_fleet import redact


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--source', type=Path, required=True)
    p.add_argument('--label', required=True)
    p.add_argument('--target-file', type=Path, required=True)
    args = p.parse_args()
    assert re.fullmatch(r'[a-z0-9-]+', args.label)
    targets = json.loads(args.target_file.read_text())
    private = {r[key] for r in targets for key in ('serial', 'hardware') if r.get(key)}
    def clean(value):
        if isinstance(value, dict):
            return {k: ('[device-private]' if 'serial' in k.lower() or k in ('port','lan_port','api_port') else clean(v)) for k,v in value.items()}
        if isinstance(value, list): return [clean(v) for v in value]
        if isinstance(value, str):
            value = redact(value)
            for identifier in sorted(private, key=len, reverse=True): value = value.replace(identifier, '[device-private]')
            return re.sub(r'(?<![A-Za-z0-9])(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?', '[ip-redacted]', value)
        return value
    dest = Path(__file__).resolve().parent / 'physical' / args.label
    count = 0
    for source in sorted(args.source.rglob('*')):
        if not source.is_file() or source.suffix not in ('.json','.jsonl','.log','.txt','.md','.png','.mp4'): continue
        relative = source.relative_to(args.source)
        if {'runner-source', 'runner-sources'} & set(relative.parts): continue
        target = dest / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        if source.suffix == '.json': target.write_text(json.dumps(clean(json.loads(source.read_text())),ensure_ascii=False,indent=2)+'\n')
        elif source.suffix == '.jsonl': target.write_text('\n'.join(json.dumps(clean(json.loads(row)),ensure_ascii=False) for row in source.read_text().splitlines() if row.strip())+'\n')
        elif source.suffix in ('.log','.txt','.md'):
            target.write_text('\n'.join(row.rstrip() for row in clean(source.read_text(errors='replace')).splitlines()).rstrip()+'\n')
        else: shutil.copy2(source, target)
        count += 1
    for target in dest.rglob('*'):
        if target.is_file() and target.suffix not in ('.png','.mp4'):
            data = target.read_text(); assert not any(identifier in data for identifier in private)
    print(f'Sanitized evidence: {count} files -> {dest}')


if __name__ == '__main__': main()
