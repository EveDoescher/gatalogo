# Brief de arte — interações e produção do Quintal

Data: 06/10/2026. Brief revisado a partir de referências de jogos mobile. O lote de 34 PNGs fornecido em `Downloads/Quintal` foi incorporado a `assets/quintal/ui`. As ações rápidas usam ferramentas ilustradas junto ao objeto; escolhas abrem uma bandeja inferior. O inventário voltou a ser uma bandeja com Decorações, Rações e Ingredientes. Validação estética final continua com a usuária.

## Lote recebido e pendências de arte

Recebidos os 15 ícones de ação, nove ingredientes, nove embalagens de ração e indicador `ready` (34 arquivos ao todo). Os PNGs originais foram preservados; a interface reduz a resolução de decodificação ao tamanho efetivo de exibição.

As receitas continuam sendo as definidas pela API. As embalagens de milho, trigo, cenoura e abóbora ficam disponíveis na biblioteca, sem criar receitas automaticamente por existir uma imagem. A mistura da horta usa `racao_planta`; peixe, frango e carne usam suas embalagens correspondentes. Mistura com ovo, cremosa e especial usam a panela enquanto não houver arte específica.

Complementos úteis, sem bloquear a implementação:

- **`racao_ovo.png`:** mesma embalagem kraft das rações recebidas, símbolo central de um ovo inteiro e uma metade, contorno marrom e creme quente. PNG transparente 1280 × 1280, mesmo enquadramento das outras embalagens.
- **`racao_cremosa.png`:** mesma embalagem, tigelinha creme com uma pequena gota de leite como símbolo; evitar parecer água. Mesmo canvas, escala e contorno.
- **`racao_especial.png`:** mesma embalagem, peixe, frango e abóbora em uma composição pequena e legível; um detalhe dourado discreto. Não usar coroa ou raridade não existente no sistema.
- **Panela animada:** a panela estática já chegou. Para mostrar o preparo, faltam apenas as camadas/frames especificados na seção 2.
- **Efeitos curtos opcionais:** seção 2A. Não são necessários novos fundos ou skins para o antigo painel flutuante.

## Direção e prioridade

O objeto no cenário deve ser o centro da interação. Selecioná-lo revela uma pequena composição de ferramentas e produtos ao redor dele, com uma identificação curta quando necessária. Cabeçalho largo, corpo de texto e fileira de botões dentro de um retângulo deixam a interação parecida com um formulário, mesmo com bordas arredondadas e desenhos bonitos.

O cenário continua usando os modelos low-poly existentes. Os ícones precisam ter volumes simples e uma perspectiva em três quartos compatível com esses modelos, acabamento suave e a paleta da biblioteca do Gatalogo: madeira quente, creme, verde de folha e pequenos acentos coral/dourado. Usar o contorno creme para separar uma ferramenta do cenário quando necessário. Não transformar toda ação em um medalhão circular idêntico.

Trocar os PNGs sozinho não resolve o problema. O código precisa mudar a composição, a quantidade de informação no primeiro toque e a resposta visual do objeto.

**Os ícones de ação da seção 1 já foram fornecidos.** A lista abaixo preserva o brief original como referência; não é um pedido para refazer o lote. Não precisamos de novos pacotes de árvores, pedras ou mato.

## Referências consultadas e aplicação

| Referência | Evidência observada | Aplicação ao Quintal |
| --- | --- | --- |
| [Hay Day — fabricação, Supercell](https://support.supercell.com/hay-day/en/articles/product-making-2.html) | A produção é organizada em espaços de fila; produtos são arrastados para esses espaços, e os ingredientes podem ser consultados pressionando o produto. | Receita representada pela comida; fila legível como objetos enfileirados junto da cozinha; detalhes aparecem por intenção do jogador. |
| [Hay Day — captura da máquina de ração](https://hay-day.en.uptodown.com/android) | Na captura consultada, máquina, escolhas de produto, slots e temporizador compartilham o mesmo cenário. Fonte visual secundária; a imagem não é uma promessa do layout da versão atual. | Objeto fica visível no centro. Usar pequenos elementos próximos dele em vez de cobri-lo com um painel opaco. |
| [Township — plantio, colheita e alimentação, Playrix](https://playrix.helpshift.com/hc/en/3-township/faq/152-farming-fields-crops-and-animals/) | Sementes, ferramenta de colheita e saco de ração são associados ao gesto de levar o item ao destino. | Ferramentas reconhecíveis e ações sobre canteiro/pote. O toque simples permanece disponível; arrastar pode ser um gesto complementar com destino destacado. |
| [Township — captura do galpão](https://www.bluestacks.com/blog/game-guides/township/tns-beginner-guide-en.html) | A janela de cuidado usa animais, recipientes e ração como elementos centrais. | Aproveitar a clareza dos objetos. A janela que cobre o mapa não é adequada ao fluxo solicitado para o Quintal. |
| [Animal Crossing: Pocket Camp — controles, Nintendo](https://support.ac-pocketcamp.com/en-US/faq) | Coleta, pesca e interação com móveis são acionadas por toque no mundo. Esta é a documentação da versão original. | Concluir uma ação deve ter resposta no objeto e no cenário, sem levar cada cuidado a outra tela. |

As decisões abaixo são uma proposta para o Gatalogo, e não uma descrição literal de nenhum desses jogos. Não copiar telas ou assets comerciais.

## Composição proposta para substituir o painel atual

1. **Selecionar:** contorno suave no objeto ou pequeno anel no chão. Se houver uma ação principal, aparece uma ferramenta grande junto dele; se houver mais de uma, até três ferramentas em arco. O objeto continua visível.
2. **Identificar:** nome curto em uma pequena etiqueta, como “Pote de Mimi”. Nome e símbolo permanecem além da cor. Sem cabeçalho ocupando toda a largura.
3. **Estado:** um produto sobre o objeto significa pronto; pequeno relógio indica trabalho em andamento. Quantidades e tempo ficam em cápsulas curtas. Texto explicativo só quando necessário.
4. **Escolher:** sementes ou rações em uma faixa curta de miniaturas. Receita selecionada mostra ingredientes e estoque como ícone + quantidade. A faixa acompanha o objeto enquanto houver espaço e pode se apoiar na borda inferior em telas pequenas.
5. **Executar:** toque na ferramenta; a API confirma; o recurso faz um pequeno salto e segue para o inventário. Água aparece no recipiente e planta muda de estágio. Falha de rede mantém o estado anterior com uma mensagem curta junto da ação.
6. **Sair:** tocar no chão fecha a seleção. Não colocar um botão X grande em todo cuidado. Detalhes, escolha de nome e confirmação de desperdício ainda precisam de controles explícitos e legíveis.

| Objeto | Primeira interação | Escolha adicional, quando necessária | Resposta esperada |
| --- | --- | --- | --- |
| Canteiro pronto | Cesta de colheita e quantidade do lote | Nenhuma | Cultivo some, recurso sobe e canteiro fica vazio. |
| Canteiro vazio | Muda/semente | Faixa com cultivos liberados | Muda aparece na terra; tempo fica disponível ao selecionar. |
| Canteiro crescendo | Regador, se ainda não regado | Nenhuma | Pequeno respingo, terra úmida e tempo reduzido confirmado. |
| Pote de água | Jarra e nome do dono | Nenhuma | Água preenche o pote; brilho curto de confirmação. |
| Pote de comida | Ração e nome do gato | Miniaturas, estoque, quantidade e preferência; aviso explícito se haverá recusa | Porção no pote ou animação de comer/recusar conforme o resultado real. |
| Ninho/leite | Ovos ou balde visíveis, com contagem | Nenhuma | Produto recolhido e recipiente muda de cheio para vazio. |
| Cozinha | Panela, prato da receita ativa e espaços da fila | Faixa de receitas; ingredientes da receita selecionada | Vapor durante preparo; prato pronto para coleta. |
| Ruína | Ferramenta de reparo presa ao local | Pequena prancha de projeto com resultado, requisitos, custo e prazo | Mato/entulho é retirado; canteiro de obra; construção concluída. |

Gesto de arrastar fica restrito às ferramentas/miniaturas: arrastar o chão continua movendo a câmera. Feedback visual nunca concede recursos por si só. Movimento reduzido utiliza transições simples e confirmação estática.

## 1. Oito ícones essenciais de ação

Um PNG transparente de 512 × 512 por item, com o desenho ocupando aproximadamente 80% do quadro. Deve continuar legível a 32–48 pixels e funcionar sem fundo de botão. Uma imagem-base é suficiente: pressionado, indisponível, contorno e destaque são tratados pelo app. A área de toque no código será maior que o desenho.

| Arquivo sugerido | Desenho e composição | Uso e distinção |
| --- | --- | --- |
| `action_harvest_basket.png` | Cesta baixa de palha vista em três quartos, com uma cenoura, uma espiga e duas folhas saindo. Alça simples, silhueta larga e clara; sem dezenas de produtos pequenos. | **Colher** na horta. Deve parecer uma colheita recolhida, diferente da muda usada para plantar. |
| `action_plant_seedling.png` | Uma muda com duas folhas grandes em um pequeno torrão de terra, com duas sementes visíveis ao lado. Folhas abertas, terra marrom quente, sem vaso. | **Plantar**. O foco é iniciar um cultivo; não usar árvore adulta nem colheita pronta. |
| `action_water_can.png` | Regador verde-sálvia ou azul acinzentado, inclinado em três quartos, com três gotas grandes saindo do bico. Alça e bico bem separados do corpo. | **Regar** cultivos. Não usar apenas uma gota, que se confundiria com a água dos animais. |
| `action_refill_water.png` | Jarrinha despejando um fio curto de água em um pote baixo, com superfície azul clara e um único brilho. Pote sem rosto, sem texto e sem identidade de gato. | **Encher água** dos gatos e bebedouros. A identidade do dono continua sendo apresentada pelo app. |
| `action_serve_food.png` | Pequena pá de ração inclinada sobre um pote baixo com três ou quatro grãos grandes. Pote creme, detalhe coral e ração dourada. | **Servir/abastecer comida**, separado de cozinhar. Evitar prato de comida humana ou ossos. |
| `action_cook_pot.png` | Panela de duas alças, arredondada, creme ou azul acinzentado; colher de madeira apoiada, tampa ligeiramente levantada e duas curvas largas de vapor. | **Preparar receita**. O volume e o vapor devem permitir reconhecer a panela mesmo sem legenda. É a base da animação da seção 2. |
| `action_repair_tools.png` | Martelo de cabo de madeira e uma tábua curta com dois pregos, em composição diagonal compacta. Metal cinza quente, madeira da mesma família das cercas. | **Consertar** construções abandonadas. Sem engrenagem, porque não é uma configuração do aplicativo; sem pilha de moedas, porque não representa comprar. |
| `action_fish_rod.png` | Vara curta de madeira curvada, linha descrevendo um arco simples e boia coral/creme. Pode ter um pequeno peixe na ponta, mas a vara precisa ser o elemento principal. | **Pescar** no píer. Diferente do ícone de peixe usado como ingrediente no inventário. |

## 2. Panela em funcionamento

Entregar `cooking_pot_idle.png` e oito frames `cooking_pot_00.png` a `cooking_pot_07.png`, todos com 256 × 256, transparência e exatamente o mesmo enquadramento/ponto de apoio.

- A panela fica parada. Apenas a tampa levanta levemente, o vapor sobe e duas bolhas aparecem na superfície.
- Loop suave em aproximadamente 1,2–1,6 s, sem sacudir o objeto inteiro, sem flashes e sem fumaça cobrindo o desenho.
- Primeiro e último frame devem conectar sem salto; não deslocar nem redimensionar a panela entre frames.
- A versão estática será usada com movimento reduzido. A animação indica **preparando**, não entrega nem duplica recursos.
- Esta versão ilustrada é para o balão/fila. Para animar a panela **no cenário**, preferir o modelo GLB existente com tampa separada, mais vapor em camada própria; não colar um ícone frontal sobre a bancada isométrica.

## 2A. Efeitos opcionais no cenário

Cada sequência: PNGs transparentes de 256 × 256, enquadramento idêntico, 6–8 frames, duração de 0,4–0,7 s, sem repetir continuamente. Centro e base estáveis; o código dispara após confirmação real da ação.

| Arquivo-base | Desenho | Uso |
| --- | --- | --- |
| `effect_water_00.png` | Três gotas azul suave se espalhando baixinho, com dois arcos pequenos de água; nada de grande explosão azul. | Abastecimento e rega. |
| `effect_harvest_00.png` | Duas folhas e três brilhos creme/dourado se afastando do centro e sumindo; sem moeda ou produto desenhado. | Coleta confirmada; o produto real é desenhado separadamente pelo app. |
| `effect_repair_dust_00.png` | Duas pequenas nuvens de poeira bege e um fragmento de madeira, assentando para baixo; transparência suave. | Transição do terreno abandonado para obra/construção. |

Relógios, números, contagens e progresso são desenhados pelo código. O `ready.png` recebido já cobre o sinal estático de conclusão. Em movimento reduzido, usar confirmação estática sem partículas.

## 3. Segundo lote de ícones

Mesmas especificações da seção 1. Estes melhoram a distinção das ações, mas os modelos atuais permitem continuar usando o sistema enquanto eles não chegam.

| Arquivo | Descrição | Onde aparece |
| --- | --- | --- |
| `action_collect_eggs.png` | Ninho baixo com três ovos creme e um ovo sendo erguido por um pequeno brilho; palha simples, sem galinha cobrindo tudo. | Recolher ovos. |
| `action_collect_milk.png` | Balde baixo de metal com alça de madeira e leite branco visível; um pequeno respingo curvo, sem embalagem industrial. | Recolher leite. |
| `action_pickup_delivery.png` | Caixote pequeno aberto com pano creme dobrado e uma marca de confirmação em folha verde, sem conteúdo de carne explícito. | Encomenda pronta para retirar. |
| `action_order_market.png` | Sacola de papel ou cesta com etiqueta simples e duas moedas ao lado; não repetir o caixote de entrega pronta. | Fazer encomenda. |
| `action_recipe_book.png` | Caderno creme aberto, marcador verde, desenho de panela em uma página e pequenos ingredientes na outra. Sem letras desenhadas. | Escolher receita. |
| `action_production_queue.png` | Dois pequenos cartões sobrepostos e um relógio redondo de madeira na frente. Ponteiros visíveis, sem números minúsculos. | Ver fila de preparo. |
| `action_expand_area.png` | Pequeno cercado aberto com dois postes se afastando e setas discretas para fora. | Ampliar espaço, distinguindo ampliação de reparo. |

Para a progressão da pesca, depois podemos usar três varas da mesma família: madeira simples, madeira com carretilha e vara reforçada com detalhe dourado. A mudança deve aparecer no equipamento, não só na cor do fundo.

## 4. Expressões para preferências alimentares

Opcional. Uma mesma carinha de gato, na mesma posição e escala, em sete PNGs de 256 × 256:

| Estado | Expressão desejada |
| --- | --- |
| Odeia | Focinho virado de lado, olhos semicerrados e boca de recusa. Sem sofrimento ou caveira. |
| Não é fã | Sobrancelha levantada e boca levemente torta. |
| Aceita | Expressão calma, um pouco indecisa; boca pequena. |
| Normal | Neutra e relaxada. |
| Gosta | Sorriso curto, olhos atentos. |
| Gosta muito | Olhos felizes semicerrados e bochechas discretas. |
| Favorita | Alegria evidente, pequeno coração coral junto da cabeça. |

Acrescentar uma oitava versão **Ainda não experimentou**, neutra com um pequeno ponto de interrogação. As legendas continuam obrigatórias: cor e expressão não devem ser a única forma de entender a preferência.

## 5. Modelos de cenário que mais melhorariam as composições

Já há composições de abandono, reforma e funcionamento feitas com os modelos fornecidos. Um kit próprio daria identidade maior às construções. Estes pedidos são opcionais, de prioridade posterior aos ícones.

| Modelo | Elementos necessários | Estados/partes separados |
| --- | --- | --- |
| Galinheiro | Casinha baixa de madeira clara, telhado quente, portinhola acessível às galinhas, uma pequena rampa e ninho externo. Abertura frontal visível no ângulo do jogo. | Pronto; arruinado com metade do telhado faltando, tábuas caídas e porta torta. Ninho vazio/com ovos como peça separada. |
| Abrigo do pasto | Cobertura mais larga e alta que a do galinheiro, dois apoios, fundo parcial e frente aberta. Precisa caber uma vaca sem atravessar pilares. | Pronto; arruinado com um apoio inclinado e parte da cobertura no chão. Comedouro e bebedouro separados. |
| Cozinha de jardim | Bancada rústica, pequeno fogareiro de pedra, panela e tábua de preparo. Sem cara de cozinha doméstica moderna. | Pronta; bancada quebrada, panela tombada e pedras soltas. Tampa e colher separadas para animação. |
| Píer | Passarela baixa e um pequeno tablado sobre a água, pilares que continuam para baixo e ponto livre para pescar. | Pronto; duas tábuas faltando, uma solta inclinada e acesso interrompido. Nada de piso quebrado flutuando acima da margem. |
| Mercado | Banca pequena de madeira com tecido creme/verde, um caixote de retirada e espaço legível para encomendas. | Pronto; cobertura rasgada/caída e caixotes tombados. Caixote de entrega separado. |
| Kit modular de entulho | Duas tábuas curtas, uma longa rachada, poste tombado, segmento de cerca quebrado e montinho de telhas. | Peças independentes. Mato e pedras existentes completam os terrenos; não é preciso desenhá-los de novo. |
| Recipientes de produção | Comedouro de madeira comprido, bebedouro baixo com água e balde de leite; proporções menores que os residentes. | Vazio/cheio, mesma origem e tamanho em ambos. |

Não assar mato, pedras ou um chão enorme no modelo principal. Precisamos poder tirar o abandono ao consertar e ordenar cada elemento por profundidade, sem cercas aparecendo à frente de objetos indevidamente.

## 6. Entrega técnica

- **Ícones:** PNG RGBA, sem fundo, sem sombra projetada grande, sem borda de botão ou texto. Arquivos individuais; uma prancha de contato é útil para revisar o conjunto. Guardar também o arquivo editável, se houver.
- **GLB:** origem no centro do apoio no chão, eixo Y para cima, frente consistente em +Z, transformações aplicadas, materiais incorporados e escala comum entre todas as variantes. Usar o modelo pronto como referência de tamanho para o quebrado.
- **Prévia do cenário:** mesma câmera ortográfica do Quintal, com elevação de 30° e azimute de 45°. O pipeline do projeto gera as orientações e sombras; não incluir uma sombra fixa em uma direção incompatível.
- **PNG de cenário, se não houver GLB:** entregar a imagem com transparência e informar ponto de apoio, dimensões ocupadas e orientação; pronto/quebrado devem ter o mesmo enquadramento. Não entregar uma perspectiva de câmera diferente.
- **Animação:** frames com canvas e ponto de apoio iguais; entregar ordem, duração/fps e indicar se o loop fecha. A imagem estática de descanso é obrigatória.
- **Estilo:** legibilidade antes de detalhes pequenos. Evitar neon, ciano saturado, contorno preto grosso, texturas fotográficas ou brilho metálico excessivo.

## 7. O que não precisa ser solicitado agora

Para a troca do mercado, já há uma composição reutilizável de trigo, cenoura e duas setas verdes. Um ícone dedicado é opcional: `action_exchange_products.png`, PNG transparente de 512 × 512 ou maior, trigo dourado no canto superior esquerdo e cenoura no inferior direito, ligados por duas setas verdes curvas em sentidos opostos. Contorno marrom suave, volumes e iluminação iguais aos ingredientes recebidos, sem texto, números ou moldura de botão. A moeda dourada existente permanece como ícone do pagamento em moedas.

O app compõe as áreas de toque, contornos, contagens, estados desabilitados e relógios. Não precisamos de imagens diferentes para cada número ou prazo. Os ingredientes da interface agora usam as ilustrações fornecidas, mantendo os modelos isométricos no mundo; matos e pedras já foram reaproveitados nos terrenos abandonados. Fundos completos novos também não são necessários para estas interações.

As referências concretas estão na galeria: `quintal_world_coop_abandoned`, `quintal_world_coop_repairing`, `quintal_world_coop_nest`, `quintal_world_kitchen_choices` e `quintal_world_page`.
