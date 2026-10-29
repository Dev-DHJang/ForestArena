"""대전 대표 이미지의 원본·배치·승인 기록 검사. 시각 QA는 별도로 수행한다."""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
VIEWS = ('combat', 'front', 'side', 'rear')
ROSTER = ('ja-hyun', 'myo-ryung', 'nabi', 'yu-ran')
CONTRACT = 'docs/contracts/character-appearance-v01.json'


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def local_path(root, value):
    path = (root / value).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError('project-relative path required')
    return path


def distance(a, b):
    return math.dist(a, b)


def place(source, scale, offset):
    """그림 부위 편집 없이 전체 원본을 한 번의 균일 배율·이동으로 배치한다."""
    return source.transform((1024, 1024), Image.Transform.AFFINE,
                            (1 / scale, 0, -offset[0] / scale,
                             0, 1 / scale, -offset[1] / scale),
                            Image.Resampling.BICUBIC)


def assemble(root, character_id, marks_path, output):
    if not output.resolve().is_relative_to((root / '_workspace').resolve()):
        raise ValueError('layout writes draft candidates under _workspace only')
    marks = json.loads(marks_path.read_text())
    concept = f'assets/character/{character_id}/concept/{character_id}-concept-v01.png'
    output.mkdir(parents=True, exist_ok=True)
    front = marks['front']
    front_scale = 640 / (max(p[1] for p in front['soles']) - front['head_crown'][1])
    target_head = distance(front['head_crown'], front['chin']) * front_scale
    entries = {}
    for view in VIEWS:
        mark = marks[view]
        source_path = local_path(root, mark['source_path'])
        with Image.open(source_path) as source:
            if source.mode != 'RGBA':
                raise ValueError(f'{view}: source must be RGBA')
            body = max(p[1] for p in mark['soles']) - mark['head_crown'][1]
            scale = (target_head / distance(mark['head_crown'], mark['chin'])
                     if view == 'combat' else 640 / body)
            feet_x = sum(p[0] for p in mark['soles']) / len(mark['soles'])
            offset = [512 - feet_x * scale,
                      896 - max(p[1] for p in mark['soles']) * scale]
            image = place(source, scale, offset)
            path = output / f'{view}.png'
            image.save(path)
        convert = lambda p: [round(p[0] * scale + offset[0], 4),
                             round(p[1] * scale + offset[1], 4)]
        entries[view] = dict(asset_id=f'{character_id}-motion-reference-{view}-v01',
                             path=path.relative_to(root).as_posix(), sha256=digest(path),
                             source_path=mark['source_path'], source_sha256=digest(source_path),
                             source_landmarks={k: mark[k] for k in ('head_crown', 'chin', 'soles')},
                             head_crown=convert(mark['head_crown']), chin=convert(mark['chin']),
                             chin_estimated=(view == 'rear'),
                             soles=[convert(p) for p in mark['soles']],
                             layout_scale=scale, layout_offset=offset,
                             body_height=round(body * scale, 4),
                             head_height=round(distance(mark['head_crown'], mark['chin']) * scale, 4))
    record = dict(schema_version=1, character_id=character_id, reference_version='v01',
                  status='draft', reference_concept_asset_id=f'{character_id}-concept-v01',
                  reference_concept_sha256=digest(root / concept),
                  appearance_contract_sha256=digest(root / CONTRACT),
                  approval={'status': 'pending', 'record': None, 'image_sha256': {}},
                  qa={'status': 'pending', 'record': None, 'image_sha256': {}},
                  geometry={'canvas_size': [1024, 1024], 'neutral_body_height': 640,
                            'foot_baseline_y': 896}, images=entries)
    (output / 'reference.json').write_text(json.dumps(record, ensure_ascii=False, indent=2) + '\n')
    return record


def validate(root, reference, require_approved=False):
    errors = []
    cid = reference.get('character_id')
    if reference.get('schema_version') != 1 or cid not in ROSTER:
        return ['unknown schema or character']
    if reference.get('reference_version') != 'v01':
        errors.append('unknown reference version')
    if reference.get('status') not in ('draft', 'approved'):
        errors.append('invalid status')
    if reference.get('geometry') != {'canvas_size': [1024, 1024],
                                    'neutral_body_height': 640, 'foot_baseline_y': 896}:
        errors.append('geometry differs from reference standard')
    if reference.get('reference_concept_asset_id') != f'{cid}-concept-v01':
        errors.append('wrong concept ID')
    for path, field in [(f'assets/character/{cid}/concept/{cid}-concept-v01.png',
                         'reference_concept_sha256'), (CONTRACT, 'appearance_contract_sha256')]:
        if not (root / path).is_file() or digest(root / path) != reference.get(field):
            errors.append(f'{field}: missing or changed')
    images = reference.get('images', {})
    if set(images) != set(VIEWS):
        return errors + ['exactly combat/front/side/rear required']
    paths = set()
    for view, row in images.items():
        try:
            path = local_path(root, row['path'])
            source_path = local_path(root, row['source_path'])
            if path in paths:
                errors.append(f'{view}: duplicate image path')
            paths.add(path)
            if row.get('asset_id') != f'{cid}-motion-reference-{view}-v01':
                errors.append(f'{view}: wrong asset ID')
            for file, field in [(path, 'sha256'), (source_path, 'source_sha256')]:
                if digest(file) != row[field]:
                    errors.append(f'{view}: {field} changed')
            scale, offset = row['layout_scale'], row['layout_offset']
            if not math.isfinite(scale) or scale <= 0 or len(offset) != 2 or not all(math.isfinite(x) for x in offset):
                raise ValueError('invalid layout transform')
            with Image.open(path) as image, Image.open(source_path) as source:
                if image.mode != 'RGBA' or image.size != (1024, 1024) or source.mode != 'RGBA':
                    errors.append(f'{view}: 1024 square RGBA and RGBA source required')
                    continue
                if image.tobytes() != place(source, scale, offset).tobytes():
                    errors.append(f'{view}: output differs from uniform source layout')
                alpha = image.getchannel('A')
                box = alpha.point(lambda x: 255 if x >= 16 else 0).getbbox()
                if alpha.getextrema() != (0, 255) or box is None:
                    errors.append(f'{view}: transparent background and solid body required')
                elif min(box[0], box[1], 1024 - box[2], 1024 - box[3]) < 16:
                    errors.append(f'{view}: insufficient margin or clipping')
            src = row['source_landmarks']
            for key in ('head_crown', 'chin', 'soles'):
                old = src[key] if key == 'soles' else [src[key]]
                new = row[key] if key == 'soles' else [row[key]]
                if len(old) != len(new) or len(new) < 1:
                    raise ValueError('missing landmarks')
                for a, b in zip(old, new):
                    expected = [a[0] * scale + offset[0], a[1] * scale + offset[1]]
                    if distance(expected, b) > .01 or not all(0 <= x < 1024 for x in b):
                        errors.append(f'{view}: inconsistent {key}')
            body = max(p[1] for p in row['soles']) - row['head_crown'][1]
            head = distance(row['head_crown'], row['chin'])
            if abs(body - row['body_height']) > .01 or abs(head - row['head_height']) > .01:
                errors.append(f'{view}: inconsistent measured dimensions')
            if abs(max(p[1] for p in row['soles']) - 896) > .01 or abs(sum(p[0] for p in row['soles']) / len(row['soles']) - 512) > .01:
                errors.append(f'{view}: wrong foot baseline or center')
            if view != 'combat' and abs(body - 640) > .01:
                errors.append(f'{view}: neutral body must be 640px')
            if view in ('front', 'side') and not 2.6 <= body / head <= 3.4:
                errors.append(f'{view}: neutral body/head ratio must be approximately three (2.6..3.4)')
            if row.get('chin_estimated') is not (view == 'rear'):
                errors.append(f'{view}: rear chin must be marked estimated; front/side/combat must be observed')
            front_head = images['front']['head_height']
            if abs(head / front_head - 1) > .08:
                errors.append(f'{view}: head proportion differs by more than 8%; visual review required')
        except (KeyError, ValueError, TypeError, OSError, ZeroDivisionError) as exc:
            errors.append(f'{view}: {exc}')
    if require_approved or reference.get('status') == 'approved':
        expected = {k: row['sha256'] for k, row in images.items()}
        if reference.get('status') != 'approved':
            errors.append('approved reference status required')
        for field, decision in [('approval', 'approved'), ('qa', 'pass')]:
            section = reference.get(field, {})
            if section.get('status') != decision or section.get('image_sha256') != expected:
                errors.append(f'{field}: decision for these image hashes required')
            try:
                record = json.loads(local_path(root, section['record']).read_text())
                if (record.get('character_id') != cid or record.get('reference_version') != reference['reference_version']
                    or record.get('decision') != decision or record.get('image_sha256') != expected
                    or not record.get('evidence')):
                    errors.append(f'{field}: record does not match character/version/hashes/evidence')
            except (KeyError, ValueError, TypeError, OSError):
                errors.append(f'{field}: structured decision record missing or invalid')
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--project-root', type=Path, default=ROOT)
    commands = parser.add_subparsers(dest='command', required=True)
    layout = commands.add_parser('layout')
    layout.add_argument('--character', choices=ROSTER, required=True)
    layout.add_argument('--landmarks', type=Path, required=True)
    layout.add_argument('--output', type=Path, required=True)
    check = commands.add_parser('validate')
    check.add_argument('--reference', type=Path, required=True)
    check.add_argument('--require-approved', action='store_true')
    args = parser.parse_args()
    root = args.project_root.resolve()
    if args.command == 'layout':
        record = assemble(root, args.character, args.landmarks, args.output.resolve())
        errors = validate(root, record)
    else:
        errors = validate(root, json.loads(args.reference.read_text()), args.require_approved)
    for error in errors:
        print('FIX:', error)
    if errors:
        raise SystemExit(1)
    print('COMBAT_REFERENCE_STRUCTURE: PASS (checks recorded evidence consistency, not human judgment)')


if __name__ == '__main__':
    main()
