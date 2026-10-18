"""Bake coat variants on the ORIGINAL cat geometry and rig, in model space.

Rasterize geometry once per pose, then reuse its surface coordinates/lighting
for every palette. No screen-space spots, geometry changes or runtime 3D.
"""
import argparse
import json
import math
import posixpath
from pathlib import Path, PurePosixPath

import numpy as np
from PIL import Image
from build_model_asset_gallery import GitAssets
from build_habitat_lighting import project
from habitat_model import load_model, read_document

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/habitat/cat_coats'
BASE = ROOT / 'assets/habitat/cat'
SOURCE_PATH = 'assets/3d_assets/kenney_cube-pets_1.0/Models/GLB_format/animal-cat.glb'
SOURCE = ROOT / 'build/quintal-models' / SOURCE_PATH
COLORS = {'black': (53, 52, 56), 'white': (242, 235, 220),
          'gray': (139, 145, 151), 'orange': (210, 131, 57),
          'brown': (131, 94, 69), 'cream': (225, 201, 158)}
LABELS = {'black': 'Preto', 'white': 'Branco', 'gray': 'Cinza',
          'orange': 'Laranja', 'brown': 'Marrom', 'cream': 'Creme'}


def catalog():
    rows = []
    def add(id, pattern, palette, label):
        rows.append(dict(id=id, pattern=pattern, palette=palette, label=label))
    for color in COLORS:
        add('solid_'+color, 'solid', [color]*3, 'Sólido · '+LABELS[color])
    for color in COLORS.keys()-{'white'}:
        add('tabby_'+color, 'tabby', [color, color, color], 'Rajado · '+LABELS[color])
        add('tuxedo_'+color, 'tuxedo', [color, 'white', color], 'Tuxedo · '+LABELS[color])
        add('bicolor_'+color+'_white', 'bicolor', [color, 'white', color], 'Bicolor · '+LABELS[color]+' e branco')
        add('bicolor_white_'+color, 'patches', ['white', color, color], 'Bicolor · Branco e '+LABELS[color].lower())
    for id, palette, label in [
        ('calico', ['white', 'black', 'orange'], 'Tricolor'),
        ('calico_dilute', ['white', 'gray', 'cream'], 'Tricolor diluído'),
        ('calico_dark', ['black', 'orange', 'white'], 'Tricolor escuro'),
        ('tortie', ['black', 'orange', 'black'], 'Escaminha'),
        ('tortie_dilute', ['gray', 'cream', 'gray'], 'Escaminha diluída'),
        ('tortie_brown', ['brown', 'orange', 'brown'], 'Escaminha marrom'),
    ]:
        add(id, 'calico' if id.startswith('calico') else 'tortie', palette, label)
    for point in ['brown', 'gray', 'black']:
        add('point_'+point, 'point', ['cream', point, point], 'Colorpoint · '+LABELS[point])
    featured = {'tabby_gray': 'Rajado clássico', 'bicolor_orange_white': 'Laranja e branco',
                'solid_orange': 'Todo laranja', 'bicolor_white_brown': 'Branco com manchas marrons'}
    for row in rows:
        if row['id'] in featured: row['label'] = featured[row['id']]
    return sorted(rows, key=lambda row: (row['id'] not in featured, row['id']))


def ensure_source():
    if SOURCE.exists():
        return
    git = GitAssets('feature/etapa9-3d-metagame')
    try:
        SOURCE.parent.mkdir(parents=True, exist_ok=True)
        SOURCE.write_bytes(git.read(SOURCE_PATH))
        doc, _ = read_document(SOURCE)
        for image in doc.get('images', []):
            if 'uri' in image:
                path = posixpath.normpath(str(PurePosixPath(SOURCE_PATH).parent / image['uri']))
                dest = ROOT / 'build/quintal-models' / path
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(git.read(path))
    finally:
        git.close()


def surface_buffer(meshes, rest, origin, scale, size=320):
    positions = np.zeros((size, size, 3), np.float32)
    lighting = np.zeros((size, size), np.float32)
    original = np.zeros((size, size, 4), np.float32)
    furry = np.zeros((size, size), bool)
    body_part = np.full((size, size), -1, np.int8)
    zbuffer = np.full((size, size), -np.inf)
    light = np.array([.60, 1, -.16]); light /= np.linalg.norm(light)
    view = np.array([math.sqrt(3/8), .5, math.sqrt(3/8)])
    for part, (mesh, neutral) in enumerate(zip(meshes, rest)):
        texture = np.asarray(Image.open(mesh.texture).convert('RGBA')) / 255
        projected = (project(mesh.positions)*scale+origin)*2
        depth = mesh.positions @ view
        for indices in mesh.indices:
            a,b,c = projected[indices]
            determinant = (b[1]-c[1])*(a[0]-c[0])+(c[0]-b[0])*(a[1]-c[1])
            if abs(determinant)<1e-7: continue
            left,top = np.maximum(np.floor(np.minimum.reduce([a,b,c])).astype(int),0)
            right,bottom = np.minimum(np.ceil(np.maximum.reduce([a,b,c])).astype(int),size-1)
            if left>right or top>bottom: continue
            yy,xx = np.mgrid[top:bottom+1,left:right+1]+.5
            w0=((b[1]-c[1])*(xx-c[0])+(c[0]-b[0])*(yy-c[1]))/determinant
            w1=((c[1]-a[1])*(xx-c[0])+(a[0]-c[0])*(yy-c[1]))/determinant
            weights=np.stack([w0,w1,1-w0-w1],axis=-1)
            fragment=weights@depth[indices]
            z=zbuffer[top:bottom+1,left:right+1]
            mask=(weights.min(axis=-1)>=-1e-7)&(fragment>=z-1e-7)
            if not mask.any(): continue
            uv=weights@mesh.uv[indices]
            tx=np.clip((uv[...,0]*texture.shape[1]).astype(int),0,texture.shape[1]-1)
            ty=np.clip((uv[...,1]*texture.shape[0]).astype(int),0,texture.shape[0]-1)
            color=texture[ty,tx]*mesh.color
            normal=weights@mesh.normals[indices]
            normal/=np.linalg.norm(normal,axis=-1,keepdims=True).clip(1e-9)
            intensity=.48+.65*np.maximum(normal@light,0)
            # The face details have their own dark/gold palette. Keep the eyes,
            # pupils, mouth, nose and inner ears; recolor only the feather/fur grey.
            fur=(part>=2) | ((part==0)&(color[...,0]>.37)&(color[...,2]>color[...,0]*1.08))
            color[...,:3]=np.clip(color[...,:3]**2.2*intensity[...,None],0,1)**(1/2.2)
            mask &= color[...,3]>0
            sl=np.s_[top:bottom+1,left:right+1]
            original[sl][mask]=color[mask]
            positions[sl][mask]=(weights@neutral.positions[indices])[mask]
            lighting[sl][mask]=intensity[mask]
            furry[sl][mask]=fur[mask]
            body_part[sl][mask]=part
            z[mask]=fragment[mask]
    return positions,lighting,original,furry,body_part


def markings(pattern, points, parts):
    x,y,z=points[...,0],points[...,1],points[...,2]
    front=z>.52
    paws=(parts>=3)&(y<.17)
    bib=front&(np.abs(x)<.27)&(y<.75)
    muzzle=front&(np.abs(x)<.22)&(y<.72)
    belly=(y<.33)&(parts==0)
    region=np.zeros(y.shape,np.uint8)
    if pattern=='solid': return region
    if pattern=='tuxedo':
        region[bib|paws|belly|muzzle]=1
    elif pattern=='bicolor':
        blaze=front&(np.abs(x)<(.18+(.9-y)*.22))&(y<1.17)
        flank=(x>.32)&(((z+.02)/.58)**2+((y-.66)/.73)**2<1)
        region[blaze|bib|paws|belly|flank]=1
    elif pattern=='patches':
        cap=(y>1.01)&(x<.17)&(z>.12)
        flank=((z+.32)/.55)**2+((y-.90)/.55)**2<1
        region[cap|flank|(parts==2)]=1
    elif pattern=='tabby':
        stripe=np.sin(z*22+x*3+np.sin(y*5))>.55
        stripe &= (np.abs(x)>.44)|(y>1.30)|(z<-.52)
        forehead=front&(y>1.03)&(np.cos(x*27+(y-1.03)*10)>.42)
        rings=((parts==2)&(np.sin((y+z)*26)>.25))|((parts>=3)&(np.sin(y*35)>.4))
        region[stripe|forehead|rings]=1
    elif pattern in ('calico','tortie'):
        field=np.sin(x*7+z*3)+np.cos(z*8-y*4)+.40*np.sin(y*8+x*3)
        if pattern=='calico':
            region[field>.65]=1
            region[field<-.50]=2
            region[paws|muzzle|bib]=0
        else:
            region[field>.05]=1
    elif pattern=='point':
        mask=front&(((x/.47)**2+((y-.79)/.47)**2)<1)
        region[mask|(y>1.44)|(parts>=2)]=1
    return region


def paint_coat(buffer, definition, masks):
    points,lighting,original,fur,parts=buffer
    pattern=definition['pattern']
    if pattern not in masks:
        masks[pattern]=markings(pattern,points,parts)
    region=masks[pattern]
    palette=np.array([COLORS[c] for c in definition['palette']],dtype=np.float32)/255
    if pattern=='tabby': palette[1]=palette[0]*.52
    pixels=original.copy()
    color=np.clip(palette[region]**2.2*lighting[...,None],0,1)**(1/2.2)
    pixels[fur,:3]=color[fur]
    return Image.fromarray(np.clip(pixels*255,0,255).round().astype(np.uint8))


def gallery(rows, metadata):
    dest=ROOT/'build/galeria-visual/pelagens';dest.mkdir(parents=True,exist_ok=True)
    relative='../../../assets/habitat/cat_coats/'
    cards=''.join(f'<button data-id="{r["id"]}"><img loading="lazy" src="{relative}{r["id"]}__preview.png"><span>{r["label"]}</span></button>' for r in rows)
    html='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Pelagens do Quintal</title><style>body{margin:0;background:#fbf6e8;color:#4b281b;font:16px/1.5 system-ui}main{max-width:1100px;margin:auto;padding:24px}button,select{font:inherit;color:inherit;background:#fff9ec;border:1px solid #c9b793;border-radius:14px;padding:10px;cursor:pointer}button[aria-pressed=true]{outline:3px solid #578243}#grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(160px,1fr));gap:14px}img{width:100%;display:block}span{display:block}#viewer{background:#dfeac9;border-radius:20px;padding:16px;text-align:center;margin-bottom:24px}canvas{display:block;margin:auto;max-width:100%}select{margin:4px}a{color:inherit}</style>
<main><a href="../galeria.html">Voltar à galeria de telas</a><h1>Pelagens do Quintal</h1><p>Mesmo modelo e animações. Variações ilustrativas escolhidas pela cor e pelo padrão registrados na ficha; não são uma reconstrução exata da fotografia.</p>
<section id="viewer"><h2 id="name"></h2><canvas width="320" height="320"></canvas><select id="clip" aria-label="Animação"><option value="idle">Parado</option><option value="walk">Andando</option><option value="run">Correndo</option><option value="eat">Comendo</option><option value="play">Brincando</option><option value="dance">Dançando</option><option value="gesture-positive">Feliz</option><option value="gesture-negative">Contrariado</option></select><select id="direction" aria-label="Direção"><option value="0">Frente direita</option><option value="1">Costas direita</option><option value="2">Costas esquerda</option><option value="3">Frente esquerda</option></select></section><div id="grid">CARDS</div>
<script>const rows=ROWS,meta=META,root='ROOT';let selected=rows.find(r=>r.id==='calico'),image=new Image();const canvas=document.querySelector('canvas'),ctx=canvas.getContext('2d'),clip=document.querySelector('#clip'),direction=document.querySelector('#direction');function load(){image=new Image();image.src=root+selected.id+'__'+clip.value+'.png';document.querySelector('#name').textContent=selected.label;document.querySelectorAll('button').forEach(b=>b.setAttribute('aria-pressed',b.dataset.id===selected.id));}document.querySelectorAll('button').forEach(b=>b.onclick=()=>{selected=rows.find(r=>r.id===b.dataset.id);load();});clip.onchange=load;function draw(t){ctx.clearRect(0,0,320,320);const d=meta.clips[clip.value],f=Math.floor(t/1000%d.duration/d.duration*d.count);if(image.complete&&image.naturalWidth)ctx.drawImage(image,f*160,Number(direction.value)*160,160,160,0,0,320,320);requestAnimationFrame(draw);}load();requestAnimationFrame(draw);</script></main></html>'''
    html=html.replace('CARDS',cards).replace('ROWS',json.dumps(rows,ensure_ascii=False)).replace('META',json.dumps(metadata)).replace('ROOT',relative)
    (dest/'index.html').write_text(html,encoding='utf-8')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--previews-only',action='store_true');args=parser.parse_args()
    ensure_source();OUT.mkdir(parents=True,exist_ok=True)
    rows=catalog();meta=json.loads((BASE/'animations.json').read_text())
    rest=load_model(SOURCE)
    ground=min(m.positions[:,1].min() for m in load_model(SOURCE, ground=0))
    scale=meta['restHeight']/np.ptp(np.concatenate([project(m.positions)[:,1] for m in rest]))
    origin=np.array(meta['origin'])
    preview=surface_buffer(rest,rest,origin,scale)
    masks={}
    for row in rows:
        paint_coat(preview,row,masks).save(OUT/(row['id']+'__preview.png'))
    (OUT/'catalog.json').write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    gallery(rows,meta)
    if args.previews_only: return
    for clip,definition in meta['clips'].items():
        count,duration=definition['count'],definition['duration']
        atlases={row['id']:Image.new('RGBA',(160*count,640)) for row in rows}
        for direction in range(4):
            for frame in range(count):
                time=frame*duration/count
                meshes=load_model(SOURCE,animation=None if clip=='play' else clip,time=time,
                                  play_time=time if clip=='play' else None,rotation=direction,ground=ground)
                buffer=surface_buffer(meshes,rest,origin,scale);masks={}
                for row in rows:
                    image=paint_coat(buffer,row,masks).resize((160,160),Image.Resampling.LANCZOS)
                    atlases[row['id']].paste(image,(frame*160,direction*160))
        for id,atlas in atlases.items(): atlas.save(OUT/(id+'__'+clip+'.png'))
        print(f'{clip}: {len(rows)} coats, {count} frames × 4 directions',flush=True)
    print('Coat gallery:',ROOT/'build/galeria-visual/pelagens/index.html')


if __name__=='__main__': main()
