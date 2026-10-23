"""File-backed inventory plus the dated manual comparison with the approved scope.

File checks prove export completeness, not completed gameplay or animation.
Integration observations below were inspected in source on 2026-10-08.
"""
import fnmatch
import json
import re
from pathlib import Path
import numpy as np
from PIL import Image
from habitat_model import read_document,load_model

ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build/galeria-visual/modelos-novos'
ASSETS=ROOT/'assets/quintal/production'
CATALOG=ROOT/'docs/design/catalogo_modelos_quintal_2026-10-07.md'

# ID, title, file pattern, expected export count, scene evidence, remaining work.
REQUIREMENTS=[
('CAT-FOOD','Tigelas de ração','cat-food-*',18,'Seis cores × vazia/uma/duas porções; quantidade escolhida por habitat_care.dart.','Animação de abastecimento e redução do conteúdo ainda pendente.'),
('CAT-WATER','Tigelas de água','cat-water-*',18,'Seis cores × três níveis. A cena usa cheia/vazia, conforme a regra atual.','Estado parcial existe como recurso; falta a transição de abastecimento e ondulação.'),
('COOP-HOUSE','Galinheiro','coop-[12]-*|coop-upgrading',5,'Abandono, reforma, níveis 1/2 e ampliação. Coleta ligada à casinha.','Revisar alinhamento da origem entre ruína e prédio pronto; finalizar entrada/saída das galinhas.'),
('COOP-NEST','Ninhos','nest-*',3,'Vazio, um e dois ovos do food-kit; largura 0,475 para módulos com passo 0,50 na casinha.','Falta efeito de coleta; conferir encaixe final em todos os níveis no jogo.'),
('COOP-FOOD','Comedouro das galinhas','coop-food-*',3,'Vazio, parcial e cheio; abastecimento acompanha fed_count.','Animação de servir e aproximação ao comedouro pendentes.'),
('COOP-WATER','Bebedouro das galinhas','coop-water-*',3,'Três níveis exportados; estado persistente usa validade da água.','Faltam transição de encher e deslocamento para beber.'),
('PASTURE-BARN','Celeiro','barn-[12]-*|barn-upgrading',5,'Abandono, reforma, níveis 1/2 e ampliação. Abrigo substitui a tenda.','Revisar origem entre ruína/pronto, circulação e entrada das vacas.'),
('PASTURE-COW','Vaquinhas reutilizadas','',0,'Modelo existente preservado; atlas idle/walk/eat; indicação e ação de leite por vaca.','Faltam beber no cocho e ordenha animada. O eat atual acontece no ponto de descanso.'),
('PASTURE-FOOD','Cocho de alimento','cow-food-*',3,'Três níveis, cavaletes, cavidade e feno. Integrado ao abastecimento real.','Falta animação de reposição e comer junto ao cocho.'),
('PASTURE-WATER','Cocho de água','cow-water-*',3,'Três níveis abaixo da borda; cena usa cheio/vazio.','Falta animação de abastecimento e beber.'),
('PASTURE-BUCKET','Balde de ordenha','bucket-*',3,'Vazio, parcial e cheio exportados em GLB e quatro vistas.','Ainda não usado pela cena; falta aparecer, encher e sair durante a ordenha.'),
('GARDEN-BED','Canteiros','garden-bed-*',4,'Quatro combinações de solo seco/úmido e vazio/plantado; cultura separada.','Falta efeito de rega e de retirada da planta.'),
('GARDEN-OVERGROWN','Horta abandonada e preparo','',0,'A cena ainda usa garden-ruins e construction-site legados; recuperação usa os novos canteiros.','Faltam composição editável própria, quatro orientações e preparo visível dos lotes de expansão.'),
('CROP-CORN','Milho','crop-corn-*',4,'Quatro estágios; espiga madura revisada sem alterar caule, folhas ou pendão.','Faltam balanço discreto, rega e colheita animados.'),
('CROP-WHEAT','Trigo','crop-wheat-*',4,'Quatro estágios próprios; formação de espigas e transição do verde ao dourado.','Faltam balanço discreto, rega e colheita animados.'),
('CROP-CARROT','Cenoura','crop-carrot-*',4,'Quatro estágios, folhas recortadas e só o ombro da raiz acima da terra.','Falta efeito de colher que possa mostrar a raiz inteira.'),
('CROP-TURNIP','Nabo','crop-turnip-*',4,'Quatro estágios, roseta e topo de raiz parcialmente aparente.','Falta efeito de colher que possa mostrar a raiz inteira.'),
('CROP-PUMPKIN','Abóbora','crop-pumpkin-*',4,'Quatro estágios; geometria madura original do nature-kit com as ramas novas.','Faltam balanço, rega e retirada animados.'),
('CROP-MELON','Melão','crop-melon-*',4,'Quatro estágios; forma facetada do mesmo pacote e listras verdes suaves.','Faltam balanço, rega e retirada animados.'),
('KITCHEN-STATION','Cozinha','kitchen-*',5,'Abandono, reforma, dois níveis e ampliação. Módulos de preparo/fila/porções separados.','Revisão final de profundidade dos módulos na bancada, sobretudo nível 2.'),
('KITCHEN-POT','Panela','pot-*',2,'Repouso e preparo exportados; ativo somente para tarefa que já começou.','Ainda estática: faltam tampa em movimento e vapor; revisar integração das brasas ao fogão.'),
('KITCHEN-PORTIONS','Refeições prontas','portions-*',3,'Um mesmo recipiente com níveis diferentes; a cena o omite sem lotes prontos.','Falta animação de retirada. Não multiplicar potes por porção.'),
('KITCHEN-QUEUE','Ingredientes reservados','queue-*',2,'Bandeja vazia/com recipiente tampado e pano; a versão com ingredientes aparece para tarefas futuras.','Confirmar visualmente todas as combinações no nível 2.'),
('ORDER-POST','Mercadinho rural','post-*',3,'Abandono, reforma e funcionamento; modelo de reforma disponível sem inventar espera no desbloqueio imediato.','Falta transição visual de recuperação; bancada agora tem caixotinhos de frutas e pano.'),
('ORDER-PARCEL','Caixote de retirada','parcel',1,'Caixote coberto presente quando pronto, ausente antes/depois da coleta; ausência não exige outra malha.','Falta animação de retirada.'),
('ORCHARD-OVERGROWN','Vegetação do pomar','orchard-*',3,'Abandono, limpeza e recuperado exportados; abandono/limpeza usam grama e arbustos.','Composição recuperada ainda não é adicionada à cena para preservar arbustos nas bordas.'),
('ORCHARD-APPLE','Macieira','apple-tree-*',3,'Sem frutos, frutos verdes e maduros. Coleta individual ligada à árvore.','Frutos maduros ainda têm quantidade visual fixa; falta retirada animada e conferir correspondência com saldo real.'),
('ORCHARD-PEAR','Pereira','pear-tree-*',3,'Sem frutos, frutos verdes e maduros. Coleta individual ligada à árvore.','Frutos maduros ainda têm quantidade visual fixa; falta retirada animada e conferir correspondência com saldo real.'),
]

COMMON=[
('Destroços, capim, arbustos e pedras','Reaproveitados nas composições; abrigos, cozinha e Mercadinho têm ruínas próprias.','Não existe um conjunto novo independente de ferramentas de obra em GLB.'),
('Cercas e portões','Cercas e portão existente reutilizados nos cercados.','Portão não abre/fecha quando o animal passa; falta eixo/animação e circulação integrada.'),
('Conteúdos e materiais','Ração, grãos, feno, água, leite, ovos, frutas e porções são peças separadas nos GLBs.','Animações de transferência/coleta não estão finalizadas.'),
('Origem e escala entre estados','Quatro vistas, origem e escala exportadas; testes de encaixe dos itens passaram.','Ruínas de coop/pasto são posicionadas em +1,5/+1,5; prontos em +0,8/+0,55. Ainda não preservam a mesma origem na cena.'),
('Relógio e produto pronto','Relógios e pronto consultam prazos/estoques; pronto tem prioridade. Coleta de vaca/fruteira é individual.','Falta a apresentação de obra de expansão em todos os alvos e validação interativa de todos os estados simultâneos.'),
('Interações e confirmação','Operações aguardam a API, impedem repetição durante envio e preservam o estado em falha.','Faltam as animações confirmadas de encher, colher, retirar ovos/frutos, leite e caixote.'),
('Animais e redução de movimento','Idle/walk/eat são reutilizados; reducedMotion interrompe o movimento da cena.','Beber, ordenhar, entrar/sair do abrigo e aproximação dos recipientes ainda não cumprem o fluxo completo.'),
('Coleções individuais na API','collect_residents aceita resident_id para pasto/pomar; há teste de idempotência e preservação do outro residente.','Validar também o fluxo ponta a ponta com a API em execução; capturas usam fixtures.'),
('Preço, desconto e duração','Revisão visual atual não altera o catálogo econômico nem os prazos.','Ajustes futuros devem continuar preservando esses valores.'),
('Galeria e fontes','Todos os GLBs do lote têm quatro PNGs; galeria inclui estados, arquivos e famílias.','Fontes e recursos existentes não substituem prova de animação ou funcionalidade concluída.'),
]


def audit():
    rows=json.loads((ASSETS/'crafted_catalog.json').read_text(encoding='utf-8'))
    manifest=json.loads((ASSETS/'manifest.json').read_text(encoding='utf-8'))
    ids={row['id'] for row in rows};errors=[];png_count=0
    declared=set(re.findall(r'^\| ([A-Z]+(?:-[A-Z]+)+) \|',CATALOG.read_text(encoding='utf-8'),re.M))
    checked={r[0] for r in REQUIREMENTS}
    if declared!=checked:errors.append(f'Cobertura do catálogo divergente: {declared ^ checked}')
    result=[]
    for id,title,pattern,count,scene,pending in REQUIREMENTS:
        matches=sorted(key for key in ids if any(fnmatch.fnmatchcase(key,'crafted-'+p) for p in pattern.split('|') if p))
        if len(matches)!=count:errors.append(f'{id}: esperados {count}, encontrados {len(matches)}')
        result.append({'id':id,'title':title,'models':matches,'scene':scene,'pending':pending})
    for row in rows:
        path=ROOT/'art/quintal/models'/f'{row["id"]}.glb'
        try:
            doc,_=read_document(path)
            names=[n['name'] for n in doc['nodes']]
            if len(names)!=len(set(names)):errors.append(f'Nomes repetidos: {path.name}')
            meshes=load_model(path,ground=0)
            if not meshes or not all(np.isfinite(m.positions).all() for m in meshes):errors.append(f'Geometria inválida: {path.name}')
            if row['directions']!=['NE','SE','SW','NW']:errors.append(f'Orientações incompletas: {path.name}')
            for direction in row['directions']:
                key=row['id']+'-'+direction;meta=manifest[key]
                image=Image.open(ASSETS/(key+'.png')).convert('RGBA');box=image.getbbox()
                if not box or [box[0],box[1],box[2]-box[0],box[3]-box[1]]!=meta['bounds']:errors.append(f'Limites PNG divergentes: {key}')
                if meta['source']!=str(path.relative_to(ROOT)).replace('\\','/'):errors.append(f'Fonte divergente: {key}')
                png_count+=1
        except (OSError,ValueError,KeyError) as e:errors.append(f'{row["id"]}: {e}')
    report={'reviewed_on':'2026-10-08','models':len(rows),'pngs':png_count,'requirements':result,'common':[{'title':a,'evidence':b,'pending':c} for a,b,c in COMMON],'errors':errors}
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'auditoria.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
    lines=['# Conferência dos modelos do Quintal — 08/10/2026','',
        'Comparação com [o catálogo aprovado](catalogo_modelos_quintal_2026-10-07.md).',
        f'Foram conferidos **{len(rows)} arquivos GLB e {png_count} PNGs**, incluindo cores e estados. Os {len(REQUIREMENTS)} IDs de modelos do catálogo estão relacionados abaixo. **O lote completo ainda não corresponde a todos os requisitos de animação e integração.**','',
        'A verificação automática confere existência, geometria finita, nomes, fonte, quatro orientações e limites dos PNGs. As observações de integração são uma revisão manual dos arquivos atuais; não são inferidas da presença dos assets.','',
        '## Modelos e estados','',
        '| ID | Modelo | GLBs neste lote | Evidência na cena | Falta concluir |','|---|---|---:|---|---|']
    for r in result:lines.append(f'| {r["id"]} | {r["title"]} | {len(r["models"])} | {r["scene"]} | {r["pending"]} |')
    lines+=['','## Requisitos compartilhados','', '| Requisito | Evidência | Pendência / limite |','|---|---|---|']
    lines += [f'| {a} | {b} | {c} |' for a,b,c in COMMON]
    lines+=['','## Fontes examinadas','',
        '- `tool/quintal_cozy_models.py`, `tool/quintal_cozy_crops.py`, `tool/build_quintal_crafted_models.py`: geometria e exportação.',
        '- `lib/game/quintal_production_scene.dart`: modelos, fases, posições, quantidades e indicadores.',
        '- `lib/game/quintal_resident_motion.dart`: trajetos e clipes usados pelos residentes.',
        '- `lib/services/habitat_care.dart`: conteúdo e cor dos potes.',
        '- `lib/widgets/quintal_object_actions.dart`: alvos de coleta e ações.',
        '- API: `app/services/quintal_production.py` e `tests/test_quintal_production.py`: coleta por residente.',
        '- `test/quintal_production_visual_test.dart`: capturas de demonstração; não substituem validação de conta real.','',
        '## Resultado da checagem de arquivos','',*(errors or ['Nenhuma divergência de arquivo encontrada.'])]
    (ROOT/'docs/design/auditoria_modelos_quintal_2026-10-08.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    if errors:raise ValueError('\n'.join(errors))
    return report


if __name__=='__main__':
    r=audit();print(f'{r["models"]} GLBs; {r["pngs"]} PNGs; {len(r["requirements"])} requisitos de modelos conferidos.')
