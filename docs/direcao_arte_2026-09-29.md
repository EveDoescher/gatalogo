# Direção de arte — 29/09/2026

## Referências e implementação

Home.jpg e Social.jpg, montagens fornecidas pelo usuário, orientam a composição. A biblioteca `assets/gatalogo_asset_library` substitui os antigos caminhos de imagens e interfaces. O arquivo `rename_map.csv` mantém a correspondência dos nomes. O pubspec inclui as nove categorias utilizadas, sem empacotar as folhas de contato ou o arquivo antigo.

Home usa quadro de missão, botão de folhagem, medalhas, fotografias, mapa e navegação ilustrada. O jardim preenche a tela atrás do menu; a rolagem reserva espaço para manter o último registro acessível. Nível tem alinhamento óptico, e a missão adapta sua composição quando o texto cresce.

Social tem cabeçalho com saldo, Comunidade/Amigos, filtros de conteúdo, acesso às buscas e cartões com foto real, autor, tempo, localização e ações. Os filtros consultam os serviços; respostas antigas não substituem uma seleção mais recente. A composição de cartão é independente das chamadas de rede.

## Composições por área

| Área | Artes e intenção |
| --- | --- |
| Captura | Câmera, lupa com pata e caderno ilustram fotografar, analisar e colecionar. |
| Coleção | Fotografias empilhadas e caderno reforçam o álbum de descobertas. |
| Missões | Prancheta com pequeno ramo, selos e fita sobre os objetivos confirmados. |
| Meus Gatos | Coleira identifica os gatos sob os cuidados do usuário. |
| Notificações | Caixa de correio no estado vazio. |
| Conversas | Balão com coração no estado vazio. |
| Cartazes | Lupa e coração acompanham o texto de ajuda, sem recompensa fictícia. |
| Loja do Habitat | Fachada com toldo e pequeno jardim, mantendo itens e preços do serviço. |
| Configurações | Engrenagem ilustrada em uma apresentação discreta e legível. |

## Reuso

- `BotanicalScene` e `BotanicalScaffold`: fundos, papel e decoração sem capturar toques; preservam visualizadores fotográficos.
- `BotanicalPaper`: cartões com cantos botânicos.
- `BotanicalAction`: botão compartilhado com estados de carregamento e texto flexível.
- `IllustratedSectionHeader`: texto adaptável ao lado de uma composição de objeto e acento, sem esticar imagens.
- `IllustratedAppHeader` e `AccountCoinBadge`: marca, saldo real e ações da conta.
- `CommunityPostCard`: apresentação do post com callbacks para as operações existentes.
- `FramedUserAvatar`: foto enviada ou Bapinho/Bapinha, com moldura e persistência da escolha.

Os fundos não substituem as composições particulares de Home, Social ou o cenário jogável do Habitat. Formulários e situações de busca priorizam leitura e ações.

## Dados e fluxos

XP, nível, moedas, missões diárias, conquistas, registros, mensagens e contadores sociais usam serviços e dados persistidos da conta. Falta de progresso confirmado é apresentada como indisponibilidade, sem inventar valores. Fotos ilustrativas e valores usados nos testes ficam restritos aos testes.

Compartilhamento externo e curtidas não dão recompensa. Repostagem interna confirmada atualiza o progresso; o cartaz mantém vínculo e estado da busca. Os fluxos de descoberta, revisão de atributos, coleção, busca e cuidado continuam integrados à reestruturação. Esta rodada não altera a configuração de liberação gradual da economia.

## Verificação e limites

- Análise Flutter final: sem problemas (`build/art-direction-analyze-final.log`).
- Rodada de Home, Social, reestruturação e correções: 25 testes passaram (`build/art-direction-confirmation.log`).
- Confirmação após ajuste do fundo e últimos detalhes: 14 testes passaram (`build/art-direction-final-check.log`).
- Suíte completa anterior desta implementação: 121 passaram, 2 ignorados. API: 133 passaram, 23 ignorados por infraestrutura de integração indisponível.
- Capturas Flutter verificadas em 360 px, com verificações de layout em 320 px e texto ampliado, além de largura maior. Home e Social: `build/home-reference` e `build/art-direction`; telas secundárias: `build/restructure`.
- A imagem ilustrativa do gato no teste do Social é uma fixture de decodificação. Em produção a mídia vem do post.
- Sem dispositivo Android conectado: não foi validada a aparência em aparelho, câmera nativa ou equivalência pixel a pixel às montagens. A compilação tem registro em `build/art-direction-apk.log`.

As capturas mostram a implementação; aprovação visual final e validação da liberação em produção continuam sendo etapas distintas.
