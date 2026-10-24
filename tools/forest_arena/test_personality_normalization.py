"""Synthetic-only tests. These are not approvals to edit character artwork."""
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import numpy as np
from PIL import Image, ImageDraw
from normalize_personality_concepts import POLICY, normalize_image, prepare_review
from verify_personality_concepts import ROSTER, image_errors, check_review


class PersonalityNormalizationTest(unittest.TestCase):
    def raw(self,color=(40,80,120,255)):
        image=Image.new('RGBA',(1024,1536))
        ImageDraw.Draw(image).rectangle((4,4,1020,1532),fill=color)
        image.putpixel((0,0),(200,100,50,1))
        return image

    def fixture(self,root):
        work=root/'_workspace/character-personality-concepts'
        drafts=work/'03_drafts'
        drafts.mkdir(parents=True)
        report={}
        for i,cid in enumerate(ROSTER):
            path=drafts/f'{cid}.png'
            self.raw((40+i,80,120,255)).save(path)
            reference=root/f'assets/character/{cid}/concept/{cid}-concept-v01.png'
            reference.parent.mkdir(parents=True)
            reference.write_bytes(path.read_bytes())
            report[cid]={'path':str(path.relative_to(root)),
                'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'reference_concept_asset_id':f'{cid}-concept-v01',
                'reference_sha256':hashlib.sha256(reference.read_bytes()).hexdigest()}
        report_path=work/'review-candidates.json'
        report_path.write_text(json.dumps(report))
        permission_path=work/'synthetic-permission.json'
        permission={'user_approved_local_normalization':True,
            'raw_report_sha256':hashlib.sha256(report_path.read_bytes()).hexdigest(),
            'policy':POLICY.copy()}
        return work,report_path,permission_path,permission

    def test_shrink_and_margin_without_mutating_input(self):
        image=self.raw()
        before=image.tobytes()
        final,details=normalize_image(image)
        self.assertEqual(image.tobytes(),before)
        self.assertEqual(image_errors(final),[])
        self.assertLess(details['uniform_scale'],1.0)
        self.assertEqual(final.getpixel((0,0)),(0,0,0,0))
        self.assertEqual(final.getpixel((512,768)),(40,80,120,255))

    def test_no_upscale_or_double_alpha_and_internal_holes_preserved(self):
        image=Image.new('RGBA',(1024,1536))
        draw=ImageDraw.Draw(image)
        draw.rectangle((300,300,700,1200),fill=(40,80,120,254))
        draw.rectangle((450,700,550,800),fill=(0,0,0,0))
        image.putpixel((310,310),(40,80,120,8))
        image.putpixel((0,0),(1,2,3,1))
        final,details=normalize_image(image)
        self.assertEqual(details['uniform_scale'],1.0)
        self.assertEqual(final.getchannel('A').getextrema(),(0,254))
        for alpha in (8,254):
            self.assertEqual(int((np.asarray(image)[:,:,3]==alpha).sum()),
                             int((np.asarray(final)[:,:,3]==alpha).sum()))
        self.assertEqual(image_errors(final),[])

    def test_invalid_or_empty_input_rejected(self):
        for image in (Image.new('RGB',(1024,1536)),Image.new('RGBA',(1024,1536)),
                      Image.new('RGBA',(1024,1536),'white')):
            with self.assertRaises(ValueError):
                normalize_image(image)

    def test_missing_or_false_permission_creates_no_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            work,report,permission,record=self.fixture(root)
            with self.assertRaises(PermissionError):
                prepare_review(report,permission,root)
            record['user_approved_local_normalization']=False
            permission.write_text(json.dumps(record))
            with self.assertRaises(PermissionError):
                prepare_review(report,permission,root)
            self.assertFalse((work/'05_normalized').exists())
            self.assertFalse((work/'normalized-candidates.json').exists())

    def test_stale_report_or_changed_policy_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            work,report,permission,record=self.fixture(root)
            valid=record['raw_report_sha256']
            record['raw_report_sha256']='changed'
            permission.write_text(json.dumps(record))
            with self.assertRaises(PermissionError):
                prepare_review(report,permission,root)
            record['raw_report_sha256']=valid
            record['policy']['alpha_threshold']=128
            permission.write_text(json.dumps(record))
            with self.assertRaises(PermissionError):
                prepare_review(report,permission,root)
            self.assertFalse((work/'05_normalized').exists())

    def test_synthetic_preparation_is_not_artwork_approval_or_registration(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            work,report,permission,record=self.fixture(root)
            permission.write_text(json.dumps(record))
            originals={p:p.read_bytes() for p in root.rglob('*.png')}
            result=prepare_review(report,permission,root)
            self.assertEqual(check_review(result,root),[])
            self.assertTrue(all(row['user_approved'] is False for row in result.values()))
            for path,data in originals.items():
                self.assertEqual(path.read_bytes(),data)
            self.assertFalse((root/'assets/character/manifest.json').exists())
            with self.assertRaises(FileExistsError):
                prepare_review(report,permission,root)


if __name__=='__main__':
    unittest.main()
