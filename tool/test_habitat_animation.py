import json
import unittest

import numpy as np
from PIL import Image

from habitat_model import load_model, sample_channel
from render_habitat_cat import CLIPS, OUTPUT, SOURCE, SIZE


class HabitatAnimationTest(unittest.TestCase):
    def test_rotation_uses_shortest_spherical_path_and_remains_normalized(self):
        a = np.array([0., 0., 0., 1.])
        b = np.array([0., 1., 0., 0.])
        result = sample_channel([0, 1], [a, b], 0.5, rotation=True)
        np.testing.assert_allclose(result, [0, 2**-0.5, 0, 2**-0.5])
        np.testing.assert_allclose(sample_channel([0, 1], [a, -a], 0.5, rotation=True), a)

    def test_channel_clamps_endpoints_and_honors_step(self):
        values = np.array([[0., 2, 4], [4, 6, 8]])
        np.testing.assert_allclose(sample_channel([0, 1], values, 0.5), [2, 4, 6])
        np.testing.assert_allclose(sample_channel([0, 1], values, -1), values[0])
        np.testing.assert_allclose(sample_channel([0, 1], values, 2), values[1])
        np.testing.assert_allclose(sample_channel([0, 1], values, 0.5, interpolation="STEP"), values[0])

    def test_original_walk_preserves_vertical_motion_relative_to_fixed_ground(self):
        raw = load_model(SOURCE, ground=0)
        ground = min(mesh.positions[:, 1].min() for mesh in raw)
        heights = []
        for time in np.linspace(0, 0.5, 9):
            meshes = load_model(SOURCE, animation="walk", time=time, ground=ground)
            heights.append(min(mesh.positions[:, 1].min() for mesh in meshes))
        self.assertGreater(np.ptp(heights), 0.02)

    def test_atlases_have_every_clip_direction_and_pose_without_clipping(self):
        metadata = json.loads((OUTPUT / 'animations.json').read_text())
        self.assertEqual(set(metadata['clips']), set(CLIPS))
        for clip, (_, count) in CLIPS.items():
            with self.subTest(clip=clip):
                image = Image.open(OUTPUT / f'{clip}.png')
                shadow = Image.open(OUTPUT / f'{clip}-shadow.png')
                self.assertEqual(image.size, (SIZE * count, SIZE * 4))
                self.assertEqual(shadow.size, image.size)
                self.assertEqual(len(metadata['clips'][clip]['bounds']), count * 4)
                for box in metadata['clips'][clip]['bounds']:
                    self.assertGreater(min(box[:2]), 0)
                    self.assertLess(max(box[2:]), SIZE)
                first = image.crop((0, 0, SIZE, SIZE)).tobytes()
                later = image.crop((SIZE * (count // 2), 0, SIZE * (count // 2 + 1), SIZE)).tobytes()
                self.assertNotEqual(first, later)
                image.close()
                shadow.close()


if __name__ == '__main__':
    unittest.main()
