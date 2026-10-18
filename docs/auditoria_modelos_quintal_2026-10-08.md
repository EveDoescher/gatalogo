# Conferência dos modelos do Quintal — 08/10/2026

Comparação com [o catálogo aprovado](catalogo_modelos_quintal_2026-10-07.md).
Foram conferidos **117 arquivos GLB e 468 PNGs**, incluindo cores e estados. Os 28 IDs de modelos do catálogo estão relacionados abaixo. **O lote completo ainda não corresponde a todos os requisitos de animação e integração.**

A verificação automática confere existência, geometria finita, nomes, fonte, quatro orientações e limites dos PNGs. As observações de integração são uma revisão manual dos arquivos atuais; não são inferidas da presença dos assets.

## Modelos e estados

| ID | Modelo | GLBs neste lote | Evidência na cena | Falta concluir |
|---|---|---:|---|---|
| CAT-FOOD | Tigelas de ração | 18 | Seis cores × vazia/uma/duas porções; quantidade escolhida por habitat_care.dart. | Animação de abastecimento e redução do conteúdo ainda pendente. |
| CAT-WATER | Tigelas de água | 18 | Seis cores × três níveis. A cena usa cheia/vazia, conforme a regra atual. | Estado parcial existe como recurso; falta a transição de abastecimento e ondulação. |
| COOP-HOUSE | Galinheiro | 5 | Abandono, reforma, níveis 1/2 e ampliação. Coleta ligada à casinha. | Revisar alinhamento da origem entre ruína e prédio pronto; finalizar entrada/saída das galinhas. |
| COOP-NEST | Ninhos | 3 | Vazio, um e dois ovos do food-kit; largura 0,475 para módulos com passo 0,50 na casinha. | Falta efeito de coleta; conferir encaixe final em todos os níveis no jogo. |
| COOP-FOOD | Comedouro das galinhas | 3 | Vazio, parcial e cheio; abastecimento acompanha fed_count. | Animação de servir e aproximação ao comedouro pendentes. |
| COOP-WATER | Bebedouro das galinhas | 3 | Três níveis exportados; estado persistente usa validade da água. | Faltam transição de encher e deslocamento para beber. |
| PASTURE-BARN | Celeiro | 5 | Abandono, reforma, níveis 1/2 e ampliação. Abrigo substitui a tenda. | Revisar origem entre ruína/pronto, circulação e entrada das vacas. |
| PASTURE-COW | Vaquinhas reutilizadas | 0 | Modelo existente preservado; atlas idle/walk/eat; indicação e ação de leite por vaca. | Faltam beber no cocho e ordenha animada. O eat atual acontece no ponto de descanso. |
| PASTURE-FOOD | Cocho de alimento | 3 | Três níveis, cavaletes, cavidade e feno. Integrado ao abastecimento real. | Falta animação de reposição e comer junto ao cocho. |
| PASTURE-WATER | Cocho de água | 3 | Três níveis abaixo da borda; cena usa cheio/vazio. | Falta animação de abastecimento e beber. |
| PASTURE-BUCKET | Balde de ordenha | 3 | Vazio, parcial e cheio exportados em GLB e quatro vistas. | Ainda não usado pela cena; falta aparecer, encher e sair durante a ordenha. |
| GARDEN-BED | Canteiros | 4 | Quatro combinações de solo seco/úmido e vazio/plantado; cultura separada. | Falta efeito de rega e de retirada da planta. |
| GARDEN-OVERGROWN | Horta abandonada e preparo | 0 | A cena ainda usa garden-ruins e construction-site legados; recuperação usa os novos canteiros. | Faltam composição editável própria, quatro orientações e preparo visível dos lotes de expansão. |
| CROP-CORN | Milho | 4 | Quatro estágios; espiga madura revisada sem alterar caule, folhas ou pendão. | Faltam balanço discreto, rega e colheita animados. |
| CROP-WHEAT | Trigo | 4 | Quatro estágios próprios; formação de espigas e transição do verde ao dourado. | Faltam balanço discreto, rega e colheita animados. |
| CROP-CARROT | Cenoura | 4 | Quatro estágios, folhas recortadas e só o ombro da raiz acima da terra. | Falta efeito de colher que possa mostrar a raiz inteira. |
| CROP-TURNIP | Nabo | 4 | Quatro estágios, roseta e topo de raiz parcialmente aparente. | Falta efeito de colher que possa mostrar a raiz inteira. |
| CROP-PUMPKIN | Abóbora | 4 | Quatro estágios; geometria madura original do nature-kit com as ramas novas. | Faltam balanço, rega e retirada animados. |
| CROP-MELON | Melão | 4 | Quatro estágios; forma facetada do mesmo pacote e listras verdes suaves. | Faltam balanço, rega e retirada animados. |
| KITCHEN-STATION | Cozinha | 5 | Abandono, reforma, dois níveis e ampliação. Módulos de preparo/fila/porções separados. | Revisão final de profundidade dos módulos na bancada, sobretudo nível 2. |
| KITCHEN-POT | Panela | 2 | Repouso e preparo exportados; ativo somente para tarefa que já começou. | Ainda estática: faltam tampa em movimento e vapor; revisar integração das brasas ao fogão. |
| KITCHEN-PORTIONS | Refeições prontas | 3 | Um mesmo recipiente com níveis diferentes; a cena o omite sem lotes prontos. | Falta animação de retirada. Não multiplicar potes por porção. |
| KITCHEN-QUEUE | Ingredientes reservados | 2 | Bandeja vazia/com recipiente tampado e pano; a versão com ingredientes aparece para tarefas futuras. | Confirmar visualmente todas as combinações no nível 2. |
| ORDER-POST | Mercadinho rural | 3 | Abandono, reforma e funcionamento; modelo de reforma disponível sem inventar espera no desbloqueio imediato. | Falta transição visual de recuperação; bancada agora tem caixotinhos de frutas e pano. |
| ORDER-PARCEL | Caixote de retirada | 1 | Caixote coberto presente quando pronto, ausente antes/depois da coleta; ausência não exige outra malha. | Falta animação de retirada. |
| ORCHARD-OVERGROWN | Vegetação do pomar | 3 | Abandono, limpeza e recuperado exportados; abandono/limpeza usam grama e arbustos. | Composição recuperada ainda não é adicionada à cena para preservar arbustos nas bordas. |
| ORCHARD-APPLE | Macieira | 3 | Sem frutos, frutos verdes e maduros. Coleta individual ligada à árvore. | Frutos maduros ainda têm quantidade visual fixa; falta retirada animada e conferir correspondência com saldo real. |
| ORCHARD-PEAR | Pereira | 3 | Sem frutos, frutos verdes e maduros. Coleta individual ligada à árvore. | Frutos maduros ainda têm quantidade visual fixa; falta retirada animada e conferir correspondência com saldo real. |

## Requisitos compartilhados

| Requisito | Evidência | Pendência / limite |
|---|---|---|
| Destroços, capim, arbustos e pedras | Reaproveitados nas composições; abrigos, cozinha e Mercadinho têm ruínas próprias. | Não existe um conjunto novo independente de ferramentas de obra em GLB. |
| Cercas e portões | Cercas e portão existente reutilizados nos cercados. | Portão não abre/fecha quando o animal passa; falta eixo/animação e circulação integrada. |
| Conteúdos e materiais | Ração, grãos, feno, água, leite, ovos, frutas e porções são peças separadas nos GLBs. | Animações de transferência/coleta não estão finalizadas. |
| Origem e escala entre estados | Quatro vistas, origem e escala exportadas; testes de encaixe dos itens passaram. | Ruínas de coop/pasto são posicionadas em +1,5/+1,5; prontos em +0,8/+0,55. Ainda não preservam a mesma origem na cena. |
| Relógio e produto pronto | Relógios e pronto consultam prazos/estoques; pronto tem prioridade. Coleta de vaca/fruteira é individual. | Falta a apresentação de obra de expansão em todos os alvos e validação interativa de todos os estados simultâneos. |
| Interações e confirmação | Operações aguardam a API, impedem repetição durante envio e preservam o estado em falha. | Faltam as animações confirmadas de encher, colher, retirar ovos/frutos, leite e caixote. |
| Animais e redução de movimento | Idle/walk/eat são reutilizados; reducedMotion interrompe o movimento da cena. | Beber, ordenhar, entrar/sair do abrigo e aproximação dos recipientes ainda não cumprem o fluxo completo. |
| Coleções individuais na API | collect_residents aceita resident_id para pasto/pomar; há teste de idempotência e preservação do outro residente. | Validar também o fluxo ponta a ponta com a API em execução; capturas usam fixtures. |
| Preço, desconto e duração | Revisão visual atual não altera o catálogo econômico nem os prazos. | Ajustes futuros devem continuar preservando esses valores. |
| Galeria e fontes | Todos os GLBs do lote têm quatro PNGs; galeria inclui estados, arquivos e famílias. | Fontes e recursos existentes não substituem prova de animação ou funcionalidade concluída. |

## Fontes examinadas

- `tool/quintal_cozy_models.py`, `tool/quintal_cozy_crops.py`, `tool/build_quintal_crafted_models.py`: geometria e exportação.
- `lib/game/quintal_production_scene.dart`: modelos, fases, posições, quantidades e indicadores.
- `lib/game/quintal_resident_motion.dart`: trajetos e clipes usados pelos residentes.
- `lib/services/habitat_care.dart`: conteúdo e cor dos potes.
- `lib/widgets/quintal_object_actions.dart`: alvos de coleta e ações.
- API: `app/services/quintal_production.py` e `tests/test_quintal_production.py`: coleta por residente.
- `test/quintal_production_visual_test.dart`: capturas de demonstração; não substituem validação de conta real.

## Resultado da checagem de arquivos

Nenhuma divergência de arquivo encontrada.
