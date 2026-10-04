"""Render recovered decorations with aligned footprints and fixed lighting."""

import json
from pathlib import Path

import numpy as np

from build_habitat_lighting import bake
from habitat_assets import DECORATIONS
from habitat_model import load_model
from render_habitat_models import framing, render_meshes

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/habitat/decor"


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    profiles = {}
    for asset in DECORATIONS:
        if asset.pack == "kenney_nature-kit":
            continue
        model = ROOT / asset.model_path
        poses = [load_model(model, rotation=turn) for turn in range(4)]
        origin, scale = framing([mesh for pose in poses for mesh in pose])
        for direction, meshes in zip(("NE", "SE", "SW", "NW"), poses):
            key = f"{asset.name}_{direction}"
            image = render_meshes(meshes, origin, scale)
            image.save(OUTPUT / f"{key}.png")
            triangles = np.concatenate([mesh.positions[mesh.indices] for mesh in meshes])
            profile = bake(triangles, scale, origin.tolist())
            left, top, right, bottom = image.getchannel("A").getbbox()
            profile["bounds"] = [left, top, right - left, bottom - top]
            profiles[key] = profile
    (OUTPUT / "profiles.json").write_text(json.dumps(profiles, separators=(",", ":")), encoding="utf-8")
    print(f"Rendered {len(profiles)} decoration orientations")


if __name__ == "__main__":
    main()
