"""Deterministic alpha cleanup regressions; no model/network calls."""
import unittest
import numpy as np
from PIL import Image, ImageDraw
from normalize_concept_transparency import remove_black_background


class ConceptTransparencyTest(unittest.TestCase):
    def image(self):
        image = Image.new('RGB', (64,64), 'black')
        draw = ImageDraw.Draw(image)
        draw.rectangle((8,8,55,55), fill=(30,20,40))
        draw.rectangle((20,20,43,43), fill='black')
        return image

    def test_preserves_rgb_and_large_enclosed_black_clothing(self):
        original = self.image()
        result, _ = remove_black_background(original)
        self.assertTrue(np.array_equal(np.asarray(original), np.asarray(result)[:,:,:3]))
        self.assertEqual(result.getpixel((0,0))[3], 0)
        self.assertEqual(result.getpixel((25,25))[3], 255)
        self.assertEqual(result.getpixel((10,10))[3], 255)

    def test_only_explicit_reviewed_gap_is_removed(self):
        result, report = remove_black_background(self.image(), [(20,20,44,44)])
        self.assertEqual(result.getpixel((25,25))[3], 0)
        self.assertEqual(report['enclosed_regions_removed'], 1)

    def test_changed_gap_geometry_is_rejected(self):
        with self.assertRaises(AssertionError):
            remove_black_background(self.image(), [(21,20,44,44)])


if __name__ == '__main__':
    unittest.main()
