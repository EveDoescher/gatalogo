---
name: Gatálogo
description: Caderno vivo e acolhedor de descobertas felinas
colors:
  primary: "#DC8BA1"
  primary-dark: "#C7607E"
  primary-light: "#FCEBE8"
  primary-soft-bg: "#FCEDED"
  green: "#6A914C"
  green-button: "#52783C"
  green-light: "#ECF2D8"
  green-link: "#426538"
  green-progress: "#6B8A5A"
  background: "#FBF6E8"
  surface: "#FFF9EC"
  card-background: "#F8F0DF"
  card-alt-background: "#FFFAEF"
  text-dark: "#4B281B"
  text-title: "#4B281B"
  text-medium: "#80654E"
  text-light: "#948C87"
  border: "#BCA381"
  border-light: "#E2D4B7"
  input-bg: "#FFF8E9"
  guest-card-bg: "#F0EEE3"
  guest-card-text: "#4A5844"
  guest-card-subtext: "#7A8772"
  game-paper: "#FFF8E7"
  game-canvas: "#F1E7D5"
  game-ink: "#93765F"
  game-edge: "#C2AA87"
  game-gold: "#F5CC66"
  game-green-paper: "#E7EEDC"
  game-pink-edge: "#B5647C"
  game-rose-action: "#EBA7B9"
  game-sage-action: "#D2E1BC"
  game-coin-paper: "#FFE9A6"
  game-xp-paper: "#E3EDD5"
  game-progress: "#AEC58C"
  game-progress-track: "#E5DECC"
  game-cover: "#B89A79"
  error: "#D4543C"
  home-paper: "#FBF6E8"
  home-background: "#F0F0DD"
  home-ink: "#4B281B"
  home-green: "#426538"
  home-edge: "#94724E"
  home-progress-track: "#F4EBD9"
  home-progress-fill: "#8EB35C"
  home-progress-edge: "#C6AE8E"
  home-nav-selected: "#EDF3C9"
typography:
  display:
    fontFamily: "Fredoka, sans-serif"
    fontSize: "32px"
    fontWeight: 700
    lineHeight: 1.1
  headline:
    fontFamily: "Fredoka, sans-serif"
    fontSize: "26px"
    fontWeight: 700
    lineHeight: 1.15
  title:
    fontFamily: "Fredoka, sans-serif"
    fontSize: "22px"
    fontWeight: 600
    lineHeight: 1.1
  body:
    fontFamily: "Nunito, sans-serif"
    fontSize: "14px"
    fontWeight: 500
    lineHeight: 1.3
  label:
    fontFamily: "Nunito, sans-serif"
    fontSize: "13px"
    fontWeight: 700
rounded:
  sm: "8px"
  md: "14px"
  lg: "16px"
  xl: "18px"
  pill: "24px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "#FFFFFF"
    rounded: "{rounded.pill}"
    padding: "14px 24px"
    height: "48px"
  button-google:
    backgroundColor: "{colors.input-bg}"
    textColor: "{colors.text-title}"
    rounded: "21px"
    padding: "10px 20px"
    height: "42px"
  input-text:
    backgroundColor: "{colors.input-bg}"
    textColor: "{colors.text-dark}"
    rounded: "{rounded.lg}"
    padding: "16px 18px"
  button-game-rose:
    backgroundColor: "{colors.game-rose-action}"
    textColor: "{colors.text-title}"
    rounded: "{rounded.xl}"
    padding: "13px 16px"
  button-game-sage:
    backgroundColor: "{colors.game-sage-action}"
    textColor: "{colors.text-title}"
    rounded: "{rounded.xl}"
    padding: "13px 16px"
  game-panel:
    backgroundColor: "{colors.game-paper}"
    textColor: "{colors.text-dark}"
    rounded: "{rounded.lg}"
    padding: "16px"
  game-notebook:
    backgroundColor: "{colors.game-paper}"
    textColor: "{colors.text-dark}"
    rounded: "11px"
    padding: "20px 16px 20px 26px"
  game-reward-coins:
    backgroundColor: "{colors.game-coin-paper}"
    textColor: "{colors.text-dark}"
    rounded: "{rounded.md}"
    padding: "5px 9px"
  game-progress:
    backgroundColor: "{colors.game-progress-track}"
    textColor: "{colors.text-dark}"
    rounded: "12px"
    height: "24px"
  game-photo:
    backgroundColor: "{colors.game-paper}"
    rounded: "9px"
    padding: "7px"
---

# Design System: Gatálogo

## Overview

**Creative North Star: "O Caderno Vivo de Descobertas Felinas"**

Gatálogo transforma a exploração em um caderno de campo acolhedor: fotografias reais são lembranças guardadas em papel creme, enquanto gatos ilustrados e folhagens existentes habitam as margens e os destinos. A direção autorizada é a de um jogo calmo, com materiais de álbum, contornos marrons e controles pastel.

A camada de jogo convive com a identidade botânica anterior. Autenticação e formulários preservam suas superfícies claras, componentes arredondados e leitura limpa; caderno, fita, notas e selos dão presença física à descoberta e à progressão. A implementação nativa é a fonte dos valores abaixo. A home atual segue a composição ilustrada do Home.jpg fornecido pelo usuário e os arquivos em assets/gatalogo_asset_library, e o Social segue Social.jpg; as demais telas compartilham papel, cores, ações e composições botânicas reutilizáveis. A documentação registra o código e a existência das capturas de widgets Flutter informadas nesta rodada; não houve dispositivo nativo disponível nem nova captura nesta atualização documental. Não se declara equivalência pixel a pixel com a referência.

**Key Characteristics:**
- Fotografias reais enquadradas como lembranças coladas no álbum.
- Papel creme, encadernação visível e contornos marrons suaves nas áreas de jogo.
- Rosa para ações, verde para crescimento e dourado para recursos e conquistas.
- Fredoka nos títulos de jogo e Nunito no corpo e nos números de progresso.
- Ilustrações felinas e botânicas existentes integradas à experiência.
- Home composta com as artes fornecidas, proporções preservadas e dados reais da conta.

## Colors

A paleta mantém os tons botânicos existentes e acrescenta materiais de caderno ao jogo. Os valores normativos estão no frontmatter; AppColors e GameStyle são suas fontes Flutter.

### Primary
- **Rosa Gatálogo / primary:** marca e botões convencionais de autenticação; primary-dark reforça estados ativos, primary-light e primary-soft-bg acolhem acentos.
- **Rosa de ação / game-rose-action:** preenchimento dos GameButtons nas superfícies de jogo que ainda os utilizam; a home atual usa a arte Button.png.
- **Borda pétala / game-pink-edge:** detalhe de selos ainda não concluídos.

### Secondary
- **Verde da home / home-green:** títulos de ação, avatar e seleção do menu ilustrado; home-progress-fill preenche a trilha de XP e missão.
- **Verde botânico / green:** natureza e progresso; green-link mantém leitura dos links e ícones de crescimento.
- **Sálvia de ação / game-sage-action:** ações secundárias ligadas ao Quintal.
- **Papéis verdes / game-green-paper e game-xp-paper:** notas concluídas e XP; game-progress preenche a trilha de crescimento.
- **Acesso sem conta / guest-card-bg:** preserva o cartão de entrada com guest-card-text e guest-card-subtext.

### Tertiary
- **Ouro guardado / game-gold e game-coin-paper:** moedas, progresso de uma compra e conquistas. Sempre acompanhado de número ou rótulo significativo.
- **Coral / error:** erro ou urgência real, sem promover missões comuns a alertas.

### Neutral
- **Papel e jardim da home / home-paper e home-background:** jardim ilustrado até a borda inferior, atrás da navegação, e áreas legíveis sobre as artes fornecidas. Home-ink fornece café escuro; home-edge delimita superfícies; home-progress-track e home-progress-edge formam a trilha clara. Home-nav-selected marca o destino ativo.
- **Papel de jogo / game-paper:** páginas, molduras de fotografia e notas.
- **Mesa de caderno / game-canvas:** fundo das superfícies de jogo; background permanece o fundo da identidade de formulários.
- **Café de contorno / game-ink e game-edge:** desenho estrutural; não substituem os tons de texto de maior contraste.
- **Capa / game-cover:** espessura da encadernação.
- **Café de leitura / text-dark, text-title e text-medium:** corpo, títulos e explicações.
- **Superfícies existentes / surface, card-background, card-alt-background e input-bg:** preservam formulários e conteúdo fora da camada de jogo.
- **Linhas existentes / border e border-light:** divisores e limites discretos dos formulários.

**The Warm Ink Rule.** Usar cafés para texto e contornos da interface; a regra não altera as cores de fotografias reais ou assets existentes.

**The Meaningful Accent Rule.** Rosa indica ação, verde indica crescimento e dourado indica recurso ou conquista; a cor acompanha texto e estado real.

## Typography

**Display Font:** Fredoka, com fallback sans-serif. **Body Font:** Nunito, com fallback sans-serif.

Fredoka dá títulos arredondados e reconhecíveis ao jogo; Nunito sustenta leitura de descrições, formulários e quantidades. O tema observado usa display 32/700 e headline 26/700, title 22/600, corpo 14/500 com altura 1.3; textos maiores usam 16/600. GameStyle.title aplica Fredoka 600 com tamanho explícito, normalmente 20–28 nas ações e títulos, e não fixa altura de linha.

A navegação ilustrada principal usa Nunito 10/900. HomeArt.title usa Fredoka 600, altura 1.08 e tamanho adaptado à composição; a home preserva Nunito nos textos descritivos, valores de progresso e links. Essas escolhas locais não substituem a escala do tema para as outras telas. Recompensas usam Nunito 13/900 ou 22/900 no tamanho grande. A trilha de progresso usa 12/900. A escala antiga de autenticação é preservada onde a tela declara Nunito diretamente; não converter seus formulários em títulos decorativos por consequência deste documento.

**The Readable Record Rule.** Reservar a personalidade de Fredoka para títulos e ações; usar Nunito para instruções, valores e estados que precisam ser comparados ou compreendidos rapidamente.

## Layout

As telas de jogo usam rolagem e largura disponível com margens observadas de 12–20 unidades lógicas. O resultado limita o conteúdo a 560 e sua fotografia a 320; esses limites são locais, não breakpoints globais. O caderno pode ser uma página com lombada lateral ou uma abertura com duas páginas e costura central. GameNotebook reserva 26 à esquerda na variante de página e continua disponível nas superfícies de álbum, perfil e desafios; não é mais a estrutura da home atual.

A home atual monta as artes do Home.jpg do usuário com conteúdo dinâmico: logo, caixa de mensagens e avatar; nível, XP e moedas; Jornada de hoje; conquistas reais; Gatalogar; atalhos Meus Gatos e Meu Mapa; última descoberta. O corpo é rolável, centralizado e limitado a 560 unidades lógicas, com escala de composição width/390. A logo mede 143 vezes essa escala e usa contain; não deve ocupar o espaço reservado às ações do cabeçalho. Gatalogar usa altura proporcional limitada entre 62 e 95, com ajuste para texto ampliado. No quadro Jornada, a arte Card.png mantém a razão 1478/520 com tipografia e Board.png encaixados nas aberturas; acima de escala de texto 1.2 o conteúdo passa a uma composição vertical que pode crescer.

O menu ilustrado mantém Início, Social, Gatalogar, Coleção e Quintal e preserva a proporção de Bar.png usando cover, que pode recortar a imagem para preencher a faixa, sem esticá-la. Coleção conserva suas abas internas Gatos e Desafios. O editor existente do Quintal permanece o destino funcional. A troca da home não redefine as composições dessas outras superfícies.

Autenticação preserva a composição central compacta de 340–360, margens de 24–36, SafeArea e rolagem para teclado. Folhagens perimetrais usam Stack e IgnorePointer, sem capturar toques. O ritmo compartilhado continua baseado em 4, 8, 12, 16 e 24. Foram informadas capturas de widgets Flutter nas larguras 360, 320 com escala de texto 1.5 e 820, incluindo build/home-reference/home-360.png e build/home-reference/home-820.png. Elas não substituem validação em dispositivo nativo, que não estava disponível; não garantem ajuste a todas as larguras, escalas ou equivalência pixel a pixel. Esta revisão documental não gerou nem reviu capturas.

## Elevation & Depth

Na home ilustrada, textura, moldura e volume vêm prioritariamente dos assets fornecidos; os componentes nativos acomodam o conteúdo. Nas demais superfícies, o jogo admite profundidade de materiais de papel: bordas, capa, folhas, fita e sombra quente difusa. Essa autorização substitui a antiga regra global de planicidade. GamePanel usa sombra com deslocamento vertical 3, blur 8 e café a 20/255 de opacidade; GameNotebook usa deslocamento 5, blur 12 e café a 34/255. Formulários, dialogs e bottom sheets mantêm a elevação convencional zero do tema.

O botão de jogo possui uma base marrom de 2 unidades sob a face, construída como geometria de Material/DecoratedBox. Isso descreve o componente atual; não institui sombras duras como linguagem geral. A fita e as folhas são estruturas discretas, sem textura gerada sobre a fotografia.

**The Paper Depth Rule.** Usar profundidade para distinguir capa, página e lembrança; manter a leitura dos formulários limpa e a fotografia reconhecível.

## Shapes

O sistema existente preserva inputs com raio 16, botões convencionais em cápsula de raio 24, botão Google de raio 21 e cartão de convidado de raio 18. A camada de jogo usa painel 16, botão 18, recompensa 14, trilha 12 e foto 9 com imagem interna 4. Caderno tem capa 15 e folha 11. Fita possui raio 2, altura 15 e largura padrão 48; costuras e contornos são geometria, não novos assets ilustrados.

Bordas do jogo são visíveis e quentes: painel e capa 1.5, botão 2, foto 1.3, recompensa 1.2. Essas diferenças refletem a escala dos objetos, sem impor uma espessura única a toda a aplicação.

## Components

### Buttons

**GameButton:** face rosa ou sálvia, contorno quente, Fredoka 20/600, ícone Material 25 e padding 13 vertical por 16 horizontal. A ação usa InkWell e semântica de botão. O comportamento nativo de foco, toque e indisponibilidade deve continuar acessível; a documentação não atesta sua validação em dispositivo.

**Botões de autenticação:** preservar o rosa original, Nunito e a pata sólida branca em suas chamadas principais. O botão Google mantém o asset oficial google_logo.png, fundo input-bg, raio 21 e altura 42. Essa convenção não exige ícone de pata branco nos botões do jogo, que usam ícones de ação e café.

### Inputs / Text Fields

Campos preservam input-bg, OutlineInputBorder com raio 16 e borda 1.2, foco rosa 1.6 e erro coral. O tema aplica padding 16 vertical por 18 horizontal. Prefixos mantêm text-medium. O cartão de convidado preserva guest-card-bg, raio 18 e os textos próprios já existentes.

### Navigation

IllustratedNavigationBar aplica Bar.png como fundo proporcional com cover. As cinco entradas têm ícone de 22 e rótulo Nunito 10/900, padding vertical 5 e raio 17. A seleção usa home-nav-selected, contorno verde de 1.5 e texto home-green; demais ícones e textos ficam claros sobre a faixa. SafeArea protege a borda inferior e a contagem não lida continua vinculada ao Social. O InkWell inclui ícone e rótulo; a documentação não certifica alvos de toque em dispositivo. Em Coleção, as abas Gatos/Desafios têm topo arredondado de 12, Fredoka 18 e indicador de página creme com borda 1.5.

### Illustrated home and account avatar

HomeArt.image carrega assets/gatalogo_asset_library com contain por padrão e exclui a decoração da árvore semântica. A ação Gatalogar combina Button.png com rótulo e ícones nativos; Jornada usa Card.png e Board.png, nunca Board_2.png. O quadro compacto posiciona os textos nos espaços vazios da arte e usa scaleDown quando necessário. Logo, rótulo Jornada e conteúdo de Gatalogar têm medidas reduzidas para caber nas artes; o ajuste é local, sem instituir redução de todo texto do aplicativo.

A home lê moedas exclusivamente de progress.summary['balance']; XP, nível, título e metas vêm da progressão da conta, condicionados à presença de xp no resumo. A missão vem diretamente de daily_missions, priorizando a primeira não concluída e depois a primeira disponível. Recompensas e progresso pertencem à missão recebida. A prateleira mostra até cinco entradas reais de challenges, diferenciando conclusão e progresso; não preenche vagas com medalhas fictícias. Sem a fonte, aparecem travessões, XP indisponível, Missões indisponíveis ou orientação de sincronização. Não usar saldos, missões ou conquistas da imagem de referência como conteúdo de produção.

FramedUserAvatar oferece Bapinho e Bapinha com os assets bapinho_moldura.png e bapinha_moldura.png. Fotos locais ou remotas ocupam a abertura circular de moldura.png, preservando a moldura botânica externa; erro de imagem apresenta o ícone de usuário. A escolha de preset é persistida localmente pelo SessionStore e, quando autenticado, enviada à API com avatar_preset. Falha ao salvar tem mensagem explícita. Os presets são escolhas de avatar, não fotografias de gatos catalogados.
### Notebook, notes and photos

GameNotebook oferece encadernação lateral ou central, com três costuras e conteúdo variável. GameNote coloca uma fita sobre GamePanel, com padding 18 superior e 14 nos demais lados. GamePhotoCard usa CatPhotoView para a foto real do registro, moldura de papel com padding 7, número de captura e nome opcional; a fita é decorativa e ignora eventos de ponteiro. GameTape inclina em -0.08 radianos sem distorcer a imagem guardada.

### Rewards and progress

GameReward diferencia moedas e XP por ícone, cor e texto; o asset existente de moeda permanece. GameProgress mostra o valor textual e fornece semântica de quantidade, limitando o preenchimento entre zero e um. GameSeal e GoalProgressCard representam desafios com selo, nota, estado de conclusão, trilha e recompensas declaradas pelos dados. RecordStateNotice distingue registro local, análise, confirmação, revisão, falha e inelegibilidade; aspecto visual de recompensa não equivale a crédito já concedido.

### Capture and profile

A captura usa GamePanel para instruções sobre o fundo game-canvas. O perfil aplica o mesmo fundo, apresenta a biografia como GameNote e usa o caderno compartilhado para nível, XP e conquistas guardadas. O cabeçalho do próprio perfil omite o atalho redundante de avatar. Essas aplicações estendem os materiais existentes; não introduzem uma nova escala ou uma regra global de composição.

### Discovery reveal

A revelação observada escala a foto de 0.96 a 1 em 420 ms com easeOutCubic. Respeita disableAnimations, a preferência de movimento e a ação Pular animação, convertendo a duração em zero. Esse movimento curto apresenta a lembrança; não é autorização para movimento contínuo ou bloqueio do próximo passo.

## Do's and Don'ts

### Do:
- Do preservar fotos reais e usar assets existentes de gatos, folhas e Quintal para contextualizar a coleção.
- Do usar estados e quantidades reais nos rótulos de XP, moedas, desafios e próximos objetivos.
- Do manter as cinco entradas principais e o editor existente do Quintal.
- Do preservar a proporção da arte do menu e usar Board.png no quadro Jornada da home.
- Do mostrar indisponibilidade quando a fonte real de XP, moedas, missões ou conquistas estiver ausente.
- Do manter o asset oficial google_logo.png e a pata sólida branca nas chamadas de autenticação que já os utilizam.
- Do preservar OutlineInputBorder com raio 16 e foco visível nos formulários.
- Do manter Folha_2 na margem superior esquerda e Folha_4 próxima da ação principal nas composições de autenticação existentes.
- Do manter fita, folhas e costuras decorativas fora da captura de toques.

### Don't:
- Don't substituir fotos do catálogo por ilustrações ou placeholders que aparentem registros reais.
- Don't apresentar recurso pendente como prêmio confirmado.
- Don't copiar números da referência visual nem preencher a home com missões ou medalhas inventadas.
- Don't converter formulários em páginas densas de decoração por aplicar a camada de jogo.
- Don't impor ausência de profundidade às páginas, notas e fotos do caderno.
- Don't usar preto puro como tinta de texto da interface ou sombras escuras pesadas nos materiais de papel.
- Don't aproximar excessivamente o gato ilustrado do texto da logo Gatálogo.


## Direção compartilhada — 29/09/2026

### Hierarquia de superfícies — 04/10/2026

Fundos são definidos pelo papel da tela na navegação, nunca pelo assunto ou por uma cor escolhida localmente. `BotanicalLevel` e `BotanicalLevelScope` centralizam essa regra:

- Principal: Início, Social, Gatalogar e Coleção usam o jardim ilustrado sobre creme, até a borda inferior atrás da navegação. O Quintal mantém o cenário jogável, com o mesmo menu e controles da família visual.
- Secundário: perfis próprio/público, listas, detalhes de descoberta, missões, histórico, configurações e Loja usam creme (`AppColors.background`) com os mesmos ramos discretos nas margens. Cabeçalhos transparentes compartilham a superfície da página.
- Terciário: cadastro de gato, criação de alerta, detalhe de pista, álbum de fotos, chat, cartaz, preferências de experiência e Ajuda usam papel (`AppColors.surface`) e a mesma folhagem discreta. São ações ou leitura dentro de outra área, com menor presença de cenário.
- Autenticação e visualização de mídia: login restaurado permanece na composição aprovada; fotos ampliadas mantêm o fundo escuro para leitura da imagem. Mapas e o quintal preservam a superfície funcional da cena.

A profundidade é uma categoria de interface, não a contagem literal de páginas na pilha. O escopo principal envolve somente o corpo das abas: rotas abertas pelo Navigator retornam ao estilo secundário, e páginas terciárias declaram seu nível explicitamente. Loja e Ajuda declaram seus níveis mesmo quando abertas dentro do Quintal.

`IllustratedProfileIdentity` padroniza o retrato de 116 pontos sobre jardim de 162 pontos e o espaço para o nome. Ambos os perfis usam identidade sem cartão envolvente, nível em caderno e bio em nota presa. Editar a própria conta e interagir com outra pessoa continuam sendo ações diferentes. Não fabricar barra de progresso, amigos ou estatísticas quando a resposta pública não oferece esses dados.

Verificação e capturas desta direção: `build/navigation-level-capture.log`, `build/navigation-level-analyze.log` e `build/galeria-visual/galeria.html`. A galeria permanente continua sendo atualizada após toda alteração visual.

A biblioteca atual é `assets/gatalogo_asset_library`, registrada por categoria no pubspec. Os nomes anteriores existem apenas como aliases em HomeArt; `rename_map.csv` documenta a migração. Fotografias, moedas, nível, XP, missões, conquistas e contadores sociais vêm dos serviços e registros da conta. Imagens e valores de testes não entram no aplicativo.

`BotanicalScene` cuida dos fundos; `BotanicalScaffold` aplica essa camada nas rotas sem interferir em visualizadores de fotos. `BotanicalPaper` compõe papel com folhagem discreta. `BotanicalAction` centraliza as ações; `IllustratedSectionHeader` combina texto adaptável e objetos ilustrados sem distorcer as artes. Home e Social preservam composições próprias das montagens.

Assets precisam de uma relação espacial coerente: objetos apoiados na base, fitas presas ao papel e ramos com o caule saindo pela margem. Não acrescentar adereços flutuantes apenas para preencher espaço. `IllustratedGardenStage` usa uma única base sob o avatar ou objeto; não combina arbusto, flores separadas e marcador solto ao redor.

Todas as abas usam `IllustratedNavigationScaffold`: o fundo ocupa a altura inteira da tela, atrás do menu. Conteúdo rolável e controles respeitam o espaço do menu sem deslocar o fundo para cima. Quintal mantém a navegação principal; a captura da aba deve incluí-la.

A galeria visual é uma entrega permanente: após qualquer rodada que altere telas, recapturar as telas e atualizar `build/galeria-visual/galeria.html` e `LEIA-ME.md` pelo teste `visual_validation_capture_test.dart` com `GATALOGO_CAPTURE_ALL=1`. O índice é gerado automaticamente junto às imagens, com data, rótulos e limitações. Não apresentar capturas antigas como resultado de alterações novas. Login permanece na composição restaurada.

`IllustratedPaperHeading` associa um único objeto ilustrado à função do conteúdo: álbum para fotos, caderno para cadastro, câmera para escolher fotografia, balão para conversas e sino para avisos. Sem ornamentos independentes ao redor. Meus Gatos, perfil do gato e galeria usam `GamePhotoCard` com a fotografia do registro; o papel e a fita enquadram a foto sem substituí-la por um asset. Perfil público reaproveita `IllustratedGardenStage`, `GameSeal` e `IllustratedStatTile` com valores da resposta real. Estados vazios de correio usam a caixa apoiada na base de jardim.

A Captura usa câmera, lupa e caderno; a Coleção usa fotografias empilhadas e álbum; Missões usa prancheta; Meus Gatos usa coleira; Notificações usa caixa de correio; Conversas usa balão com coração; Cartazes usa lupa e coração; a Loja usa fachada com toldo e jardim. Configurações mantém leitura simples com engrenagem ilustrada. O Quintal preserva seu cenário jogável.

`IllustratedSectionTitle` associa uma ilustração pequena ao título de uma seção e permite quebra de linha. `GamePhotoMount` enquadra fotografias de fontes distintas em papel com fita presa à borda; a fonte e as regras de acesso continuam no widget filho. Usar câmera para fotografias, mapa para área monitorada, lupa para pistas e caderno para história. Controles de alternância usam contornos dos tokens botânicos, sem borda preta padrão no tema claro.

Os estilos `headlineLarge`, `headlineMedium` e `headlineSmall` também usam Fredoka e a tinta do tema. Avatares de mensagens, sugestões, pesquisa e ranking reutilizam `FramedUserAvatar`, inclusive presets Bapinho/Bapinha e fotos enviadas. Avisos usam artes pequenas relacionadas ao tipo de notificação; não acrescentar fundos ou ornamentos diferentes a cada linha da lista. Miniaturas de pistas reutilizam o acesso protegido de `PrivateCluePhoto` com altura e enquadramento adequados ao espaço, mantendo a fotografia ampliada disponível ao toque.

Evidências e limitações: `docs/direcao_arte_2026-09-29.md`. As capturas são de widgets Flutter, não validação de dispositivo Android nem promessa de equivalência pixel a pixel.
