"""Render crisp PNGs from the existing models, using the Habitat's fixed camera.

Run this before build_habitat_manifest.py and build_habitat_lighting.py.
The renderer runs offline on the development machine. The app ships only PNGs
and projection metadata. Requires NumPy and Pillow, without a GPU or Blender.
"""

import json
import math
from pathlib import Path

import numpy as np
from PIL import Image

from build_habitat_lighting import project
from habitat_model import load_model

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "habitat"
SIZE = 256
SUPERSAMPLE = 3


def render(path: Path) -> dict:
    meshes = load_model(path)
    coordinates = np.concatenate([project(mesh.positions) for mesh in meshes])
    minimum, maximum = coordinates.min(axis=0), coordinates.max(axis=0)
    scale = (SIZE - 16) / (maximum - minimum).max()
    origin = np.array([SIZE / 2, SIZE / 2]) - (minimum + maximum) / 2 * scale
    size = SIZE * SUPERSAMPLE
    pixels = np.zeros((size, size, 4), dtype=np.float32)
    depth_buffer = np.full((size, size), -np.inf)
    light = np.array([0.60, 1, -0.16])
    light /= np.linalg.norm(light)
    view = np.array([math.sqrt(3 / 8), 0.5, math.sqrt(3 / 8)])
    for mesh in meshes:
        texture = np.asarray(Image.open(mesh.texture).convert("RGBA")) / 255 if mesh.texture else np.ones((1, 1, 4))
        projected = (project(mesh.positions) * scale + origin) * SUPERSAMPLE
        depth = mesh.positions @ view
        for indices in mesh.indices:
            a, b, c = projected[indices]
            determinant = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
            if abs(determinant) < 1e-7:
                continue
            left, top = np.maximum(np.floor(np.minimum.reduce([a, b, c])).astype(int), 0)
            right, bottom = np.minimum(np.ceil(np.maximum.reduce([a, b, c])).astype(int), size - 1)
            if left > right or top > bottom:
                continue
            yy, xx = np.mgrid[top:bottom + 1, left:right + 1] + 0.5
            w0 = ((b[1] - c[1]) * (xx - c[0]) + (c[0] - b[0]) * (yy - c[1])) / determinant
            w1 = ((c[1] - a[1]) * (xx - c[0]) + (a[0] - c[0]) * (yy - c[1])) / determinant
            weights = np.stack([w0, w1, 1 - w0 - w1], axis=-1)
            fragment_depth = weights @ depth[indices]
            target_depth = depth_buffer[top:bottom + 1, left:right + 1]
            mask = (weights.min(axis=-1) >= -1e-7) & (fragment_depth >= target_depth - 1e-7)
            if not mask.any():
                continue
            uv = weights @ mesh.uv[indices]
            tx = np.clip((uv[..., 0] * texture.shape[1]).astype(int), 0, texture.shape[1] - 1)
            ty = np.clip((uv[..., 1] * texture.shape[0]).astype(int), 0, texture.shape[0] - 1)
            color = texture[ty, tx] * mesh.color
            normals = weights @ mesh.normals[indices]
            normals /= np.linalg.norm(normals, axis=-1, keepdims=True).clip(1e-9)
            illumination = 0.48 + 0.65 * np.maximum(normals @ light, 0)
            color[..., :3] = np.clip(color[..., :3] ** 2.2 * illumination[..., None], 0, 1) ** (1 / 2.2)
            mask &= color[..., 3] > 0
            pixels[top:bottom + 1, left:right + 1][mask] = color[mask]
            target_depth[mask] = fragment_depth[mask]
    image = Image.fromarray((pixels * 255).round().astype(np.uint8))
    image.resize((SIZE, SIZE), Image.Resampling.LANCZOS).save(OUTPUT / f"{path.stem}.png")
    return {"origin": origin.round(4).tolist(), "scale": round(scale, 4)}


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    sources = [
        ROOT / "assets/3d_assets/kenney_city-kit-suburban_20/Models/GLB format" / f"{name}.glb"
        for name in ["building-type-a", "building-type-f"]
    ] + [ROOT / "assets/3d_assets/kenney_cube-pets_1.0/Models/GLB_format/animal-cat.glb"]
    profiles = {source.stem: render(source) for source in sources}
    (OUTPUT / "projection.json").write_text(json.dumps(profiles, separators=(",", ":")), encoding="utf-8")
    print(f"Rendered {len(profiles)} Habitat sprites at {SIZE}px")


if __name__ == "__main__":
    main()
