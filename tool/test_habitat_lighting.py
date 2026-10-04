"""Asset geometry regressions: python -m unittest discover -s tool -p 'test_*.py'."""

import json
import math
import unittest

import numpy as np

from build_habitat_lighting import DIRECTIONS, NATURE, NATURE_NAMES, mesh_triangles, project


class HabitatLightingTest(unittest.TestCase):
    def test_camera_projection_matches_existing_sprites_in_every_direction(self):
        bounds = json.loads((NATURE / "Isometric" / "habitat_bounds.json").read_text())
        for name in NATURE_NAMES:
            triangles = mesh_triangles(NATURE / "Models" / "GLTF_format" / f"{name}.glb")
            for rotation, direction in enumerate(DIRECTIONS):
                with self.subTest(model=name, direction=direction):
                    angle = rotation * math.pi / 2
                    rotated = triangles.copy()
                    rotated[..., 0] = triangles[..., 0] * math.cos(angle) - triangles[..., 2] * math.sin(angle)
                    rotated[..., 2] = triangles[..., 0] * math.sin(angle) + triangles[..., 2] * math.cos(angle)
                    points = project(rotated).reshape(-1, 2) * 64 * math.sqrt(2) + [256, 315.5]
                    left, top, width, height = bounds[f"{name}_{direction}"]
                    # Raster antialiasing adds up to two pixels outside the mesh.
                    np.testing.assert_allclose(points.min(axis=0), [left, top], atol=2.1)
                    np.testing.assert_allclose(points.max(axis=0), [left + width, top + height], atol=2.1)

    def test_each_solid_has_its_own_shadow_and_ground_contact(self):
        profiles = json.loads((NATURE / "Isometric" / "habitat_lighting.json").read_text())
        for key, profile in profiles.items():
            with self.subTest(sprite=key):
                self.assertTrue(profile["shadow"])
                self.assertTrue(profile["contact"])
                for polygon in profile["shadow"] + profile["contact"]:
                    self.assertTrue(np.isfinite(polygon).all())
        silhouettes = {
            json.dumps(profiles[key]["shadow"])
            for key in ("tree_default_NE", "bed_NE", "tent_smallOpen_NE", "building-type-a", "animal-cat")
        }
        self.assertEqual(len(silhouettes), 5)

    def test_ground_centers_follow_the_model_base_in_every_direction(self):
        profiles = json.loads((NATURE / "Isometric" / "habitat_lighting.json").read_text())
        for name in NATURE_NAMES:
            if name == 'fence_simple':
                continue
            triangles = mesh_triangles(NATURE / 'Models' / 'GLTF_format' / f'{name}.glb')
            for rotation, direction in enumerate(DIRECTIONS):
                with self.subTest(model=name, direction=direction):
                    angle = rotation * math.pi / 2
                    rotated = triangles.copy()
                    rotated[..., 0] = triangles[..., 0] * math.cos(angle) - triangles[..., 2] * math.sin(angle)
                    rotated[..., 2] = triangles[..., 0] * math.sin(angle) + triangles[..., 2] * math.cos(angle)
                    minimum, maximum = rotated.min(axis=(0, 1)), rotated.max(axis=(0, 1))
                    center = (minimum + maximum) / 2
                    center[1] = 0
                    profile = profiles[f'{name}_{direction}']
                    np.testing.assert_allclose(project(center) * 64 * math.sqrt(2), profile['groundCenter'], atol=0.001)
                    np.testing.assert_allclose((maximum - minimum)[[0, 2]] * 64, profile['groundSize'], atol=0.001)
                    if name == 'bed':
                        self.assertEqual(profile['groundSize'][0] > profile['groundSize'][1], bool(rotation % 2))


if __name__ == "__main__":
    unittest.main()
