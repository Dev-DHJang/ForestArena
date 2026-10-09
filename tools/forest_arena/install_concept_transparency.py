"""Install/check only explicitly approved alpha-only concept replacements."""
import argparse
import json
import shutil
import numpy as np
from PIL import Image
from normalize_concept_transparency import ROOT, WORK, ROSTER, sha

MANIFEST = ROOT / 'assets/character/manifest.json'


def validate_images(row, source, output):
    assert sha(source) == row['source_sha256']
    assert sha(output) == row['output_sha256']
    with Image.open(source) as original, Image.open(output) as final:
        assert final.mode == 'RGBA' and final.size == original.size == (1086,1448)
        assert final.getchannel('A').getextrema() == (0,255)
        assert np.array_equal(np.asarray(original.convert('RGB')), np.asarray(final.convert('RGB')))
        pixels = np.asarray(final)
        assert pixels[0,0,3] == pixels[-1,-1,3] == 0
        assert (pixels[:,:,3] == 0).mean() > 0.25
        # Every non-near-black source pixel survives: no hair/ears/clothing repaint or cut.
        if original.mode == 'RGB':
            assert np.all(pixels[np.asarray(original).max(axis=2)>6,3] == 255)


def check():
    receipt = json.loads((WORK / 'installation.json').read_text())
    approval = json.loads((WORK / 'approval.json').read_text())
    report_path = WORK / '02_local/report.json'
    assert approval['user_approved_local_alpha_cleanup'] is True
    assert approval['report_sha256'] == receipt['approval_report_sha256'] == sha(report_path)
    assert receipt['records'] == json.loads(report_path.read_text())
    assert tuple(r['character_id'] for r in receipt['records']) == ROSTER
    before = json.loads((WORK / '03_backup/manifest.json').read_text())
    current = json.loads(MANIFEST.read_text())
    changed = {r['character_id']:r for r in receipt['records'] if r['source_sha256'] != r['output_sha256']}
    assert current['schema_version'] == before['schema_version']
    assert len(current['assets']) == len(before['assets'])
    for old, entry in zip(before['assets'],current['assets']):
        cid = entry.get('character_id')
        if entry.get('type') != 'concept' or cid not in changed:
            assert entry == old, entry.get('asset_id')
        else:
            assert {k:v for k,v in entry.items() if k not in ('sha256','verified_on','modifications','transparency_cleanup')} == {k:v for k,v in old.items() if k not in ('sha256','verified_on','modifications','transparency_cleanup')}
            assert entry['sha256'] == changed[cid]['output_sha256']
            assert entry['modifications'][:-1] == old.get('modifications',[])
            assert entry['transparency_cleanup']['source_sha256'] == changed[cid]['source_sha256']
    for row in receipt['records']:
        source = WORK / '03_backup' / row['source_path'] if row['character_id'] in changed else ROOT / row['source_path']
        validate_images(row, source, ROOT / row['source_path'])
    print('CONCEPT_TRANSPARENCY: PASS (4 RGBA PNGs; source RGB unchanged; IDs/other manifest entries preserved)')


def install():
    approval = json.loads((WORK / 'approval.json').read_text())
    assert approval['user_approved_local_alpha_cleanup'] is True
    report_path = WORK / '02_local/report.json'
    assert approval['report_sha256'] == sha(report_path)
    records = json.loads(report_path.read_text())
    assert tuple(r['character_id'] for r in records) == ROSTER
    for row in records:
        validate_images(row, ROOT / row['source_path'], ROOT / row['output_path'])
    document = json.loads(MANIFEST.read_text())
    for row in records:
        entry = next(e for e in document['assets'] if e.get('type')=='concept' and e['character_id']==row['character_id'])
        assert entry['sha256'] == row['source_sha256'], 'Manifest changed before installation'
    backup = WORK / '03_backup'
    backup.mkdir(parents=True,exist_ok=True)
    assert not (backup / 'manifest.json').exists(), 'Already installed; use --check'
    shutil.copy2(MANIFEST, backup / 'manifest.json')
    for row in records:
        if row['source_sha256'] == row['output_sha256']:
            continue
        target = ROOT / row['source_path']
        saved = backup / row['source_path']
        saved.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(target,saved)
        shutil.copy2(ROOT / row['output_path'],target)
        entry = next(e for e in document['assets'] if e.get('type')=='concept' and e['character_id']==row['character_id'])
        assert entry['sha256'] == row['source_sha256']
        entry['sha256'] = row['output_sha256']
        entry['verified_on'] = '2026-10-09'
        entry.setdefault('modifications',[]).append('2026-10-09: User-approved local alpha cleanup of black backdrop and manually reviewed enclosed gaps. Original RGB bytes, dimensions, design, pose, logical ID and consumer path unchanged; real transparent RGBA PNG.')
        entry['transparency_cleanup'] = {'method':row['method'],'source_sha256':row['source_sha256'],
            'source_backup_path':str(saved.relative_to(ROOT)),
            'approval_record':str((WORK / 'approval.json').relative_to(ROOT))}
    MANIFEST.write_text(json.dumps(document,ensure_ascii=False,indent=2)+'\n')
    (WORK / 'installation.json').write_text(json.dumps({'records':records,'approval_report_sha256':sha(report_path)},ensure_ascii=False,indent=2)+'\n')
    check()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--install',action='store_true')
    args = parser.parse_args()
    install() if args.install else check()
