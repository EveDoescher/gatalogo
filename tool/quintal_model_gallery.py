"""One browsable gallery for the complete authored lot and earlier animal variants."""
import html
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/galeria-visual/modelos-novos'
H=html.escape
FAMILIES=[('cats','Potes dos gatos'),('coop','Galinheiro'),('pasture','Pasto e ordenha'),('garden','Horta e cultivos'),('kitchen','Cozinha'),('orders','Mercadinho rural'),('orchard','Pomar')]


def family(key):
    k=key.removeprefix('crafted-')
    if k.startswith('cat-'):return 'cats'
    if k.startswith(('coop-','nest-')):return 'coop'
    if k.startswith(('barn-','cow-','bucket-')):return 'pasture'
    if k.startswith(('garden-','crop-')):return 'garden'
    if k.startswith(('kitchen-','pot-','portions-','queue-')):return 'kitchen'
    if k.startswith(('post-','parcel')):return 'orders'
    return 'orchard'


def label(row):
    key=row['id'].removeprefix('crafted-')
    for prefix,name in [('coop','Galinheiro'),('barn','Celeiro'),('kitchen','Cozinha')]:
        states={'1-abandoned':'Abandonado','1-building':'Em reforma','1-ready':'Nível 1','upgrading':'Ampliando','2-ready':'Nível 2'}
        if key.startswith(prefix+'-') and key[len(prefix)+1:] in states:
            return name+' · '+states[key[len(prefix)+1:]]
    if key.startswith('cat-'):
        _,kind,color,amount=key.split('-')
        names=['Rosa','Azul','Lilás','Amarelo','Verde','Menta']
        state=['Vazio','Uma porção','Duas porções'][int(amount)] if kind=='food' else ['Vazio','Parcial','Cheio'][int(amount)]
        return f'{"Ração" if kind=="food" else "Água"} · {names[int(color)]} · {state}'
    for prefix,name in [('cow-food','Cocho de alimento'),('cow-water','Cocho de água'),('coop-food','Comedouro'),('coop-water','Bebedouro')]:
        if key.startswith(prefix):return name+' · '+['Vazio','Parcial','Cheio'][int(key[-1])]
    value=row['label']
    for old,new in [('abandoned','abandono'),('building','em reforma'),('ready','pronto'),('growing','frutos crescendo'),('empty','sem frutos')]:value=value.replace(old,new)
    if key=='portions-3':value='Refeições · vários lotes no mesmo recipiente'
    if key=='portions-1':value='Refeições · um lote'
    if key=='portions-0':value='Refeições · recipiente vazio'
    return value


def display_order(row):
    key=row['id'].removeprefix('crafted-')
    for prefix in ('coop','barn','kitchen'):
        suffix=key.removeprefix(prefix+'-')
        states=['1-abandoned','1-building','1-ready','upgrading','2-ready']
        if key.startswith(prefix+'-') and suffix in states:return (0,states.index(suffix),'')
    return (1,0,key)


def render_gallery(rows):
    OUT.mkdir(parents=True,exist_ok=True)
    audit_path=OUT/'auditoria.json'
    audit=json.loads(audit_path.read_text(encoding='utf-8')) if audit_path.exists() else None
    intro=f'{len(rows)} arquivos GLB · {sum(len(r["directions"]) for r in rows)} vistas exportadas · cores e estados incluídos'
    sections=[]
    for id,title in FAMILIES:
        group=sorted([r for r in rows if family(r['id'])==id],key=display_order);cards=[]
        for row in group:
            key=row['id'];title_card=label(row);base='../../../assets/quintal/production/'+key
            others=''.join(f'<a href="{base}-{d}.png"><img loading="lazy" src="{base}-{d}.png" alt="{H(title_card)}: {d}"><span>{d}</span></a>' for d in row['directions'][1:])
            cards.append(f'<article class="model" data-name="{H(title_card+" "+key)}"><h3>{H(title_card)}</h3><a class="hero-model" href="{base}-NE.png"><img loading="lazy" src="{base}-NE.png" alt="{H(title_card)}"></a><details><summary>Outras orientações</summary><div class="views">{others}</div></details><a class="source" href="../../../art/quintal/models/{key}.glb">Arquivo 3D · GLB</a></article>')
        sections.append(f'<section class="family" id="{id}" data-family="{id}"><header><h2>{title}</h2><span>{len(group)} modelos e estados</span></header><div class="grid">{"".join(cards)}</div></section>')
    audit_html=''
    if audit:
        items=[]
        for r in audit['requirements']:
            items.append(f'<tr><th scope="row">{H(r["id"])}<br><span class="muted">{H(r["title"])}</span></th><td>{len(r["models"])} GLBs</td><td>{H(r["scene"])}</td><td>{H(r["pending"])}</td></tr>')
        common=''.join(f'<details><summary>{H(r["title"])}</summary><p>{H(r["evidence"])}</p><p class="pending">{H(r["pending"])}</p></details>' for r in audit['common'])
        audit_html=f'''<section id="audit"><h2>Conferência com a lista combinada</h2><p>Revisão de 08/10/2026. Todos os {len(audit["requirements"])} IDs do catálogo estão mapeados abaixo. Arquivos presentes não significam que a animação ou o fluxo estejam concluídos.</p><p><strong>Ainda não está tudo completo.</strong> Faltam a composição própria de recuperação da horta, ajustes de encaixe/posição e as animações de interação descritas na lista.</p><a href="../../../docs/auditoria_modelos_quintal_2026-10-08.md">Relatório completo em Markdown</a><div class="table"><table><thead><tr><th>Requisito</th><th>Arquivos do lote</th><th>O que existe</th><th>O que falta</th></tr></thead><tbody>{"".join(items)}</tbody></table></div><h3>Requisitos compartilhados</h3>{common}</section>'''
    animals=[]
    for id,name,note in [('hen-white','Galinha branca','Adaptação do pintinho, com crista e cores próprias.'),('hen-brown','Galinha marrom','Mesma forma quadrada, com a segunda paleta.'),('cow','Vaquinha','Modelo original reutilizado; adaptação funcional ainda parcial.')]:
        meta=json.loads((ROOT/'assets/quintal'/id/'animations.json').read_text())
        size=meta['size'];clip=meta['clips']['idle'];count=clip['count']
        animals.append(f'<article><h3>{name}</h3><div class="resident" role="img" aria-label="{name}, animação de repouso" style="--size:{size}px;--end:{-size*count}px;--duration:{clip["duration"]}s;--frames:{count};background-image:url(../../../assets/quintal/{id}/idle.png)"></div><p>{note}</p></article>')
    coats_path=ROOT/'assets/habitat/cat_coats/catalog.json'
    coats=json.loads(coats_path.read_text(encoding='utf-8')) if coats_path.exists() else []
    coat_images=''.join(f'<figure><img loading="lazy" src="../../../assets/habitat/cat_coats/{r["id"]}__preview.png" alt="{H(r["label"])}"><figcaption>{H(r["label"])}</figcaption></figure>' for r in coats)
    existing=f'<section id="animals"><h2>Animais e pelagens já trabalhados</h2><p>Separados dos {len(rows)} GLBs novos: são adaptações e reutilizações dos animais existentes.</p><div class="grid">{"".join(animals)}</div><h3>{len(coats)} pelagens dos gatos</h3><p>O corpo permanece o mesmo. <a href="../pelagens/index.html">Abrir galeria com as animações das pelagens</a></p><div class="coats">{coat_images}</div></section>'
    options=''.join(f'<option value="{id}">{title}</option>' for id,title in FAMILIES)
    page='''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Quintal — galeria completa de modelos</title><style>
:root{color-scheme:light}*{box-sizing:border-box}body{margin:0;background:#f6f0df;color:#493627;font:16px/1.55 system-ui,sans-serif}main{max-width:1320px;margin:auto;padding:28px}h1{font-size:clamp(28px,4vw,44px);line-height:1.15;margin:12px 0}h2{font-size:26px;margin:0}h3{font-size:17px;margin:0 0 10px}p{max-width:86ch}a{color:#365f38}nav{display:flex;gap:12px;flex-wrap:wrap;margin:22px 0}nav a,.source{padding:9px 13px;background:#e4ebcf;border:1px solid #bcc9a4;border-radius:10px;text-decoration:none}section{margin:46px 0}section>header{display:flex;align-items:baseline;gap:16px;margin-bottom:18px;flex-wrap:wrap}.muted,section>header span{font-weight:400;color:#706c54}.notice{background:#fff6da;border-left:4px solid #bc9857;padding:14px 18px;border-radius:0 12px 12px 0}.filters{display:flex;gap:16px;flex-wrap:wrap;margin:24px 0}.filters label{display:grid;gap:6px}input,select{font:inherit;padding:10px;border:1px solid #b1bc95;border-radius:9px;background:#fffaf0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(260px,1fr));gap:18px}.grid>article{padding:18px;background:#fffaf0;border:1px solid #cfd4b7;border-radius:16px;min-width:0}.hero-model{display:grid;place-items:center;background:#e8ecd9;border-radius:12px;margin:12px 0}.hero-model img{display:block;width:100%;max-width:320px;aspect-ratio:1;object-fit:contain}.source{display:inline-block;margin-top:12px}summary{cursor:pointer;padding:8px 0;font-weight:600}.views{display:grid;grid-template-columns:repeat(3,1fr);gap:6px}.views img{display:block;width:100%}.views a{text-align:center;font-size:13px}#audit{background:#fffaf0;border:1px solid #cfd4b7;padding:22px;border-radius:16px}.table{overflow-x:auto;margin:20px 0}table{border-collapse:collapse;min-width:860px;width:100%;font-size:14px}th,td{padding:12px;text-align:left;vertical-align:top;border-bottom:1px solid #d9dcc8}thead{background:#e4ebcf}.pending{color:#805c2c}#audit>details{border-top:1px solid #d9dcc8;padding:8px 0}.coats{display:grid;grid-template-columns:repeat(auto-fit,minmax(145px,1fr));gap:10px}.coats figure{margin:0;padding:10px;background:#e8ecd9;border-radius:12px;text-align:center;font-size:14px}.coats img{width:100%;max-width:160px}.resident{width:var(--size);height:var(--size);margin:auto;background-repeat:no-repeat;animation:idle var(--duration) steps(var(--frames)) infinite}@keyframes idle{to{background-position-x:var(--end)}}:focus-visible{outline:3px solid #b28452;outline-offset:4px}[hidden]{display:none!important}@media(prefers-reduced-motion:reduce){.resident{animation:none}}@media(max-width:600px){main{padding:16px}.grid{grid-template-columns:1fr 1fr;gap:10px}.grid>article{padding:10px}h3{font-size:14px}.source{font-size:13px;padding:6px}#audit{padding:14px}}
</style><main><a href="../galeria.html">← Galeria de telas</a><h1>Todos os modelos do Quintal</h1><p>INTRO</p><div class="notice">Fontes 3D e estados visuais conferidos. O lote ainda tem pendências de animação e integração — veja a comparação com a lista.</div><nav><a href="#models">Modelos e estados</a><a href="cultivos.html">Crescimento das plantações</a><a href="#animals">Animais e pelagens</a><a href="#audit">Conferência com a lista</a><a href="../quintal_world_page.png">Captura dentro do Quintal</a></nav><div id="models" class="filters"><label>Espaço<select id="family"><option value="">Todos os espaços</option>OPTIONS</select></label><label>Buscar modelo<input id="search" type="search" placeholder="Espiga, celeiro, água…"></label></div><p id="result" aria-live="polite"></p>SECTIONS EXISTING AUDIT</main><script>
const norm=s=>s.normalize('NFD').replace(/[\u0300-\u036f]/g,'').toLowerCase();
function filter(){const q=norm(document.querySelector('#search').value),f=document.querySelector('#family').value;let count=0;document.querySelectorAll('.family').forEach(section=>{let visible=0;section.querySelectorAll('.model').forEach(card=>{card.hidden=!!q&&!norm(card.dataset.name).includes(q);if(!card.hidden)visible++});section.hidden=(!!f&&section.dataset.family!==f)||!visible;if(!section.hidden)count+=visible});document.querySelector('#result').textContent=count+' modelos e estados exibidos'}document.querySelector('#search').addEventListener('input',filter);document.querySelector('#family').addEventListener('change',filter);filter();</script></html>'''
    page=page.replace('INTRO',H(intro)).replace('OPTIONS',options).replace('SECTIONS',''.join(sections)).replace('EXISTING',existing).replace('AUDIT',audit_html)
    (OUT/'index.html').write_text(page,encoding='utf-8')


if __name__=='__main__':
    from quintal_model_audit import audit
    audit()
    render_gallery(json.loads((ROOT/'assets/quintal/production/crafted_catalog.json').read_text(encoding='utf-8')))
    print(OUT/'index.html')
