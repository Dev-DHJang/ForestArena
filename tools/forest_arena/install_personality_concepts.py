"""Add exactly four hash-bound approved static variants; never replace a source asset."""
from pathlib import Path
import argparse
import hashlib
import json
import shutil
from PIL import Image
from verify_personality_concepts import ROSTER, ROOT, check_review, image_errors

TOPIC = Path('_workspace/character-personality-concepts')
REPORT_HASH = '65e21cdfade2232ac7cba52876a3252066f4ef6a6b72e1d151ca95e197bb0129'
APPROVED_IMAGES = {
    'ja-hyun': 'd05bc864b97fde740af736b0b32f03ec4bc8cd39e31c37c328d2d68fcdc3da9e',
    'myo-ryung': '078189c635b7b06246250ba48865e33d4df5008a8d6791bc8e7ea7f6f1c4b8fa',
    'nabi': '2e2b8ad595cf5a815c76b9884052df284a3eaefa582483be126389b9e64951ed',
    'yu-ran': 'aee6cf8dc63bf9b7e3396cc4000ca5db7404ed7d4edbad918c3ace1f8f8fbdd3',
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2)+'\n')


def approved_report(root=ROOT):
    work = root/TOPIC
    report_path = work/'normalized-candidates.json'
    approval = read(work/'approval.json')
    assert approval.get('user_approved') is True, 'Final image adoption approval required'
    assert approval.get('user_message') == '네 장 모두 등록 승인'
    assert approval.get('images') == APPROVED_IMAGES, 'Approval must cover exactly the reviewed four images'
    assert sha(report_path) == approval.get('report_sha256') == REPORT_HASH, 'Reviewed report changed'
    report = read(report_path)
    assert not check_review(report, root), check_review(report, root)
    assert {cid: row['sha256'] for cid, row in report.items()} == APPROVED_IMAGES
    for cid, row in report.items():
        source = (root/row['raw_source_path']).resolve()
        assert source.is_relative_to((work/'03_drafts').resolve()), f'Unexpected raw source: {cid}'
        assert source.exists() and sha(source) == row['raw_source_sha256'], f'Raw source changed: {cid}'
    return report, approval


def expected_entries(root=ROOT):
    report, approval = approved_report(root)
    entries = []
    for cid in ROSTER:
        row = report[cid]
        entries.append({
            'asset_id': f'{cid}-concept-personality-v01', 'character_id': cid,
            'type': 'concept-variant', 'variant': 'personality',
            'reference_concept_asset_id': row['reference_concept_asset_id'],
            'reference_sha256': row['reference_sha256'],
            'path': f'assets/character/{cid}/concept/{cid}-concept-personality-v01.png',
            'sha256': row['sha256'],
            'creation': {'method': 'built-in image generation using approved concept identity; user-approved local alpha cleanup and aspect-preserving placement',
                         'provider': 'OpenAI built-in image generation + project-local normalization', 'version': 'personality-v01'},
            'rights': {'status': 'derived from approved project character concept; user explicitly approved this additional final image; external license verification not asserted',
                       'references': [row['reference_concept_asset_id']]},
            'verified_on': approval['approved_on'],
            'modifications': ['Removed alpha below 8; aspect-preserving downscale only when needed; centered on transparent 1024x1536 canvas with at least 48px clear margin. No repaint or upscale.'],
            'consumer_path': f'assets/character/{cid}/concept/personality-v01.md',
            'personality_review': {'report_sha256': REPORT_HASH, 'approval_record': str(TOPIC/'approval.json'),
                                   'candidate_path': row['path'], 'raw_source_path': row['raw_source_path'],
                                   'raw_source_sha256': row['raw_source_sha256'], 'normalization': row['normalization']},
        })
    return entries


def without_personality_variants(assets, root=ROOT):
    """For historical preservation checks: accept only this exact approved addition.

    Unknown/partial variants, modified metadata, duplicate IDs or substituted PNGs
    fail rather than silently disappearing from the old manifest comparison.
    """
    variants = [e for e in assets if e.get('type') == 'concept-variant']
    ids = [e['asset_id'] for e in assets]
    assert len(ids) == len(set(ids)), 'Duplicate manifest ID'
    if not variants:
        return assets
    expected = expected_entries(root)
    assert {e['asset_id'] for e in variants} == {e['asset_id'] for e in expected}
    assert len(variants) == 4
    for entry in expected:
        assert entry in variants, entry['asset_id']
        target = root/entry['path']
        assert target.exists() and sha(target) == entry['sha256'], target
        with Image.open(target) as image:
            assert not image_errors(image), target
        assert (root/entry['consumer_path']).exists()
    return [e for e in assets if e.get('type') != 'concept-variant']


def check(root=ROOT, *, preserve_install_snapshot=False):
    """Validate the installed static variants; optionally audit the installation moment.

    Ongoing development may legitimately add approved motions and change gameplay
    code. Only an installation audit freezes every pre-install file. The current
    check always protects the four variants, their approvals and canonical sources.
    """
    work = root/TOPIC
    receipt = read(work/'installation.json')
    current = read(root/'assets/character/manifest.json')
    before_path = work/'07_before_install/manifest.json'
    assert sha(before_path) == receipt['before_manifest_sha256']
    before = read(before_path)
    assert current['schema_version'] == before['schema_version'] == 1
    assert [e for e in current['assets'] if e.get('type') == 'concept-variant'] == expected_entries(root), 'All four approved additions must remain installed'
    existing = without_personality_variants(current['assets'], root)
    old_concepts = {e['asset_id']: e for e in before['assets'] if e.get('type') == 'concept'}
    current_concepts = {e['asset_id']: e for e in existing if e.get('type') == 'concept'}
    assert current_concepts == old_concepts, 'Canonical concept entries changed'
    for entry in old_concepts.values():
        assert sha(root/entry['path']) == entry['sha256'], f"Canonical concept image changed: {entry['asset_id']}"
    if preserve_install_snapshot:
        assert existing == before['assets'], 'Existing manifest entries changed during installation'
        for path, digest in receipt['preserved_files'].items():
            assert sha(root/path) == digest, f'Existing asset, UI, combat or data file changed during installation: {path}'
    appearance = read(root/'docs/contracts/character-appearance-v01.json')
    old_appearance = read(work/'07_before_install/appearance.json')
    assert appearance['characters'] == old_appearance['characters'], 'Existing appearance profiles changed'
    assert receipt['report_sha256'] == REPORT_HASH
    print('PERSONALITY_CONCEPT_INSTALL: PASS (4 approved static variants; canonical sources unchanged%s)' % ('; installation snapshot preserved' if preserve_install_snapshot else ''))


def install(root=ROOT):
    entries = expected_entries(root)
    work = root/TOPIC
    backup = work/'07_before_install'
    assert not backup.exists(), 'Already prepared/installed; never overwrite backups'
    manifest_path = root/'assets/character/manifest.json'
    manifest = read(manifest_path)
    assert not any(e.get('type') == 'concept-variant' for e in manifest['assets'])
    assert len({e['asset_id'] for e in manifest['assets']}) == len(manifest['assets'])
    for entry in entries:
        assert not (root/entry['path']).exists(), 'Never overwrite an existing asset'
        assert (root/entry['consumer_path']).exists(), 'Design record missing'
    # Snapshot existing presentation/runtime sources, not another checkout's dirty baseline.
    preserved = {}
    for folder in ('assets', 'scripts', 'scenes', 'forest_arena'):
        for path in (root/folder).rglob('*'):
            if path.is_file() and path != manifest_path and path.suffix != '.import':
                preserved[str(path.relative_to(root))] = sha(path)
    backup.mkdir()
    shutil.copy2(manifest_path, backup/'manifest.json')
    shutil.copy2(root/'docs/contracts/character-appearance-v01.json', backup/'appearance.json')
    for entry in entries:
        shutil.copy2(root/entry['personality_review']['candidate_path'], root/entry['path'])
    write(manifest_path, {**manifest, 'assets': manifest['assets']+entries})
    write(work/'installation.json', {'report_sha256': REPORT_HASH,
          'before_manifest_sha256': sha(backup/'manifest.json'), 'preserved_files': preserved})
    check(root, preserve_install_snapshot=True)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--install', action='store_true')
    parser.add_argument('--verify-installation-snapshot', action='store_true', help='Also require every pre-install file and entry to remain unchanged; use for the original installation audit, not ongoing development')
    args = parser.parse_args()
    install() if args.install else check(preserve_install_snapshot=args.verify_installation_snapshot)
