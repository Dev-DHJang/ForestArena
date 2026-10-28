#!/usr/bin/env python3
import json
from pathlib import Path
import shutil
import tempfile
import unittest
from PIL import Image
from verify_branding import compare_icon, verify_assets, ROOT

class BrandingTests(unittest.TestCase):
    def test_opaque_pixel_change_rejected(self):
        a=Image.new('RGBA',(4,4),(255,100,60,255));b=a.copy();b.putpixel((2,2),(250,100,60,255))
        self.assertFalse(compare_icon(a,b)['valid'])

    def test_alpha_change_rejected(self):
        a=Image.new('RGBA',(4,4),(255,100,60,255));b=a.copy();b.putpixel((2,2),(255,100,60,254))
        self.assertFalse(compare_icon(a,b)['valid'])

    def test_invisible_rgb_is_irrelevant(self):
        a=Image.new('RGBA',(4,4),(255,100,60,0));b=Image.new('RGBA',(4,4),(0,0,0,0))
        self.assertTrue(compare_icon(a,b)['valid'])

    def test_scaled_image_rejected(self):
        self.assertFalse(compare_icon(Image.new('RGBA',(4,4)),Image.new('RGBA',(3,3)))['valid'])

    def fixture(self,p):
        shutil.copytree(ROOT/'assets/branding',p/'assets/branding')
        shutil.copytree(ROOT/'_workspace/myoryung-app-branding-v02/source',p/'_workspace/myoryung-app-branding-v02/source')
        for name in ['project.godot','export_presets.cfg']:shutil.copy2(ROOT/name,p/name)

    def test_sources_hash_and_body_connection(self):
        self.assertEqual(verify_assets()[0],[])

    def test_demo_cannot_revert_while_debug_stays_correct(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);self.fixture(p)
            config=p/'export_presets.cfg';parts=config.read_text().split('[preset.1]')
            self.assertEqual(len(parts),2)
            config.write_text(parts[0]+'[preset.1]'+parts[1].replace('myo-ryung-v02','myo-ryung-v01'))
            self.assertTrue(any('Android 아이콘 경로' in x for x in verify_assets(p)[0]))

    def test_source_corruption_is_caught(self):
        with tempfile.TemporaryDirectory() as tmp:
            p=Path(tmp);self.fixture(p)
            f=p/'assets/branding/myo-ryung-v02/main-192.png';f.write_bytes(f.read_bytes()+b'changed')
            self.assertTrue(any('해시 불일치' in x for x in verify_assets(p)[0]))

if __name__=='__main__':unittest.main()
