# Catálogo definitivo de modelos e estados do Quintal

Data: 07/10/2026. Escopo consolidado com a usuária para o lote de arte e integração.

**Estado da entrega — 08/10:** a revisão dos abrigos, cozinha, Mercadinho e recipientes foi exportada para os GLBs e imagens usados pelo jogo. Os seis cultivos agora têm 24 estados 3D revisados, incluindo trigo com espigas facetadas e maturação verde/dourada. Foram acrescentados quatro canteiros e três estados de ampliação. A galeria está em `build/galeria-visual/modelos-novos/index.html`, com comparação dos cultivos na mesma escala em `cultivos.html`. O lote completo continua em desenvolvimento: animações de interação, demais estados complementares e validação dos fluxos no Quintal ainda precisam ser concluídos. As imagens isoladas não comprovam o funcionamento desses fluxos.

Referências de implementação: `docs/plano_quintal_producao_2026-10-06.md`, `lib/game/quintal_production_scene.dart`, `tool/build_quintal_compositions.py` e, na API, `app/services/quintal_catalog.py` e `app/services/quintal_production.py`.

Conferência atual: [auditoria dos 28 itens, fontes e pendências](auditoria_modelos_quintal_2026-10-08.md). A galeria completa inclui os 117 GLBs do lote, suas 468 vistas e acesso às adaptações anteriores dos animais. Foram retiradas as seis variantes indevidas de nível 2 abandonado/em reforma e as duas caixas de correio. A espiga madura tem corpo afunilado, grãos encaixados em toda a circunferência e palha aberta; caule, folhas e pendão foram preservados.

## 1. Direção de arte e regras comuns

- Preservar o estilo dos gatos, galinhas e vaquinhas: volumes simples, poucos polígonos, cores suaves, madeira quente e detalhes legíveis no celular.
- Objetos têm espessura e interior quando necessário. Água e comida ficam dentro do recipiente, abaixo da borda; eliminar superfícies flutuantes e colheres nos potes dos animais.
- Manter escala, posição no chão, iluminação e orientação consistentes entre estados. Uma construção recuperada ocupa o mesmo terreno da abandonada.
- As ações pertencem aos objetos: ovos no galinheiro, leite na vaca, plantio no canteiro, refeições e água nos potes, receitas na cozinha e pedidos no Mercadinho rural.
- Produzir fontes 3D editáveis e reproduzíveis, com peças nomeadas, materiais separados e exportação GLB. Gerar sprites, prévias e sombras nas quatro orientações usadas pelo jogo.
- Modelos de conteúdo, materiais e efeitos são reutilizáveis. Cheio/vazio, cor do pote, quantidade de ovos e nível da instalação não exigem duplicar a construção inteira.
- Cores dos potes continuam vinculadas ao gato. Comida e água do mesmo gato usam a mesma identificação, além do nome ao tocar; o formato/conteúdo distingue a função.
- Estados devem refletir quantidades, prazos e condições reais da API. Animação ou passagem de tempo local não entrega recompensas nem conclui operações.

## 2. Potes dos gatos

| ID | Modelo | Estados necessários | Detalhes |
|---|---|---|---|
| CAT-FOOD | Tigela baixa de ração, com cavidade e borda | Vazia; uma porção; duas porções | Ração em pequenos sólidos, sem caldo ou colher. Porções mudam o volume visível. Base colorida por gato. |
| CAT-WATER | Tigela baixa de água, do mesmo conjunto | Vazia; parcialmente cheia; cheia | Água dentro da cavidade, com margem abaixo da borda. Reflexo discreto e ondulação curta ao abastecer/beber. |

Animações de interação: encher, gato comendo/bebendo e conteúdo diminuindo. Reutilizar as animações dos gatos; ajustar aproximação e altura do focinho ao recipiente.

A API já informa o número de porções. Para água, o estado atual informa validade temporal, não litros consumidos: cheia/vazia são estados persistentes; a versão parcial serve inicialmente à transição de abastecimento. Um nível persistente intermediário só pode ser exibido se houver uma regra de consumo definida.

Recusa: usar a reação do gato e atualizar o conteúdo conforme a perda real das porções. Não criar sujeira permanente ou uma obrigação nova de limpar.

## 3. Galinheiro

| ID | Modelo | Estados necessários | Detalhes |
|---|---|---|---|
| COOP-HOUSE | Casinha de madeira com telhado, entrada, rampinha e compartimento de ninhos visível | Abandonada; em reforma; pronta no nível 1; ampliação em andamento; pronta no nível 2 | Substitui a tendinha. Nível 1 atende duas galinhas; nível 2, quatro. Crescimento modular dentro do cercado. |
| COOP-NEST | Módulo de ninho com palha, integrado à casinha | Vazio; um ovo; dois ovos | Reutilizar `egg.glb` do food-kit. Um módulo por galinha, com largura inferior ao espaçamento de 0,50. Total visível acompanha os ovos disponíveis; capacidade atual de dois por galinha. |
| COOP-FOOD | Comedouro baixo de grãos | Vazio; parcialmente abastecido; abastecido | Grãos agrupados dentro do recipiente; leitura adequada à altura das galinhas. |
| COOP-WATER | Bebedouro das galinhas | Vazio; parcial; cheio | Recipiente próprio e água interna; parcial pode ser usado na animação de reposição. |

Abandono: telhado incompleto, rampinha caída, tábuas deslocadas e vegetação ocupando o futuro abrigo. Reforma: estrutura reconhecível sendo recomposta, com pilhas pequenas de material fora da passagem.

O jogador toca no galinheiro para recolher os ovos prontos. O ninho avulso atual deixa de ser um ponto separado de coleta. Os ovos somem somente após confirmação da API. A estrutura pode conter ovos disponíveis enquanto a próxima produção está em andamento.

Reutilizar as galinhas brancas e marrons já criadas, com suas animações. Ajustar entrada/saída e deslocamento para que não atravessem paredes ou a rampinha. Não é necessário criar outra espécie ou modelo de galinha neste lote.

## 4. Pasto e ordenha

| ID | Modelo | Estados necessários | Detalhes |
|---|---|---|---|
| PASTURE-BARN | Pequeno celeiro aberto, com pilares, telhado e palha | Abandonado; em reforma; pronto no nível 1; ampliação em andamento; pronto no nível 2 | Substitui a tendinha. Um ou dois espaços para as vaquinhas, conforme o nível. Entrada larga e circulação livre. |
| PASTURE-COW | Adaptação funcional da vaquinha existente | Ociosa; andando; comendo; bebendo; aguardando ordenha; sendo ordenhada | Preservar a aparência quadrada. Produção pronta é indicada sobre a própria vaca; não exige deformar o corpo. |
| PASTURE-FOOD | Cocho de alimento com feno e grãos | Vazio; parcialmente abastecido; abastecido | Conteúdo encaixado no cocho; alimento compatível com a receita atual de trigo e milho. |
| PASTURE-WATER | Cocho de água | Vazio; parcial; cheio | Cavidade profunda o suficiente para dar leitura de volume, com água abaixo da borda. |
| PASTURE-BUCKET | Balde de ordenha | Vazio; recebendo leite; cheio | Aparece durante a ação, em posição coerente junto à vaca, e sai ao concluir. |

Abandono do celeiro: pilares/tábuas quebrados, cobertura parcialmente caída, pedras e vegetação no terreno. A ruína não contém um celeiro intacto escondido sob destroços.

Tocar numa vaca identifica aquele animal e oferece ordenha quando ele tiver leite disponível. Remover o estrado/cartonagem que hoje representa um ponto coletivo de leite. O celeiro é abrigo e referência do pasto, não um recipiente produtor de leite.

**Requisito de integração:** a ordenha deve identificar o residente por ID, recolher apenas sua produção, preservar a das demais vacas e ser idempotente. Esse comportamento já foi adicionado a `collect_residents`; a coleta agregada continua disponível para compatibilidade. O alvo de toque e o indicador acompanham a posição animada da vaca. A animação da ordenha com balde ainda consta como pendência na auditoria.

Nos comedouros coletivos, a versão parcial pode representar abastecimento real de parte dos residentes; não inventar uma porcentagem de alimento por animal que a API não forneça. Falta de água ou comida interrompe a produção conforme as regras vigentes, mas não esconde leite ou ovos já prontos.

## 5. Horta e cultivos

### Base dos canteiros

| ID | Modelo | Estados necessários |
|---|---|---|
| GARDEN-BED | Canteiro de terra com sulcos e borda discreta | Vazio/seco; vazio/úmido; plantado/seco; plantado/úmido |
| GARDEN-OVERGROWN | Composição do espaço da horta antes da recuperação | Abandonada; em limpeza/preparo; recuperada |

Terra e planta são módulos separados. A colheita retira a planta e mantém o canteiro. Terra molhada acompanha o estado de rega real. As expansões utilizam o mesmo módulo para 4, 8 e 12 canteiros, com novas posições e transição de preparo nas áreas adicionadas.

### Quatro estágios para cada cultivo

Todos os seis cultivos atuais terão **pequeno/broto, médio, grande ainda imaturo e pronto para colher**. Os estágios são mudanças de forma, folhagem e maturação; aumentar a escala do mesmo vegetal não resolve sozinho.

| ID | Cultivo | Pequeno / broto | Médio | Grande, imaturo | Pronto |
|---|---|---|---|---|---|
| CROP-CORN | Milho | Poucas folhas baixas | Caule e folhas se formando | Planta alta com espigas imaturas | Espigas desenvolvidas e detalhe de maturação |
| CROP-WHEAT | Trigo | Brotos verdes baixos | Tufo verde mais denso | Hastes altas com espigas verdes | Espigas douradas |
| CROP-CARROT | Cenoura | Pequeno tufo de folhas | Folhas maiores e abertas | Copa densa, raiz ainda enterrada | Folhagem completa e apenas o ombro laranja da raiz aparecendo |
| CROP-TURNIP | Nabo | Pequenas folhas junto ao solo | Roseta de folhas | Roseta maior, raiz se formando | Topo arredondado da raiz parcialmente aparente |
| CROP-PUMPKIN | Abóbora | Broto com folhas largas | Rama curta crescendo | Rama com abóbora pequena e verde | Abóbora madura no chão, ligada à rama |
| CROP-MELON | Melão | Broto baixo | Rama rasteira com folhas | Melão pequeno e imaturo junto à rama | Melão desenvolvido, apoiado no chão |

Resultado: **24 estados de cultivo**. Conforme a revisão solicitada em 08/10, milho e trigo também receberam modelos próprios, substituindo os originais. Trigo possui hastes variadas, espigas verdes imaturas e grãos dourados na maturação; milho possui folhas curvadas, espigas com grãos e pendão. Cenoura, nabo, abóbora e melão recebem plantas próprias, substituindo folhas genéricas e vegetais soltos sobre a terra. A implementação reproduzível está em `tool/quintal_cozy_crops.py`.

A raiz da cenoura/nabo permanece sob o plano do solo; o objeto colhido pode aparecer inteiro apenas no efeito de coleta. Abóbora e melão são frutos acima do solo e precisam de rama para leitura de plantação.

Revisão aprovada em 08/10: a abóbora madura preserva a geometria original `crop_pumpkin` do nature-kit (gomos largos e volume achatado); o melão segue a geometria facetada `crop_melon` do mesmo conjunto, com listras em verdes suaves. As ramas novas permanecem, e os frutos imaturos usam essas mesmas formas em tamanho menor e cores verdes. Os demais cultivos mantêm os modelos novos.

Proposta fechada para a apresentação: pequeno de 0 a menos de 25%, médio de 25 a menos de 60%, grande de 60 a menos de 100%, pronto somente ao alcançar `ready_at`. O progresso usa `started_at`, `ready_at` atualizado após rega e relógio do servidor. Não alterar durações ou rendimentos neste lote.

Animações: folhas balançando discretamente, rega breve e retirada do cultivo na colheita confirmada. Cultivos não morrem nem apodrecem; esses estados não existem nas regras atuais.

## 6. Cozinha do Quintal

| ID | Modelo | Estados necessários | Detalhes |
|---|---|---|---|
| KITCHEN-STATION | Fogão de tijolos com bancada de madeira | Abandonada; em reforma; pronta nível 1; ampliando; pronta nível 2 | Reconhecível em todas as fases; expansão adiciona espaço útil de bancada/armazenamento. |
| KITCHEN-POT | Panela com tampa móvel | Em repouso; preparando | Fogo discreto, vapor e tampa com movimento suave apenas enquanto um preparo estiver ativo. |
| KITCHEN-PORTIONS | Recipiente de refeições prontas | Ausente; um lote disponível; vários lotes disponíveis | Um mesmo recipiente na bancada, com níveis de conteúdo diferentes; não multiplicar potes por porção. Quantidade exata e receitas aparecem na interação. |
| KITCHEN-QUEUE | Bandeja de ingredientes reservados para o próximo preparo | Sem fila; com preparos aguardando | Recipiente tampado e pano na bandeja indicam ingredientes separados; aparece apenas com tarefas futuras. Não representa comida pronta nem outro fogão ativo. |

Abandono: tijolos deslocados, bancada quebrada, panela tombada e capim nas frestas. Reforma: base sendo recuperada, bancada incompleta e materiais próximos.

Estados operacionais combináveis: ociosa, preparando, com fila, com comida pronta e preparando enquanto há comida pronta. Não duplicar o prédio para cada combinação: utilizar panela, bandeja de ingredientes e porções como peças independentes.

Tocar na cozinha oferece receitas, fila e coleta. A fila só mostra fogo/vapor no lote cujo preparo já começou; tarefas futuras não simulam cozimento simultâneo. Recipientes prontos permanecem enquanto houver lotes não recolhidos.

As sete receitas existentes compartilham os modelos de recipiente e preparo, com apoio dos ícones ilustrados já fornecidos: horta, peixe, ovo, frango, carne, cremosa e especial. Não é necessário criar sete cozinhas ou sete panelas.

## 7. Mercadinho rural

Uma banca rural para trocar produtos da horta ou moedas por alimentos e suprimentos. O identificador interno `market` e os IDs de assets `post-*`/`parcel` são preservados para compatibilidade; não indicam um serviço postal.

| ID | Modelo | Estados necessários | Detalhes |
|---|---|---|---|
| ORDER-POST | Banca de madeira com toldo, balcão, caixotinhos de frutas e pano | Abandonada; em reforma; funcionando | Reaproveita a estrutura existente. Frutas são a decoração permanente da banca, sem representar estoque coletável. |
| ORDER-PARCEL | Caixote de madeira com pano claro e borda verde, inspirado em `action_pickup_delivery.png` | Ausente; disponível; sendo recolhido | Surge na área de retirada somente quando o pedido estiver pronto. Desaparece após confirmação da coleta. |

Abandono: toldo rasgado, tábuas quebradas, placa caída e vegetação ocupando a estrutura. Reforma: pilares recuperados, balcão em montagem e toldo sendo instalado. A banca não usa envelopes, caixa de correio ou sinalizadores postais.

Fluxo: tocar no Mercadinho rural → escolher produtos e pagar com moedas ou produtos da horta → relógio durante o preparo do pedido → caixote coberto e indicador de pronto → retirar → voltar a disponível.

O catálogo atual permite um pedido pendente e oferece frango e carne. Peixe e outros suprimentos cabem no conceito, mas sua inclusão e preços exigem definição de catálogo; esta revisão visual preserva a economia existente. Os animais residentes permanecem no Quintal.

**Compatibilidade com o tempo atual:** o desbloqueio de `market:1` é imediato. A versão em reforma é um recurso para transição visual e não acrescenta espera artificial. O Mercadinho ainda não possui nível 2 nas regras.

## 8. Pomar

| ID | Modelo / composição | Estados necessários | Detalhes |
|---|---|---|---|
| ORCHARD-OVERGROWN | Terreno tomado por capim e arbustos | Abandonado; em limpeza; recuperado | Capim de alturas variadas, arbustos em grupos naturais e pequenas clareiras. Sem construção arruinada. |
| ORCHARD-APPLE | Macieira, adaptada do conjunto existente | Sem frutos após colheita; em produção; com maçãs maduras | Frutos visíveis ligados à copa. Preparar grupo destacável de maçãs para coleta. |
| ORCHARD-PEAR | Pereira, adaptada do conjunto existente | Sem frutos após colheita; em produção; com peras maduras | Forma/cor dos frutos permite distinguir da macieira sem depender só de texto. |

O pomar abandonado é composto apenas pela vegetação solicitada, aproveitando os modelos existentes de capim e arbustos. Retirar a composição de troncos/destroços usada atualmente. Recuperar significa limpar a área de circulação e liberar as fruteiras; preservar alguns arbustos nas bordas.

Durante produção, frutos pequenos/verdes podem surgir conforme o progresso real disponível; frutos maduros indicam unidades coletáveis. Não criar envelhecimento, crescimento por vários dias ou uma mecânica de plantar árvores neste lote. As fruteiras atuais entram adultas.

Tocar na fruteira deve recolher aquela fruteira. A API já aceita o ID do residente e preserva o saldo da outra árvore; esse comportamento precisa permanecer nas interações. Não aplicar rega/alimentação do gado às fruteiras. A retirada animada e a correspondência entre a quantidade visual de frutos e o saldo ainda estão pendentes na auditoria.

## 9. Módulos compartilhados e reaproveitamento

| Conjunto | Variações / estados necessários | Tratamento |
|---|---|---|
| Destroços de madeira | Tábua quebrada, pilar caído, pequeno trecho de cobertura | Reutilizar onde a silhueta funcionar; criar peças específicas que conectem a ruína ao prédio final. |
| Vegetação de abandono | Capim baixo/médio/alto; arbustos de tamanhos diferentes | Reutilizar modelos existentes e compor grupos coerentes, incluindo o pomar. |
| Pedras e entulho | Pequenos grupos junto à base; tijolos na cozinha | Reutilizar pedras; complementar tijolos/madeira conforme a construção. |
| Materiais de obra | Tábuas e tijolos empilhados, ferramentas, estrutura incompleta | Compor por instalação; manter acessos desobstruídos. |
| Cercas e portões | Íntegros; danificados onde fizer sentido; portão fechado/aberto ao passar | Adaptar modelos existentes ao galinheiro e celeiro. Portas animadas precisam ter eixo de giro correto. |
| Conteúdos | Grãos, ração, feno, água, leite, ovos, frutos e porções | Peças separadas e reutilizáveis; conteúdo respeita a cavidade e sua capacidade. |

O píer, as varas, os caminhos e os demais animais permanecem com os modelos atuais neste lote. Ajustar encaixes necessários às novas construções sem iniciar uma reformulação paralela desses conjuntos.

## 10. Estados da interface e animações compartilhadas

Estes são estados de apresentação, não novas malhas 3D:

| Estado | Representação |
|---|---|
| Bloqueado por requisito | Composição abandonada; requisitos aparecem ao tocar. |
| Disponível para recuperar | Mesma composição abandonada; ação de recuperação habilitada. |
| Em obra / em produção | Relógio ligado ao prazo real, ancorado ao objeto. |
| Sem alimento / sem água | Recipiente vazio e indicação da necessidade; não mostrar relógio de produção ativa se ela estiver parada. |
| Pronto para recolher | Indicador de pronto maior, junto ao objeto correto, e produto visível quando aplicável. |
| Pronto e ainda produzindo | Pronto tem prioridade visual; a interação informa o próximo lote/tempo. |
| Ação enviada | Retorno breve de toque; bloquear repetição enquanto a operação é confirmada. |
| Coleta/abastecimento confirmado | Pequena animação de conteúdo entrando/saindo e atualização do estoque. |
| Falha ou indisponibilidade | Preservar estado confirmado anterior; oferecer nova tentativa sem consumir de novo. |
| Selecionado | Realce suave e ações flutuantes junto ao objeto; alvo acompanha a vaca em movimento. |

Reutilizar os ícones e indicadores fornecidos pela usuária. Animações previstas: água servida, ração/grãos despejados, galinha entrando/saindo e bicando, vaca comendo/bebendo e ordenha com balde, folhas balançando, colheita, retirada de ovos/frutos, vapor/tampa da panela e retirada do caixote. Redução de movimento mantém todos os estados legíveis sem animação.

## 11. Entregáveis e sequência de criação

1. **Potes e recipientes:** tigelas dos gatos, comedouro/bebedouro das galinhas, cochos das vacas e balde. Validar preenchimento, escala e cores.
2. **Abrigos e coleta:** galinheiro com ninhos, celeiro e estados de abandono/reforma; adaptar coleta dos ovos e ordenha individual.
3. **Horta:** base dos canteiros e os 24 estados dos seis cultivos, reaproveitando estágios compatíveis.
4. **Cozinha e pedidos:** estruturas abandonadas/recuperadas, obras, ampliações aplicáveis e módulos operacionais combináveis.
5. **Pomar e integração do cenário:** composição de capim/arbustos, fruteiras e seus estados; revisar cercas, portões e circulação.

Cada conjunto terá fonte 3D, prévias de quatro orientações, estados lado a lado, animações pertinentes e captura dentro do Quintal. A galeria principal deve ser atualizada ao final de cada entrega visual.

Critérios de conclusão:

- Nenhuma colher nos potes dos animais, água sobreposta à borda ou fruto/raiz flutuando.
- Nenhuma tendinha nos espaços substituídos, ninho separado de ovos ou ponto de leite avulso.
- Modelos abandonados reconhecíveis como versões da construção futura; pomar abandonado apenas com grama e arbustos.
- Animais, cercas, portões e construções ordenados corretamente em profundidade, com circulação e áreas de toque válidas.
- Todas as variantes compartilham origem, escala e ocupação coerentes; ampliações respeitam os espaços previstos.
- Estados visuais correspondem ao relógio, estoque e residente corretos; não somem produtos prontos por haver outra produção em andamento.
- Coleta individual de leite/frutos, coleta no galinheiro e pagamentos mantêm validação e idempotência na API.
- Preços base, desconto de testes, durações, rendimentos e receitas continuam preservados; alterações de balanceamento exigem escopo próprio.

Revisão de estados em 08/10: galinheiro, celeiro e cozinha possuem exatamente **abandonado → em reforma → nível 1 → ampliando → nível 2**. Não existem variantes abandonadas ou em reforma de nível 2. As espigas maduras possuem grãos em toda a circunferência, mantendo as folhas e o caule aprovados.
