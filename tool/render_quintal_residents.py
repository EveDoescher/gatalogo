"""Bake resident cow and adult hen variants using the established animation format."""
import json
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from habitat_model import load_model
from build_habitat_lighting import project, ground_projection
from render_habitat_models import render_meshes, framing
from render_habitat_cat import shadow_image
from build_quintal_production_assets import adult, CACHE, OUT

SIZE = 160
ROOT = Path(__file__).resolve().parents[1]

def bake(name, source, variant=None):
    target = ROOT / 'assets/quintal' / name
    target.mkdir(parents=True, exist_ok=True)
    clips = {'idle': (1., 8), 'walk': (.5, 8), 'eat': (.5, 8)}
    poses, coordinates = {}, []
    for clip, (duration, count) in clips.items():
        frames = []
        for direction in range(4):
            for index in range(count):
                meshes = load_model(source, animation=clip, time=index * duration / count, rotation=direction)
                if variant: meshes = adult(meshes, variant, direction)
                frames.append(meshes)
                points = np.concatenate([mesh.positions for mesh in meshes])
                coordinates.extend((project(points), ground_projection(points, True)))
        poses[clip] = frames
    points = np.concatenate(coordinates)
    low, high = points.min(axis=0), points.max(axis=0)
    scale = (SIZE - 18) / (high - low).max()
    origin = np.array([SIZE / 2, SIZE / 2]) - (low + high) / 2 * scale
    rest = load_model(source)
    if variant: rest = adult(rest, variant)
    metadata = {'size': SIZE, 'origin': origin.tolist(), 'restHeight': float(np.ptp(np.concatenate([project(m.positions)[:,1] for m in rest])) * scale), 'clips': {}}
    for clip, frames in poses.items():
        duration, count = clips[clip]
        atlas = Image.new('RGBA', (SIZE * count, SIZE * 4))
        shadows = Image.new('RGBA', atlas.size)
        bounds = []
        for index, meshes in enumerate(frames):
            position = (index % count * SIZE, index // count * SIZE)
            image = render_meshes(meshes, origin, scale, SIZE, 2)
            atlas.paste(image, position)
            shadows.paste(shadow_image(meshes, origin, scale), position)
            bounds.append(image.getchannel('A').getbbox())
        atlas.save(target / (clip + '.png'))
        shadows.save(target / (clip + '-shadow.png'))
        metadata['clips'][clip] = {'duration': duration, 'count': count, 'bounds': bounds}
        print(name, clip, flush=True)
    (target / 'animations.json').write_text(json.dumps(metadata), encoding='utf-8')

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--hens-only', action='store_true')
    args = parser.parse_args()
    manifest = json.loads((OUT / 'manifest.json').read_text(encoding='utf-8'))
    if not args.hens_only:
        bake('cow', CACHE / manifest['animal-cow']['source'])
    for variant in ('white', 'brown'):
        source = CACHE / manifest['animal-chick']['source']
        bake('hen-' + variant, source, variant)
        meshes = adult(load_model(source), variant)
        origin, scale = framing(meshes, size=320)
        render_meshes(meshes, origin, scale, size=320, supersample=2).save(OUT / ('hen-' + variant + '.png'))
        manifest['hen-' + variant].update(origin=origin.tolist(), scale=float(scale))
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')

if __name__ == '__main__': main()

