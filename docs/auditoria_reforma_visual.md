# Auditoria da reforma visual

Objetivo: manter todas as áreas do aplicativo na direção cozy das montagens fornecidas, com assets contextualizados, componentes reutilizáveis e galeria atualizada. O inventário foi confrontado com as classes públicas de `lib/pages`, as composições compartilhadas e as capturas atuais. Login preservado conforme a orientação posterior do usuário.

## Cobertura por área

| Área e fontes | Composição verificada | Evidência na galeria permanente |
|---|---|---|
| HomePage | Logo, selo de nível centralizado, missão no quadro, medalhas, botão verde, fotos e mapa; fundo até a borda inferior | home, home_progress |
| SocialPage | Cabeçalho e filtros da montagem, cartões com avatar e fotografia, folhagem ligada às bordas | social |
| CapturePage / DiscoveryResultPage | Câmera e caderno, revisão da foto, fotografia em papel, resultado e ações seguintes | capture, result |
| LibraryPage / CatAlbumPage / ChallengesPage | Abas, busca, pilha de fotos fora das ações, álbum com peças e progresso | collection, challenges, challenges_progress |
| CatDetailsPage / CatGalleryPage | Fotografias reais enquadradas em papel, caderno para história, álbum e ângulos | cat_detail, cat_gallery, cat_gallery_angles |
| MyCatsPage / AddPetPage / PetProfilePage | Álbum de proteção, formulário em papel, câmera junto à escolha de foto, coleira junto à identificação | my_cats, add_pet, add_pet_details, pet |
| ProfilePage / PublicProfilePage | Avatar apoiado em uma base de jardim, nota presa, contadores e selo reais | profile, public_profile |
| JourneyPage / ResultHistoryPage / ContributionPage | Prancheta de missões, mural e peças, caderno de histórico; placa no estado pendente e troféu no confirmado | achievements, achievements_progress, achievements_medals, history, contribution, contribution_confirmed |
| FriendsPage | Moldura única para lista, sugestões e ranking; convite em papel; seleção verde e aberturas contextualizadas | friends, friends_discover, friends_invites, friends_ranking e variantes filled |
| InboxPage / ConversationPage | Caixa de correio apoiada no vazio; fotografia/preset na moldura, mensagens e indicadores reais | inbox, inbox_filled, chat |
| NotificationsPage | Sino na abertura; lupa, balão e medalha ligados ao tipo do aviso; seções ordenadas | notifications, notifications_filled |
| MissingCatsPage / CreateMissingReportPage / MissingReportDetailPage | Busca ativa e concluída em cartões; prancheta no cadastro, fotografia em papel, mapa e lupa nas ações correspondentes | missing_cats, missing_cats_filled, quick_alert, registered_alert, active_alert |
| CluesPage / ClueDetailPage / MissingCatPosterPage | Timeline, miniaturas protegidas em papel, status adaptável, comparação e cartaz preservando contatos/QR | clues, clues_filled, clue_detail, poster |
| CommunityPostersPage / CommunityCasePage | Cartazes com fotografia montada, busca e contatos; rótulo e repost respeitam estado original | community_posters, community_posters_filled, community_case, community_case_filled |
| LocationPage / MissingMapConsolidatedPage | Pins ilustrados ancorados na coordenada e ações de mapa preservadas | map, missing_map; tiles indisponíveis nas capturas |
| SettingsPage / ExperienceSettingsPage | Engrenagem e novelo nas aberturas; controles legíveis, contornos botânicos, preferências mantidas | settings, experience |
| HabitatPage / HabitatShopPage / HabitatHelpPage | Cenário jogável preservado, loja apoiada no jardim, prancheta e moedas na ajuda; menu sobre o fundo | habitat, shop, habitat_help |
| AuthPage | Composição restaurada: gato sobre a logo, folhas e formulário existentes; sem nova reforma | login |

## Invariantes e verificação

- Direção compartilhada: papel creme, tinta de café, verdes, coral, Fredoka e Nunito. Os estilos de headline e os contornos dos switches/filtros não herdam preto padrão do Material.
- Composição: fitas presas à fotografia/papel, caderno com marcador associado, avatar e objetos apoiados no chão; ramos com caule na margem. Sem os acessórios independentes rejeitados no Perfil.
- Reuso: BotanicalScene/Scaffold/Paper, IllustratedPaperHeading/SectionTitle/GardenStage/StatTile, GamePhotoCard/Mount, FramedUserAvatar e componentes de progresso.
- Fundo sob o menu: IllustratedNavigationScaffold nas cinco abas; o teste navigation_background_test verifica a borda inferior e o espaço seguro de controles. Capturas de Quintal, Loja e Ajuda incluem a navegação.
- Dados reais: as mudanças de composição mantêm stores, respostas e ações existentes. Fixtures de fotografias, conta e progresso permanecem em `test`. O cliente de imagem da galeria só intercepta a URL exclusiva de fixture durante testes; não modifica transporte de produção.
- Galeria: índice e PNGs regenerados juntos pelo teste de captura, com 59 imagens em `build/galeria-visual`. Inclui listas vazias/preenchidas, pistas com três estados, contribuição reconhecida e desafios/missões/medalhas.
- Layout: verificações de telas em 320/820 pontos com texto a 1,5×, além dos testes existentes das áreas principais. As abas roláveis são trazidas para a área visível antes do toque de teste; as miniaturas precisam ter imagem decodificada e área de 62×62, evitando aprovação de molduras vazias.
- Cartazes: a fixture contém busca ativa e encerrada; a verificação exige rótulo correto e apenas uma ação de repost para o caso ativo de outra pessoa.

## Evidência e limites

`build/visual-filled-capture.log` registra a rodada de 19 testes, incluindo a galeria e verificações ampliadas. `build/visual-reform-full-tests.log` registra 122 testes gerais aprovados e três ignorados. A análise final fica em `build/visual-filled-analyze.log`.

Revisão do Impeccable feita inline no fluxo degradado usado nesta sessão. As capturas são de widgets Flutter; o login restaurado, Perfil sem adereços soltos, fotografias, cabeçalhos e listas preenchidas foram inspecionados. A disposição de evidência nativa permanece `recapture`: tiles de mapa, câmera e aparência final em dispositivo não foram validados. Isso é uma limitação da evidência disponível, não uma aprovação pixel a pixel das montagens nem um teste com conta de produção.
