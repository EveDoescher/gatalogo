# Refatoração arquitetural — 21/10/2026

Branch: `code-quality-cleanup`.

## Extrações realizadas em ordem de risco

| Unidade | Responsabilidade preservada |
|---|---|
| `AppDates` | Formatação de datas do álbum, captura e chat. Captura mantém o calendário recebido; chat usa o fuso do aparelho. Testes incluem virada de ano, mês e dia local. |
| Páginas de resgate | `missing_cats_page` mantém listagem e exports de compatibilidade. Formulário, detalhes do alerta, lista de pistas e detalhes da pista têm suas próprias bibliotecas, imports e State. |
| `PrivateCluePhoto` | Widget compartilhado pelos dois fluxos de pista; carregamento autenticado e fallback preservados. |
| `CatCoatColorItem` e `CatNameDialog` | Apresentação da cor e edição do nome independentes da página de detalhes, com os mesmos estilos e resultado do diálogo. |
| `ChatMessageBubble` | Conteúdo de texto, resposta citada, mídia, localização, ficha, reações e recibos. Recebe valores/callbacks; não depende do SessionStore, API ou State da conversa. Navegação e comandos continuam com o chamador. |
| `models/habitat.dart` | Valores de item, definição de loja e gato separados do ChangeNotifier. O serviço reexporta esses tipos para preservar consumidores existentes. |
| `HabitatCamera` | Projeção isométrica, transformação inversa, região visível, zoom, pan e limites do mundo independentes da cena Flame e da persistência. HabitatGame mantém sua API pública. |

A separação das páginas usa bibliotecas independentes, sem transformar o arquivo
grande em vários `part` com o mesmo estado privado. Os componentes extraídos são
unidades de composição com dependências explícitas. O catálogo gerado não foi
editado manualmente nem foram removidos assets referenciados dinamicamente.

## Validação

- Análise estática sem apontamentos após as extrações.
- Primeira suíte completa: 264 aprovados, os mesmos 6 condicionais, zero falhas.
- Depois dos componentes/modelos: 34 testes focados aprovados.
- Depois da câmera: 13 testes de projeção, zoom, limites e interação aprovados.
- Suíte completa final, depois de todas essas extrações: **264 aprovados, 6 condicionais e zero falhas**. Detalhes em `quality_review.md`.

## Próximas fronteiras maiores do mapa

- Conversa: controlador de eventos, timers, reconciliação de mensagens otimistas e compositor. A bolha já foi extraída; o ciclo de vida ainda pertence à página.
- Detalhes do gato: comandos e seções de mídia/análise; os dois componentes independentes já foram extraídos.
- Página do habitat: estado explícito das transições de edição, bandejas e gestos; projeção/câmera já saiu da cena.
- HabitatService, CatStore e CatDatabase: separar repositórios e casos de uso sem perder cache por conta, filas locais, replay e troca de sessão. Os valores do habitat já foram separados.
- Mapas dinâmicos de produção e configuração de release continuam no mapa. Endereço padrão de API não foi alterado sem ambiente de destino definido.

Esses itens continuam como dívida arquitetural; testes verdes e redução de tamanho
de arquivos não significam que todos os controladores e repositórios já foram extraídos.
