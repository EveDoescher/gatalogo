"""Render sharp shop previews from the exact source GLBs; world assets stay intact."""
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import json
import numpy as np
from export_habitat_catalog import read_shop
from habitat_assets import DECORATIONS
from habitat_model import load_model
from render_habitat_models import framing, render_meshes

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets/quintal/previews"

def render(job):
    key, model, rotation = job
    meshes = load_model(model, rotation=rotation)
    origin, scale = framing(meshes, size=320, padding=28)
    image = render_meshes(meshes, origin, scale, size=320, supersample=2)
    image.save(OUTPUT / f"{key}.png")
    left,top,right,bottom = image.getchannel("A").getbbox()
    return key,[left,top,right-left,bottom-top]

def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    catalog=read_shop(ROOT.parent / 'gatalogo-ai-api')
    models={a.name:ROOT/a.model_path for a in DECORATIONS}
    jobs=[]
    for sprite in sorted({item['sprite'] for item in catalog.values()}):
        model=models.get(sprite,ROOT/'assets/3d_assets/kenney_nature-kit/Models/GLTF_format'/f'{sprite}.glb')
        if not model.exists():
            if sprite.startswith('building-type-'):
                model=ROOT/'assets/3d_assets/kenney_city-kit-suburban_20/Models/GLB format'/f'{sprite}.glb'
            else:
                continue
        if sprite.startswith('building-type-'):
            jobs.append((sprite,model,0))
        else:
            jobs.extend((f'{sprite}_{direction}',model,turn) for turn,direction in enumerate(('NE','SE','SW','NW')))
    profiles={}
    with ProcessPoolExecutor(max_workers=2) as pool:
        for key,box in pool.map(render,jobs):
            profiles[key]=box
            print(f'PREVIEW {key}',flush=True)
    (OUTPUT/'bounds.json').write_text(json.dumps(profiles,separators=(',',':')),encoding='utf-8')
    print(f'Rendered {len(profiles)} crisp previews from source models',flush=True)

if __name__=='__main__': main()
