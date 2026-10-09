"""Deterministic regressions for motion extraction; no model calls or runtime writes."""
import unittest
import tempfile
import hashlib
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from motion_sheet_regions import split_regions
from recover_motion_review_sources import gray_review_alpha, verify_recovery_record
from audit_character_motion_visuals import detached_regions, validation_errors, EXPECTED_MOTIONS
from prepare_motion_integration import nearest_ignore_marker


class MotionVisualToolsTest(unittest.TestCase):
    def test_integration_copies_task_root_ignore_marker(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            task = root / '_workspace/chibi-task'
            source = task / '01_drafts/nabi/base/idle.png'
            source.parent.mkdir(parents=True)
            marker = task / '.gdignore'
            marker.touch()
            self.assertEqual(nearest_ignore_marker(source, root), marker)
            marker.unlink()
            self.assertIsNone(nearest_ignore_marker(source, root))

    def test_recovery_rejects_changed_upstream_or_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / 'source.png'
            output = root / 'output.png'
            Image.new('RGBA', (2, 2), (0, 0, 0, 255)).save(source)
            Image.new('RGBA', (2, 2), (1, 2, 3, 255)).save(output)
            record = {'source':source.name, 'output':output.name,
                      'source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),
                      'output_sha256':hashlib.sha256(output.read_bytes()).hexdigest()}
            verify_recovery_record(record, root)
            original = output.read_bytes()
            output.write_bytes(b'tampered')
            with self.assertRaises(AssertionError):
                verify_recovery_record(record, root)
            output.write_bytes(original)
            source.write_bytes(b'tampered')
            with self.assertRaises(AssertionError):
                verify_recovery_record(record, root)

    def audit_report(self):
        return {'characters':{cid:{'motions':[
            {'motion':f'motion_{i}', 'valid_runtime_shape':True,
             'manifest_sha_matches':True, 'valid_transparency':True,
             'nonempty_frames':16} for i in range(count)
        ]} for cid,count in EXPECTED_MOTIONS.items()}}

    def test_complete_audit_is_valid(self):
        self.assertEqual(validation_errors(self.audit_report()), [])

    def test_audit_rejects_missing_sheet_and_roster(self):
        report = self.audit_report()
        report['characters']['ja-hyun']['motions'].pop()
        self.assertTrue(validation_errors(report))
        del report['characters']['nabi']
        self.assertTrue(any('roster' in error for error in validation_errors(report)))

    def test_audit_rejects_bad_hash_alpha_and_empty_frame(self):
        report = self.audit_report()
        row = report['characters']['yu-ran']['motions'][0]
        row.update(manifest_sha_matches=False,valid_transparency=False,nonempty_frames=15)
        self.assertEqual(len(validation_errors(report)),3)

    def test_audit_rejects_duplicate_motion_names(self):
        report = self.audit_report()
        rows = report['characters']['myo-ryung']['motions']
        rows[1]['motion'] = rows[0]['motion']
        self.assertTrue(any('duplicate' in error for error in validation_errors(report)))

    def test_audit_rejects_stale_or_unknown_unregistered_sheet(self):
        report = self.audit_report()
        report['unregistered_sheets'] = [{'path':'legacy.png','approved_alias':True,'canonical_sha_matches':False}]
        self.assertTrue(validation_errors(report))
        report['unregistered_sheets'][0]['canonical_sha_matches'] = True
        self.assertEqual(validation_errors(report),[])
        report['unregistered_sheets'][0]['approved_alias'] = False
        self.assertTrue(validation_errors(report))

    def sheet(self):
        image=Image.new('RGBA',(400,400))
        draw=ImageDraw.Draw(image)
        for y in range(4):
            for x in range(4):
                # Deliberately cross a nominal cell edge without overlap.
                left=x*100+15
                top=y*100+10
                draw.rectangle((left,top,left+50,top+70),fill=(20,15,19,255))
                if x==0:
                    draw.rectangle((left+50,top+30,left+95,top+40),fill=(20,15,19,255))
        return image

    def test_regions_preserve_cross_grid_arm(self):
        frames=split_regions(self.sheet())
        self.assertEqual(len(frames),16)
        self.assertEqual(frames[0].width,96)
        self.assertEqual(frames[1].width,51)
        self.assertEqual(frames[0].getpixel((95,35)),(20,15,19,255))

    def test_missing_pose_is_rejected(self):
        image=self.sheet()
        ImageDraw.Draw(image).rectangle((300,300,399,399),fill=(0,0,0,0))
        with self.assertRaisesRegex(ValueError,'16 complete'):
            split_regions(image)

    def test_background_does_not_erase_dark_clothes(self):
        image=Image.new('RGB',(3,1))
        image.putdata([(50,55,60),(25,21,24),(220,220,230)])
        result=gray_review_alpha(image)
        self.assertEqual(result.getpixel((0,0))[3],0)
        self.assertEqual(result.getpixel((1,0)),(25,21,24,255))
        self.assertEqual(result.getpixel((2,0))[3],255)

    def test_detached_fragment_flag(self):
        alpha=np.zeros((128,128),dtype=np.uint8)
        alpha[40:100,30:90]=255
        alpha[3:7,40:50]=255
        self.assertEqual(len(detached_regions(alpha)),1)
        alpha[3:7,40:50]=0
        self.assertEqual(detached_regions(alpha),[])

    def test_light_neutral_background_preserves_white_and_pink(self):
        image=Image.new('RGB',(40,40),(114,117,119))
        draw=ImageDraw.Draw(image)
        draw.rectangle((12,12,20,20),fill=(245,232,235))
        draw.rectangle((21,12,28,20),fill=(215,100,130))
        result=gray_review_alpha(image)
        self.assertEqual(result.getpixel((0,0))[3],0)
        self.assertEqual(result.getpixel((15,15)),(245,232,235,255))
        self.assertEqual(result.getpixel((25,15)),(215,100,130,255))


if __name__=='__main__':
    unittest.main()
