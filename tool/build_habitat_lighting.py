"""Bake fixed ground shadows from source meshes; no GLB is loaded by the app.

Run with Python, NumPy and Pillow after changing a Habitat model or preview.
Coordinates are expressed in source PNG pixels, relative to the ground origin.
The Kenney nature sprites use a 30-degree orthographic camera at azimuth 45.
"""

import json
import math
from pathlib import Path

import numpy as np
from habitat_model import load_model
from habitat_assets import DECORATIONS

ROOT = Path(__file__).resolve().parents[1] / "assets" / "3d_assets"
NATURE = ROOT / "kenney_nature-kit"
DIRECTIONS = ("NE", "SE", "SW", "NW")
NATURE_NAMES = (
    "bed", "bed_floor", "fence_simple", "flower_redA", "flower_yellowA",
    "grass", "log_large", "plant_bushSmall", "plant_flatShort", "rock_largeA",
    "rock_smallA", "tent_detailedOpen", "tent_smallOpen", "tree_default",
    "tree_detailed", "tree_oak", "tree_pineTallA", "tree_pineDefaultA",
) + tuple(asset.name for asset in DECORATIONS if asset.pack == 'kenney_nature-kit')
def mesh_triangles(path: Path) -> np.ndarray:
    return np.concatenate([mesh.positions[mesh.indices] for mesh in load_model(path)])


def project(vertices: np.ndarray) -> np.ndarray:
    x, y, z = np.moveaxis(vertices, -1, 0)
    return np.stack(((x - z) / math.sqrt(2),
                     (x + z) / math.sqrt(8) - y * math.sqrt(3) / 2), axis=-1)


def ground_projection(vertices: np.ndarray, cast: bool) -> np.ndarray:
    ground = vertices.copy()
    if cast:
        # Light from upper-right; a fixed shadow extending left and slightly back.
        ground[..., 0] -= ground[..., 1] * 0.60
        ground[..., 2] += ground[..., 1] * 0.16
    ground[..., 1] = 0
    return project(ground)


def polygons(vertices: list[np.ndarray], scale: float) -> list[list[float]]:
    result = []
    seen = set()
    for polygon in vertices:
        polygon = np.round(polygon * scale, 2)
        area = sum(polygon[i, 0] * polygon[(i + 1) % len(polygon), 1]
                   - polygon[i, 1] * polygon[(i + 1) % len(polygon), 0]
                   for i in range(len(polygon)))
        if abs(area) < 0.05:
            continue
        if area < 0:
            polygon = polygon[::-1]
        # A consistently wound compound path fills overlapping triangles once.
        key = tuple(sorted(map(tuple, polygon)))
        if key not in seen:
            result.append(polygon.ravel().tolist())
            seen.add(key)
    return result


def contact_sections(triangles: np.ndarray) -> list[np.ndarray]:
    ceiling = triangles[:, :, 1].max() * 0.035
    sections = []
    for triangle in triangles:
        clipped = []
        for index, a in enumerate(triangle):
            b = triangle[(index + 1) % 3]
            if a[1] <= ceiling:
                clipped.append(a)
            if (a[1] <= ceiling) != (b[1] <= ceiling):
                clipped.append(a + (b - a) * ((ceiling - a[1]) / (b[1] - a[1])))
        if len(clipped) >= 3:
            sections.append(ground_projection(np.array(clipped), False))
    return sections


def bake(triangles: np.ndarray, scale: float = 64 * math.sqrt(2), origin: list[float] | None = None) -> dict:
    origin = [256, 315.5] if origin is None else origin
    minimum = triangles.min(axis=(0, 1))
    maximum = triangles.max(axis=(0, 1))
    center = (minimum + maximum) / 2
    center[1] = 0
    return {
        "origin": origin,
        "groundCenter": (project(center) * scale).tolist(),
        "groundSize": ((maximum - minimum)[[0, 2]] * scale / math.sqrt(2)).tolist(),
        "shadow": polygons(ground_projection(triangles, True), scale),
        "contact": polygons(contact_sections(triangles), scale),
    }


def main() -> None:
    output = {}
    for name in NATURE_NAMES:
        triangles = mesh_triangles(NATURE / "Models" / "GLTF_format" / f"{name}.glb")
        for rotation, direction in enumerate(DIRECTIONS):
            angle = rotation * math.pi / 2
            rotated = triangles.copy()
            rotated[..., 0] = triangles[..., 0] * math.cos(angle) - triangles[..., 2] * math.sin(angle)
            rotated[..., 2] = triangles[..., 0] * math.sin(angle) + triangles[..., 2] * math.cos(angle)
            key = f"{name}_{direction}"
            if name == "fence_simple":
                rotated[..., 1] *= 1.6
            output[key] = bake(rotated)
            if name == "fence_simple":
                # Perimeter segments must keep their shared tile-edge anchor.
                output[key]["depthCenter"] = output[key]["groundCenter"]
                output[key]["groundCenter"] = [0, 0]
                output[key]["heightScale"] = 1.6
                output[key]["groundLine"] = [(0.5, -32), (-0.5, 32), (0.5, 32), (-0.5, -32)][rotation]
    projections = json.loads((ROOT.parent / "habitat" / "projection.json").read_text())
    for pack, folder, names in (
        ("kenney_city-kit-suburban_20", "GLB format", ["building-type-a", "building-type-f"]),
        ("kenney_cube-pets_1.0", "GLB_format", ["animal-cat"]),
    ):
        for name in names:
            triangles = mesh_triangles(ROOT / pack / "Models" / folder / f"{name}.glb")
            output[name] = bake(triangles, **projections[name])
    path = NATURE / "Isometric" / "habitat_lighting.json"
    path.write_text(json.dumps(output, separators=(",", ":")), encoding="utf-8")
    print(f"Baked {len(output)} sprite shadow profiles ({path.stat().st_size:,} bytes)")


if __name__ == "__main__":
    main()
