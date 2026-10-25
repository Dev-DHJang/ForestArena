"""Synthetic structural regressions; never edit character artwork."""
import hashlib
from pathlib import Path
import tempfile
import unittest
from PIL import Image, ImageDraw
from verify_personality_concepts import image_errors, check_review, ROSTER


class PersonalityConceptTest(unittest.TestCase):
    def report(self,root):
        report={}
        for i,cid in enumerate(ROSTER):
            path=root/f'{cid}.png'
            image=self.good_image()
            image.putpixel((101,101),(i,30,40,255))
            image.save(path)
            reference=root/f'assets/character/{cid}/concept/{cid}-concept-v01.png'
            reference.parent.mkdir(parents=True)
            image.save(reference)
            report[cid]={'path':path.name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                         'reference_concept_asset_id':f'{cid}-concept-v01',
                         'reference_sha256':hashlib.sha256(reference.read_bytes()).hexdigest()}
        return report

    def good_image(self):
        image=Image.new('RGBA',(1024,1536))
        ImageDraw.Draw(image).rectangle((100,100,900,1400),fill=(20,30,40,255))
        return image

    def test_real_transparent_canvas(self):
        self.assertEqual(image_errors(self.good_image()),[])

    def test_rgb_and_opaque_background_rejected(self):
        self.assertTrue(image_errors(self.good_image().convert('RGB')))
        self.assertTrue(image_errors(Image.new('RGBA',(1024,1536),'white')))

    def test_missing_margin_wrong_size_and_empty_rejected(self):
        image=self.good_image()
        image.putpixel((0,0),(1,2,3,1))
        self.assertTrue(any('48' in e for e in image_errors(image)))
        self.assertTrue(image_errors(Image.new('RGBA',(512,768))))
        self.assertTrue(image_errors(Image.new('RGBA',(1024,1536))))

    def test_review_hash_roster_and_path_validation(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            report=self.report(root)
            self.assertEqual(check_review(report,root),[])
            report['ja-hyun']['sha256']='changed'
            self.assertTrue(any('hash' in e for e in check_review(report,root)))
            report['ja-hyun']['path']='../outside.png'
            self.assertTrue(any('outside' in e for e in check_review(report,root)))
            del report['nabi']
            self.assertTrue(any('four' in e for e in check_review(report,root)))

    def test_duplicate_artwork_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            report=self.report(root)
            report['nabi']['path']=report['ja-hyun']['path']
            report['nabi']['sha256']=report['ja-hyun']['sha256']
            self.assertTrue(any('duplicate' in e for e in check_review(report,root)))

    def test_wrong_reference_id_and_hash_are_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory)
            report=self.report(root)
            report['yu-ran']['reference_concept_asset_id']='nabi-concept-v01'
            report['yu-ran']['reference_sha256']='changed'
            errors=check_review(report,root)
            self.assertTrue(any('reference concept ID' in e for e in errors))
            self.assertTrue(any('source hash' in e for e in errors))


if __name__=='__main__':
    unittest.main()
