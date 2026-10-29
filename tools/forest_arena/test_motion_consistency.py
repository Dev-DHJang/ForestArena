"""Regression checks for audit coverage and fixed-coordinate comparison evidence."""
import json,sys,tempfile,unittest
from unittest.mock import patch
from pathlib import Path
from PIL import Image
from audit_motion_consistency import composite,validate_sources,sha,prepare
from motion_layout import layout,frame_box

class EvidenceTests(unittest.TestCase):
    def test_variable_atlas_last_drawing_is_not_lost(self):
        for count in (16,24,32):
            spec=layout({'frame_count':count,'atlas_columns':16})
            sheet=Image.new('RGBA',spec['sheet_size'])
            sheet.paste((255,0,70,255),frame_box(count-1,spec))
            self.assertEqual(sheet.crop(frame_box(count-1,spec)).getpixel((127,127)),(255,0,70,255))
            self.assertIsNone(sheet.crop(frame_box(count-2,spec)).getbbox())
    def test_display_scale_does_not_fit_each_pose_to_bounds(self):
        a=Image.new('RGBA',(128,128));a.paste((255,0,0,255),(50,30,60,50))
        b=Image.new('RGBA',(128,128));b.paste((255,0,0,255),(50,30,60,50));b.paste((0,0,0,255),(120,0,128,5))
        first=composite(a,1,(0,-50));second=composite(b,1,(0,-50))
        self.assertEqual(first.crop((65,30,90,60)).tobytes(),second.crop((65,30,90,60)).tobytes())
        self.assertEqual(first.getpixel((70,34)),(255,0,0))
    def test_foot_pivot_and_body_root_are_observed_translations(self):
        cell=Image.new('RGBA',(128,128));cell.putpixel((64,124),(255,0,0,255))
        # fighter.y118 + sprite.y-46 + (124-64) = ground132.
        self.assertEqual(composite(cell,1,(0,-46)).getpixel((80,132)),(255,0,0))
        # body-root (54,100): x+10, sprite.y=14-(100-64)=-22.
        cell=Image.new('RGBA',(128,128));cell.putpixel((54,100),(255,0,0,255))
        self.assertEqual(composite(cell,1,(10,-22)).getpixel((80,132)),(255,0,0))
    def test_mirror_preserves_scale_and_vertical_placement(self):
        cell=Image.new('RGBA',(128,128));cell.putpixel((48,80),(255,0,0,255))
        self.assertEqual(composite(cell,1,(0,-50),flip=True).getpixel((95,84)),(255,0,0))
    def test_missing_or_changed_source_does_not_reuse_review(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);source=root/'sheet.png';source.write_bytes(b'original')
            snapshot={'sources':{'sheet.png':sha(source)}}
            self.assertEqual(validate_sources(root,snapshot),[])
            source.write_bytes(b'replaced')
            self.assertIn('changed source',validate_sources(root,snapshot)[0])
            source.unlink()
            self.assertIn('missing source',validate_sources(root,snapshot)[0])
    def test_prepare_contains_every_authored_drawing_for_all_counts(self):
        with tempfile.TemporaryDirectory() as folder:
            root=Path(folder);(root/'assets/character').mkdir(parents=True);(root/'docs/contracts').mkdir(parents=True)
            (root/'docs/contracts/character-appearance-v01.json').write_text('{}')
            rows=[];motions=[]
            for count in (16,24,32):
                cid=f'fixture-{count}';base=root/'assets/character'/cid/'reference/v01';base.mkdir(parents=True)
                for view in ['combat','front','side','rear']:Image.new('RGBA',(1024,1024)).save(base/(view+'.png'))
                (base/'reference.json').write_text('{}')
                path=f'assets/character/{cid}/sheet.png';sheet=Image.new('RGBA',layout({'frame_count':count})['sheet_size'])
                sheet.paste((255,0,70,255),frame_box(count-1,layout({'frame_count':count})));sheet.save(root/path)
                rows.append({'type':'animation-runtime','character_id':cid,'visual_state_id':'idle','path':path,'sha256':sha(root/path),'sprite_frames_path':'res://fixture.tres','frame_count':count})
                samples=[{'frame':i,'sprite_scale':[1,1],'sprite_position':[0,-46],'sprite_offset':[0,0]} for i in range(count)]
                motions.append({'character_id':cid,'motion':'idle','variants':[{'attack_id':'fixture','samples':samples}]})
            (root/'assets/character/manifest.json').write_text(json.dumps({'assets':rows}))
            timeline=root/'timeline.json';timeline.write_text(json.dumps({'sources':{},'motions':motions,'warnings':[]}))
            with patch('audit_motion_consistency.timeline_errors',return_value=[]):prepare(root,timeline,root/'out')
            coverage=json.loads((root/'out/coverage.json').read_text())
            self.assertEqual(coverage['frame_count'],72)
            for row in coverage['motions']:
                count=row['frame_count'];self.assertEqual(len(row['alpha_bounds']),count)
                board=Image.open(root/'out'/row['board'])
                self.assertEqual(board.size,(1280,160+((count+7)//8)*320))
                x=((count-1)%8)*160+80;y=160+((count-1)//8)*320+84
                red,green,blue=board.getpixel((x,y));self.assertGreater(red,230);self.assertLess(green,20)
    def test_invalid_scale_rejected(self):
        for scale in (0,-1,float('nan'),float('inf')):
            with self.assertRaises(ValueError):composite(Image.new('RGBA',(128,128)),scale,(0,0))

if __name__=='__main__':unittest.main()
