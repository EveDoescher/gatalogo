# Plano de eficiência — roteiro Flutter

Data: 21/10/2026. Branch `code-quality-cleanup`. **Somente documentação para revisão; nenhum teste desta campanha executado nesta etapa.** Sem alteração funcional/visual, instrumentação ou build Android/emulador.

O [plano completo compartilhado na API](https://github.com/EveDoescher/gatalogo-api/blob/code-quality-cleanup/docs/test_plan_efficiency.md) define ambientes, fixtures, métricas, oráculos, cenários por categoria, 28 famílias de mutação e ordem sugerida. O [modelo de resultados](https://github.com/EveDoescher/gatalogo-api/blob/code-quality-cleanup/docs/test_results_template.md) registra cada execução. Na cópia local, os arquivos ficam em `../gatalogo-ai-api/docs/` a partir da raiz deste repositório.

Este roteiro relaciona IDs compartilhados ao código Flutter. Referências a testes são bases para ampliar, não declaração de cobertura integral ou aprovação atual.

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

Caminhos sem prefixo são relativos a `lib/`, salvo quando indicado. O mapa de melhorias já medidas está em [performance_flows.md](performance_flows.md), separado desta campanha futura.

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

A primeira rodada caracteriza baseline. Mudança posterior deve preservar o contrato e repetir os mesmos casos; segurança/integridade reprovam a otimização mesmo que fique mais rápida.
