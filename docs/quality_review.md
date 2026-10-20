# Revisão de qualidade e arquitetura — 20/10/2026

## Escopo

Inventário de todas as fontes Dart/Python versionadas e novas, análise do grafo de imports/exports/parts a partir de `lib/main.dart`, análise estática, inspeção de serviços, stores, widgets e telas centrais, execução de testes unitários, widgets e visuais. Plataformas nativas, assets selecionados dinamicamente e integrações externas não podem ser declarados sem uso apenas por busca textual.

As alterações pendentes foram preservadas em `0ed31b2`, publicado na `main`. A limpeza está em `code-quality-cleanup`, criada dessa base.

## Correções realizadas

| Achado | Correção | Validação |
|---|---|---|
| `ProductApiService` duplicava autenticação, transporte, timeout e retry já disponíveis no cliente compartilhado | Delegação a `AuthenticatedApiClient`, com cliente HTTP injetável e callback para erros específicos | Testes de renovação única, corpo JSON, status, 204, token ausente, erros de rede e respostas inválidas |
| Carregamento remoto e fallback repetidos em avatares | `RemoteAvatarImage` compartilhado por `UserAvatarButton` e `FramedUserAvatar` | Preservados molduras, presets locais, tamanhos e ícones; teste de fallback |
| Detalhes do inventário usavam `Scrollbar` visível sem controlador próprio, dentro de outras áreas roláveis | Controlador dedicado compartilhado com a lista e descartado no `dispose` | Teste de inventário confirma controlador anexado a uma posição e navegação sem gastar recursos |
| Teste de inventário fixava altura de 258 mesmo com texto ampliado | Critérios de área disponível na cena e limite de altura para acessibilidade | Cenários de 320/390 pixels, escala 1,5 e detalhes de recursos |

## Mapa de arquitetura e reutilização pendente

| Prioridade | Local | Evidência / problema | Próxima mudança segura |
|---|---|---|---|
| Alta | `lib/pages/conversation_page.dart` | Mais de 3.000 linhas, timers de digitação, eventos e apresentação na mesma classe | Extrair controlador de conversa e widgets de mensagem/compositor com testes de cancelamento e reconexão |
| Alta | `lib/pages/missing_cats_page.dart` | Mais de 2.600 linhas | Separar listagem, filtros, formulário e fluxo de relato sem mudar navegação |
| Alta | `lib/pages/cat_details_page.dart` | Mais de 2.000 linhas com detalhes, mídia e ações | Extrair seções de apresentação e comandos do registro |
| Alta | `lib/game/habitat_game.dart` | Mais de 2.000 linhas de cena, interação e câmera | Separar seleção e projeção de coordenadas com regressão de hit testing |
| Alta | `lib/pages/habitat_page.dart` | Aproximadamente 1.850 linhas, estado de edição, bandejas e gestos | Introduzir estado explícito da interação e extrair overlays por responsabilidade |
| Média | `lib/services/habitat_service.dart` e seus `part` | Persistência, rede, domínio, catálogo e estado observável compartilham a mesma biblioteca | Extrair modelos tipados e repositório; manter reconciliação offline e saldo autoritativo do servidor |
| Média | `lib/stores/cat_store.dart`, `lib/data/cat_database.dart` | Stores e persistência grandes | Separar consultas de coleção, sincronização e notificações; manter migrações SQLite |
| Média | `lib/widgets/gatalogo_components.dart`, `app_widgets.dart`, `illustrated_home_components.dart` | Famílias distintas de avatar, cartão e progresso | Reutilizar comportamentos antes de unificar aparência; variantes têm diferenças visuais intencionais |
| Média | `lib/pages/conversation_page.dart`, `library_page.dart`, `cat_details_page.dart` | Vários formatadores locais de data/hora | Criar formatadores por propósito e locale; formatos diferentes não são duplicação automática |
| Média | Serviços e páginas com `Map<String, dynamic>` | Contratos de rede e produção frequentemente interpretados na UI | Introduzir modelos por resposta, com teste de payload ausente/legado |
| Média | `lib/config/api_config.dart` | URL padrão aponta para IP local, sobreponível por `--dart-define` | Validar configuração de builds de release sem mudar o ambiente local silenciosamente |
| Média | Testes visuais | Expectativas de texto/altura/hit testing ficaram desatualizadas ou revelam problemas reais | Separar teste de contrato de captura visual e aguardar estado pronto de forma determinística |

## Arquivos sem uso, gerados e referências dinâmicas

- O grafo estático não identificou arquivos em `lib/` desconectados de `lib/main.dart`. Isso não prova que cada classe/método público seja usado; evita excluir módulos ativos por engano.
- `habitat_catalog.g.dart` é incluído por `part`, e outros arquivos de regras também; não são órfãos por ausência de `import` tradicional.
- Assets de sprites, animações e catálogos usam nomes compostos dinamicamente. Não foram excluídos por falta de uma string literal.
- `tool/`, fixtures e testes visuais são ferramentas de validação, não código descartável.
- `.agents/skills/` contém ferramentas externas ao aplicativo. Aparece no inventário completo, mas não foi alterado.
- Plataformas Android/iOS, ícones e configurações de empacotamento permanecem necessários mesmo fora do grafo Dart.
- Caches, builds e logs ignorados foram preservados; não constituem limpeza de código versionado.

## Validação e limitações

A execução inicial teve **241 aprovados, 6 ignorados e 8 falhas**. Os 21 testes direcionados após a limpeza passaram, incluindo o teste de inventário antes falho. Resultados da comparação final são registrados abaixo.

Falhas observadas na base: menu do habitat não encontrou `Editar` (prontidão da cena é uma hipótese a validar); navegação procurava texto `Quintal`; horta/cozinha tinham expectativas de hit testing; inventário fixava altura antiga; recibo de recompensa permanecia pendente; teste amplo de produção expunha erro de controlador de scroll. Não foram relaxadas as regras de estoque, recompensas ou autorização para fazer os testes passarem.

O inventário completo está em `quality_inventory.md`. Os itens arquiteturais acima são pendências mapeadas, não refatorações declaradas concluídas.

## Resultado final

- `flutter analyze --no-pub`: **nenhum problema encontrado**.
- Testes direcionados: **21 aprovados**.
- `flutter test --no-pub --reporter expanded`: **255 aprovados, 6 ignorados, 6 falhas**.
- Comparação dos nomes das falhas: **nenhuma falha nova em relação à execução inicial**.
- Passaram após a correção: detalhes do inventário e cenário visual amplo de ações/estoque no Quintal.

Permanecem falhando, também na base anterior:

| Teste | Sintoma observado |
|---|---|
| `test/habitat_page_test.dart` | A busca por `Editar` no menu não encontra o widget |
| `test/home_reference_test.dart` | A busca por texto `Quintal` não encontra candidato com escala 1,5 |
| `test/quintal_garden_visual_test.dart` | Hit testing retorna `plot` onde se esperava `build` |
| `test/quintal_kitchen_visual_test.dart` | Hit testing retorna null onde se esperava `kitchen` |
| `test/quintal_rewards_visual_test.dart` | Recibo de recompensa permanece pendente |
| `test/screen_corrections_test.dart` | Busca por texto de navegação sem candidato; exceções de construção no cenário |

Essas falhas e as extrações arquiteturais maiores permanecem como dívida explícita. A suíte completa não está verde. Não foram executados builds nativos nem validação em aparelho real.
