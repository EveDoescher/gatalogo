# Conclusão da rodada arquitetural — 21/10/2026

Branch: `code-quality-cleanup`. A main permanece inalterada nesta rodada.
Este documento substitui os próximos passos históricos da etapa anterior.

## Classificação do mapa

| Pendência | Resultado e fronteira |
|---|---|
| Conversa | ConversationController possui carregamento, comandos, timers, assinaturas, presença, digitação, reconexão e reconciliação otimista. ConversationComposer recebe valores/callbacks. Página mantém navegação e seleção de mídia. |
| Respostas assíncronas e conta | Controlador descarta respostas de conta anterior, encerra assinaturas/timers e bloqueia novos comandos após troca. HTTP e eco WebSocket não duplicam a mensagem; reload conserva envios ainda pendentes. |
| Fotos/localização | Preparação de mídia e envio têm estados separados, permitindo que o envio seja disparado após a preparação. Teste de upload confirma o despacho da mensagem. |
| Detalhes do gato | CatDetailsController concentra comandos e enriquecimento de localização; CatAnalysisCard e CatHistoryPhotos separam análise e histórico, preservando callbacks, estilos e navegação. Nome/cor já compartilhados na etapa anterior. |
| Resgate e datas | Páginas independentes, PrivateCluePhoto e AppDates concluídos na etapa anterior. Formatos distintos por propósito e fuso foram preservados. |
| Habitat | HabitatInteractionState concentra edição, bandejas e gestos; HUD/ferramentas recebem valores e callbacks. HabitatCamera e HabitatSceneSelection separam projeção e seleção. A cena mantém API pública e regras de hit testing. |
| HabitatService | HabitatRepository concentra rede/cache. Serviço mantém reconciliação offline, filas idempotentes, geração por conta e saldo autoritativo. |
| CatDatabase | Fachada pública preservada. Schema/migrações e quatro repositórios separam catálogo, referências, metadados de sync e cache. Abertura concorrente usa uma única operação e permite retry após falha. Versão 17 e dados SQL existentes preservados. |
| CatStore | CatCollection concentra consultas; CatalogSyncCoordinator coordena snapshot/sync/avistamentos; AccountActivityController possui notificações e assinaturas. Aplicação do snapshot verifica o proprietário capturado. |
| Mapas de produção | QuintalSnapshot oferece leituras tipadas, defaults e compatibilidade com payload legado; campos desconhecidos são conservados. Fachada Map existente continua disponível aos consumidores. |
| Configuração de release | Release exige API_BASE_URL explícita e válida; endereço padrão de desenvolvimento não é fallback em release. Helper valida URI antes de compilar, sem assumir URL de produção. Debug conserva o endereço local anterior. |
| CI | Flutter 3.47.1 fixado, resolução pelo lockfile, analyze e suíte padrão. Live é executado separadamente pelo harness da API. |
| Arquivos/reutilização | Widgets existentes com diferenças visuais intencionais, assets dinâmicos, código gerado, plataformas e ferramentas foram preservados. Não houve redesenho nem exclusão especulativa. |

Facadas de compatibilidade e mapas no limite JSON não representam uma extração
incompleta. Foram mantidos para não quebrar consumidores, cache e operações offline.
Não se propõe substituir toda a aplicação por novas camadas.

## Configuração e reprodução

```powershell
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
.\tool\build_release.ps1 -ApiUrl 'https://sua-api.exemplo' -CheckOnly
```

A distribuição deve informar API_BASE_URL explicitamente. O helper aceita apk,
appbundle ou windows, mas nenhum build Android/emulador foi iniciado nesta rodada.
Não há credenciais no valor de configuração. URI com usuário/senha, query,
fragmento ou esquema diferente de HTTP(S) é rejeitada.

## Resultados verificáveis

Suíte completa recuperada: **274 aprovados, 6 condicionais, zero falhas**.
Após tornar obrigatória a configuração de release: **10 testes focados aprovados**
de contratos e controlador. `flutter analyze --no-pub`: **nenhum apontamento**.
Catálogo gerado validado por `python tool/export_habitat_catalog.py --check`.

Os seis condicionais são quatro capturas opcionais, um preview dependente de fonte
e o cliente live. O harness da API fornece contas e serviços descartáveis para
executar esse cliente com SQLite persistente, resposta perdida após commit, replay,
reinício e troca de conta. Sua execução final é registrada no relatório da API.

Smartphone, câmera/permissões físicas, FCM, SMTP e inferência real não são comprovados
pelos testes de widgets e fixtures. Não há promessa de validação em aparelho real.
Logs locais ignorados documentam execuções; fonte, testes e CI não dependem deles.
