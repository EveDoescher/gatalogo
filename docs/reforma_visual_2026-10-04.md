# Reforma visual — 04/10/2026

## Rodada de fechamento das listas e estilos compartilhados

As listas de buscas passaram a usar papel e artes relacionadas ao estado: lupa para busca ativa e coração para caso concluído. Notificações usam lupa, conversa, caderno e medalha de acordo com o aviso. Avatares de Inbox, pesquisa, sugestões e ranking agora reutilizam a moldura com foto/presets. A abertura de Descobrir não tem mais o ramo independente.

As miniaturas protegidas de pistas receberam tamanho e enquadramento próprios, sem a altura fixa da foto ampliada. Datas e status quebram linha; o ranking também acomoda texto ampliado. Títulos de headline foram integrados à tipografia e tinta dos temas; filtros usam contornos de papel e seleção botânica.

A galeria passou de 44 para 59 imagens, com listas preenchidas, três estados de pistas, contribuição reconhecida e progresso de missões/conquistas. A captura exige fotografias decodificadas nas miniaturas. Cartaz encerrado exibe o estado correto e não oferece repost premiado. Os exemplos são restritos aos testes.

As pendências de evidência dos estados preenchidos citadas nas rodadas anteriores foram cobertas nesta rodada. O inventário por área, componentes, invariantes e limites está em `docs/auditoria_reforma_visual.md`. Verificação: 19 testes da rodada visual e 122 testes da suíte geral aprovados; três ignorados. Login e fontes reais de dados preservados. A validação nativa continua sem evidência neste ambiente.

## Continuação — buscas, configurações e compartilhamento

Configurações recebeu uma abertura com engrenagem; Experiência usa o novelo para apresentar os ajustes de ritmo e movimento. As preferências e controles existentes foram mantidos. O contorno dos switches passou a usar as cores dos temas.

O compositor associa o balão à publicação e enquadra a fotografia selecionada em papel. A contribuição pendente usa a placa de caminhos sobre jardim; a confirmação usa o troféu somente quando o estado real está confirmado. A Coleção ganhou uma seção própria para a pilha de fotos, afastando a arte dos botões do cabeçalho. Detalhes de descoberta reutilizam a fotografia em papel e o caderno junto à história.

As buscas receberam composições ligadas às ações: prancheta no cadastro e cartaz, mapa na área monitorada, lupa nas pistas e câmera no avistamento. Fotografias protegidas continuam com a mesma regra de acesso. Cartazes públicos e detalhes da comunidade usam as mesmas molduras. Missões e Ajuda do Habitat receberam aberturas em papel com objetos relacionados ao conteúdo.

O chat reutiliza a moldura de avatar que suporta foto enviada e presets. Corrigida a rolagem que ultrapassava a última mensagem. Títulos dos detalhes de pistas agora quebram linha em tela estreita com texto ampliado.

Reuso: `IllustratedSectionTitle` e `GamePhotoMount`. Dados de exemplo continuam exclusivamente no teste; nenhuma moeda, missão, conquista ou fotografia de demonstração foi inserida nos serviços de produção.

Evidência desta continuação: galeria permanente com 44 imagens de widgets; teste de captura e layout com telas em 320 e 820 pontos e texto a 1,5×. Análise sem problemas. A suíte geral aprovou 122 testes, com três testes ignorados. Logs: `build/visual-validation-capture.log`, `build/visual-validation-analyze.log` e `build/visual-reform-full-tests.log`.

Revisão visual inline: papel e fita ligados às fotografias, objetos junto às respectivas ações, cabeçalho da Coleção sem sobreposição e mensagem do chat visível nas capturas. Login preservado. A reforma permanece em andamento: faltam ampliar a evidência de listas preenchidas de notificações, conversas, amigos, cartazes e pistas, além dos estados confirmados de contribuição. Disposição `recapture` para evidência nativa; mapas com tiles e aparência em aparelho não foram validados neste ambiente.

Continuação da direção das montagens Home.jpg e Social.jpg e da biblioteca fornecida pelo usuário. O login foi restaurado à composição anterior de gato deitado sobre a logo; o portão experimental foi removido após a orientação do usuário.

## Telas desta rodada

- Perfil: moldura existente apoiada no chão de jardim, sem arbusto lateral, flores separadas ou marcador flutuante; bio com nota presa; contadores reais em cartões ilustrados de fotos, medalha e conversa. O ramo da margem direita foi girado para que o caule saia pela borda e as folhas entrem na composição.
- Amigos: abas com seleção verde arredondada, avatar com a mesma moldura da conta, introdução com placa de caminhos em Descobrir, e composições de casinha, correio e troféu nos estados vazios. Ações e convites continuam nos serviços existentes.
- Histórico: caderno e marcador na abertura, cartões de papel com artes correspondentes a descoberta, conversa, cartaz ou pista. O estado de cada resultado vem do progresso confirmado.
- Mapa: pins ilustrados com a fotografia do registro; o pin selecionado usa coral, e os demais ouro. A base do pin fica ancorada na coordenada. A ação de salvar usa o botão compartilhado.

## Reuso e correções

`IllustratedGardenStage` apoia objeto ou avatar sobre uma única base de jardim. Foram retirados os adereços independentes após a revisão do usuário. `IllustratedStatTile` recebe valor e rótulo da conta. `IllustratedPhotoPin` recebe a fotografia do avistamento. `BotanicalEmpty` aceita uma composição personalizada. Esses componentes ampliam a biblioteca compartilhada sem embutir exemplos de conta no app.

`BotanicalPaper` agora fornece sua própria camada Material transparente para garantir que listas e toques apareçam sobre o papel; o teste do histórico preenchido detectou e confirmou essa correção.

## Evidência

- Nova rodada: `build/validacao-visual-2026-10-04/galeria.html` e `LEIA-ME.md` organizam 42 capturas atuais de telas e estados, incluindo login restaurado, Perfil corrigido e Habitat carregado. Captura automatizada habilitada apenas com `GATALOGO_CAPTURE_ALL=1`; dados e fotos de exemplo ficam restritos ao teste. Os mapas de ruas não carregam neste ambiente. A galeria inclui telas com apenas o tema aplicado, sem declarar toda a reforma concluída.
- O cabeçalho do chat passou a limitar o subtítulo ao espaço disponível para evitar corte em 390 px.
- Após essas correções: `build/visual-validation-capture.log` registra a captura completa aprovada pelo teste; `build/visual-validation-layout.log` registra 17 testes aprovados; `build/visual-validation-analyze.log` registra análise sem problemas.

- `build/visual-oct04-final-tests.log`: 17 testes passaram, incluindo 320, 390 e 820 px, texto normal e ampliado.
- `build/visual-oct04-final-analyze.log`: análise Flutter sem problemas.
- Capturas em `build/restructure`: Perfil, Amigos, histórico preenchido e login restaurado. Fotografias e valores dessas capturas são fixtures de teste, restritas aos testes.
- `build/restructure/login-restaurado-2026-10-04.png`: arquivo separado da composição restaurada para distinguir as capturas anteriores.
- As capturas verificadas são de widgets Flutter. Mapa com tiles, câmera e aparência final em aparelho Android ainda precisam de validação nativa. O APK anterior não representa esta rodada.

## Padronização por nível de navegação

A rodada de hierarquia visual centraliza a escolha de superfícies em `BotanicalLevel` e `BotanicalLevelScope`. Abas principais usam o jardim compartilhado; páginas secundárias usam creme e folhagem discreta; formulários e ações internas usam papel marfim com a mesma folhagem discreta. A classificação considera a função da página. Rotas abertas a partir de uma aba não herdam indevidamente sua decoração. O cenário jogável do Habitat, a composição restaurada do login e os visualizadores de fotografias mantêm suas características próprias.

Meu Perfil e Perfil Público reutilizam `IllustratedProfileIdentity`, com a mesma dimensão do retrato e o mesmo chão. Nível em caderno e bio em nota seguem a mesma composição; ações de amizade, edição e contadores preservam seus dados e permissões. O perfil público não apresenta uma barra de progressão inventada. Os anéis do caderno se ajustam à altura disponível.

Validação desta rodada: 21 testes passaram, incluindo capturas, navegação entre níveis, fundo sob o menu e layouts compactos/amplos com texto ampliado. A análise Flutter terminou sem problemas. Logs: `build/navigation-level-capture.log` e `build/navigation-level-analyze.log`. A galeria permanente foi regenerada com 59 capturas de widgets. Revisão inline do Impeccable: hierarquia e composição dos perfis confirmadas; disposição `recapture` permanece exclusivamente para evidência nativa em aparelho.

## Revisão e documentação

Revisão final realizada inline conforme o fluxo degradado do Impeccable. Fidelidade: login restaurado, direção compartilhada mantida, composições adicionais solicitadas pelo usuário presentes. Layout e legibilidade passaram nas larguras testadas; fotos, contadores e estados continuam vindos dos dados da conta. Limite de evidência: sem captura nativa do mapa. Disposição: `recapture` para aprovação visual nativa; sem bloqueio identificado nos widgets verificados.

Conferidos `DESIGN.md`, `lib/theme/app_theme.dart` e os componentes compartilhados. Esta rodada estende a direção existente e mantém seus tokens. Não atualiza o lançamento em produção nem declara a reforma inteira aprovada visualmente.

### Revisão da correção solicitada

Revisão do Impeccable executada inline, usando o fluxo degradado já adotado nesta sessão. Disposição: `recapture` para evidência nativa. Nas capturas atuais, a retirada dos adereços independentes está resolvida, o chão sob o avatar foi preservado e o ramo da direita está orientado com seu caule na margem. As 42 imagens de widgets estão disponíveis para a validação solicitada pelo usuário; mapas de ruas e aparência em aparelho continuam sem evidência nativa. Login preservado.

### Fundo sob a navegação e galeria permanente

Por orientação do usuário, todas as abas passaram a usar `IllustratedNavigationScaffold`, com o fundo estendido até a borda inferior, atrás do menu. As folhas adicionais da Coleção ficam fora da área segura do conteúdo; câmera, prévia, ferramentas, inventário e conteúdo da loja/ajuda respeitam o espaço da navegação. O Habitat nunca perdeu seu menu no app: a captura anterior foi feita com a página isolada. As novas capturas de Habitat, Loja e Ajuda incluem o menu real compartilhado.

A entrega atual passa a ter endereço fixo: `build/galeria-visual/galeria.html` e `LEIA-ME.md`. O teste de captura gera o índice automaticamente, com 42 imagens, rótulos, horário e busca por tela. A regra de atualizar a galeria após toda rodada visual está registrada em `DESIGN.md`. A pasta com data preserva a rodada anterior.

Verificação: 19 testes passaram na rodada conjunta (capturas, geometria da navegação e 17 testes de layout existentes). O novo teste verifica nas cinco abas que o fundo chega ao fim da tela e o conteúdo seguro termina acima do menu. As capturas continuam restritas ao ambiente de widgets; a aprovação visual pelo usuário e a validação nativa permanecem pendentes.

### Continuação — álbum dos gatos e comunidade

- Meus Gatos: álbum de proteção com quantidade do store, fotografias enquadradas em papel e fita, cadastro e alerta rápido acessíveis; dica dos ângulos ligada à prancheta. A lista e os estados dos alertas continuam nos serviços existentes.
- Cadastro: caderno apresenta a ficha; câmera acompanha a escolha da foto. Removida uma explicação duplicada. Campos, limites, escolha de imagem, validação e salvamento preservados.
- Perfil do gato: fotografia real no `GamePhotoCard`, informações no papel compartilhado, álbum associado à pilha de fotos e identificação associada à coleira. Acesso à foto ampliada, edição e alerta mantidos.
- Galeria do gato: abertura de álbum e fotografia principal com o mesmo enquadramento. Título e etiquetas de ângulos agora quebram linha com texto ampliado, mantendo cadastrar, trocar e remover fotos.
- Conversas: abertura com balão de conversa; caixa de correio apoiada no jardim no estado vazio. Estado vazio pode rolar em telas pequenas. Conversas embutidas preservam o espaço do anfitrião.
- Notificações: sino identifica a abertura, caixa de correio no chão do estado vazio, removida a camada duplicada de vegetação local.
- Perfil público: avatar apoiado no chão, selo real de nível e contadores ilustrados reutilizados. Botão de amizade sem altura fixa que cortava seu rótulo.

Componente novo: `IllustratedPaperHeading`, com um objeto ligado ao contexto e texto que se adapta à largura. Não usa acessórios soltos. Sem mudanças nos tokens de cor ou nas fontes; login e montagens de Home/Social preservados.

A galeria atual foi ampliada para 44 capturas, incluindo foto/salvamento no cadastro e ângulos no álbum. Evidência: teste de captura com verificações adicionais das sete telas em 320 e 820 pontos com texto a 1,5×, mais a rodada de 19 testes existentes. Os números e fotos das capturas são fixtures restritas aos testes. Revisão do Impeccable inline: composições e encaixes confirmados nas imagens de widgets; disposição `recapture` permanece para evidência nativa. Esta rodada não declara todas as telas do aplicativo concluídas.
