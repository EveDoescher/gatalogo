# Correções de interface e sincronização — 23/09/2026

Escopo: itens de `correcoes.md`, no app Flutter e na API `gatalogo-ai-api`.
Commits locais autorizados pelo usuário após a revisão. Nenhum deploy executado.

## Auditoria por tela

| Tela | Resultado implementado | Verificação |
| --- | --- | --- |
| Login | Apple somente em iOS nativo; botão cresce com o texto sem recortar o rótulo | `auth_page_test.dart`: seis plataformas, larguras 320/390 e escalas de texto 1/1,3/2 |
| Início | Meus Gatos e Avistamentos em destaque; remoção dos atalhos sociais duplicados, mensagens e cards excessivos; XP e sino compartilhados | Testes de layout, `notification_store_test.dart`, `gamification_service_test.dart` e renderização |
| Menu | Cinco destinos, botão de câmera destacado e Habitat ao lado de Coleção com “Em breve” | Navegação real do widget em 320 px e texto ampliado |
| Social | Postar Gato flutuante; compositor reutilizável; publicações com avatar; feed sem posts oficiais artificiais | Feed autenticado, abertura do compositor, verificação da URL do avatar e testes da API para feed vazio/legado |
| Amigos | Título Amigos, pesquisa clara, sem recarga no cabeçalho; abas roláveis | Layout em celular/tablet e inspeção dos estilos da pesquisa |
| Gatalogar | Espaço após cabeçalho; título sem quebra no meio da palavra; câmera e galeria em coluna; ilustração inferior ancorada | Layout e renderização com fontes locais |
| Coleção | Sem modo álbum e sem engrenagem na busca; filtros por pills; decoração sem cobrir o sino | `library_filters_test.dart`, layout e renderização |
| Detalhe do gato | Anotações legíveis; compartilhamento interno; menu só editar nome/excluir | Abertura de modal, verificação das cores, opções do menu e abertura do compositor |
| Meus Gatos | Criar Alerta Rápido com a descrição solicitada | Auditoria do texto e layout |
| Criar alerta | Modo inicial explícito; campos/dropdown claros; endereço, características e contatos opcionais | Troca entre modos, múltiplos telefones/WhatsApp e testes de persistência/validação na API |
| Meu gato | Sem “Toque para ampliar”; “Ver todos os meus alertas de busca” | Auditoria textual e layout |
| Alerta ativo | Foto/status e ações agrupadas; Explorar Avistamentos ocupa a largura disponível | Layout e renderização |
| Cartaz | Endereço, coleira, marcas, microchip e contatos quando informados; comunidade antes de outros apps; sem copiar texto | `missing_poster_test.dart`, teste de ordem das ações e round-trip no PostgreSQL |
| Conquistas | Título simples, resumo e filtros de situação, linhas de progresso com compartilhamento | `gamification_test.dart`, layout e renderização |
| Perfil | Sem banner e card de conta conectada; estatísticas reorganizadas; mesmo componente de nível do início | Layout, renderização e sincronização do estado compartilhado |
| Configurações | Liga/desliga persistente de sincronização automática; sincronização manual continua disponível | `auto_sync_test.dart` e acionamento real do switch |

## Consistência e manutenção

- Notificações usam uma única fonte de estado. Leituras confirmadas não são revertidas por respostas atrasadas; troca de conta invalida requisições antigas.
- Operações de gamificação são ordenadas e o cache é separado por conta. Falhas de rede preservam o XP confirmado; não simulam recompensas.
- Cabeçalhos recebem o mesmo store pelo escopo do aplicativo; páginas com store explícito também usam o componente compartilhado.
- App usa a paleta clara de forma consistente em telas, modais e menus, inclusive quando o sistema está em modo escuro.
- Nunito e Fredoka ficam disponíveis como assets locais, com licenças OFL incluídas.
- Compartilhamento externo cancelado não concede recompensa. Ausência de análise não exibe confiança ou pelagem inventadas.
- Testes de API não enviam push externo. Falhas de entrega após commit não transformam uma operação persistida em erro para o cliente.

## API e migração

Migração `20260922_07_report_poster.py` adiciona o JSON nullable `missing_reports.poster_details`.
Os alertas armazenam endereço, contatos e características; a atualização de área preserva contatos e características.
Registros antigos continuam válidos; não recebem endereço ou telefone inventado. O cartaz tenta resolver o endereço antigo pelas coordenadas quando necessário.
Telefones são opcionais, limitados a cinco, com 8–15 dígitos e opção WhatsApp independente.
A migração foi aplicada somente ao PostgreSQL descartável de testes. Antes de disponibilizar o app, aplicar `alembic upgrade head` no ambiente da API correspondente.

## Evidências e limites

- API: **46 testes passaram** nas suítes de produto, feed, gamificação, social, resgate, cartaz e eventos em tempo real, usando PostgreSQL descartável com migrações.
- Flutter: **82 testes passaram**; dois geradores opcionais de pré-visualização ficam ignorados na execução normal. Inclui contatos opcionais, configurações, modais, feed e sincronização.
- Análise estática: `dart analyze lib test` concluído com **No issues found!**.
- Pré-visualizações: `test/previews/corrections/`, geradas pelo Flutter com fontes e ícones locais; conteúdo de teste explicitamente fictício e fotos ausentes usam placeholder. São evidência de layout, não capturas de dispositivo.
- Sem celular/emulador conectado. Câmera, seletor nativo de galeria, folha de compartilhamento e autenticação Apple real não foram exercitados em dispositivo. A mudança de Apple cobre visibilidade/layout; não implementa um provedor novo de autenticação.
- APK de depuração compilado com sucesso: `build/app/outputs/flutter-apk/app-debug.apk`. O build reporta avisos preexistentes de compatibilidade futura do Firebase/Kotlin e versões do SDK. Não houve distribuição do app nem alteração de dados de produção.

## Reproduzir

App: `flutter test --no-pub` e `dart analyze lib test`.
Pré-visualizações: definir `GATALOGO_PREVIEWS=1` e executar `flutter test --no-pub test/corrections_preview_test.dart --update-goldens`.
API: apontar `DATABASE_URL` e `RECOGNITION_TEST_DATABASE_URL` para um banco descartável chamado `recognition_test`, aplicar migrações e executar:

```text
python -m pytest tests/test_screen_corrections.py tests/test_product.py tests/test_feed_etapa5.py tests/test_gamification_etapa6.py tests/test_social_etapa7.py tests/test_etapa8.py tests/test_chat_rescue.py tests/test_realtime_events.py -q
```
