# Mapa de pendências dos novos fluxos do Quintal

Atualizado em **18/10/2026**. Este arquivo é a fonte do **estado atual**; o [registro de execução](registro_execucao_fluxos_quintal_2026-10.md) guarda o histórico e as evidências detalhadas. Afirmações antigas do registro não substituem o estado abaixo.

## Resumo e próxima etapa

| Estado | Quantidade | Itens |
|---|---:|---|
| Feito localmente | 26 | F01, F02, F03, F04, F05, F07, F08, F09, V01, V02, V03, V04, V05, V06, V07, V08, V10, U01, U02, U03, U04, U06, U07, U08, U09, U10 |
| Parcial | 4 | F06, V09, V11, U05 |
| Pendente | 0 | — |

**Prioridade atual, conforme solicitação da usuária:** dos 17 parciais originais, **14 estão feitos localmente** (F05, F09, V01–V06, U01–U04, U09 e U10). Restam **V09, V11 e U05**, com validações em aparelho/integração discriminadas abaixo; não foram marcados como completos usando fixtures. U03/U04 foram encerrados localmente em 16/10. Com os gates de aparelho ainda abertos, **V10 e F07 foram encerrados localmente em 16/10**; **F04 foi encerrado localmente em 17/10**, com receitas e troca de frutas. **F08 encerrado localmente em 17/10**, com rotinas opcionais por desbloqueio. Com banco/API disponibilizados em 17/10, **F06** já tem nove testes HTTP, quatro PostgreSQL e cliente Flutter com perda de resposta/reinício aprovados; V07/V08 encerrados localmente em 18/10. Cliente conectado com perda de resposta/reinício e matriz local completa de câmera aprovados. Os quatro parciais conservam apenas as verificações físicas/app instalado explicitadas abaixo.

- **Feito localmente:** implementação entregue; testes/capturas especificados em cada item e no registro. Não equivale a validação conectada. U07 tem implementação local, sem teste específico registrado.
- **Parcial:** existe entrega, mas faltam partes do aceite ou verificações necessárias, discriminadas em “Falta”.
- **Pendente:** a entrega solicitada ainda falta. Código anterior ou uma decisão de produto não bastam para concluir o item.
- **F06 retomado em 17/10:** a usuária ligou o banco e a API com hot reload e autorizou seu uso. API autenticada e testes PostgreSQL passaram; detalhes em F06. Em 18/10, a usuária orientou continuar no computador. Validações em aparelho continuam abertas, sem iniciar outra infraestrutura.
- **F04 entregue:** maçãs e peras entram em duas receitas e na troca por frango. Preços base e configuração de gratuidade preservados; valores detalhados abaixo.
- **Ajustes solicitados já entregues:** plantas maiores em relação ao canteiro e enquadramento automático da câmera ao selecionar ações cortadas, sem botão de enquadramento.

P1 = corrigir ou fechar antes de considerar os fluxos prontos. P2 = completar a experiência e a leitura de jogo. “Validação” não significa defeito comprovado. A meta completa permanece aberta.

## Feito localmente

### F01 · Vínculo após carinho

**Prioridade / área:** P1 · integração.

**Feito:** Em 18/10, API/PostgreSQL reais confirmaram carinho simultâneo por duas sessões, resposta/projeção 12→13 e 19→20, reconexão e replay sem regressão ou ponto extra. Projeção atual aplicada e persistida na mesma resposta; testes HTTP e cliente de replay, resposta atrasada e reinício aprovados.

**Falta:** Nenhuma implementação local pendente identificada neste item. Validação conectada permanece em F06.

**Critério de aceite integral:** Usar uma projeção coerente após qualquer cuidado. A ficha, a barra e os próximos marcos devem refletir o ponto na mesma resposta, sem aguardar o refresh periódico. Testar carinho → fechar ficha → reabrir → reiniciar app.

### F02 · Calendário dos eventos

**Prioridade / área:** P1 · progressão temporal.

**Feito:** Diário transacional usa a ocorrência de refeições/preparos e a confirmação das ações. Legado sem data não inventa crédito diário/semanal; regressões de domingo/segunda aprovadas.

**Falta:** Nenhuma implementação local pendente. Matriz PostgreSQL de concorrência e domingo/segunda aprovada em F06; testes em aparelho permanecem nesse item.

**Critério de aceite integral:** Definir e implementar a data correta para conclusão, consumo e coleta; separar ações de quantidades. Testar passagem de meia-noite e domingo/segunda. Não atribuir silenciosamente vários dias de refeições ao dia de retorno.

### F03 · Recompensas e próximos marcos de vínculo

**Prioridade / área:** P1 · integração/experiência.

**Feito:** Em 18/10, prêmio de vínculo 20 verificado na API/PostgreSQL reais: item único, recibo persistido após reconexão e reconhecimento sem reapresentar no replay. Recibos persistidos por conta, fila de celebrações sem crédito duplicado, reconhecimento individual, retry e abertura da bandeja. Ficha mostra prêmios reais de 20/50/100/200. Testes API/cliente e 14 capturas locais aprovados.

**Falta:** Validação conectada em F06. A quebra dos rótulos da navegação em 320 px foi corrigida em U03.

**Critério de aceite integral:** Mostrar o que a ação acabou de concluir: missão, medalha, XP, moedas ou item. Exibir próximo marco de vínculo entre 20/50/100/200, seu prêmio real e destino no inventário. Não reapresentar a mesma celebração a cada refresh.

### F04 · Destino de maçãs e peras

**Prioridade / área:** P1 · catálogo/balanceamento.

**Feito:** Após F07, catálogo v2 oferece Mistura com maçã e Mistura com pera: 1 trigo + 2 frutas, 20 minutos, 3 porções e satisfação 16. Troca alternativa: 3 maçãs + 3 peras por 2 frangos em 1 hora, liberada pelo pomar. Pagamentos anteriores por produtos/moedas preservados. Projeto do pomar explica os usos antes de construir; inventário abre receita/troca. Reservas, cancelamento, coleta, servir e replay verificados; 48 testes API aprovados, ações e matriz visual aprovadas, última regressão de inventário/cenas com quatro testes aprovados e galeria completa atualizada.

**Falta:** Nenhuma implementação local pendente identificada. Validação conectada e em aparelho permanece em F06/V11. Capturas usam fixtures; a simulação F07 permanece como retrato anterior à inclusão das frutas.

**Critério de aceite integral:** Uso definido pela usuária em 13/10: receitas e trocas no Mercadinho. Simular F07 e então ajustar catálogo, descrição e balanceamento. O jogador deve conseguir responder “para que colho isso?” antes de construir o pomar.

### F05 · Construções, ampliações e capacidade

**Prioridade / área:** P1 · coerência dos estados.

**Feito:** Prévia de perímetro/capacidade, área em preparo e enquadramento automático implementados. Origens e produtos preservados nas capacidades 4/8/12 canteiros, 2/4 galinhas, 1/2 vacas e cozinha 1/2. Ampliações verificadas nos testes da API; continuidade da horta em 96 quadros e prato pronto da cozinha durante obra capturados. Prévia não libera alvos nem altera estoque antes da confirmação.

**Falta:** Nenhuma implementação local pendente identificada nesta revisão. Verificação integrada em aparelho, com API conectada, continua obrigatória em F06/V11; vídeos e capturas locais usam fixtures.

**Critério de aceite integral:** Antecipar perímetro/capacidade, mostrar a área em obra e preservar a posição da construção entre estados. Confirmar 4/8/12 canteiros, 2/4 galinhas, 1/2 vacas e cozinha 1/2. Manter produtos prontos visíveis durante ampliação.

### F07 · Simulação da economia e dos cuidados

**Prioridade / área:** P1 · balanceamento.

**Feito:** [Simulação reproduzível concluída](simulacao_economia_quintal_2026-10-16.md): 3/6 gatos × 1/2 visitas, sempre com 4 galinhas e 2 vacas, nas dietas Horta e Ovo. Mede comandos/toques estimados, estoque mínimo/inicial/final, consumo, espera por coleta, falta de insumo e ociosidade. Orçamento das sete receitas e amostra de 10 mil preferências incluídos. Quatorze testes aprovados, com comparação do modelo de residentes ao reconciliador real. Preços base e flags preservados; propostas numéricas de frutas/troca discriminadas, sem aplicá-las nesta etapa.

**Falta:** Nenhuma implementação local pendente neste item. A capacidade modelada pressupõe espaços ampliados e refeições aceitas; recusa foi analisada separadamente. Contagem de toques é estimativa de fluxo, não telemetria. Teste conectado/aparelho permanece nos gates já abertos. Novos usos das frutas aplicados e verificados em F04 (17/10); este relatório de simulação preserva o catálogo anterior.

**Critério de aceite integral:** Simular 3 e 6 gatos, 1–2 visitas diárias, 4 galinhas e 2 vacas. Medir quantidade de cliques, trigo/milho disponíveis, consumo das receitas, horas de produção parada e tempo até favoritas. Preservar preços base e configuração de gratuidade; alterações numéricas devem ser explícitas.

### F08 · Missões recorrentes contextuais

**Prioridade / área:** P2 · progressão.

**Feito:** Uma atividade à escolha por dia e dois dias não consecutivos por semana. Alternativas somente dos espaços desbloqueados no servidor (carinho, horta, cozinha, galinheiro, vacas ou pesca), sem exigir todos os sistemas nem outra visita no mesmo dia. Descobertas continuam primeiro. Recompensas limitadas a 10 XP/5 moedas na diária e 30 XP/15 moedas na semanal, sem pontos de ranking; preços e XP base preservados. IDs de integração com tutorial mantidos. Testes de calendário, desbloqueio, expansão, replay, persistência e recompensas pausadas aprovados; interface e galeria verificadas em 320/390 px com texto 1,5.

**Falta:** Nenhuma implementação local pendente identificada. Validação conectada/em aparelho continua em F06/V11; capturas usam fixtures. A rotina é opcional e não penaliza dias pulados.

**Critério de aceite integral:** Criar objetivos opcionais compatíveis com desbloqueios e tempo disponível, preservando descobrir gatos como atividade principal. Não obrigar a usar todos os sistemas em cada login. Manter os pontos de integração para o tutorial futuro.

### F09 · Notificações e resumo de retorno

**Prioridade / área:** P2 · notificações/retorno.

**Feito:** Agendamento sem app aberto, outbox persistente, retry/deduplicação e preferências implementados. Avisos de residentes agora verificam o ciclo exato, descartando aviso antigo mesmo que nova produção esteja pronta. Resumo informa produtos/quantidades/atalhos e reconhece somente eventos apresentados, sem coletar. No cliente, recebimento duplicado e corrida entre abertura inicial/toque não repetem o aviso; listeners são descartados corretamente. Dez testes API e nove testes de push/caixa de entrada aprovados localmente.

**Falta:** Nenhuma implementação local pendente identificada nesta revisão. Entrega real FCM, permissões e navegação em aparelho continuam em U05; concorrência PostgreSQL em F06. Testes locais usam transporte simulado.

**Critério de aceite integral:** Se a intenção for avisar com o app fechado, implementar um processamento agendado com deduplicação. Melhorar o resumo com nomes, produtos, quantidades e atalhos por espaço. Reconhecer apenas os eventos efetivamente apresentados, sem coletar automaticamente.

### U01 · Minigame de pesca

**Prioridade / área:** P1.

**Feito:** Cena integrada com espera/mordida/disputa/resultado/prática; controle de segurar/soltar, multitoque, teclado e slider, tempo independente da taxa de quadros. Pausa e resposta inicial tardia exigem nova rodada, sem prêmio. Corrigido retry sem saída após rejeição 422: 409/422 reiniciam; rede/5xx repetem sessão, trace e chave originais. Testes da página verificam sucesso, falha e prática exclusivamente pelo resultado da API; servidor comprova replay/recarregamento sem novo crédito.

**Falta:** Nenhuma implementação local pendente identificada. Validação conectada/em aparelho dos controles, interrupções e baixa taxa de quadros permanece em V09/F06; os testes locais usam transporte simulado.

**Critério de aceite integral:** Espera, mordida, disputa, acerto, falha e recompensa distinguíveis; resposta clara a segurar/soltar e controle alternativo; aparência integrada ao Quintal. Validar pausa/retomada, baixa taxa de quadros e repetição sem duplicar recompensa. Complementa V09.

### U02 · Brincar com o gato

**Prioridade / área:** P1.

**Feito:** Asset da varinha em uso com o próprio gato/pelagem/posição. Rota contínua em células livres, perseguição, alcance único, reação e descanso; varinha parada não provoca saltos repetidos. Resultado informa o vínculo efetivamente recebido e o bônus temporário de satisfação, sem inventar pontos em respostas antigas. Oito testes locais de movimento/rota/resultado e teste API de vínculo/replay aprovados; sequência visual existente de 48 quadros conferida.

**Falta:** Nenhuma implementação local pendente identificada nesta revisão. Validação contínua com API conectada e aparelho de movimento, controles, pausa e resultado permanece em V09/F06.

**Critério de aceite integral:** Perseguição, aproximação, tentativa de alcançar, reação e descanso legíveis; movimento sem repetição estranha. Explicar progresso, resultado e efeito real na satisfação/vínculo, preservando a validação da API. Usar o asset novo de brincar.

### U03 · Hierarquia, textos e controles

**Prioridade / área:** P1.

**Feito:** Revisão local concluída: receitas e preparos agora usam títulos de 15 px e detalhes de 13 px; inventário mantém a bandeja de 258 px com dicas maiores. Contraste medido entre 4,76:1 e 12,37:1 nas combinações de texto, custos e progresso. Estados pressionado/desabilitado preservados. Matriz visual de cenas, fila, receitas e bandeja em 320/390 px aprovada. Botões ilustrados agora acompanham a escala do texto, com espaço vertical para reordenar ações sem partir palavras; Receitas/Recolher/Fila verificados com fontes e ícones reais em 320/390 px. Componentes compartilhados com textos maiores, hierarquia de ações/custos/recompensas e artes locais. Balões e celebrações testados em 390/320 px com texto ampliado. Navegação com rótulos de 12 px; quando falta espaço, a aba ativa ganha largura e as demais preservam ícone, nome acessível e tooltip. As cinco abas têm alvos de pelo menos 48 px e o nome ativo não corta em 320 px com texto 1,5.

**Falta:** Nenhuma implementação local pendente identificada nesta revisão. Conferência de composição e controles em aparelho permanece em V11/F06; capturas usam fixtures.

**Critério de aceite integral:** Separar título, estado, ação principal, ações secundárias, custos e recompensas; botões ilustrados e textos maiores, com contraste e estados de pressionado/desabilitado. Reutilizar componentes. Usar Kingshot como referência de hierarquia, escala e composição, preservando cores, materiais e identidade cozy do Gatálogo. Não transformar o inventário em tela completa nem cobrir o cenário sem necessidade.

### U04 · Relógio e barra de progresso

**Prioridade / área:** P1.

**Feito:** Relógio/barra cobrem cultivo, recuperação, ampliação, preparo, pedido e produção. Ampliações agora têm indicador próprio: horta sobre os novos canteiros; construções acima da produção existente, sem interceptar coleta. Intervalo real do servidor, HH:MM:SS centralizado, pausa por insumo e ausência de início preservados. Fila da cozinha aceita registros sem início sem quebrar nem inventar percentual. Testes verificam obra ativa/pronta, seleção, coleta preservada e nenhum crédito automático; cenas simultâneas e ampliações capturadas.

**Falta:** Nenhuma implementação local pendente identificada nesta revisão. Dados/migração com API e PostgreSQL continuam em F06; composição e interação em aparelho permanecem em V11. Capturas usam fixtures.

**Critério de aceite integral:** Relógio + barra associados ao objeto com atividade temporizada (cultivo, obra, preparo, pedido e produção aplicável). Preenchimento calculado pelo intervalo real do servidor e texto `HH:MM:SS` centralizado e legível. Diferenciar aguardando, produzindo, pausado por falta de insumo e pronto; não inventar progresso quando faltarem os dados de início. Concluir o tempo não pode coletar nem creditar automaticamente.

### U06 · Retornos sem avisos rotineiros no rodapé

**Prioridade / área:** P1.

**Feito:** Sucessos rotineiros usam objeto/estado/estoque; erros ficam contextuais. Testes de ações verificam ausência de SnackBar, erro legível e retry sem crédito repetido.

**Falta:** Validação integrada em aparelho permanece em F06.

**Critério de aceite integral:** Remover snackbars/toasts de sucesso rotineiro que poluem ou bloqueiam a tela. Confirmação deve acontecer no objeto/estado/efeito e no estoque; reservar celebrações para marcos relevantes. Erros e ações bloqueadas continuam explicados de modo contextual e legível, sem sumir silenciosamente.

### U07 · Remoção do atalho de locais no menu +

**Prioridade / área:** P1.

**Feito:** Atalho e lista de locais removidos do menu; ações úteis e foco contextual preservados. Implementado localmente.

**Falta:** Não há resultado de teste específico registrado para este item; verificação integrada permanece em F06/V11.

**Critério de aceite integral:** Remover esse atalho e sua lista de locais desse menu, pois os espaços estão próximos. Preservar as demais ações úteis do “+”; não remover o foco contextual acionado por notificações ou objetivos.

### U08 · Botão Publicar no Social

**Prioridade / área:** P1.

**Feito:** Botão integrado ao fluxo existente e ao estado do menu inferior; verificações/capturas locais registradas.

**Falta:** Validação integrada em aparelho permanece em F06.

**Critério de aceite integral:** Botão visível e acessível, com identidade do app, abre o fluxo existente de criar publicação. Respeitar menu inferior, área segura e teclado; não cobrir ações dos posts. Verificar comportamento nas abas de Social e regras existentes de autenticação.

### U09 · Ancoragem e enquadramento das ações

**Prioridade / área:** P1.

**Feito:** Âncora acompanha mundo, câmera e residentes; seleção e crescimento do conteúdo reenquadram automaticamente uma vez, sem botão. Estado preservado fora da tela/durante API; pan/zoom seguintes continuam manuais. Corrigido o limite da câmera que cortava a cozinha em 320 px: alcance calculado pelas áreas reais. Matriz de todos os tipos de alvo, quatro bordas, zooms 0,8/1,9, telas 320/390 e texto 1,5 aprovada com o tema real. Ícones/rótulos ampliados legíveis nas capturas; vídeos de pan/zoom e seleção mantidos.

**Falta:** Nenhuma implementação local pendente identificada nesta revisão. Verificação integrada de toque, movimento e câmera em aparelho permanece em F06/V11; capturas e vídeos usam fixtures.

**Critério de aceite integral:** Ações ficam associadas às coordenadas do objeto no mundo, acompanhando sua projeção ao arrastar/zoom, sem permanecer presas à câmera nem se deslocar para outro objeto. Um animal em movimento mantém a âncora correta. Não usar ajuste aos limites da tela para fazê-las flutuar longe do alvo; tratar saída da tela explicitamente. Aumentar botões e rótulos, manter leitura em 320/390 px, escala de texto maior, múltiplos zooms e bordas do cenário. Registrar vídeo de pan/zoom e seleção, além das capturas.

### U10 · Referências, assets e galeria

**Prioridade / área:** P1.

**Feito:** Oito referências locais e 38 assets conferidos no projeto; os 38 hashes correspondem ao manifesto. As quatro artes novas estão em uso nas ações de nome, brincar, produtos e melhoria. Código de `lib/` sem caminhos de Downloads/referências externas; bundle declarado no pubspec. Galeria preserva as entregas anteriores, datas próprias e sequências novas. Auditoria reproduzida em 15/10 (`build/quintal-u10-audit.json`); galeria geral aprovada.

**Falta:** Nenhuma pendência atual identificada. Manter esta verificação e atualizar a galeria nas próximas entregas visuais; é uma regra contínua de trabalho.

**Critério de aceite integral:** Referências em `docs/referencias/kingshot/`; arte de produção em `assets/quintal/ui/`, com nomes semânticos e inventário de origem/hash. Código usa somente caminhos relativos ao bundle do projeto, nunca Downloads, caminhos absolutos externos ou imagens de referência como arte de produção. Aproveitar as novas artes nas ações correspondentes, sem criar mecânicas só por existir um ícone. Atualizar a galeria a cada entrega visual.

### V01 · Efeitos das ações no objeto

**Prioridade / área:** Todos · P1.

**Feito:** Efeitos curtos no alvo capturado, somente após confirmação: ferramentas de água/ração/feno, retirada das seis culturas, ordenha, coleta e conclusão de obra. Falha mantém estado; retry confirma uma vez; refresh não repete o efeito. Movimento reduzido e retorno dos controles testados. Vídeos locais de ferramentas e colheita e testes de ações aprovados.

**Falta:** Nenhuma implementação local pendente identificada nesta revisão. Verificação integrada em aparelho, com API conectada, continua obrigatória em F06/V11; vídeos e capturas locais usam fixtures.

**Critério de aceite integral:** Encher, servir, colher, coletar e concluir obra produzem retorno visual curto no objeto correto. Falha preserva o estado; retry não repete crédito. Animação é consequência da API, não fonte de recursos.

### V02 · Refeições, água e reações dos gatos

**Prioridade / área:** Gatos/potes · P2.

**Feito:** Consumo gradual após confirmação, ida ao pote do próprio gato, reação conforme preferência, recusa sem comer, mudança de gosto e próximo apetite pelo prazo do servidor. Beber usa o pote de água vinculado e preserva sua regra de 24 h. Movimento reduzido mantém o estado/texto legível sem deslocar o gato. O painel cede espaço durante o uso do pote e retorna depois. Recusa conhecida entra no histórico com recibo; refresh não repete a reação. Testes API/cliente e capturas/sequências com dois gatos aprovados localmente.

**Falta:** Nenhuma implementação local pendente identificada neste item. Validação conectada/em aparelho permanece na matriz F06/V11; os registros visuais usam fixtures.

**Critério de aceite integral:** Gato correto usa seu pote; nenhuma reação toca outro gato. Comunicar receita, porções, próximo apetite, recusa e mudança de gosto. Beber e redução de movimento devem preservar legibilidade.

### V03 · Galinhas, ninhos e abrigo

**Prioridade / área:** Galinheiro · P1.

**Feito:** Quatro residentes percorrem ciclos completos sem atravessar abrigo/rampa/ninhos/recipientes, entram/descansam/saem pelos acessos e ciscam. Fachada/telhado têm profundidade própria. Níveis 1/2, ampliação e ninhos capturados; ovos dependem da projeção confirmada da coleta. Testes percorrem todos os residentes e vídeos locais mostram portão e abrigo.

**Falta:** Nenhuma implementação local pendente identificada nesta revisão. Verificação integrada em aparelho, com API conectada, continua obrigatória em F06/V11; vídeos e capturas locais usam fixtures.

**Critério de aceite integral:** Trajetos consideram abrigo, rampinha, ninhos e recipientes; não atravessam objetos. Validar os quatro residentes e os ninhos no nível 2. Ovos saem dos ninhos após coleta confirmada.

### V04 · Vacas, ordenha e celeiro

**Prioridade / área:** Pasto · P1.

**Feito:** Ordenha confirmada mostra balde vazio/meio/cheio e o retira; somente a vaca escolhida pausa e retoma sem salto. Coleta individual e replay preservam o leite da outra vaca nos testes da API. As duas vacas percorrem rotas, portão e celeiro nos níveis 1/2 com profundidade e piso corretos; capturas e sequências locais verificadas.

**Falta:** Nenhuma implementação local pendente identificada nesta revisão. Verificação integrada em aparelho, com API conectada, continua obrigatória em F06/V11; vídeos e capturas locais usam fixtures.

**Critério de aceite integral:** Clicar na vaca certa exibe o balde, mostra a ordenha e retira o balde ao terminar. Preservar leite da outra vaca. Cercas/portão e animais respeitam a profundidade.

### V05 · Plantas, colheita e expansão da horta

**Prioridade / área:** Horta · P2.

**Feito:** Quatro fases, rega, composição em preparo e plantas maiores preservadas. Retirada das seis culturas revela a raiz inteira de cenoura/nabo somente na colheita. Folhagem agora tem balanço discreto em torno da origem; sementes, edição e movimento reduzido ficam estáticos. Novos canteiros confirmados retiram gradualmente os elementos de obra, sem mover os antigos ou reiniciar no refresh. Testes das ampliações 4/8/12, preservação do estado e 96 quadros/três vídeos locais aprovados.

**Falta:** Nenhuma implementação local pendente identificada neste item. Matriz integrada em aparelho permanece em F06/V11; capturas usam fixtures.

**Critério de aceite integral:** Terra e plantas permanecem na mesma origem; cenoura/nabo só mostram raiz inteira durante coleta. Novos canteiros não surgem sem transição ao expandir.

### V06 · Cozinha e estados simultâneos

**Prioridade / área:** Cozinha · P1.

**Feito:** Panela, tampa/vapor, bandeja reservada e prato pronto separados na cozinha nível 2. Relógio/barra posicionados acima da chaminé, sem cobrir a panela, nos dois níveis e três zooms. Movimento contínuo (64 quadros/vídeo), movimento reduzido, próximo preparo sem coleta automática e prato preservado na ampliação capturados. Reserva, devolução única de ingredientes no retry e reorganização exata da fila aprovadas em teste da API.

**Falta:** Nenhuma implementação local pendente identificada. Validação conectada e em aparelho permanece em F06/V11. A sequência visual usa fixtures.

**Critério de aceite integral:** Um preparo ativo; ingredientes da próxima receita reservados; recipiente pronto separado. Panela não fica escondida pela própria construção; nada flutua ou atravessa a bancada. Cancelamento devolve os ingredientes e reorganiza o tempo da fila.

### V10 · Inventário e destino dos recursos

**Prioridade / área:** Inventário · P2.

**Feito:** Bandeja inferior preservada em 258 px. Recursos incluem disponível, reservado em preparos/pedidos, em preparo/fila, servido nos potes e aguardando coleta; estoque disponível não sofre um segundo desconto de reservas. Coletas de cozinha, pedidos, horta, ovos, leite e cada fruta permanecem separadas do estoque. Detalhes mostram receitas, trocas do Mercadinho e gostos por gato, com atalhos para cozinha, espaços de coleta e pote específico. Atalhos verificados na página real sem consumo automático. Capturas 320/390 px com texto 1,5, testes de transições e galeria completa aprovados.

**Falta:** Nenhuma implementação local pendente identificada neste item. Validação conectada/em aparelho permanece em F06/V11. Receitas e trocas de maçãs/peras entregues em F04, com atalhos conferidos no inventário.

**Critério de aceite integral:** Manter a bandeja inferior. Não apresentar ingredientes já reservados como disponíveis. Atalho contextual para a cozinha/pote e informação dos gostos sem trocar por uma tela inteira.


### V07 · Mercadinho e retirada do caixote

**Prioridade / área:** Mercadinho · P2.

**Feito:** Recuperação com transição entre os modelos na mesma origem e caixote com retirada animada somente após confirmação. Falha/envio pendente mantêm o pedido; retry usa a mesma chave e refresh não repete o efeito. Frutas decorativas permanecem na bancada. Escolha moedas OU troca explícita, incluindo frutas e preço base/gratuidade de testes. Vinte testes locais aprovados; 14 capturas, dois vídeos e galeria completa atualizados em 18/10 (fixtures).

**Falta:** Nenhuma implementação local pendente identificada. Movimentos reduzidos mostram diretamente o estado confirmado. Validação em aparelho permanece em V11/F06.

**Critério de aceite integral:** Exposição de frutas permanece decorativa; caixote aparece somente pronto e some apenas após coleta confirmada. Mostrar moedas OU produtos e preço base/desconto de testes sem ambiguidade.

### V08 · Pomar e frutos

**Prioridade / área:** Pomar · P2.

**Feito:** Vegetação recuperada nas bordas; três tamanhos de frutos verdes interpolados pela projeção temporal do servidor, sem inventar maturação/coleta local. Camadas independentes preservam os três frutos por lote e animam somente a árvore confirmada. Coletar maçãs mantém as peras e vice-versa, inclusive durante envio e refresh. Dezessete testes existentes/visuais aprovados e dois novos testes individuais aprovados após corrigir a leitura do campo data no teste. Dezessete capturas, dois vídeos, oito modelos/32 vistas e galeria completa atualizados em 18/10; análise dos sete arquivos alterados sem problemas.

**Falta:** Nenhuma implementação local pendente identificada. Movimento reduzido aplica o estado final. Capturas usam fixtures; coleta individual também foi verificada contra PostgreSQL/API em F06. Validação física permanece em V11/F06.

**Critério de aceite integral:** Hoje o servidor gera três frutas de uma vez por árvore: três frutos maduros são coerentes, não um bug por si só. Se houver quantidade variável no futuro, parametrizar a geometria. Uma árvore não recolhe a produção da outra.


## Parcial — implementação ou validação restante


### F06 · Validação integrada com API e banco reais

**Prioridade / área:** P1 · validação.

**Feito:** Em 18/10, cliente Flutter conectado aprovado em dois processos distintos: UI envia troca por frutas; socket TCP é fechado após commit; SQLite preserva a chave; segundo processo com outra sessão retoma sem desconto/pedido duplicado. Troca de conta e retorno preservam os dados de cada conta. PostgreSQL 17.11 e API local em execução verificados. Quatro testes PostgreSQL aprovados: operação concorrente/reconexão, coleta única entre contas, dois workers de notificação com retry persistido e datas domingo/segunda preservadas. Nove testes HTTP autenticados aprovados na API ligada, incluindo carinho concorrente com vínculo 12→13/19→20, recibo de prêmio 20/reconhecimento/replay, pesca com acerto/erro/prática e brincadeira com espera real. Os três fluxos de produção cobrem: pedido/troca de frutas entre duas sessões, commit/reconexão/replay, construção/plantio/rega/colheita, fila/cancelamento/coleta, recusa/retirada do gato e coleta individual de árvore/vaca. Contas temporárias próprias removidas ao final; nenhuma conta existente alterada. Corrigido contrato da rota que rejeitava product_option de F04; nove testes HTTP/contrato aprovados.

**Falta:** Validação em dois dispositivos físicos e ciclo no app instalado. O teste conectado usa widgets/serviços reais no flutter_tester de Windows, HTTP e SQLite reais; não comprova inicialização, plugins e interação física do aplicativo instalado. Perda de resposta após commit, reinício de processo Flutter, reconexão e troca de conta foram aprovados no computador. Prazos vencidos de produção foram preparados somente nas contas temporárias, sem alterar o relógio. Usuária orientou continuar no computador; sem celular conectado.

**Critério de aceite integral:** Executar compra/obra, plantio, fila/cancelamento, recusa, coleta individual e retirada com persistência real. Testar dois dispositivos, resposta perdida após commit, reinício, reconexão, troca de conta e repetição da mesma operação. Não usar tempo do aparelho para acelerar testes.

### V09 · Pesca e brincadeira no cenário

**Prioridade / área:** Pesca/brincadeira · P2.

**Feito:** Em 18/10, quatro cenários contra a API ligada passaram: pesca com acerto, erro e prática, além de brincadeira. Espera real do servidor, rejeição de conclusão precoce/conta diferente e replay por outra sessão sem duplicar peixe/vínculo. Controles sobre a cena, enquadramento, estados distintos, própria pelagem/posição do gato, perseguição/alcance/descanso e resultado da API. Testes locais de controles e tempo em diferentes taxas de quadros.

**Falta:** Validação conectada, toque/slider, baixa taxa de quadros, pausa/retomada e repetição em aparelho. Complementado por U01/U02.

**Critério de aceite integral:** Espera, jogo ativo, sucesso, falha, prática, repetição e pausa ficam claros. Testar segurar/soltar e slider em aparelho real, inclusive baixa taxa de quadros. Tratar o resultado da API como definitivo.

### V11 · Matriz visual do cenário e câmera

**Prioridade / área:** Câmera/cenário · P1 validação.

**Feito:** Matriz local em movimento aprovada em 18/10: todos os alvos com 12 canteiros, quatro galinhas e duas vacas, nas quatro bordas × zooms 0,8/1,6/2,4 × 320/390 px, texto 1,5. Cada balão permanece dentro da área útil sem botão de enquadramento; cena não altera a produção. Quinze testes aprovados, incluindo modelos rotacionáveis nas quatro orientações, limites/pinch, trajetos, abrigos e portões. Seis novas capturas na galeria; sequências anteriores de pan/zoom, colheita e ferramentas preservadas. Evidência usa fixtures.

**Falta:** Repetir a matriz em dispositivo físico/app instalado. A matriz automatizada de movimento, orientações pertinentes, zooms, bordas e textos foi aprovada no computador; não comprova entrada física nem desempenho do aparelho.

**Critério de aceite integral:** Nenhum animal atravessa construção/rio; nenhum balão fica fora da área útil; portões são passáveis; cercas não encobrem objetos à frente; limites da câmera e bandejas funcionam em 320 e 390 px e em dispositivo real.


### U05 · Integração das notificações

**Prioridade / área:** P1.

**Feito:** Corrigidos reenvio de ciclo já coletado, replay de toque após remontagem e corrida com callback inicial; push em primeiro plano deduplicado, listeners descartados, permissão negada não pede token. Testes locais de transporte aprovados; dois workers concorrentes em PostgreSQL e retry após reconexão também aprovados, com transporte simulado. Agendamento na API, fila persistente, retry, deduplicação, preferências e resumo com recibos por evento implementados/testados localmente.

**Falta:** Permissões e entrega FCM em primeiro/segundo plano/app fechado, toque no destino e item já coletado em aparelho; compartilhado com F09/F06. Concorrência PostgreSQL da fila já aprovada, sem comprovar entrega FCM real.

**Critério de aceite integral:** Integrar produção, obras, recompensas e retorno: deduplicação, preferências/permissões, agendamento quando o app estiver fechado e destino correto ao tocar. Não repetir avisos a cada consulta; distinguir notificação, indicador no objeto e resumo de retorno. Testar primeiro plano, segundo plano, app fechado e item já coletado. Complementa F09.


## Ordem recomendada de execução

1. **Consistência e testes:** F01/F02/F06; conferir migração do cuidado legado, datas de eventos e projeções após cada ação.
2. **Ações e ocupação do mundo:** V01/V03/V04/V06, F05 e V11; recipientes, ordenha, ninhos, circulação e estados de obra.
3. **Recompensa e leitura do progresso:** F03, V02/V09/V10; mostrar consequência, próximo marco e destino do recurso.
4. **Fechar a utilidade dos recursos:** decidir F04 e simular F07 antes de acrescentar novas receitas/trocas.
5. **Retorno e rotina:** F08/F09, V05/V07/V08; objetivos contextuais, avisos e acabamento.

Após cada entrega visual, atualizar a galeria permanente. Acrescentar capturas de estados simultâneos e pequenos vídeos das rotas/ações: galinheiro 2, duas vacas, ordenha, cozinha 2 preparando + fila + pronto, expansão de horta, refeição/recusa e retorno após ausência. A captura deve indicar se usa fixture ou conta conectada.

### Ordem do adendo prioritário de 09/10

1. U09/U03: corrigir a ancoragem, escala dos textos e hierarquia dos componentes compartilhados, usando as referências locais.
2. U04/U06/U07: progresso no cenário, remoção dos avisos repetitivos e limpeza do menu “+”.
3. U01/U02: pesca e brincadeira, com controles e retornos visuais coerentes.
4. U05: notificações integradas ao ciclo real e ao destino no cenário; U08: acesso à publicação no Social.
5. U10 acompanha todas as etapas: assets locais, composição coerente, testes e galeria atualizada.

Não marcar estes itens como implementados apenas por terem sido adicionados ao mapa. As regras e restrições anteriores continuam valendo.

## Escopo e regras preservadas

Revisão: 08/10/2026. Escopo: produção, cuidados, residentes, construções, minijogos, inventário e ligação com progressão. Não é uma auditoria integral de Social, reconhecimento de gatos ou busca de desaparecidos.

Base: plano de produção, catálogo de modelos atualizado, implementação Flutter/API, testes existentes e capturas atuais. Esta revisão não altera regras nem o banco de uma conta real. A reprodução auxiliar usou SQLite em memória. Não foi executado um ciclo integral com o app conectado ao PostgreSQL nesta revisão.

**Diagnóstico:** o ciclo econômico principal já está implementado. O trabalho restante é sobretudo conectar melhor as projeções, completar a apresentação das ações no mundo, dar destino a recursos e validar progressão/tempo em condições reais. Não é necessário refazer tudo.

O adendo U01–U10 integra a meta e complementa F09/V09/V11. U08 amplia pontualmente o escopo para o botão de postagem no Social; não representa auditoria integral dessa área.

### O que já existe e deve ser preservado

- Horta com plantio, quatro fases, rega opcional única, prazo no servidor e colheita manual.
- Cozinha com reserva de ingredientes, preparo sequencial, cancelamento apenas de lotes não iniciados e coleta de porções prontas.
- Potes vinculados ao gato, colocação conjunta, retirada automática dos potes, duas porções e água diária. Cores persistidas nos itens.
- Preferências por gato/receita, recusa com perda da porção, evolução persistida e ausência de regressão a partir de Gosta.
- Produção de ovos/leite limitada por alimento, água e capacidade; coleta no galinheiro e individual na vaca. Fruteiras também têm coleta individual.
- Mercadinho rural com pagamento por moedas OU produtos, uma vaga de pedido e caixote apenas quando pronto. O catálogo atual oferece frango e carne.
- Pesca com sessão validada, varas, limite diário, modo de prática e controle alternativo por slider. Brincadeira exige movimento, não apenas deixar o tempo passar.
- Inventário em bandeja inferior com Decorações, Rações e Ingredientes.
- Missões iniciais, rotinas opcionais diárias/semanais e conquistas de produção integradas ao sistema de marcos; produção sem XP base ilimitado.
- Chaves persistentes de idempotência, proteção contra resposta atrasada e troca de conta. Existem testes específicos; isso não substitui prova de concorrência real no banco de produção.
- Os cinco estados solicitados de galinheiro/celeiro/cozinha, ovo original, milho com grãos em 360°, bandeja de ingredientes e Mercadinho sem correio já estão corrigidos.

### O que não deve virar trabalho indevido

- **Sem construir outro conjunto de nível 2 abandonado.** Isso já foi removido.
- **Sem reintroduzir correio.** Mercadinho permanece rural; IDs técnicos antigos não são conceitos visuais.
- Água cheia/vazia é compatível com a regra simples de 24 h; ter um asset parcial não exige inventar uma sede complexa.
- Preferências positivas sem regressão e perda da ração recusada permanecem como combinado.
- Incubação, pintinhos crescendo e bezerros são etapa posterior. Não são bloqueadores da produção atual de ovos/leite.
- Tutorial guiado, temporada ativa e itens raros ainda não definidos não devem ser inventados para fechar a auditoria.
- Peixe e novos produtos no Mercadinho dependem de catálogo/preços; não entram automaticamente por existir um ícone/modelo.
- Não criar mais moeda, XP agrícola, apodrecimento ou abate dos residentes.

### Esclarecimento sobre a investigação do carinho

Na investigação original, uma chamada isolada ao serviço legado reproduziu `12 → 13 → 12`; isso não comprovava perda pelo fluxo normal, cuja rota já tinha uma ponte de vínculo. **Estado atual:** a regra foi centralizada em `habitat_interactions.interact`, a ponte redundante foi removida e os testes HTTP/cliente passaram. A evidência detalhada está em F01 no registro de execução; falta a validação conectada de F06.

## Referências e importação

- Origem fornecida: `C:/Users/Evelynn_Doescher/Downloads/game_refs`. As oito imagens foram copiadas para [referências locais de Kingshot](referencias/kingshot/), com correspondência de nomes em `manifest.json`.
- Pontos observados: barras compactas sobre construções com tempo central de alto contraste; identificação clara do objeto; painéis de detalhe com título/nível, informação agrupada e ação principal evidente. Adaptar esses princípios à arte do Gatálogo, sem importar seus menus militares, publicidade ou excesso de indicadores.
- Origem dos assets: `C:/Users/Evelynn_Doescher/Downloads/Quintal`. Conferidos 38 PNGs: 34 já existentes idênticos e quatro novos importados, sem alterar o conteúdo das imagens.
- Novos arquivos: `action_rename.png` (lápis), `action_play.png` (varinha), `action_trade.png` (troca) e `action_upgrade.png` (melhoria). Pasta: `assets/quintal/ui/`; rastreabilidade em `import_manifest.json`.
- Integração inicial realizada: botão Nome dos residentes, botão de brincar na ficha do gato, pagamento por Produtos e ações Ampliar/Melhorar usam essas artes pelo componente `QuintalArtwork`. Os 38 hashes da importação foram verificados; a busca no código `lib/` não encontrou dependências de Downloads nem URLs de arquivo externo.
- A importação não encerra U10: conferir o uso efetivo nas telas reformadas e a ausência de dependência de arquivos externos.

## Evidências e limites da revisão

| Evidência | Fonte |
|---|---|
| Regras, reservas, capacidades, preferências, datas e coleta | [quintal_production.py](../../gatalogo-ai-api/app/services/quintal_production.py), [quintal_catalog.py](../../gatalogo-ai-api/app/services/quintal_catalog.py) |
| Regra centralizada de carinho e rota | [habitat.py](../../gatalogo-ai-api/app/routers/habitat.py), [habitat_interactions.py](../../gatalogo-ai-api/app/services/habitat_interactions.py) |
| Projeção das missões, data e unidade dos eventos | [quintal_progress.py](../../gatalogo-ai-api/app/services/quintal_progress.py), [milestones.py](../../gatalogo-ai-api/app/services/milestones.py), [progression.py](../../gatalogo-ai-api/app/services/progression.py) |
| Processamento e avisos do Quintal | [quintal_notifications.py](../../gatalogo-ai-api/app/services/quintal_notifications.py), [router](../../gatalogo-ai-api/app/routers/quintal.py) |
| Atualização de estado e vínculo no cliente | [habitat_care.dart](../lib/services/habitat_care.dart), [quintal_production.dart](../lib/services/quintal_production.dart), [habitat_service.dart](../lib/services/habitat_service.dart) |
| Objetos, modelos e rotinas | [quintal_production_scene.dart](../lib/game/quintal_production_scene.dart), [quintal_resident_motion.dart](../lib/game/quintal_resident_motion.dart) |
| Ações, estoques, próximos marcos e minijogos | [quintal_object_actions.dart](../lib/widgets/quintal_object_actions.dart), [inventário](../lib/widgets/quintal_inventory_tray.dart), [ficha do gato](../lib/widgets/habitat_care_sheet.dart), [minijogos](../lib/pages/quintal_game_page.dart) |
| Capturas e cobertura existentes | [galeria](../build/galeria-visual/galeria.html), `test/quintal_*`, API `tests/test_quintal_production.py` e `tests/test_quintal_router.py` |
| Inventário de fontes 3D | [auditoria de modelos](auditoria_modelos_quintal_2026-10-08.md): 117 GLBs, 468 vistas, 28 itens de catálogo |

Os testes existentes já cobrem vários casos de repetição, fila, recusa, coleta individual e troca de conta. Não classificar esses mecanismos como ausentes. PostgreSQL/concorrência, viradas de período, cliente conectado com perda de resposta/reinício e matriz local de layout/movimento foram aprovados em 18/10. Ainda faltam os gates físicos de F06/V09/V11/U05 discriminados acima. O estado atual de cada item está nas seções Feito localmente, Parcial e Pendente. As correções registradas têm evidência de implementação/testes; documentar uma tarefa não a torna concluída.

## Como atualizar este mapa

Após cada implementação, atualizar “Feito” e “Falta” do item, preservando seu aceite integral. Se o estado mudar, mover o item de seção e ajustar o resumo. Registrar data, arquivos/evidências, testes e limitações no [registro de execução](registro_execucao_fluxos_quintal_2026-10.md). Após entrega visual, atualizar também a galeria e identificar fixture ou conta conectada. Não marcar um item como feito apenas porque foi documentado ou porque um teste cobre só parte do aceite.
