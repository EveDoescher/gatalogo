# Habitat vivo, cartazes exportáveis e feed de conversas

Data: 04/10/2026. Estado: plano de implementação; funcionalidades ainda não implementadas nesta rodada.

Branch nos dois repositórios: `codex/habitat-social-improvements`, criada a partir da `main` sincronizada com o remoto. Gatálogo: base `def9876`. API: base `94e9827`.

## Objetivo e regras compartilhadas

Implementar os sete pedidos do usuário mantendo a direção cozy e a hierarquia de superfícies já definida em `DESIGN.md`. O feed ganhará a organização de uma timeline de conversas, preservando cores, fontes e assets do Gatálogo. O Habitat ficará mais vivo sem comprometer a leitura do espaço editável.

- Reutilizar componentes e separar apresentação, interação local e regras persistidas.
- Moedas, inventário, cuidados e recompensas continuam reais e controlados pela API. Animações e relógio do aparelho não concedem itens.
- Preservar contas, inventários, saldos e layouts existentes. Não resetar dados para liberar os testes.
- Atualizar a galeria permanente após cada etapa visual. Para animações, incluir demonstrações em movimento; imagens estáticas não comprovam o resultado.
- Manter fundo até a borda inferior atrás do menu, login restaurado e navegação compartilhada.

## Diagnóstico do código atual

| Pedido | Situação encontrada | Consequência para a implementação |
|---|---|---|
| Loja gratuita | `app/routers/habitat.py` rejeita definições com `price <= 0`; preços e catálogo offline vêm do serviço do servidor. | Alterar preço efetivo e elegibilidade separadamente, mantendo itens exclusivos de recompensa fora da compra. |
| Brincadeira | `HabitatCatMotion.clip` usa `happy`, cujo asset `gesture-positive` dura 0,25 s. Durante visitas, o gato é aproximado do centro do móvel. | Criar uma ação de brincar com fases, orientação e pontos de interação próprios; apenas diminuir a velocidade pode não resolver. |
| Cartaz | `CatSharingService.shareMissingPoster` envia a foto original e texto. O modelo `MissingPoster` já concentra contatos e características. | Extrair um cartaz reutilizável e gerar arquivos a partir dele, sem incluir os controles da tela. |
| Feed | `CommunityPostCard` usa papel com mídia obrigatória na interface; o composer e a API exigem nome de gato. Curtidas, comentários e compartilhamento já existem. | Tornar texto o elemento central e mídia/gato opcionais, adaptando o contrato sem quebrar publicações antigas. |
| Entorno do Habitat | O cenário e uma abelha já são desenhados em `habitat_game.dart`. | Separar cenário externo, visitantes e objetos editáveis; aproveitar os sprites existentes. |
| Caminhos | `itemAtScreen` exclui chão; existe fallback por célula em `_itemAt`. Um item de chão selecionado ativa pintura nos gestos de toque/escala. | Reproduzir a falha e separar seleção/movimentação de uma peça da ferramenta de pintar; não tratar como simples ausência de seleção no código. |
| Baús e satisfação | Há afinidade persistida, cuidados diários, carteira e transações idempotentes. Não há estado de satisfação nem sistema de encontros/baús. | Definir satisfação separadamente e acrescentar encontros persistidos com sorteio e resgate no servidor. |

## Etapa 1 — editor de caminhos e loja com preço zero

### Editor

Introduzir modos explícitos de **selecionar/mover**, **pintar** e **recolher**, em vez de decidir pelo tipo do item selecionado. Um caminho colocado é uma peça com ID; um pincel é uma ferramenta com SKU e quantidade disponível. Selecionar uma peça não deve consumir outra peça do inventário.

- No modo de seleção, resolver objeto/gato/chão por camada e célula; permitir escolher chão quando houver um objeto por cima, por um seletor de camada contextual.
- Destacar o losango real da peça selecionada; permitir mover, guardar e recolocar pelo fluxo existente.
- No modo de pintura, arrastar coloca trechos do inventário; no modo de recolher, devolve trechos ao inventário sem apagar propriedade.
- Atualizar conexões e curvas dos caminhos de origem e destino após cada operação.
- Manter pinça para zoom e arrasto de câmera sem produzir pinturas acidentais; cancelar gesto não pode aplicar mudanças.
- Preservar regras de água, pontes, ocupação, limites e revisão concorrente do layout.

Aceite: colocar, selecionar, mover, guardar e recolocar um trecho mantém seu ID e a quantidade total; funciona após reabrir o app e sincronizar. Cobrir caminho sob decoração, bordas da área editável, texto ampliado nos controles e conflitos entre dispositivos.

### Loja de teste

Adicionar uma configuração no servidor para preço zero, ativada no ambiente de teste desta rodada. Manter `base_price`, expor `price` efetivo e `purchasable`, além do indicador de modo de teste. O servidor usa a mesma regra para exibir e cobrar; não basta mudar o rótulo no app.

- Itens compráveis, terrenos/caminhos e expansões custam zero enquanto o modo estiver ativo. Petiscos pagos também ficam gratuitos para testar cuidados; cotas diárias continuam válidas.
- Itens exclusivos, como Flores da amizade, continuam vinculados às suas mecânicas. Preço zero não torna todos os SKUs compráveis.
- Manter limites de posse, lotes, autenticação, propriedade e idempotência. Registrar a aquisição com custo efetivo zero sem conceder moedas artificiais.
- Atualizar catálogo gerado e cache por versão. Offline pode exibir a última informação conhecida, mas não confirma compra nem inventa saldo.
- Mostrar “Grátis para teste” e permitir restaurar os preços pelo servidor sem apagar inventários ou reembolsar compras gratuitas.

Aceite: conta com saldo zero compra e expande; saldo permanece igual; repetir a mesma requisição não duplica itens; desativar o modo retoma os preços normais. Testar também SKU exclusivo e limites de quantidade.

## Etapa 2 — brincadeira legível e natural

Substituir o loop atual por uma sequência curta: aproximar-se, observar, tocar com a pata, saltar ou contornar o brinquedo, pausar e voltar a caminhar. Evitar oscilação repetida do quadril, interpenetração com o móvel e posicionamento permanente no centro do objeto.

- Criar pontos de acesso e orientação por tipo de móvel: caixa, tronco e toco não usam exatamente a mesma ação.
- Preferir clips disponíveis que comuniquem a ação; se insuficientes, estender a geração dos atlases a partir do modelo existente com um clip dedicado.
- Separar postura de felicidade da interação de brincar. Usar pequenas variações e pausas, com transição suave e duração limitada.
- Preservar navegação, cancelamento quando o móvel for removido/movido, exclusão de dois gatos no mesmo ponto e movimento reduzido.

Aceite: demonstração em movimento nas quatro direções, em cada móvel, sem tremor, encaixe estranho ou movimento sugestivo. Testar chegada, saída, interrupção e retorno ao estado idle. A validação visual do usuário é necessária para confirmar a leitura da animação.

## Etapa 3 — cartaz como imagem e arquivo de impressão

Extrair `MissingPosterArtwork` e um serviço de exportação compartilhado. A tela mostra a prévia; o conteúdo exportado contém apenas o cartaz, com fotografia, nome, último local visto, características e contatos escolhidos para divulgação.

- **Compartilhar cartaz:** gerar PNG em alta resolução e enviá-lo ao compartilhamento nativo, com texto complementar opcional.
- **Salvar imagem:** escolher destino por recurso nativo adequado à plataforma e confirmar o arquivo salvo. Não informar sucesso ao cancelar.
- **Salvar para imprimir:** gerar PDF A4 com texto legível e margens de impressão; oferecer impressão nativa quando disponível. PNG e PDF usam o mesmo modelo de dados e conteúdo.
- Aguardar carregamento da fotografia e das fontes. Tratar foto ausente, nomes/endereço longos e contatos múltiplos sem cortar informação. Limitar memória e limpar arquivos temporários.
- Só exportar informações públicas do cartaz; não incluir coordenadas exatas ou dados privados adicionais por conveniência. Não criar QR/link que não tenha destino funcional.
- Distinguir compartilhar, salvar e imprimir no registro de ações: cancelamento ou salvar localmente não equivale automaticamente a uma divulgação confirmada.

Aceite: o arquivo contém o cartaz completo, não apenas a foto; abre em outro app e imprime em A4; sem menu/botões da interface. Testar cancelamento, erro de escrita, imagem indisponível e execução nativa de compartilhamento/salvamento.

## Etapa 4 — feed com organização de timeline

Reorganizar o post em avatar à esquerda, nome e identificação do autor, horário discreto, texto com melhor tamanho e leitura, mídia opcional e linha compacta de ações. Reduzir ornamentação repetida por publicação; manter a moldura cozy da tela e decoração coerente nos pontos de abertura/estados vazios.

- Posts de texto funcionam sem gato ou foto. Associação a gato e localização ficam opcionais; não preencher nome fictício para satisfazer o contrato antigo.
- Composer centrado em “O que seus gatinhos estão aprontando?”, anexar foto e associar gato quando fizer sentido. Preservar audiência pública/amigos e validação do conteúdo.
- Atualizar `CatPostCreate`, criação/leitura e regras de progressão para texto sem gato; preservar posts antigos, uploads autorizados, filtros, paginação e realtime.
- Comentários/respostas ganham visual de conversa ligado ao post. Manter curtir, comentar e compartilhar com contadores reais e estados de erro/repetição coerentes.
- Cartazes e conquistas usam variantes da mesma estrutura, com identificação e ações específicas. Repost de cartaz já existente permanece; repost genérico, citações, trending e algoritmo de recomendação não são requisitos desta etapa.
- Reutilizar cabeçalho de autor, corpo, anexos e barra de ações em feed e detalhe; não duplicar lógica de rede dentro do widget.

Aceite: publicação só de texto, com foto e vinculada a gato; texto longo e fonte ampliada; audiência respeitada na lista, detalhe e mídia; contadores e atualização após comentar/curtir corretos. Atualizar capturas do Social, composer e detalhe de publicação.

## Etapa 5 — entorno mais rico e visitantes ambientais

Extrair uma camada de cenário externo descrita por regiões: margem do rio, bosque, clareira e trilhas. Compor vegetação em grupos, alturas e densidades diferentes; ligar caminhos a destinos e pontes; ajustar margens da água para evitar manchas soltas.

- Área externa fica fora de seleção, inventário e colisões do editor; respeitar todos os níveis de expansão, incluindo espaço reservado para futuras áreas editáveis.
- Deixar o centro do quintal legível. Vegetação alta não cobre gatos, controles ou pontos de interação importantes.
- Adicionar movimento pontual de água/folhas e visitantes em rotas coerentes. Começar com a abelha, cujo asset já existe; outros animais dependem de assets compatíveis e animações adequadas.
- Visitantes aparecem, percorrem trajetos e saem, com pausas. Controlar quantidade, descarregar recursos e suspender atualizações com a tela em segundo plano. Movimento reduzido mantém a composição com menos animação.
- Separar visitantes decorativos locais dos encontros recompensáveis da próxima etapa. Ver um animal local não implica ganhar um item.

Aceite: cenário visivelmente mais rico, com continuidade de rios/trilhas, sem invadir área editável. Revisar nas quatro expansões e com diferentes zooms; medir estabilidade de quadros e memória em aparelho. Atualizar galeria e demonstração de visitantes em movimento.

## Etapa 6 — satisfação, encontros e presentes

Criar um ciclo: cuidar dos gatos → melhorar satisfação do Habitat → aumentar a chance de um visitante entregar presente → tocar para recolher → receber moedas, porções ou decoração real.

### Proposta inicial de satisfação

Satisfação de 0–100, separada da afinidade permanente. Calcular no servidor para os gatos presentes: conforto acessível para descanso/brincadeira, alimentação e carinho recentes registrados. Usar a média para não privilegiar somente quem tem mais gatos. Não exigir petiscos pagos, não diminuir afinidade por ausência e não apresentar mensagens de culpa.

A fórmula e os pesos serão parametrizados e cobertos por testes. Considerar um bônus temporário de cuidados recentes sobre uma base de conforto; explicar os componentes na tela, sem expor uma fórmula extensa ao jogador. Sem gatos presentes, não existe bônus por satisfação.

### Proposta inicial de encontros

- Parâmetros de partida para calibrar: janela de 20 minutos, chance base de 10% chegando a 35% com satisfação máxima, até 3 presentes por dia e um presente pendente por vez. Estes números são proposta de balanceamento, não resultados já validados.
- Avaliar janelas elegíveis apenas durante visitas ao Habitat; não acumular uma fila infinita em segundo plano. Tempo, elegibilidade, limites e sorteio são do servidor. Abrir/fechar a tela, atualizar ou alternar gatos não gera novos sorteios na mesma janela.
- Persistir resultado e satisfação usada por janela, com unicidade por usuário/janela; não usar posição visual ou taxa de quadros como fonte de probabilidade. A sinalização do cliente de tela ativa não é prova de cuidado; recompensas continuam limitadas no servidor.
- Persistir o presente entregue e seu conteúdo. Um visitante o deixa em um ponto visível e acessível do quintal, sem ocupar permanentemente uma célula de construção. No modo de edição, suspender a cena do encontro.
- Recolher é uma transação idempotente com bloqueio da carteira, validação de propriedade e atualização do inventário. Duplo toque, timeout, reinício e dois dispositivos não duplicam prêmios.
- Conteúdo inicial: pequenas quantidades de moedas, porções e itens de jardim. Respeitar limites de posse e oferecer conversão definida para moedas quando o item estiver no limite; não selecionar apenas itens inutilizáveis.
- O presente já entregue permanece disponível após sair; sem punição por não tocar imediatamente. Offline mostra estado conhecido, mas não sorteia nem confirma resgate.

Contratos propostos: snapshot com `satisfaction` e `pending_gift`; endpoint para verificar encontro da janela atual; endpoint de resgate por ID. Separar `HabitatEncounter`, tabela/configuração de recompensas e serviço de resgate; acrescentar migração e catálogo versionado. O app apenas anima os dados confirmados e mostra o resultado da coleta.

Aceite: chance cresce conforme satisfação, não pelo número de frames; pesos e limites verificáveis com relógio/RNG injetados nos testes; nenhuma duplicação sob concorrência; inventário cheio tratado; presente reaparece depois de reiniciar; usuários não acessam presentes de outras contas. Testar a experiência com a loja gratuita e também com preços normais.

## Sequência e dependências

1. Editor + loja gratuita: desbloqueiam testes e reduzem a fricção para montar habitats.
2. Brincadeira: corrige a interação existente antes de adicionar novos personagens.
3. Cartaz exportável: entrega isolada do fluxo de busca.
4. Timeline e composer: evoluem o Social sem depender dos baús.
5. Cenário externo + visitantes: estabelecem a base visual dos encontros.
6. Satisfação + presentes: dependem do editor estável, visitantes e cuidados reais.
7. Integração final: testar API/app juntos, migrações em cópia descartável, contratos antigos, modo grátis ligado/desligado e evidência nativa.

Em cada etapa: implementar, executar testes relevantes, revisar a composição, atualizar a galeria e registrar limitações de validação. Ao final, executar as suítes completas e análise Flutter. Não alterar dados de produção para testar migrações.

## Fronteiras principais de código

App: `habitat_page.dart`, `habitat_game.dart`, `habitat_interactions.dart`, `habitat_cat_motion.dart`, `habitat_cat_animations.dart`, `habitat_service.dart`, `habitat_layout.dart`, `habitat_care.dart`, `habitat_shop_page.dart`, `missing_cat_poster_page.dart`, `cat_sharing_service.dart`, `community_post_card.dart`, `post_composer.dart`, `social_page.dart` e serviços do Social.

API: `app/routers/habitat.py`, `app/services/habitat_service.py`, `app/services/habitat_interactions.py`, `app/routers/social.py`, schemas, progressão, modelos e migrações. Acrescentar serviços próprios para encontros/satisfação; não concentrar toda a mecânica nova no router.

Documento canônico no app. A API mantém `docs/plano_habitat_social_2026-10-04.md` com seu escopo e referência a este plano. Nenhum código funcional foi alterado na elaboração deste documento.
