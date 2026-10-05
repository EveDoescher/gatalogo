"""Bake animal clips into shared sprite/shadow atlases, never runtime 3D."""

import json
import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

from build_habitat_lighting import ground_projection, project
from habitat_model import load_model
from render_habitat_models import render_meshes

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets/3d_assets/kenney_cube-pets_1.0/Models/GLB_format/animal-cat.glb"
OUTPUT = ROOT / "assets/habitat/cat"
SIZE = 160
CLIPS = {"idle": (1, 12), "walk": (0.5, 8), "run": (0.25, 4),
         "eat": (0.5, 8), "dance": (0.5, 8),
         "gesture-positive": (0.25, 4), "gesture-negative": (0.25, 4), "play": (3.6, 18)}


def shadow_image(meshes, origin, scale):
    mask = Image.new("L", (SIZE * 2, SIZE * 2))
    draw = ImageDraw.Draw(mask)
    for mesh in meshes:
        triangles = mesh.positions[mesh.indices]
        for polygon in (ground_projection(triangles, True) * scale + origin) * 2:
            draw.polygon([tuple(point) for point in polygon], fill=65)
    mask = mask.filter(ImageFilter.GaussianBlur(1.6)).resize((SIZE, SIZE), Image.Resampling.LANCZOS)
    image = Image.new("RGBA", (SIZE, SIZE), (52, 76, 43, 0))
    image.putalpha(mask)
    return image


def main():
    global SOURCE, OUTPUT, CLIPS
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--animal', choices=('cat', 'dog', 'bee', 'bunny', 'chick', 'deer', 'fox', 'beaver', 'parrot', 'fish'), default='cat')
    animal = parser.parse_args().animal
    SOURCE = SOURCE.with_name(f'animal-{animal}.glb')
    OUTPUT = OUTPUT.parent / animal
    CLIPS = ({'idle': (.25, 8), 'walk': (.25, 8)} if animal == 'bee' else
             {'idle': (1, 12), 'walk': (.25, 8)} if animal == 'parrot' else
             {'idle': (1, 12), 'walk': (.5, 8)} if animal == 'fish' else
             {**CLIPS, 'play': (3.6, 18)} if animal == 'cat' else
             {**{key: CLIPS[key] for key in ('idle', 'walk', 'eat')}, 'play': (3.6, 18)})
    OUTPUT.mkdir(parents=True, exist_ok=True)
    rest = load_model(SOURCE, ground=0)
    ground = min(mesh.positions[:, 1].min() for mesh in rest)
    poses = {}
    coordinates = []
    for clip, (duration, count) in CLIPS.items():
        frames = []
        for turn in range(4):
            for index in range(count):
                time = index * duration / count
                meshes = load_model(SOURCE, animation=None if clip == 'play' else clip, time=time,
                                    play_time=time if clip == 'play' else None,
                                    flight_time=time if animal == 'bee' or animal in ('parrot', 'fish') and clip == 'walk' else None, ground=ground, rotation=turn)
                frames.append(meshes)
                vertices = np.concatenate([mesh.positions for mesh in meshes])
                coordinates.extend((project(vertices), ground_projection(vertices, True)))
        poses[clip] = frames
    points = np.concatenate(coordinates)
    minimum, maximum = points.min(axis=0), points.max(axis=0)
    scale = (SIZE - 16) / (maximum - minimum).max()
    origin = np.array([SIZE / 2, SIZE / 2]) - (minimum + maximum) / 2 * scale
    static = load_model(SOURCE)
    static_y = np.concatenate([project(mesh.positions)[:, 1] for mesh in static])
    metadata = {"size": SIZE, "origin": origin.tolist(), "restHeight": float(np.ptp(static_y) * scale), "clips": {}}
    for clip, frames in poses.items():
        duration, count = CLIPS[clip]
        atlas = Image.new("RGBA", (SIZE * count, SIZE * 4))
        shadows = Image.new("RGBA", atlas.size)
        bounds = []
        for index, meshes in enumerate(frames):
            point = ((index % count) * SIZE, (index // count) * SIZE)
            image = render_meshes(meshes, origin, scale, SIZE, 2)
            atlas.paste(image, point)
            shadows.paste(shadow_image(meshes, origin, scale), point)
            bounds.append(image.getchannel("A").getbbox())
        atlas.save(OUTPUT / f"{clip}.png")
        shadows.save(OUTPUT / f"{clip}-shadow.png")
        metadata["clips"][clip] = {"duration": duration, "count": count, "bounds": bounds}
        print(f"Rendered {clip}: {count} frames in 4 directions", flush=True)
    (OUTPUT / "animations.json").write_text(json.dumps(metadata, separators=(",", ":")), encoding="utf-8")


if __name__ == "__main__":
    main()
