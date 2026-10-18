"""Compose the supplied meshes in 3D, with shared scale and real contact points.

No image rotation/stretching: geometry, normals and depth are rendered together.
Run after build_quintal_production_assets.py. Only selected source models ship.
"""
from pathlib import Path, PurePosixPath
import json, math, posixpath
import numpy as np
from PIL import Image
from build_quintal_production_assets import ROOT, OUT, CACHE
from build_model_asset_gallery import GitAssets
from habitat_model import load_model, read_document, Mesh
from render_habitat_models import framing, render_meshes
from build_habitat_lighting import project, ground_projection

git = GitAssets('feature/etapa9-3d-metagame')
models = {}

def source(name, pack=None):
    key = (name, pack)
    if key in models: return models[key]
    paths = [p for p in git.paths if p.startswith('assets/') and p.endswith('.glb')
             and PurePosixPath(p).stem == name and (not pack or pack in p)]
    if not paths: raise ValueError(name)
    path = paths[0]
    local = CACHE / path
    local.parent.mkdir(parents=True, exist_ok=True)
    local.write_bytes(git.read(path))
    doc, _ = read_document(local)
    for image in doc.get('images', []):
        if 'uri' in image:
            relative = posixpath.normpath(str(PurePosixPath(path).parent / image['uri']))
            texture = CACHE / relative
            texture.parent.mkdir(parents=True, exist_ok=True)
            texture.write_bytes(git.read(relative))
    models[key] = load_model(local)
    return models[key]

def part(name, dims, at=(0,0,0), angle=0, pack=None, tilt=(0,0), tint=(1,1,1)):
    meshes = source(name, pack)
    points = np.concatenate([m.positions for m in meshes])
    lo, hi = points.min(0), points.max(0)
    center = np.array([(lo[0]+hi[0])/2, lo[1], (lo[2]+hi[2])/2])
    scale = np.array(dims) / np.maximum(hi-lo, .001)
    rad = math.radians(angle)
    rotation = np.array([[math.cos(rad),0,math.sin(rad)],[0,1,0],[-math.sin(rad),0,math.cos(rad)]])
    rx, rz = map(math.radians, tilt)
    rotation = np.array([[math.cos(rz),-math.sin(rz),0],[math.sin(rz),math.cos(rz),0],[0,0,1]]) @ np.array([[1,0,0],[0,math.cos(rx),-math.sin(rx)],[0,math.sin(rx),math.cos(rx)]]) @ rotation
    floor = (((points-center)*scale) @ rotation.T)[:,1].min()
    result = []
    for m in meshes:
        positions = ((m.positions-center)*scale) @ rotation.T + np.array(at)
        positions[:,1] -= floor
        normals = (m.normals/scale) @ rotation.T
        normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), .001)
        texture=m.texture
        color=m.color.astype(float).copy()
        color[:3] *= np.array(tint)
        if name.startswith(('tree_', 'log_', 'stump_', 'plant_', 'grass', 'rock_')):
            matrix=np.array([[.3894,.1537,.4124],[.2499,.4421,.2636],[.3767,-.3186,.8419]]) if name.startswith('rock_') else np.array([[.4171,.1403,.4093],[.1098,.299,.569],[.2558,-.8953,1.5395]])
            if not texture:
                color[:3]=np.clip(matrix @ color[:3],0,1)
        if name.startswith(('tree_', 'log_', 'stump_', 'plant_', 'grass', 'rock_')) and texture:
            # Match HabitatPalette.foliage on tree materials, before adding fruit.
            target=CACHE / ('production-'+name+'-'+Path(texture).name)
            rgba=np.array(Image.open(texture).convert('RGBA'))
            rgba[:,:,:3]=np.clip(rgba[:,:,:3].astype(float) @ matrix.T,0,255).astype('uint8')
            Image.fromarray(rgba).save(target)
            texture=target
        result.append(Mesh(positions,normals,m.uv.copy(),m.indices.copy(),texture,color))
    return result

def bake(name, meshes, manifest):
    origin, scale = framing(meshes, size=384, padding=26)
    image = render_meshes(meshes, origin, scale, size=384, supersample=2)
    image.save(OUT / f'{name}.png')
    bounds = image.getbbox()
    # Same projected metres as the ground diamonds; width + depth determines scale.
    points = np.concatenate([m.positions for m in meshes])
    ground = ground_projection(points, False)
    shadow = ground_projection(points, True)
    # Convex hull is enough for these small static structures; shadows stay on ground.
    def hull(points):
        pts = sorted(set(map(tuple, np.round(points * scale, 3))))
        def cross(o,a,b): return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
        lower=[]; upper=[]
        for p in pts:
            while len(lower)>1 and cross(lower[-2],lower[-1],p)<=0: lower.pop()
            lower.append(p)
        for p in reversed(pts):
            while len(upper)>1 and cross(upper[-2],upper[-1],p)<=0: upper.pop()
            upper.append(p)
        return [list(p) for p in lower[:-1]+upper[:-1]]
    manifest[name] = {'source':'composition of supplied Kenney models',
      'origin':origin.tolist(), 'scale':float(scale), 'world_scale':True,
      'groundSize':((points.max(0)-points.min(0))[[0,2]]*scale/math.sqrt(2)).tolist(),
      'bounds':[bounds[0],bounds[1],bounds[2]-bounds[0],bounds[3]-bounds[1]],
      'shadow':hull(shadow), 'footprint':hull(ground)}

def main():
    manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    # Raised, furrowed beds use the actual farm mesh instead of painted diamonds.
    for wet in (False, True):
        soil_tint=(.47,.48,.44) if wet else (.65,.62,.55)
        bed=part('patch-sand',(1.18,.025,1.18),tint=(.46,.38,.29) if wet else (.58,.47,.35))
        bed+=part('crops_dirtDoubleRow',(1.05,.07,1.02),at=(0,.02,0),tint=soil_tint)
        for x in (-.59,.59):
            bed+=part('platform-planks',(.10,.075,1.25),at=(x,0,0),tint=(.85,.8,.68))
        for z in (-.59,.59):
            bed+=part('platform-planks',(.10,.075,1.25),at=(0,0,z),angle=90,tint=(.85,.8,.68))
        bake('garden-bed-wet' if wet else 'garden-bed',bed,manifest)
    # Reusable fragments keep ruins coherent without flattening a whole lot.
    for name, angle in [('ruin-fence-a',18),('ruin-fence-b',-24)]:
        pieces=part('fence_planks',(1.1,.58,.1),angle=angle,tilt=(82,0),tint=(.8,.8,.74))
        pieces+=part('rock_smallA',(.25,.18,.3),at=(.3,0,.3),tint=(.86,.85,.78))
        bake(name,pieces,manifest)
    bake('ruin-timber',part('log_stack',(1.05,.34,.72),tint=(.87,.84,.77)),manifest)
    kitchen = part('structure-platform',(2.8,.12,1.8)) + part('table',(2.0,.8,.95),at=(0,.12,0),pack='mini-dungeon')
    kitchen += part('pot-stew',(.75,.42,.65),at=(-.35,.94,0))
    kitchen += part('crop_carrot',(.2,.18,.4),at=(.64,.94,.03),angle=75)
    bake('kitchen-station',kitchen,manifest)
    market = part('structure-platform',(2.8,.12,1.8)) + part('table',(2,.75,1),at=(0,.12,0),pack='mini-dungeon')
    market += part('crate',(.6,.5,.65),at=(-.45,.87,0),pack='pirate')
    market += part('barrel',(.5,.7,.5),at=(1,.12,.2),pack='pirate')
    market += part('apple',(.17,.17,.17),at=(-.47,1.2,0))
    bake('market-station',market,manifest)
    for name,width in [('coop-shelter',1.45),('pasture-shelter',1.9)]:
        shelter=part('structure-fence',(width,1.25,width*.8))
        shelter+=part('structure-roof',(width+ .28,.58,width*.8+.25),at=(0,1.25,0))
        bake(name,shelter,manifest)
    for full in (False,True):
        nest=part('crate',(.58,.20,.50),pack='pirate')
        if full:
            for x,z in [(-.12,0),(.1,.1),(.1,-.1)]: nest+=part('egg',(.15,.20,.15),at=(x,.12,z))
        bake('nest-full' if full else 'nest-empty',nest,manifest)
    for fruit in ('apple','pear'):
        tree=part('tree_oak',(1.6,2.2,1.6))
        bake(f'{fruit}-tree-empty',tree,manifest)
        for x,y,z in [(-.48,1.55,.44),(.42,1.4,.52),(.65,1.8,-.1),(-.3,1.98,-.4)]:
            tree+=part(fruit,(.22,.25,.22),at=(x,y,z))
        bake(f'{fruit}-tree-full',tree,manifest)
    for broken in (False,True):
        dock=part('structure-platform-dock',(2.15,.45,1.75),at=(-.65,0,0))
        if broken:
            # Leave the access visibly incomplete; broken boards never float above water.
            dock+=part('platform-planks',(.5,.10,.55),at=(1.2,.34,-.48),angle=-12)
            dock+=part('platform-planks',(.55,.10,.5),at=(.9,.30,.48),angle=18)
        else: dock+=part('structure-platform-small',(1.3,.1,1.05),at=(.95,.35,0))
        bake('pier-broken' if broken else 'pier-ready',dock,manifest)
    # Individual ruins are small compositions. The world adds overgrowth across
    # each entire plot, so abandoned land has the same footprint as its repair.
    for kind in ('coop','pasture'):
        width=1.5 if kind=='coop' else 2.0
        ruin=part('fence_planks',(width,.5,.12),at=(0,0,-width*.3),tilt=(10,0),tint=(.83,.80,.74))
        ruin+=part('fence_planks',(width*.7,.65,.12),at=(-width*.4,0,0),angle=90,tilt=(0,-8),tint=(.83,.80,.74))
        ruin+=part('structure-roof',(width*.8,.22,width*.65),at=(.18,0,.25),angle=-10,tilt=(15,8),tint=(.78,.77,.69))
        ruin+=part('platform-planks',(.7,.08,.35),at=(-.65,0,.55),angle=18,tint=(.83,.8,.74))
        bake(f'{kind}-ruins',ruin,manifest)
    garden=part('crops_dirtDoubleRow',(1.6,.10,1.1),tint=(.53,.53,.43))
    garden+=part('fence_planks',(1.35,.25,.1),at=(.05,0,-.65),tilt=(0,24),tint=(.78,.78,.70))
    garden+=part('log_large',(.16,.14,1.3),at=(.65,0,.15),angle=15,tint=(.85,.8,.73))
    bake('garden-ruins',garden,manifest)
    kitchen=part('platform-planks',(2.2,.12,1.4),angle=6)
    kitchen+=part('table',(1.6,.65,.8),pack='mini-dungeon',at=(.1,0,0),tilt=(0,25))
    kitchen+=part('pot',(.55,.48,.55),pack='food-kit',at=(-.8,0,.5),tilt=(0,65))
    bake('kitchen-ruins',kitchen,manifest)
    market=part('platform-planks',(2.1,.12,1.4),angle=-9)
    market+=part('crate',(.65,.48,.7),pack='pirate',at=(.6,0,.25),angle=20,tilt=(0,18))
    market+=part('barrel',(.65,.9,.65),pack='pirate',at=(-.6,0,-.1),tilt=(0,90))
    bake('market-ruins',market,manifest)
    orchard=part('stump_roundDetailed',(.7,.5,.7))
    orchard+=part('log_large',(.4,.35,1.6),at=(.5,0,.7),angle=65)
    bake('orchard-ruins',orchard,manifest)
    site=part('structure-platform',(2.1,.1,1.4))
    for i in range(3):
        site+=part('platform-planks',(.8,.09,.55),at=(-.45,.1+i*.1,.1),angle=3*i)
    site+=part('crate',(.45,.45,.45),pack='pirate',at=(.6,.1,0))
    bake('construction-site',site,manifest)
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    print('Baked world compositions, raised beds and modular ruins.')

if __name__=='__main__':
    try: main()
    finally: git.close()
else:
    import atexit
    atexit.register(git.close)

