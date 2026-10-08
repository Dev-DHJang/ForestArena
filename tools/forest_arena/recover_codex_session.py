#!/usr/bin/env python3
"""Repair oversized Codex display history; never edit rollout, goals or assets."""
import argparse
import base64
from contextlib import contextmanager
from datetime import datetime, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import shutil
import sqlite3
import sys
import uuid

TERMINAL = {'completed', 'failed', 'declined'}
TOOLS = {'mcpToolCall', 'commandExecution', 'fileChange'}
LIMIT = 8192


def digest(data):
    return hashlib.sha256(data).hexdigest()


def file_digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


@contextmanager
def connect(home, name, write=False):
    path = home / name
    if not path.is_file():
        raise ValueError(f'Missing database: {path}')
    conn = sqlite3.connect(path.resolve().as_uri() + ('?mode=rw' if write else '?mode=ro'), uri=True, timeout=10)
    conn.row_factory = sqlite3.Row
    try:
        with conn:
            yield conn
    finally:
        conn.close()


def validate_schema(conn):
    required = {'thread_id', 'item_id', 'item_type', 'item_json'}
    if not required <= {r['name'] for r in conn.execute('PRAGMA table_info(thread_items)')}:
        raise ValueError('Unsupported Codex thread_items schema; no repair performed')


def inspect(home, sid):
    with connect(home, 'thread_history_1.sqlite') as conn:
        validate_schema(conn)
        rows = [dict(r) for r in conn.execute(
            'SELECT item_type, count(*) AS count, sum(length(cast(item_json AS blob))) AS bytes '
            'FROM thread_items WHERE thread_id=? GROUP BY item_type', (sid,))]
    if not rows:
        raise ValueError('Thread has no display history in this Codex home')
    return {'thread_id': sid, 'display_bytes': sum(r['bytes'] for r in rows), 'types': rows}


def shrink(value):
    if isinstance(value, str):
        if len(value) > LIMIT:
            return value[:2000] + '\n[Display data shortened; full original preserved in recovery backup.]\n' + value[-500:]
        return value
    if isinstance(value, list):
        return [({'type': 'text', 'text': '[Media omitted from display cache; original preserved in backup.]'}
                 if isinstance(v, dict) and v.get('type') in {'image', 'audio'} else shrink(v)) for v in value]
    if isinstance(value, dict):
        return {k: shrink(v) for k, v in value.items() if k not in {'screenshot', 'screenshots'}}
    return value


def prepare_item(raw):
    item = json.loads(raw)
    if item.get('status') not in TERMINAL:
        return raw, None
    image_source = None
    if item.get('type') == 'imageGeneration' and item.get('status') == 'completed':
        if len(item.get('result', '')) <= LIMIT:
            return raw, None
        path = Path(item.get('savedPath') or '')
        if not path.is_file():
            # Keep the embedded original when a separate image file cannot be verified.
            return raw, None
        try:
            from PIL import Image
        except ImportError as exc:
            raise ValueError('Pillow is needed for image previews; install it in a Python environment first') from exc
        original = path.read_bytes()
        image = Image.open(io.BytesIO(original))
        image.load()
        image.thumbnail((192, 192), Image.Resampling.LANCZOS)
        output = io.BytesIO()
        image.save(output, format='PNG', optimize=True)
        preview = base64.b64encode(output.getvalue()).decode('ascii')
        # Already small previews must not cause repeated backups and changes.
        if len(preview) >= len(item['result']):
            return raw, None
        item['result'] = preview
        image_source = {'path': str(path), 'sha256': digest(original)}
    elif item.get('type') in TOOLS:
        item = shrink(item)
    else:
        return raw, None
    if item == json.loads(raw):
        return raw, None
    return json.dumps(item, ensure_ascii=False, separators=(',', ':')), image_source


def repair(home, sid):
    before = inspect(home, sid)
    plans = []
    images = []
    # Read a consistent view before writing any cache row. SQL never targets other threads.
    with connect(home, 'thread_history_1.sqlite') as conn:
        conn.execute('BEGIN')
        for row in conn.execute('SELECT item_id,item_json FROM thread_items WHERE thread_id=?', (sid,)):
            raw = row['item_json']
            new, image = prepare_item(raw)
            if new != raw:
                plans.append({'item_id': row['item_id'], 'before_sha256': digest(raw.encode()),
                              'after_sha256': digest(new.encode()), 'new': new})
                if image:
                    images.append(image)
        if not plans:
            return {**before, 'changed_items': 0, 'backup': None}
        stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S.%fZ')
        backup = home / 'recovery' / f'session-{sid}-{stamp}'
        backup.mkdir(parents=True, mode=0o700)
        os.chmod(backup, 0o700)
        for table in ('thread_items', 'thread_turns', 'thread_history_projection_state'):
            with (backup / f'{table}.jsonl').open('w', encoding='utf-8') as stream:
                for row in conn.execute(f'SELECT * FROM {table} WHERE thread_id=?', (sid,)):
                    stream.write(json.dumps(dict(row), ensure_ascii=False) + '\n')
    rollout_backups = []
    for root in ('sessions', 'archived_sessions'):
        for path in (home / root).glob(f'**/*{sid}*.jsonl'):
            stat = path.stat()
            target = backup / path.name
            if target.exists():
                raise ValueError('Ambiguous rollout backup name')
            shutil.copy2(path, target)
            if (path.stat().st_size, path.stat().st_mtime_ns) != (stat.st_size, stat.st_mtime_ns):
                raise ValueError(f'Rollout changed during backup; retry after stopping the running turn. Backup: {backup}')
            rollout_backups.append({'path': str(path), 'backup_name': target.name, 'sha256': file_digest(target)})
    if not rollout_backups:
        raise ValueError(f'No original rollout found; no cache write performed. Backup: {backup}')
    if (home / 'goals_1.sqlite').exists():
        with connect(home, 'goals_1.sqlite') as conn:
            rows = [dict(r) for r in conn.execute('SELECT * FROM thread_goals WHERE thread_id=?', (sid,))]
        (backup / 'thread_goals.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
    manifest = {'thread_id': sid, 'codex_home': str(home), 'display_before': before['display_bytes'],
                'changes': [{k: v for k, v in p.items() if k != 'new'} for p in plans],
                'images': images, 'rollouts': rollout_backups}
    (backup / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
    # Make backups durable before changing the live display cache.
    for file in backup.iterdir():
        if file.is_file():
            with file.open('rb') as stream:
                os.fsync(stream.fileno())
    for directory in (backup, backup.parent, home):
        directory_fd = os.open(directory, os.O_RDONLY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
    if any(file_digest(Path(i['path'])) != i['sha256'] for i in images):
        raise ValueError(f'An original image changed during preparation; no cache write performed. Backup: {backup}')
    with connect(home, 'thread_history_1.sqlite', write=True) as conn:
        conn.execute('BEGIN IMMEDIATE')
        # Verify all planned rows before the first update; a conflict rolls back the entire operation.
        for plan in plans:
            row = conn.execute('SELECT item_json FROM thread_items WHERE thread_id=? AND item_id=?',
                               (sid, plan['item_id'])).fetchone()
            if row is None or digest(row['item_json'].encode()) != plan['before_sha256']:
                raise ValueError(f'Cache changed concurrently; retry. Backup: {backup}')
        for plan in plans:
            conn.execute('UPDATE thread_items SET item_json=? WHERE thread_id=? AND item_id=?',
                         (plan['new'], sid, plan['item_id']))
    with connect(home, 'thread_history_1.sqlite') as conn:
        integrity = conn.execute('PRAGMA quick_check').fetchone()[0]
    if integrity != 'ok':
        raise ValueError(f'Database integrity check: {integrity}. Backup: {backup}')
    after = inspect(home, sid)
    report = {'thread_id': sid, 'changed_items': len(plans), 'image_previews': len(images),
              'display_before': before['display_bytes'], 'display_after': after['display_bytes'],
              'backup': str(backup), 'integrity': integrity}
    (backup / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    return report


def restore(home, sid, backup):
    manifest = json.loads((backup / 'manifest.json').read_text(encoding='utf-8'))
    if manifest['thread_id'] != sid or Path(manifest['codex_home']).resolve() != home.resolve():
        raise ValueError('Backup belongs to a different thread or Codex home')
    changes = {p['item_id']: p for p in manifest['changes']}
    originals = {}
    with (backup / 'thread_items.jsonl').open(encoding='utf-8') as stream:
        for line in stream:
            row = json.loads(line)
            if row['item_id'] in changes:
                if row['thread_id'] != sid or digest(row['item_json'].encode()) != changes[row['item_id']]['before_sha256']:
                    raise ValueError('Backup record hash or thread mismatch')
                originals[row['item_id']] = row['item_json']
    if originals.keys() != changes.keys():
        raise ValueError('Incomplete backup; no restore performed')
    with connect(home, 'thread_history_1.sqlite', write=True) as conn:
        validate_schema(conn)
        conn.execute('BEGIN IMMEDIATE')
        for item, plan in changes.items():
            row = conn.execute('SELECT item_json FROM thread_items WHERE thread_id=? AND item_id=?', (sid, item)).fetchone()
            if row is None or digest(row['item_json'].encode()) != plan['after_sha256']:
                raise ValueError('Display record changed since repair; refusing to overwrite newer data')
        for item, raw in originals.items():
            conn.execute('UPDATE thread_items SET item_json=? WHERE thread_id=? AND item_id=?', (raw, sid, item))
    return {'thread_id': sid, 'restored_items': len(originals), 'backup': str(backup)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('inspect', 'repair', 'restore'))
    parser.add_argument('thread_id', type=lambda s: str(uuid.UUID(s)))
    parser.add_argument('--codex-home', type=Path, default=Path(os.environ.get('CODEX_HOME') or Path.home() / '.codex'))
    parser.add_argument('--backup', type=Path, help='Required for restore; directory printed by repair')
    args = parser.parse_args()
    home = args.codex_home.expanduser().resolve()
    try:
        if args.action == 'restore':
            if not args.backup:
                parser.error('restore requires --backup')
            result = restore(home, args.thread_id, args.backup.expanduser().resolve())
        else:
            result = (inspect if args.action == 'inspect' else repair)(home, args.thread_id)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0
    except (ValueError, sqlite3.Error, OSError) as exc:
        print(f'Recovery stopped: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
