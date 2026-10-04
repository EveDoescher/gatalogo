# Gatálogo — comparação do plano com o código

Data: 27/09/2026. Referência: `plano_reestruturacao_gatalogo_final.md`.

## Escopo e conclusão

Inspeção estática dos repositórios `catlogue` (Flutter) e `gatalogo-ai-api` (FastAPI), incluindo alterações locais ainda não commitadas. Esta revisão não executou o aplicativo, migrações ou testes; existência de implementação ou teste não significa aceite validado em execução. Nenhum comportamento do produto foi alterado nesta comparação.

A base de navegação, persistência local, sincronização, proteção, comunidade e Habitat pode ser reaproveitada. O plano exige uma mudança estrutural na progressão: hoje XP, moedas e conquistas usam gatilhos e cálculos separados. A nova experiência de Resultado depende primeiro de eventos confirmados, elegibilidade e um contrato único da API.

O Habitat já tem carteira, transações com chave única, proteção por hash de foto, limites diários, compras idempotentes e validação de layout. Isso é uma fundação aproveitável, mas ainda não é o ledger unificado de XP, moedas, desafios e desbloqueios exigido pelo plano.

## Comparação por área

| Área | Estado encontrado | Trabalho necessário |
|---|---|---|
| Navegação | As cinco abas já existem em `lib/app.dart`: Início, Social, Gatalogar, Coleção e Habitat. | Preservar a estrutura e conectar os novos percursos. |
| Home | Saudação, atalhos, buscas próximas, gamificação e progresso por contagem local. | Priorizar Gatalogar e missão; mostrar uma meta real do álbum e uma do Habitat a partir do progresso confirmado. Corrigir o texto de Avistamentos. |
| Captura e persistência | Câmera/galeria, revisão, validação local e cópia persistente antes do envio. Análise e sincronização em segundo plano. | Separar estado de salvamento, envio, análise e elegibilidade. Conectar decisão sobre indivíduo conhecido e crédito pendente. |
| Resultado | Após salvar, Captura abre diretamente `CatDetailsPage`. | Criar tela própria, resumo persistido por evento, consulta posterior, histórico, notificação e ações para desafio/Habitat. |
| Identificação do indivíduo | Há reconhecimento para buscas, fotos de referência e troca de foto principal. | Não foi localizado o percurso de captura que sugere um gato do catálogo, permite escolher existente/novo e corrigir o vínculo depois. Modelar indivíduo separado de registro fotográfico. |
| Coleção | Descobertas separadas de gatos próprios, busca, favoritos e filtros avançados. | Acrescentar Gatos/Desafios, condições e prêmios confirmados; remover classificação do valor do gato por pelagem. |
| Missões e conquistas | XP, níveis, missões e mural já implementados; parte do progresso usa contagens locais ou consultas agregadas. | Uma diária e duas semanais, fuso da pessoa, eventos confirmados, histórico e aposentadoria de objetivos incompatíveis. |
| Meus Gatos | Cadastro próprio, identificação, fotos de proteção e entrada para desaparecimento; Habitat aceita seleção de gatos próprios. | Preservar ferramentas e retirar concessões de descoberta dos cadastros próprios e alertas rápidos. Distinguir fotos complementares e seus créditos. |
| Buscas e pistas | Alertas, cartazes, mapas, correspondências, confirmação/descarte/reabertura e conversas existem. | Crédito alto apenas na confirmação; acesso do colaborador ao destino da notificação; estados apresentados de forma consistente. |
| Meus Avistamentos | Mapa pessoal já existe. | Home anuncia registros de outras pessoas; corrigir promessa e distinguir registro pessoal de contribuição para busca. |
| Social | Feed com comunidade/amigos, publicação, curtida, comentário, conversas e compartilhamento. | Filtro por tipo, repost interno vinculado a cartaz ativo, audiência e novas regras de recompensa/limites. |
| Perfil e privacidade | Perfil público e galeria controlada por `public_gallery`, com padrão `True` na API. | Audiências independentes para galeria/medalhas/Habitat, padrão amigos, migração e prévia real da audiência. |
| Notificações | Caixa, leitura, push e navegação por tipo. | Seções prioritárias, agrupamento, Resultado assíncrono e destino correto de pista confirmada. |
| Tema e componentes | Tokens de cor, tipografia, espaçamento, raio, duração e componentes compartilhados já existem. | Evoluir o sistema existente para o caderno vivo; criar componentes de resultado, desafio e créditos. Atualizar a regra de cartões planos em `DESIGN.md`. |
| Som e acessibilidade | Habitat consulta redução de animações do sistema. | Não foi encontrado serviço global de áudio ou controles independentes de música/efeitos/vibração/movimento. Implementar foco, ciclo de vida, persistência e validar acessibilidade. |
| Migração e liberação | Migrações e regras do Habitat existentes. | Não foram localizados migração de saldo inicial do novo ledger, versões da nova economia, flags de concessão ou contrato de Resultado. |

## Divergências prioritárias com evidência

Os caminhos abaixo são relativos ao repositório indicado. As linhas correspondem ao estado observado nesta revisão.

### 1. XP ainda não comprova a ação que remunera

- App: `lib/stores/cat_store.dart:284` solicita `photo` imediatamente após persistir a foto, antes da conclusão da análise. O mesmo método atende gatos próprios. Troca da foto principal e foto de referência também solicitam `photo` (`:705`, `:741`).
- API: `app/routers/product.py:529` recebe `action` e `context_id`, mas o processamento de `record_gamification_action` não usa `context_id` para validar ou deduplicar o evento. Em `:573`, até uma ação não reconhecida recebe o valor padrão de 10 XP.
- O cliente já evita inventar XP quando a requisição falha: `lib/services/gamification_service.dart:74`. Essa proteção deve ser preservada; o problema central é o servidor conceder com base em uma declaração genérica do cliente.

**Consequência:** requisições repetidas podem aumentar XP; foto pendente, cadastro próprio e complemento compartilham o gatilho de descoberta. Um crédito perdido por falha não tem ainda o Resultado consultável por ID exigido no plano.

### 2. Moedas têm proteção contra repetição, mas elegibilidade inadequada

- API: `app/persistence_models.py:60` define `HabitatTransaction` com unicidade por pessoa/evento.
- `app/services/habitat_service.py:141` implementa concessão idempotente, deduplicação de descoberta por hash e limites diários.
- Porém `app/routers/sync.py:206` concede `catalog` no upload da foto, sem exigir a nova confirmação de indivíduo/atributos.
- `app/routers/habitat.py:108` concede retroativamente `catalog` para registros com foto ao consultar o Habitat, sem separar gatos próprios de descobertas nessa seleção.

**Consequência:** não basta adicionar um novo ledger. É necessário substituir ou adaptar esses caminhos, registrar o saldo inicial sem pagar de novo e preservar compras, itens, layout e histórico de transações.

### 3. Proteção ainda dispara ganhos no momento errado

- App: `lib/pages/missing_cats_page.dart:59` dispara `care` de XP e moedas ao abrir a tela.
- `lib/stores/cat_store.dart:644` solicita XP ao enfileirar um avistamento.
- API: `app/routers/vision.py:151` concede moedas ao registrar o avistamento.
- A confirmação em `app/routers/vision.py:183` altera o estado e notifica o colaborador, mas não concede o prêmio específico de 100 XP/50 moedas.
- Alerta rápido usa `addFromTempPhoto(isOwned: true)` em `lib/pages/missing_cats_page.dart:330`, alcançando o mesmo gatilho genérico de XP.

**Implementação necessária:** ligar o prêmio à confirmação autorizada do tutor, com chave estável por contribuição/caso, bloqueio de auto-recompensa e repetição, preservando a operação dos fluxos de proteção.

### 4. A fila offline existe, mas a identidade do evento não atravessa todo o contrato

- `lib/data/cat_database.dart:370` persiste avistamentos com chave local gerada por UUID.
- `lib/stores/cat_store.dart:659` envia gato, coordenadas, nota e data; a chave da fila não segue para a API.
- `app/routers/vision.py:138` tenta deduplicar por gato/pessoa/coordenadas/data, não pela identidade estável do evento.
- `lib/models/cat_analysis.dart:3` possui `pending`, `analyzing`, `completed`, `failed`; são estados da análise, não do crédito.

**Implementação necessária:** transportar a chave offline e separar análise, sincronização e resultado da progressão. Uma revisão de atributos não pode conceder novamente a base já paga.

### 5. Missões e conquistas ainda representam a economia anterior

- API: `app/routers/product.py:395` aplica multiplicador por sequência de até 1,5.
- `:431` oferece três missões diárias, uma semanal e um bônus de compartilhamento. Os períodos usam UTC.
- A missão semanal de três dias avança a cada ação em `:601`; não verifica três datas distintas.
- `:377` anuncia bônus de XP e prioridade em alertas como recompensas de nível.
- `:652` recalcula e concede conquistas durante a consulta do mural; atributos são inferidos de texto/nome, e progresso social é aproximado a partir de XP total (`:719`).
- Objetivos noturnos e de locais diferentes continuam na API e em `lib/pages/journey_page.dart`.

**Implementação necessária:** progresso derivado do evento elegível, definição versionada dos objetivos e preservação de conquistas antigas. Conservar níveis já alcançados e substituir apenas ofertas futuras incompatíveis.

### 6. Comunidade e perfil precisam de novos contratos

- API: `app/routers/social.py:704`, `:739`, `:783` concedem moedas por publicação, curtida e comentário. O comentário no próprio post já é excluído do crédito de moedas; o XP genérico continua separado.
- `app/services/habitat_service.py:124` contém valores e limites diferentes do plano. Curtidas e compartilhamento externo ainda participam dos fluxos de premiação.
- `app/routers/habitat.py:245` aceita ação de compartilhamento; isso não comprova um repost interno de cartaz alheio ativo.
- `app/routers/social.py:307` usa `public_gallery=True` por padrão e não exige amizade nesse trecho para listar os registros. Isso evidencia exposição de metadados; a autorização dos arquivos de mídia também deve ser revisada individualmente.
- `app/routers/product.py:116` define preferências apenas de notificações, e sua atualização substitui o mapa de preferências. Ao acrescentar audiências, preservar os demais campos, inclusive o estado legado de gamificação e a bio.

**Implementação necessária:** repost como publicação vinculada ao alerta, verificação de audiência nos endpoints e mídias, limites sociais por evento e migração da vitrine sem modificar a audiência de publicações voluntárias existentes.

### 7. Resultado e navegação ainda não fecham o ciclo do plano

- `lib/pages/capture_page.dart:219` salva localmente; `:249` abre a ficha, sem tela de Resultado.
- `lib/pages/home_page.dart:55` calcula o próximo marco por contagem de descobertas locais, sem contrato de meta/prêmio confirmado.
- `lib/pages/home_page.dart:135` anuncia “você e outros”, embora abra o mapa pessoal.
- `lib/pages/notifications_page.dart:110` encaminha tanto conquista quanto `match_confirmed` para `JourneyPage`.
- A notificação da pista fornece apenas `match_id`; os endpoints de pistas consultados são destinados ao tutor. Corrigir o destino exige também disponibilizar contexto autorizado para o colaborador, não somente trocar a página Flutter.

## Sequência de implementação proposta

1. **Concluir a etapa de inventário e protótipo.** Esta comparação cobre o inventário inicial. Ainda faltam os dois protótipos navegáveis e a validação com pessoas prevista no plano. Especificar a relação indivíduo/foto/evento e o contrato de Resultado antes da nova economia.
2. **Fundação na API.** Introduzir eventos, ledger de concessões/correções, regras versionadas, consulta de Resultado e migração de abertura. Reaproveitar a carteira e a proteção transacional do Habitat; definir uma única operação lógica para XP/moedas/progresso. Desativar os gatilhos legados de forma coordenada, incluindo clientes antigos.
3. **Persistência e consumo no Flutter.** Persistir identidade de evento e resultado localmente, transmitir chaves da fila e atualizar as telas com o estado confirmado. Remover pedidos genéricos de prêmio sem perder registro, retry ou sincronização de convidado.
4. **Ciclo principal.** Evoluir tokens/componentes existentes; implementar Home → Captura → Resultado → Coleção/Desafios → Habitat, com estados offline, revisão, repetição e erro. Manter as estruturas de Habitat/Loja.
5. **Proteção e notificações.** Integrar confirmação, recompensa e destino autorizado; unificar estados do caso e das pistas; corrigir mapa pessoal e atalhos.
6. **Comunidade e privacidade.** Implementar repost vinculado, pequenas concessões sociais, controles independentes e migração para amigos. A restrição de audiência deve existir na API antes de anunciar os controles na interface.
7. **Som, movimento e validação final.** Áudio opt-in, efeitos e preferências independentes, foco/silêncio, redução de movimento, telefone pequeno e texto ampliado. Teste fechado e ativação gradual das regras.

## Verificação exigida para cada entrega

| Critério | Cobertura atual observada | Verificação a acrescentar/adaptar |
|---|---|---|
| Registro offline e conta | Testes de banco local, isolamento de conta e sincronização no Flutter. | Salvar, fechar/reabrir, sincronizar e receber exatamente uma concessão; convidado vinculado sem bônus retroativo indevido. |
| Repetição e concorrência | Habitat testa crédito por gato/hash, replay, limites e compras atômicas. | Repetição concorrente do evento envolvendo XP, moeda, missão e itens; exclusão/recriação e revisão de atributo. |
| Crédito confirmado | Flutter testa que erro de rede não inventa XP e que resposta antiga não atravessa contas. | Resultado pendente/confirmado/revisão/inelegível; falha ou resposta perdida seguida de consulta por ID. |
| Gato próprio e proteção | Cadastros e alertas têm implementações e testes existentes. | Cadastro próprio, alerta rápido, abrir Desaparecidos e envio de pista sem ganho de descoberta/proteção. |
| Confirmação de pista | Decisão do tutor e notificações já implementadas. | 100 XP/50 moedas uma vez; auto-confirmação sem crédito; caso encerrado; colaborador abre contexto permitido. |
| Social | Testes de feed e interações existentes. | Curtida/compartilhamento externo sem prêmio; repost próprio/encerrado sem prêmio; limites e spam. |
| Migração e privacidade | Não foi localizada cobertura do contrato novo. | Manter saldo/XP/nível/itens/conquistas, sem reprocessar prêmio; galeria antiga limitada a amigos e posts preservados. |
| Missões seguras | Testes atuais afirmam multiplicador e três diárias. | Substituir expectativas legadas; uma diária/duas semanais; datas distintas e virada de período no fuso correto. |

Arquivos de teste de referência: API `tests/test_habitat.py`, `tests/test_gamification.py`, `tests/test_product.py`, `tests/test_screen_corrections.py`; app `test/gamification_service_test.dart`, `test/local_database_test.dart`, `test/auto_sync_test.dart`, `test/product_flows_test.dart`, `test/notification_store_test.dart` e testes do Habitat.

## Cuidados com o estado atual do trabalho

Ambos os repositórios têm alterações locais, principalmente do Habitat, seus recursos, serviços e testes. A implementação deve partir desse estado atual e preservar esse trabalho. Esta revisão acrescenta somente este documento; não altera o plano original nem os arquivos de implementação.

Não atribuir percentual de conclusão ao plano com base apenas em telas existentes: a persistência do registro está bastante adiantada, mas os critérios integrados dependem da nova fundação de progressão e de validação em execução.
