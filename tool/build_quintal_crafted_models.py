"""Create the approved Quintal models and their independently editable states.

New geometry uses the original pack's roof/wood/plant vocabulary, camera and
lighting. Sources remain editable GLBs; only rendered assets ship in Flutter.
"""
import argparse
import html
import json
import math
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import numpy as np
from quintal_model_authoring import (Model, box, lathe, ellipsoid, beam, transform,
    mesh_faces, rgba, WOOD, WOOD_LIGHT, WOOD_DARK, CREAM, STRAW, WATER, LEAF, SOIL)
from build_quintal_compositions import part, bake
from quintal_cozy_models import bowl, shelter, kitchen, post, portions, produce_crate
from quintal_cozy_crops import crop
from build_quintal_production_assets import ROOT, OUT

SOURCES = ROOT/'art/quintal/models'
GALLERY = ROOT/'build/galeria-visual/modelos-novos'
BUILDING_STATES = [(1,'abandoned'),(1,'building'),(1,'ready'),(1,'upgrading'),(2,'ready')]
RETIRED = {f'crafted-{kind}-2-{state}' for kind in ('coop','barn','kitchen')
           for state in ('abandoned','building')} | {'crafted-mailbox-0','crafted-mailbox-1'}
COLORS = ['e8a6a8','a4bbdc','c4b3d7','ecc285','c5d58d','90c8bd']




def nest(eggs):
    m=Model()
    m.add('nest-floor',box((.43,.055,.42),WOOD_DARK,at=(0,.04,0)))
    for x in (-.215,.215):m.add('nest-side',box((.045,.17,.48),WOOD,at=(x,.095,0)))
    m.add('nest-front',box((.475,.10,.055),WOOD_LIGHT,at=(0,.06,.23)))
    m.add('nest-back',box((.475,.22,.055),WOOD,at=(0,.12,-.23)))
    m.add('straw',lathe([(0,.07),(.16,.07),(.20,.12),(.15,.11),(0,.09)],STRAW,8,(1,1)))
    for i in range(eggs):
        m.add(f'egg-{i+1}',part('egg',(.115,.16,.115),pack='food-kit',at=((i-.5)*.15 if eggs>1 else 0,.09,.015),angle=i*32))
    return m


def bucket(fill):
    m=Model().add('bucket',lathe([(0,0),(.17,0),(.23,.40),(.19,.40),(.14,.06),(0,.06)],rgba('a5aaa0'),10))
    for side in (-1,1):
        m.add('handle-side',beam((side*.22,.30,0),(side*.22,.58,0),.028,WOOD_DARK))
    m.add('handle',beam((-.22,.58,0),(.22,.58,0),.035,WOOD_DARK))
    if fill:
        y=.12+.22*fill/2
        m.add('milk',lathe([(0,y),(.145+y*.1,y),(0,y)],rgba('f2e6c9'),10))
    return m








def garden_bed(wet=False, planted=False):
    """Low furrowed soil; the plant is a separate module rooted at Y=.08."""
    m=Model();soil=rgba('795539' if wet else 'a67b50')
    m.add('soil-base',box((.99,.055,.99),soil,at=(0,.0275,0)))
    # Low timber edging leaves generous ground paths between the plots.
    for side in (-1,1):
        m.add('side-border',box((.055,.095,1.08),WOOD_DARK,at=(side*.525,.0475,0)))
        m.add('end-border',box((1.0,.095,.055),WOOD_LIGHT,at=(0,.0475,side*.525)))
    for row in range(4):
        x=-.36+row*.24
        # Broad, softly faceted earth ridges; gaps read as furrows, not deep holes.
        verts=[(x-.095,.05,-.47),(x-.060,.08,-.47),(x+.06,.08,-.47),(x+.095,.05,-.47),
               (x-.095,.05,.47),(x-.060,.08,.47),(x+.06,.08,.47),(x+.095,.05,.47)]
        m.add('furrow-ridge',mesh_faces(verts,[(0,1,5,4),(1,2,6,5),(2,3,7,6),(0,3,2,1),(4,5,6,7)],soil))
    if planted:
        # Seed dimples remain subtle under the crop, rather than floating seeds.
        for z in (-.22,0,.22):
            m.add('seed-dimple',box((.065,.003,.07),soil*.87+np.array([0,0,0,.13]),at=(0,.057,z)))
    return m






def cooking_pot(active=False, component='whole'):
    m=Model();iron=rgba('697366')
    if component != 'lid':
        m.add('pot',lathe([(0,.0),(.25,.0),(.32,.15),(.32,.35),(.28,.35),(.23,.055),(0,.055)],iron,10))
        for x in (-1,1):m.add('handle',box((.13,.065,.13),iron,at=(x*.34,.28,0)))
    if component != 'base':
        m.add('lid',lathe([(0,.405),(.11,.405),(.30,.365),(.32,.35),(0,.35)],iron* np.array([1.12,1.12,1.12,1]),10))
        m.add('lid-handle',box((.12,.045,.06),WOOD_DARK,at=(0,.43,0)))
    if active and component != 'lid':
        for i in range(3):m.add(f'ember-{i}',ellipsoid((.16,.10,.13),rgba('da9854'),at=((i-1)*.18,-.075,0)))
    return m




def preparation_tray(waiting):
    m=Model().add('tray-floor',box((.40,.025,.23),WOOD_LIGHT,at=(0,.018,0)))
    for z in (-.115,.115):m.add('tray-edge',box((.42,.035,.018),WOOD,at=(0,.045,z)))
    for x in (-.20,.20):m.add('tray-edge',box((.018,.035,.23),WOOD,at=(x,.045,0)))
    if waiting:
        # Covered ingredients avoid suggesting a specific recipe for every task.
        m.add('ingredient-bowl',lathe([(0,.03),(.07,.03),(.088,.13),(.077,.14),(0,.14)],CREAM,10,at=(-.07,0,0)))
        m.add('ingredient-cover',lathe([(0,.155),(.04,.15),(.09,.135),(0,.135)],LEAF,10,at=(-.07,0,0)))
        m.add('cover-knob',box((.03,.022,.03),WOOD_LIGHT,at=(-.07,.164,0)))
        m.add('folded-cloth',box((.12,.025,.16),CREAM,at=(.11,.053,0)))
        m.add('cloth-stripe',box((.018,.003,.16),LEAF,at=(.13,.067,0)))
    return m


def parcel():
    return produce_crate(covered=True)


def orchard(state):
    m=Model()
    pockets=[(-.65,-.5,.65),(.60,-.48,.82),(-.35,.4,.48),(.6,.5,.38),(0,0,.50)]
    for i,(x,z,h) in enumerate(pockets):
        if state=='clearing' and i in (2,3,4):continue
        if state=='ready' and i not in (0,1):continue
        if state=='ready':h*=.7
        m.add(f'vegetation-{i}',part('plant_bushSmall' if i<2 else 'grass',(.60,h,.55),at=(x,0,z),angle=i*73))
    return m


def fruit_tree(fruit,state,fruits_only=False):
    m=Model()
    if not fruits_only:m.add('tree',part('tree_oak',(1.6,2.2,1.6)))
    if state!='empty':
        for i,(x,y,z) in enumerate([(-.48,1.55,.44),(.42,1.4,.52),(.65,1.8,-.1)]):
            size={'bud':(.07,.08,.07),'growing':(.14,.16,.14),'full':(.20,.23,.20),'ready':(.22,.25,.22)}[state]
            meshes=part(fruit,size,at=(x,y,z))
            if state!='ready':
                for mesh in meshes:mesh.texture=None;mesh.color=rgba('a5b66a')
            m.add(f'fruit-{i}',meshes)
    return m


def models(groups):
    if 'bowls' in groups:
        for i,color in enumerate(COLORS):
            for kind in ('food','water'):
                for amount in range(3):
                    yield f'cat-{kind}-{i}-{amount}',f'Gatos · {kind} · cor {i+1} · {amount}/2','Recipientes',bowl(kind,amount,rgba(color))
        for kind,content,long in [('coop-food','grain',False),('coop-water','water',False),('cow-food','hay',True),('cow-water','water',True)]:
            for amount in range(3):yield f'{kind}-{amount}',f'{kind} · {amount}/2','Recipientes',bowl(content,amount,WOOD_LIGHT,long)
        for n in range(3):
            yield f'nest-{n}',f'Ninho · {n} ovos','Galinheiro',nest(n)
            yield f'bucket-{n}',f'Ordenha · {n}/2','Pasto',bucket(n)
    if 'gates' in groups:
        from quintal_gate_models import gate_post, gate_leaf
        for side, label in [(-1, 'left'), (1, 'right')]:
            yield f'gate-post-{label}', f'Portão · poste {label}', 'Cercas', gate_post(side)
        for step in range(5):
            yield f'gate-leaf-{step}', f'Portão · abertura {step}/4', 'Cercas', gate_leaf(step)
    if 'shelter-layers' in groups:
        from quintal_shelter_layers import shelter_layer
        for kind,label in [('coop','Galinheiro'),('barn','Celeiro')]:
            for level,state in [(1,'ready'),(2,'ready'),(1,'upgrading')]:
                stem=f'{kind}-upgrading' if state=='upgrading' else f'{kind}-{level}-ready'
                for layer in ('back','front'):
                    yield f'{stem}-{layer}',f'{label} · {state} · {layer}',label,shelter_layer(kind,level,state,layer)
    if 'shelters' in groups:
        for kind,label in [('coop','Galinheiro'),('barn','Celeiro')]:
            for level,state in BUILDING_STATES:
                key=f'{kind}-upgrading' if state=='upgrading' else f'{kind}-{level}-{state}'
                yield key,f'{label} · nível {level} · {state}',label,shelter(kind,level,state)
    if 'garden' in groups:
        for wet in (False,True):
            for planted in (False,True):
                state=f'{"wet" if wet else "dry"}-{"planted" if planted else "empty"}'
                yield f'garden-bed-{state}',f'Canteiro · {"úmido" if wet else "seco"} · {"plantado" if planted else "vazio"}','Horta',garden_bed(wet,planted)
    if 'action-tools' in groups:
        from quintal_action_tools import action_tool
        for kind,label in [('watering-can','Regador'),('feed-scoop','Pá de ração'),('hay-fork','Forcado de feno')]:
            for stage in range(5):
                yield f'tool-{kind}-{stage}',f'{label} · inclinação {stage}/4','Ferramentas',action_tool(kind,stage)
    if 'harvest' in groups:
        from quintal_cozy_crops import harvested_root
        for kind,label in [('carrot','Cenoura'),('turnip','Nabo')]:
            yield f'crop-{kind}-harvest',f'{label} · raiz colhida','Cultivos',harvested_root(kind)
    if 'crops' in groups:
        for kind,label in [('corn','Milho'),('wheat','Trigo'),('carrot','Cenoura'),('turnip','Nabo'),('pumpkin','Abóbora'),('melon','Melão')]:
            for stage in range(4):
                yield f'crop-{kind}-{stage}',f'{label} · {["pequeno","médio","grande","pronto"][stage]}','Cultivos',crop(kind,stage)
    if 'stations' in groups:
        yield 'pot-base','Panela · base com brasas','Cozinha',cooking_pot(True, 'base')
        yield 'pot-lid','Panela · tampa independente','Cozinha',cooking_pot(False, 'lid')
        for level,state in BUILDING_STATES:
            key='kitchen-upgrading' if state=='upgrading' else f'kitchen-{level}-{state}'
            yield key,f'Cozinha · nível {level} · {state}','Cozinha',kitchen(level,state)
        for active in (False,True):
            yield f'pot-{int(active)}',f'Panela · {"preparando" if active else "em repouso"}','Cozinha',cooking_pot(active)
            yield f'queue-{int(active)}',f'Ingredientes reservados · {"próximo preparo" if active else "bandeja vazia"}','Cozinha',preparation_tray(active)
        for count in (0,1,3):yield f'portions-{count}',f'Porções · {count}','Cozinha',portions(count)
        for state in ('abandoned','building','ready'):
            yield f'post-{state}',f'Mercadinho rural · {state}','Mercadinho',post(state)
        yield 'parcel','Caixote · pedido pronto para retirar','Mercadinho',parcel()
    if 'orchard-fruits' in groups:
        for fruit in ('apple','pear'):
            for state in ('bud','growing','full','ready'):
                yield f'{fruit}-fruits-{state}',f'{fruit} · frutos independentes · {state}','Pomar',fruit_tree(fruit,state,fruits_only=True)
    if 'orchard' in groups:
        for state in ('abandoned','clearing','ready'):
            yield f'orchard-{state}',f'Pomar · {state}','Pomar',orchard(state)
        for fruit in ('apple','pear'):
            for state in ('empty','growing','ready'):
                yield f'{fruit}-tree-{state}',f'{"Macieira" if fruit=="apple" else "Pereira"} · {state}','Pomar',fruit_tree(fruit,state)


def gallery(rows):
    from quintal_model_gallery import render_gallery
    render_gallery(rows)


def export_render(job):
    key,label,group,model,directions=job
    model.export(SOURCES/(key+'.glb'))
    entries={}
    for i,d in enumerate(directions):
        meshes=[transform(m,angles=(0,-90*i,0)) for m in model.meshes]
        bake(key+'-'+d,meshes,entries)
        if key.startswith('crafted-gate-'):
            from build_habitat_lighting import project
            points = np.concatenate([m.positions for m in meshes])
            center = (points.min(0) + points.max(0)) / 2
            center[1] = 0
            entries[key+'-'+d]['depthCenter'] = (project(center) * entries[key+'-'+d]['scale']).tolist()

        entries[key+'-'+d]['source']=str((SOURCES/(key+'.glb')).relative_to(ROOT)).replace('\\','/')
    print(key,flush=True)
    return entries,{'id':key,'label':label,'group':group,'directions':directions}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--groups',nargs='+',default=['bowls','shelters','shelter-layers','gates','garden','crops','harvest','action-tools','stations','orchard','orchard-fruits'])
    parser.add_argument('--only',nargs='*')
    parser.add_argument('--directions',type=int,choices=[1,4],default=4)
    parser.add_argument('--workers',type=int,choices=[1,2],default=1)
    parser.add_argument('--preview-only',action='store_true',help='Isolated review render; does not touch shipping assets or manifests.')
    args=parser.parse_args()
    manifest=json.loads((OUT/'manifest.json').read_text(encoding='utf-8'))
    catalog_file=OUT/'crafted_catalog.json'
    rows=json.loads(catalog_file.read_text(encoding='utf-8')) if catalog_file.exists() else []
    indexed={r['id']:r for r in rows}
    jobs=[]
    for name,label,group,model in models(args.groups):
        if args.only and name not in args.only:continue
        key='crafted-'+name
        if args.preview_only:
            from render_habitat_models import framing,render_meshes
            target=GALLERY/'revisao';target.mkdir(parents=True,exist_ok=True)
            origin,scale=framing(model.meshes,size=512,padding=32)
            render_meshes(model.meshes,origin,scale,size=512,supersample=2).save(target/(key+'.png'))
            print('Review:',key,flush=True)
            continue
        directions=['NE','SE','SW','NW'][:args.directions]
        jobs.append((key,label,group,model,directions))
    if args.preview_only:return
    with ThreadPoolExecutor(max_workers=args.workers) as executor:
        for entries,row in executor.map(export_render,jobs):
            manifest.update(entries)
            indexed[row['id']]=row
    # Delete only explicitly retired generated variants inside these asset roots.
    for key in RETIRED:
        indexed.pop(key,None)
        (SOURCES/(key+'.glb')).unlink(missing_ok=True)
        for direction in ('NE','SE','SW','NW'):
            manifest.pop(key+'-'+direction,None)
            (OUT/(key+'-'+direction+'.png')).unlink(missing_ok=True)
    rows=sorted(indexed.values(),key=lambda r:(r['group'],r['id']))
    (OUT/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding='utf-8')
    catalog_file.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf-8')
    gallery(rows)


if __name__=='__main__':main()
