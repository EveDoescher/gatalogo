# Plano de eficiência — roteiro Flutter

Escopo vigente em 23/10/2026: [fechamento sequencial e correções](https://github.com/EveDoescher/gatalogo-api/blob/code-quality-cleanup/docs/campaigns/2026-10-23-sequential/README.md). iOS, iPhone e VoiceOver estão fora do escopo por decisão do usuário e não impedem o fechamento Android/API. As definições originais abaixo permanecem como histórico.

Resultados de 25/10/2026: [mídia complementar, lotes de sincronização e quatro mutantes isolados](https://github.com/EveDoescher/gatalogo-api/blob/code-quality-cleanup/docs/campaigns/2026-10-23-sequential/SYNC-IMG03-LAT04-20261025-results.json) e [interrupção de upload com recuperação após reabrir SQLite](https://github.com/EveDoescher/gatalogo-api/blob/code-quality-cleanup/docs/campaigns/2026-10-23-sequential/RES02-20261025-results.json). As correções preservam os dados pendentes e respeitam o limite da API. IMG-03/RES-02 foram concluídos no escopo documentado; LAT-04 ainda exige perfil de parse e confirmação estatística. A matriz compartilhada permanece a única fonte de status; estes testes desktop não certificam rede física, bateria ou interface Android.

Execução posterior ao planejamento aprovado: [relatório da primeira campanha-piloto compartilhada](https://github.com/EveDoescher/gatalogo-api/blob/code-quality-cleanup/docs/campaigns/2026-10-21-pilot/README.md). Inclui comparação SQLite A/B, troca de conta em B, limitações e matriz atual. Os cenários abaixo continuam preservados como plano; a campanha não os declara integralmente concluídos.

Data: 21/10/2026. Branch `code-quality-cleanup`. **Somente documentação para revisão; nenhum teste desta campanha executado nesta etapa.** Sem alteração funcional/visual, instrumentação ou build Android/emulador.

O [plano completo compartilhado na API](https://github.com/EveDoescher/gatalogo-api/blob/code-quality-cleanup/docs/test_plan_efficiency.md) define ambientes, fixtures, métricas, oráculos, cenários por categoria, 28 famílias de mutação e ordem sugerida. O [modelo de resultados](https://github.com/EveDoescher/gatalogo-api/blob/code-quality-cleanup/docs/test_results_template.md) registra cada execução. Na cópia local, os arquivos ficam em `../gatalogo-ai-api/docs/` a partir da raiz deste repositório.

Este roteiro relaciona IDs compartilhados ao código Flutter. Referências a testes são bases para ampliar, não declaração de cobertura integral ou aprovação atual.

Revisão: os cenários e as famílias de mutação anteriores permanecem; ACC-01 a ACC-08 abaixo constituem a definição única de acessibilidade. Comparação BR, reidentificação REID e amostragem ficam no plano compartilhado, sem matrizes duplicadas aqui.

## Comparação oficial/refatorada e dimensionamento

Seguir seções 2.1/2.2 do plano compartilhado: A = API/Flutter `main`, B = API/Flutter `code-quality-cleanup`, quatro SHAs completos e cópias isoladas. Nenhuma alteração em `main`. Mesmo aparelho/hardware/configuração/dados/rede, snapshots restaurados e blocos A/B alternados. Comparação principal do pacote completo; braços com API ou cliente fixo apenas se compatíveis. Contagens otimizadas do cliente B não são requisitos impostos ao cliente A.

Depois da comparação revisada, congelar o par B aceito como baseline das otimizações futuras. Registrar SHA do código separadamente do documento/executor. Números iniciais de repetições abaixo são orçamentos de partida, subordinados ao piloto, variância e precisão definidos em 2.2; não garantem IC ou P99 confiável. Frames consecutivos não são sessões independentes.

## Fluxos a acompanhar

| Fluxo | Pontos a observar | IDs compartilhados |
|---|---|---|
| Câmera/galeria → preflight → cópia/SQLite → sync de metadados → análise → UI → reconhecimento posterior | `pages/capture_page.dart`, `services/cat_preflight_service.dart`, `stores/cat_store.dart`, `analysis_api_service.dart` | LAT-02/03, IMG-01/02/05, DATA-01/02, RES-01/02/03, UX-04 |
| Coleção/cache/dirty/pull/mídia | `catalog_sync_coordinator.dart`, `catalog_sync_service.dart`, `data/cat_database.dart`, `data/repositories/`, `data/sqlite_id_batches.dart` | LAT-01/04, DB-01/07, IMG-02/03, DATA-05, RES-01/03/07/08, RSC-03 |
| Sessão/refresh/troca de conta | `stores/session_store.dart`, `services/authenticated_api_client.dart`, `controllers/account_activity_controller.dart` | LAT-03, RES-03, SEC-01/02/07/09/10 |
| Chat/anexo/eco/recibo/polling | `controllers/conversation_controller.dart`, `services/social_api_service.dart`, `websocket_service.dart` | LAT-05, DATA-08, RES-03/06, SEC-02/03, UX-05 |
| Notificações/paginação/leitura | `stores/notification_store.dart`, `push_notification_service.dart`, `controllers/account_activity_controller.dart` | LAT-07, DATA-08, RES-03/07, DLV-03/04/05/06 |
| Quintal/cache/rascunho/comando/replay/cena | `services/habitat_service.dart`, `data/habitat_repository.dart`, `models/quintal_snapshot.dart`, `game/` | LAT-06, LOAD-03, DATA-03/04/07, RES-02/03, UX-03/07 |
| Feed/busca/pistas/favoritos | `services/social_api_service.dart`, páginas de resgate, `widgets/private_clue_photo.dart` | LAT-07, DATA-09, SEC-02/04, UX-06 |

Caminhos sem prefixo são relativos a `lib/`, salvo quando indicado. O mapa de melhorias já medidas está em [performance_flows.md](performance/performance_flows.md), separado desta campanha futura.

## Variantes e passos locais

### Coleção e sincronização

1. Criar SQLite temporário no schema real, conta A, convidado e conta B. Variar 0/1/40/499/500/501/2.000 gatos, análises ausentes e referências excluídas.
2. Medir `CatalogSyncCoordinator.read`: duração/consultas/bytes lidos e igualdade do snapshot com os métodos anteriores. Contagem usa V IDs visíveis distintos, incluindo convidado, e lotes de 500.
3. Variar 0/1/40/501 dirty, repetir gatilhos concorrentes de sync e contar requests/bytes/handshakes. Repetir após erro para detectar Future bloqueado.
4. Alterar somente metadados depois da análise e rastrear reupload. Não retirar sync pré-análise ou upload apenas por nome/timestamp iguais.
5. Interromper aplicação da página antes/depois de persistir dados/cursor; reabrir o mesmo banco e conferir que nada foi pulado/perdido.
6. Pausar resposta de A, trocar para B/logout, liberar resposta; conferir UI, cache e filas, inclusive localização/avistamento pendente.

Bases: `test/catalog_read_performance_test.dart`, `local_database_test.dart`, `auto_sync_test.dart`, `session_store_test.dart`. SQLite FFI não reproduz custo de armazenamento de um celular.

### Fotos e erros

1. Manifesto fixo com hashes/EXIF/dimensões: selecionar câmera/galeria, observar preflight, cópia privada, metadados e multipart. Captura mantém 1920/qualidade 85; compressão de post segue outro caminho.
2. Comparar bytes em cada fronteira e tempos de seleção/preflight/upload/resultado; não reduzir qualidade/resolução para melhorar o número.
3. Testar 401→refresh→sucesso, 401 persistente, 503, rejeição 400/422, JSON inválido, arquivo ausente, offline e socket perdido após commit.
4. Confirmar mensagens e estado retryable atuais, persistência após reinício e ausência de recompensas duplicadas.
5. Referência: mesmo conteúdo, conteúdo novo, apenas status e exclusão; medir download e conferir mídia disponível offline. Reuso depende de validador de conteúdo, não de timestamp sozinho.

Bases: testes de preflight, produto, sync e cliente autenticado existentes. Backend de inferência substituído só valida mecanismos; LAT/IMG reais exigem E3.

### Chat e inbox

1. Forçar eco WS antes/depois do HTTP; atraso no carregamento de detalhes/mensagens; falha de envio e upload de anexo. Conferir mensagem única, ordem, draft e recibos.
2. Derrubar WS, observar polling existente de 30 s e reconectar. Sair da conversa durante await/timer e conferir limpeza.
3. Inbox com 19/20/21/100 itens, timestamps iguais; refresh e loadMore concorrentes; markRead seguido de resposta antiga e falha de markRead.
4. Entregar mesmo ID via push/WS nas duas ordens. A coalescência já existe: medir requests antes de propor debounce.
5. Pausar callbacks, trocar conta/dispose e liberá-los. Não aplicar estado da conta anterior nem disparar notify depois de dispose.

Bases: `test/conversation_controller_test.dart`, `notification_store_test.dart`, `push_notification_service_test.dart`, `chat_rescue_test.dart`.

### Quintal e retomada

1. Cache vazio/preenchido, rascunho pendente, produção no prazo e presente para recuperar. Medir cada request real, inclusive `/app/habitat`, loja e `/app/quintal`.
2. Não classificar GET sobreposto como inútil sem verificar entrega de presente/reconciliação/calendário e fallback.
3. Enviar comando, perder resposta depois do commit, encerrar cliente, reabrir SQLite e repetir intenção com chave persistida. Conferir um débito/recibo/efeito.
4. Duas sessões: saldo/estoque disputados, fingerprint diferente com mesma chave, layout revision antigo e conta trocada durante operação.
5. Cenas vazia/média/densa, pan/zoom/seleção/efeitos: mesmos modelos, luz, animação, oclusão e hit targets.

Bases: `test/habitat_service_test.dart`, `quintal_production_service_test.dart`, `quintal_live_client_test.dart`, testes de câmera/cena. Live depende de API/PG descartáveis e flags; skip não comprova execução.

## Celular: protocolo separado

- Rodar em profile no mesmo aparelho, OS, display, brilho/rede/condição térmica; registrar SHA e dependências. Build/dispositivo ainda serão preparados posteriormente.
- Cold/warm start, primeiro conteúdo útil, ação→feedback e frame estável: 30 repetições por variante quando viável.
- Coleção/scroll/chat/Quintal com roteiro reproduzível: frame build/raster, percentis, frames fora do orçamento do display, CPU e memória. 60 Hz≈16,7 ms; 120 Hz≈8,3 ms.
- 30 ciclos de navegar/sair e repouso: objetos retidos, imagens/interpreters, timers/listeners/assinaturas. Não concluir vazamento por um pico isolado.
- Energia: sessões pareadas de 15 min, com ferramenta do dispositivo e temperatura/throttling; queda percentual de bateria isolada não sustenta diferença pequena.
- Regressão visual com fonte/locale/tema/resolução/tempo/dados fixos e percurso funcional. Mesmas telas/textos/navegação/ações; screenshot sozinho não valida regras/segurança.

Casos: UX-01 a UX-07, RSC-04/05 e LAT ponta a ponta. Teste desktop não substitui estes resultados.

## ACC — acessibilidade Flutter

**Estado de todos os casos: PLANEJADO.** Categoria própria com IDs globais ACC-01 a ACC-08, referenciada pelo plano da API. Escopo: autenticação, câmera/galeria, coleção/detalhes, resgate/pistas, feed, chat/inbox, configurações e Quintal, inclusive overlays, folhas/modais e erros. Conteúdo desenhado em canvas/Flame também precisa de inspeção de acesso às ações; não presumir que componentes visuais geram semântica utilizável.

### Ferramentas e critérios comuns

- E1: testes Flutter com árvore Semantics e Accessibility Guideline API (contraste textual, rótulo e alvos Android/iOS), variantes de MediaQuery/TextScaler/viewport, capturas e inspeção manual. Verificar APIs compatíveis com SDK fixado antes de implementar o executor. Ferramentas automáticas cobrem apenas parte do comportamento.
- E4: TalkBack em Android e VoiceOver quando houver aparelho iOS disponível; Android Accessibility Scanner e Accessibility Inspector em ambiente Apple disponível. Sem aparelho/plataforma, marcar bloqueado e delimitar cobertura, sem criar emulador nesta etapa nem considerar widget como validação assistiva real.
- Contraste de referência: WCAG 2.2, 1.4.3/1.4.11; texto comum ≥4,5:1, texto grande ≥3:1 segundo definição do critério, controles/estados visuais essenciais ≥3:1, documentando exceções aplicáveis. Medir composição efetiva sobre fundos/overlays; não classificar tamanho de texto Flutter como “grande” por conversão arbitrária de pixels.
- Alvos móveis: verificar guias Flutter Android ≥48×48 unidades lógicas e iOS ≥44×44, incluindo área interativa real, não só ícone. Registrar plataforma/unidade/espaçamento/exceções; não equiparar unidades lógicas a pixels físicos ou limiares CSS WCAG.
- Tarefas precisam ser concluíveis sem visão/gestos precisos, com foco e anúncio compreensíveis. Reportar conformidade por caso/controle, bloqueios e limitações; scanner verde não certifica o app inteiro. Nenhuma adequação será implementada nesta etapa.

| ID / prioridade / ambiente | Preparação e ação | Ferramentas e critérios de avaliação | Registro específico |
|---|---|---|---|
| ACC-01 P1 E1/E4 | Telas/estados suportados, tema(s) existentes, texto sobre imagens e overlays, foco/seleção/erro. | Guideline de contraste + amostragem da cor composta; razões conforme critérios acima, sem informação essencial comunicada só por cor. Exceções justificadas por elemento. | Tela/controle/estado, cores e razão medida, screenshot anotado, critério e resultado; fonte do cálculo/ferramenta versionada. |
| ACC-02 P0 E1/E4 | Escala de fonte 1,0/1,3/2,0 e máximo suportado pelo OS, viewport pequeno, texto longo/teclado. | TextScaler/MediaQuery e configuração real do OS; nenhum texto/ação essencial cortado, sobreposto ou inacessível. Fluxos continuam completos com rolagem quando necessária; registrar escala não linear efetiva. | Escala/OS/viewport, capturas e vídeo do fluxo, overflow/assertions, controles ocultos e tarefa afetada. |
| ACC-03 P1 E1/E4 | Botões de ícone, fechar modal, itens de coleção/chat, ações/seleção do Quintal, proximidade de controles. | Guideline de target Android/iOS e hit testing; área real conforme plataforma, sem sobreposição que acione vizinho; checar alternativa a gesto de precisão. | Bounds/unidade/área clicável, espaçamento, alvo esperado/acionado, exceção e evidência anotada. |
| ACC-04 P0 E4 | TalkBack/VoiceOver: entrar, escolher foto, localizar gato, ouvir análise, enviar mensagem, ler notificação e operar uma ação do Quintal. | Navegação sequencial/exploração, ativação e retorno; ordem lógica, foco no modal/retorno ao invocador, sem armadilha ou botão silencioso, anúncio de erro/progresso sem repetição excessiva. | Plataforma/versão/leitor/configuração, roteiro, gravação com áudio sanitizado, sequência de foco e passos concluídos/bloqueados. |
| ACC-05 P0 E1/E4 | Inspecionar ícones, imagens informativas/decorativas, tabs, contadores, mensagens e ações desenhadas na cena. | Semantics/inspector e leitor: nome acessível compreensível, papel/estado/valor/ação corretos; decorativo sem ruído/duplicação e privado sem anúncio indevido. Ações visuais essenciais disponíveis ao leitor. | Dump sanitizado da árvore com caminho/controle, esperado/observado e trecho de áudio; widget/símbolo no SHA. |
| ACC-06 P1 E1/E4 | Preferência de redução de movimento ativa/inativa, entrada/saída de telas, celebração e cena Quintal. | Observar sinal do OS e MediaQuery (disableAnimations/accessibleNavigation quando aplicável), vídeo/timeline; identificar movimento não essencial que não respeita preferência e caminho equivalente para tarefa, sem perda de feedback. Registrar comportamento atual como achado, sem remover animação. | Flags efetivas/OS, vídeo pareado, duração/tipo de efeito, possibilidade de concluir tarefa e lacuna. Não afirmar que todo OS expõe a mesma preferência. |
| ACC-07 P1 E1/E4 | Viewports lógicos 320×568, 360×800, 412×915 e tablet 800×1280 como amostra de classes; orientação suportada, safe areas e teclado. | Variantes de layout + aparelho: ações alcançáveis, ordem/foco/semântica preservados, sem clipping essencial. Cruzar menor viewport com maior fonte; rotações não suportadas documentadas, não exigidas como nova funcionalidade. | Dimensão física/lógica/DPR/orientação/insets, capturas, fonte, controle inacessível e task result. Classes são cobertura, não amostra estatística de usuários. |
| ACC-08 P0 E1/E4 | Offline, imagem rejeitada, sessão expirada, saldo insuficiente e carregamento durante tarefa assistiva. | Semantics + leitor real; erro/progresso percebidos, ação de recuperação acessível, foco/rascunho preservados e conteúdo compreensível sem depender só de cor/movimento. | Estado/rede, anúncio/foco esperado/observado, tempo/tentativas de conclusão e evidência. Não trocar mensagens para fazer o teste passar. |

### Execução e rastreabilidade ACC

Cobrir todas as telas/classes de controles essenciais e estados listados, com roteiro determinístico; amostragem por cobertura, não por milhares de cliques. Repetir percursos quando houver falha intermitente e registrar agenda/condição. Baseline A/B diferencia defeito preexistente, regressão e resultado bloqueado; mudanças posteriores precisam de aprovação funcional se implicarem adaptação visível/semântica.

Usar modelo compartilhado: cenário/variante → arquivo/widget/símbolo/linha no SHA → teste/node ID ou roteiro assistivo versionado → RUN → captura/árvore/áudio/relatório do scanner com hash → problema → commit de correção futuro → REV. Redigir conteúdo privado de mensagens/contas; evidências de voz e imagem podem permanecer fora do Git com referência controlada. Resultado inclui critério, medição/esperado/observado, ferramenta/versão, plataforma, severidade/impacto e justificativa de exceção. Caso não inspecionado fica não executado, nunca aprovado.

Referências: [Flutter — testes de acessibilidade](https://docs.flutter.dev/ui/accessibility/accessibility-testing) e [W3C — WCAG 2.2](https://www.w3.org/TR/WCAG22/). Critérios são referência técnica; este plano não declara certificação ou conformidade legal do aplicativo nativo.

## Reidentificação: fronteira do cliente

O plano compartilhado define REID-01 a REID-08, dataset, splits e métricas; não duplicar calibração no Flutter. No cliente, verificar apresentação de sugestão/restrição e ação humana explícita, ligados a REID-08/SEC-04/DATA-09. Detecção, máscara e atributos não confirmam indivíduo; não exibir similaridade cosseno como probabilidade calibrada nem promover sugestão a identificação confirmada. Esta etapa apenas registra critérios, sem mudar UI/textos.

## Mutação específica do Flutter

Aplicar um defeito por cópia isolada, após baseline limpo, com diff e evidência da linha exercitada:

| Família | Defeito | Deve falhar por |
|---|---|---|
| MUT-19 | Retirar owner guard depois do await. | RES-03: snapshot A aparece indevidamente após trocar para B. |
| MUT-20 | Pular/sobrepor borda do lote ou não deduplicar IDs. | DB-01: comparação de dados/contagem em 499/500/501 e repetidos. |
| MUT-21 | Cursor/synced salvo antes de aplicação concluída. | DB-07/RES-02: reinício perde alteração. |
| MUT-22 | Retirar generation/disposed ou proteção readIds. | RES-03/DLV-05: resposta velha reaplica estado/desfaz leitura. |
| MUT-23 | Retirar single-flight de refresh/sync. | RES-07: N gatilhos viram N operações. |
| MUT-24 | Retirar reconciliação do eco otimista. | DATA-08: mensagem duplicada em uma das ordens HTTP/WS. |
| MUT-25 | Nova chave ao repetir intenção após reinício. | DATA-03/live: mais de um efeito/débito. |
| MUT-28 | Retirar limite retried nos 401. | LAT-03: refresh/reenvio ilimitados em falha persistente. |

Falha de sintaxe/import/infraestrutura não é morte comportamental útil. Sobrevivente/não coberto/equivalente/inválido/inconclusivo têm classificações distintas no plano completo. Nenhum mutante foi implementado ou executado nesta etapa.

## Revisão e coleta

Revisar IDs/prioridade/fixtures, aparelho e orçamento. Na execução, registrar amostras brutas, n, frio/quente, erros/timeouts, SHAs, parâmetros, diffs de estado e limitações. Sem P99 confiável em piloto pequeno, sem ganho de latência inferido só por menos SQL, sem aprovação implícita de caso ignorado.

A primeira campanha compara main e code-quality-cleanup conforme BR; o par refatorado aceito vira baseline futura. Mudança posterior deve preservar o contrato e repetir os mesmos casos; segurança/integridade reprovam a otimização mesmo que fique mais rápida.

Registro obrigatório no modelo compartilhado: HIP → cenário/variante → código nos SHAs → teste/script/roteiro versionado → RUN/evidências → PROB → FIX/commit futuro → REV e comparação antes/depois. Todos os campos de execução e correção continuam sem resultado nesta revisão documental.


### Continuação da campanha crítica — 21/10/2026

Resultados e matriz cumulativa compartilhados em
[relatório da bateria crítica](../../gatalogo-ai-api/docs/campaigns/2026-10-21-critical/README.md).
Inclui dez testes de HabitatService, auditoria opt-in de AuthPage/QuintalHoldControl,
achados de contraste/alvos/truncamento e histórico de correções do executor.
A auditoria é desktop e não aprova ACC integralmente; TalkBack/VoiceOver continuam
pendentes. O produto não foi alterado. Não somar repetições como casos únicos.


### Continuacao de 22/10/2026

[Resultados e matriz cumulativa](../../gatalogo-ai-api/docs/campaigns/2026-10-22-continuation/README.md).
Preserva todos os cenarios anteriores; cobertura parcial nao significa conclusao.


### Continuação local de 23/10/2026

[Relatório central, matriz e problemas reproduzidos](../../gatalogo-ai-api/docs/campaigns/2026-10-23-local-campaign/README.md).
Preserva relatórios anteriores e os cenários integrais. Inclui contratos Apple e chat vermelhos, comparação cruzada de clientes/APIs, falhas de serviços, SQL, capturas e medições exploratórias. Nenhuma correção de produto ou conclusão de ganho foi aplicada.


### Recuperação, históricos e acessibilidade — 23/10/2026

[Resultados e matriz incremental](../../gatalogo-ai-api/docs/campaigns/2026-10-23-recovery/README.md). Inclui reinício em processos desktop, três janelas de interrupção de upload, históricos maiores, controles de identidade, revisão estática de dependências e auditoria de quatro páginas. Preserve os limites por variante; nenhum problema de produto foi corrigido nesta etapa.

Resultados Android de 25/10/2026: [fontes, teclado, TalkBack, correção do XP e evidências nativas](https://github.com/EveDoescher/gatalogo-api/blob/code-quality-cleanup/docs/campaigns/2026-10-23-sequential/ANDROID-USB-20261025-results.json). A matriz compartilhada distingue os passos executados das variantes pendentes; o roteiro TalkBack original e os passos finais de login, seleção efetiva de foto com cancelamento e envio de mensagem ao usuário de desenvolvimento foram confirmados pelo usuário. ACC-04 foi concluído no Android; variantes de erro de ACC-08 permanecem separadas. A correção do XP preserva as imagens com fonte normal e passou em 21 testes automatizados, além da conferência física com fonte ampliada.


Resultados locais de 27/10/2026, sem aparelho: [LAT-04 — 21 casos, cinco repetições de 501 registros e perfis separados de JSON/SQLite](https://github.com/EveDoescher/gatalogo-api/blob/code-quality-cleanup/docs/campaigns/2026-10-23-sequential/LAT04-20261027-results.json). A matriz única da API mantém a rastreabilidade; estes dados Windows/SQLite FFI não certificam desempenho Android nem demonstram ganho.
