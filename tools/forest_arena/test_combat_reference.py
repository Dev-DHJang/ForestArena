"""승인 참조의 누락·변경·배치 변형 회귀 검사. 그림의 외형 판단은 하지 않는다."""
import copy
import json
from pathlib import Path
import tempfile
import unittest

from PIL import Image, ImageDraw

import combat_reference as ref


class ReferenceTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        concept = self.root / 'assets/character/ja-hyun/concept/ja-hyun-concept-v01.png'
        concept.parent.mkdir(parents=True)
        concept.write_bytes(b'approved-concept-fixture')
        contract = self.root / ref.CONTRACT
        contract.parent.mkdir(parents=True)
        contract.write_text('{}')
        work = self.root / '_workspace/test'
        work.mkdir(parents=True)
        marks = {}
        for i, view in enumerate(ref.VIEWS):
            source = Image.new('RGBA', (1024, 1024))
            ImageDraw.Draw(source).rectangle((400, 256, 624, 896), fill=(100+i, 80, 160, 255))
            source.save(work / f'{view}.png')
            marks[view] = dict(source_path=f'_workspace/test/{view}.png',
                               head_crown=[512, 256], chin=[512, 470],
                               soles=[[450, 896], [574, 896]])
        self.marks = work / 'marks.json'
        self.marks.write_text(json.dumps(marks))
        self.data = ref.assemble(self.root, 'ja-hyun', self.marks, work / 'candidates')

    def check(self, data=None, **kwargs):
        return ref.validate(self.root, data or self.data, **kwargs)

    def test_draft_structure_passes_but_is_not_approved(self):
        self.assertEqual(self.check(), [])
        self.assertTrue(self.check(require_approved=True))

    def test_missing_view_and_file_rejected(self):
        row = copy.deepcopy(self.data)
        del row['images']['rear']
        self.assertTrue(self.check(row))
        (self.root / self.data['images']['side']['path']).unlink()
        self.assertTrue(self.check())

    def test_changed_source_concept_contract_and_output_rejected(self):
        for value in ('reference_concept_sha256', 'appearance_contract_sha256'):
            row = copy.deepcopy(self.data)
            row[value] = 'stale'
            self.assertTrue(self.check(row))
        row = copy.deepcopy(self.data)
        row['images']['front']['source_sha256'] = 'stale'
        self.assertTrue(self.check(row))
        path = self.root / self.data['images']['front']['path']
        with Image.open(path) as image:
            image.putpixel((500, 500), (255, 0, 0, 255))
            image.save(path)
        self.data['images']['front']['sha256'] = ref.digest(path)
        self.assertTrue(any('uniform' in x for x in self.check()))

    def test_false_approval_and_hash_mismatch_rejected(self):
        self.data['status'] = 'approved'
        self.assertTrue(self.check())
        hashes = {k: x['sha256'] for k,x in self.data['images'].items()}
        for field, decision in [('approval', 'approved'), ('qa', 'pass')]:
            path = f'_workspace/test/{field}.json'
            (self.root / path).write_text(json.dumps(dict(character_id='ja-hyun', reference_version='v01',
                decision=decision, image_sha256=hashes, evidence='Unit-test decision fixture, not actual approval.')))
            self.data[field] = dict(status=decision, record=path, image_sha256=hashes.copy())
        self.assertEqual(self.check(require_approved=True), [])
        self.data['approval']['image_sha256']['rear'] = 'old'
        self.assertTrue(self.check(require_approved=True))

    def test_wrong_character_approval_record_rejected(self):
        self.test_false_approval_and_hash_mismatch_rejected()
        self.data['approval']['image_sha256']['rear'] = self.data['images']['rear']['sha256']
        path = self.root / self.data['approval']['record']
        data = json.loads(path.read_text())
        data['character_id'] = 'nabi'
        path.write_text(json.dumps(data))
        self.assertTrue(self.check(require_approved=True))

    def test_four_head_tall_consistent_set_rejected(self):
        for row in self.data['images'].values():
            row['head_height'] = 160
            row['chin'] = [512, 416]
            row['source_landmarks']['chin'] = [512, 416]
        self.assertTrue(any('three' in x for x in self.check()))

    def test_paths_outside_project_and_live_layout_rejected(self):
        row = copy.deepcopy(self.data)
        row['images']['front']['path'] = '../outside.png'
        self.assertTrue(self.check(row))
        with self.assertRaises(ValueError):
            ref.assemble(self.root, 'ja-hyun', self.marks, self.root / 'assets/reference')

    def test_wrong_landmarks_scale_and_geometry_rejected(self):
        for field, value in [('head_crown', [512, 1]), ('layout_scale', 0),
                             ('layout_scale', float('nan')), ('body_height', 800)]:
            row = copy.deepcopy(self.data)
            row['images']['front'][field] = value
            self.assertTrue(self.check(row), field)
        row = copy.deepcopy(self.data)
        row['geometry']['neutral_body_height'] = 700
        self.assertTrue(self.check(row))


if __name__ == '__main__':
    unittest.main()
