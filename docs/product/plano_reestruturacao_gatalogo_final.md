# Gatálogo — plano final de reestruturação da experiência

**Data:** 27/09/2026  
**Estado:** direção de produto consolidada para implementação e validação  
**Base:** plano de reestruturação original, decisões desta conversa, inspeção do app Flutter, API e prévias versionadas.

## 1. Objetivo e decisões firmadas

Transformar o Gatálogo em uma experiência de descoberta felina fluida, acolhedora e claramente jogável. O ciclo de fotografar, descobrir, colecionar e personalizar o Quintal deve conduzir a navegação. A identidade atual — logo, fotografias reais, papel creme, rosa, verde, folhas, ilustrações felinas e tipografia calorosa — continua reconhecível. A interface do Quintal e da Loja é referência de jogo e será integrada ao restante, sem reforma estrutural forte.

As cinco abas continuam **Início, Social, Gatalogar, Coleção e Quintal**. A reforma visual alcança o app inteiro em etapas: Home, Captura, Resultado, Coleção, Social e Perfil recebem a transformação principal; Meus Gatos, desaparecidos, Avistamentos, Missões, Conquistas, notificações, configurações e conta recebem integração, consistência e melhorias próprias de usabilidade.

Referências criativas: a organização e personalização do quintal lembram Clash of Clans; a legibilidade de coleção, revelação, metas e recompensas lembra Clash Royale; o ritmo calmo, o espaço vivo, o som e a ilustração delicada lembram Gatos e Sopa. O Gatálogo traduz esses princípios para exploração fotográfica e cuidado com gatos reais. Não introduzir combate, competição obrigatória, raridade atribuída ao valor de um animal, monetização de moedas ou pressão para fotografar.

**Decisões de produto:**

- Álbum e Quintal têm peso semelhante na motivação; a Home mostra uma próxima meta concreta de cada um.
- Uma foto é salva localmente antes da sincronização. Progresso e créditos definitivos surgem após confirmação do servidor. Foto válida com atributos incertos recebe crédito básico; bônus de conjunto espera confirmação dos atributos.
- A IA sugere quando uma foto pode ser do mesmo gato, mas a pessoa decide criar um indivíduo ou adicionar foto ao existente e pode corrigir a decisão depois.
- O resultado tem celebração curta, pulável e acessível. Missões são poucas e flexíveis: uma diária e duas semanais. Sequência de dias pode ser registrada como marco, sem multiplicador de XP ou punição por ausência.
- A Coleção reúne gatos e desafios variados **seguros**: indivíduos distintos, atributos confirmados, fotos complementares úteis e registros em dias diferentes. Não criar desafios que exijam noite, deslocamento para uma região específica, contato com animais ou exposição de endereço.
- Gatos próprios formam uma jornada de vínculo e proteção. Podem aparecer no Quintal por escolha da pessoa; seu cadastro não conta como nova descoberta do álbum.
- “Avistamentos” da Home é o **mapa dos meus registros**, com nome e descrição coerentes. Não prometer mapa comunitário nessa entrega.
- Social é uma comunidade de conversa sobre gatos, com feed único e filtros, publicações, respostas, curtidas, conversas, conquistas e cartazes. Publicar e comentar podem receber ganhos pequenos e limitados; curtir não recebe prêmio. Compartilhamento de descobertas é voluntário.
- Pista ou avistamento útil confirmado pelo tutor rende recompensa alta de XP e moedas. Repostar **dentro do app** o cartaz ativo de outra pessoa rende recompensa pequena. Abrir telas, criar alerta, compartilhar fora do app ou apenas receber uma sugestão automática não rendem esses prêmios.
- A vitrine do Perfil começa visível apenas a amigos. Galerias de contas existentes passam para essa audiência; cada pessoa controla separadamente galeria, medalhas e prévia do Quintal. Publicações que a pessoa já fez por escolha própria mantêm sua audiência registrada.
- Notificações ficam em uma caixa com seções: buscas e pistas primeiro, depois conversas e novidades de jogo. Cada aviso abre seu destino correto.
- Efeitos suaves começam ativos e respeitam silêncio/foco do aparelho. Música é ativada por escolha da pessoa e pode tocar em Home, Coleção, Resultado e Quintal; fica pausada em captura, chats, formulários e fluxos de proteção. Vibração e movimento extra são controlados separadamente.

## 2. Mapa de jornadas e experiência de cada área

| Jornada | Entrada e percurso | Resultado esperado |
|---|---|---|
| Descoberta | Home → Gatalogar → revisão da foto → registro local → análise e sincronização → Resultado → Coleção ou Quintal | A pessoa sabe o que foi salvo, o que foi confirmado, o que ganhou, qual desafio avançou e o que fazer em seguida. |
| Gato conhecido | Captura ou ficha → sugestão de correspondência → decisão da pessoa → foto complementar | A foto enriquece a ficha; não se apresenta como novo indivíduo nem recebe o mesmo prêmio. |
| Meus Gatos | Home ou Perfil → cadastro próprio → ficha, identificação e álbum de proteção → escolha para Quintal | O cuidado e o vínculo com o gato são valorizados; cadastro e emergência não inflacionam descobertas. |
| Busca de desaparecido | Meus Gatos ou atalho de proteção → alerta com gato cadastrado ou alerta rápido → área, cartaz, pistas, mapa, conversa → confirmação/descarte → resolução | O estado do caso e a próxima ação prática são claros, sem cerimônia festiva. |
| Contribuição à busca | Registro/avistamento → possível correspondência → tutor analisa → confirmação → aviso e crédito ao colaborador | A recompensa alta é única, rastreável e ligada à confirmação do tutor. |
| Meus Avistamentos | Home ou ficha → mapa pessoal → marcador → ficha do registro | O mapa permite revisitar a própria história sem mostrar coordenadas a terceiros. |
| Comunidade | Social → feed filtrável → publicação, comentário, conversa ou repost interno de cartaz → Perfil | Interação social tem contexto e audiência claros; cartaz mantém vínculo e estado do alerta original. |
| Quintal | Resultado, Home ou aba Quintal → saldo/item → Quintal/Loja/Inventário | A pessoa encontra e usa o que conquistou, preservando controles e organização existentes. |
| Conta e preferências | Entrada como convidado ou login → sincronização → notificações, privacidade, áudio e acessibilidade | Registro local não se perde; a pessoa entende o que depende de conta ou rede. |

### Telas principais

**Home.** Primeiro campo visual: saudação, missão simples e botão Gatalogar; ao lado ou logo abaixo, avanço do álbum e próximo marco do Quintal, com número, meta e prêmio legíveis. Alertas de busca relevantes aparecem antes do conteúdo lúdico. Meus Gatos e Meus Avistamentos permanecem acessíveis como atalhos compactos. Reduzir cartões repetidos e evitar exibir contadores sem ação correspondente. Ao voltar de Resultado, atualizar todos os progressos a partir do mesmo estado confirmado.

**Captura e Resultado.** Câmera e galeria têm igual acesso. Mostrar revisão da foto e possível gato já conhecido sem aceitar a sugestão da IA automaticamente. Depois de salvar, usar estados textuais distintos: `salvo no aparelho`, `aguardando conexão`, `em análise`, `precisa de revisão`, `confirmado` ou `não elegível para prêmio`. Criar Resultado como tela própria: fotografia grande → tipo de registro → atributos confirmados/editáveis → créditos → desafio/conjunto → desbloqueio → ação seguinte. Permitir pular animação; não bloquear navegação por falha de crédito. Um resultado atrasado pode ser reaberto por notificação e histórico.

**Coleção e ficha.** Separar visualmente `Gatos` e `Desafios`, mantendo busca, favoritos e filtros compactos. Cada registro preserva número, data, foto, notas, privacidade e correção de identificação. Desafios mostram condição, progresso, próxima peça e prêmio; lacunas só aparecem quando definidas e alcançáveis. Remover rótulos de gato “comum/raro/lendário” baseados em inferência de pelagem. Medalhas podem ter níveis próprios, desde que descrevam conquistas, não o valor do animal.

**Missões e Conquistas.** Missões exibem ação, período, progresso e prêmio; Conquistas formam um mural filtrável em andamento/concluídas/disponíveis. A fonte de progresso é o evento confirmado, não contagens independentes de cada tela. Desafios existentes de saída noturna ou localização específica são aposentados da oferta futura; conquistas já obtidas permanecem no histórico. O período usa o fuso da pessoa e expiração não retira prêmio concedido.

**Social e Perfil.** Manter feed único com filtros por comunidade/amigos e tipo de conteúdo. Cartões de descoberta, conversa, conquista e cartaz têm propósito e ações legíveis. Repost de cartaz alheio é uma publicação vinculada ao alerta, mostra autoria/estado e deixa de convidar a compartilhar quando o caso se encerra. Perfil oferece prévia “como amigos me veem” e controles de visibilidade independentes. Não publicar automaticamente foto, localização, prêmio ou cuidado/proteção.

### Fluxos secundários integrados

**Meus Gatos.** Manter cadastro, ficha, coleira, marcas, microchip e fotos de referência como ferramentas de cuidado. A ficha pode oferecer “levar ao Quintal” quando elegível e escolhido. Fotos de referência podem manter o pequeno crédito único já previsto por tipo de foto, separado do prêmio de descoberta. O caminho “Declarar desaparecido” e o alerta rápido ficam próximos e claramente diferenciados. Criar alerta rápido não dispara XP de nova descoberta.

**Gatos desaparecidos e pistas.** Home, Meus Gatos, Social e notificações devem levar ao mesmo caso e estado atualizado. Na tela do alerta, destacar gato, estado, última área conhecida, pistas, contato e cartaz. Pistas têm estados `nova`, `em análise`, `confirmada`, `descartada` e `caso encerrado`, com explicação da precisão de localização disponível. O tutor confirma ou descarta; o colaborador recebe agradecimento e crédito somente após confirmação. Resolver o caso interrompe novos reposts premiados. O aviso “seu avistamento ajudou” abre a pista/caso, não Conquistas.

**Meus Avistamentos.** O mapa pessoal mostra registros próprios e leva à ficha correspondente. Corrigir o texto da Home que hoje sugere registros de outras pessoas. Diferenciar no mapa uma descoberta comum de um avistamento enviado para ajudar uma busca; a segunda situação segue regras próprias de privacidade e recompensa. Sem localização não se bloqueia o registro fotográfico legítimo.

**Notificações, configurações e conta.** Agrupar eventos duplicados e permitir acesso direto ao destino. Configurações reúnem Música, Efeitos, Vibração, Movimento, compartilhamento e audiência do Perfil, além de sincronização e avisos existentes. Modo convidado mantém catálogo local e mostra créditos como pendentes até vinculação/sincronização; nunca inventa saldo definitivo. Preservar exportação de dados, ajuda/feedback, autenticação e recuperação de conta.

## 3. Linguagem visual, movimento e som

O sistema visual será **caderno vivo**: fotografias reais lideram, papel e botânica preservam a marca, e selos, progresso, miniaturas do Quintal e ilustrações pontuais tornam a descoberta jogável. Rosa identifica ação principal; verde, crescimento e Quintal; dourado discreto, créditos e marcos; coral fica reservado para urgência real. Definir tokens únicos de cor, tipografia, espaçamento, raios, bordas, elevação e duração. Atualizar a regra atual de cartões totalmente planos apenas onde uma camada sutil melhora hierarquia; nenhuma tela deve misturar estilos arbitrários.

Construir primeiro os componentes compartilhados: botão e chip; cartão de missão; cartão de descoberta; peça/lacuna de desafio; progresso com valor/meta/prêmio; crédito e desbloqueio; estado vazio, pendente e erro; cartão de cartaz; aviso de proteção. Nas áreas de exploração, usar transições curtas para revelar peça, atualizar contadores e destacar item ganho. Detalhes ilustrados animados ficam em revelações, estados vazios e marcos, sem mascote permanente nem pulsação contínua. Testar em telefone pequeno, texto ampliado, leitor de tela, redução de movimento, volume baixo e som desligado. Toda informação transmitida por cor, áudio, vibração ou animação também aparece em texto.

Música calma acompanha apenas as áreas de jogo após ativação da pessoa; efeitos de descoberta podem começar ligados respeitando o aparelho. Som de créditos simultâneos é agrupado, sem tocar a cada incremento. Pausar ao sair do app, durante chamada ou perda de foco. Licenciar os arquivos de áudio e manter ajustes persistentes por conta/dispositivo conforme a natureza da preferência.

## 4. Progressão, integridade e contratos

O servidor é a fonte de verdade para XP, nível, moedas, desafios, conquistas e desbloqueios. Um evento de ação confirmado possui ID estável, pessoa, origem, registro relacionado, instante, versão da regra e evidência de elegibilidade. Um ledger registra cada concessão ou correção com chave idempotente. Créditos, saldo, missão, coleção e itens são processados como uma operação lógica; reenvio, reconexão, exclusão/recriação ou a mesma foto não concedem o prêmio novamente.

**Política inicial de elegibilidade:**

| Evento | Regra |
|---|---|
| Novo indivíduo confirmado | XP e moedas de descoberta uma vez; pode avançar missão, desafio e nível. |
| Foto complementar aceita | Não conta como novo gato; pode avançar objetivo próprio e manter pequeno crédito único por contexto. |
| Foto repetida, análise falha ou atributo incerto | Repetição não ganha prêmio de novo indivíduo; foto válida com atributo incerto recebe apenas base, e conjunto espera revisão. |
| Cadastro de gato próprio ou alerta rápido | Não conta como descoberta. Presença no Quintal é opcional; fluxos de proteção continuam funcionais. |
| Pista confirmada pelo tutor | XP e moedas altos uma vez por contribuição/caso, nunca pelo simples envio; impedir auto-confirmação e créditos repetidos. |
| Repost interno de cartaz alheio | XP e moedas baixos uma vez por pessoa/cartaz ativo, com limite diário; repost de cartaz próprio ou encerrado não credita. |
| Publicação e comentário no Social | Créditos pequenos e limitados por dia; excluir autopublicação repetida, comentário próprio e spam. Curtida e compartilhamento externo não creditarão. |
| Ações do Quintal | Preservar as interações e compras existentes; separar seus eventos dos de alerta de desaparecimento. |

Usar como ponto de partida as escalas atuais da economia — descoberta: **50 XP e 25 moedas**, coerente com o preço atual de itens básicos; pista confirmada: **100 XP e 50 moedas**; repost de cartaz: **5 XP e 2 moedas**, até dois por dia; publicação elegível: **10 XP e 3 moedas**, até uma por dia; comentário elegível: **3 XP e 1 moeda**, até três por dia. São valores de lançamento versionados, não promessas permanentes; validar aquisição de itens e abuso em teste fechado antes de ativar para todas as contas. Remover multiplicador de XP por sequência. Prêmios de nível são cosméticos; remover promessas de prioridade em alertas por nível.

**Contrato cliente/API:** criar um resumo único de resultado com `event_id`, estado (`pending`, `confirmed`, `needs_review`, `ineligible`), tipo de registro, atributos confirmados, créditos efetivos, saldos/XP resultantes, mudanças de missões e desafios, conquistas, nível e itens liberados. Disponibilizar consulta por ID para retorno assíncrono e histórico. O cliente nunca soma créditos por conta própria. Avistamentos e fotos enviados offline mantêm chave estável. A confirmação do tutor é o gatilho do prêmio de pista; o repost interno é evento servidor com vínculo ao cartaz original. A audiência de perfil e publicação é aplicada na API, não apenas escondida na interface.

**Migração:** preservar XP, nível alcançado, moedas, itens comprados/posicionados e conquistas já concedidas. Criar registro inicial de saldo/XP para o novo ledger sem pagar novamente por eventos antigos. Aposentar missões e multiplicadores antigos apenas para eventos futuros; conservar histórico e evitar rebaixar nível. Alterar galeria pública existente para audiência de amigos. Reprocessar sincronizações antigas sem novos bônus. Introduzir versão de regras e feature flags para liberar as novas concessões gradualmente.

## 5. Etapas de entrega e critérios de aceite

1. **Inventário e protótipo:** consolidar rotas, estados, eventos, audiências e saldo atual; criar protótipo navegável de Home → Captura → Resultado → Coleção → Quintal e de Meus Gatos → Alerta → Pista → confirmação. Revisar com pessoas que não conhecem o app antes de programar a nova economia.
2. **Fundação de progresso:** ledger e resumo de resultado na API; migração; elegibilidade e idempotência; correção dos créditos disparados ao salvar foto, abrir Desaparecidos ou enviar avistamento. Preparar feature flags e observabilidade.
3. **Jogo principal:** tokens/componentes, Home, Captura, Resultado, Coleção, Missões e Conquistas; ligar créditos e desbloqueios ao Quintal atual. Entregar estados normal, vazio, offline, incerto, repetido e erro.
4. **Fluxos secundários:** integrar Meus Gatos, álbum de proteção, alertas normal/rápido, pistas, mapa pessoal de avistamentos e notificações. Crédito alto só após tutor confirmar; os avisos abrem a tela correta.
5. **Comunidade e perfil:** feed único filtrável, repost interno de cartaz, pequenas recompensas sociais, audiência de amigos por padrão, controles e prévia do Perfil. Revisar privacidade dos contratos existentes.
6. **Som, movimento e ajuste:** música opt-in nas áreas de jogo, efeitos/vibração independentes, redução de movimento e testes de acessibilidade. Rodar teste fechado de economia, compreensão e segurança; ajustar números versionados; ativar gradualmente e acompanhar métricas.

**Aceite integrado:** uma foto válida salva offline reaparece após sincronização e recebe exatamente um crédito; pessoa entende o resultado e chega ao desafio e ao item correspondente; gato próprio e alerta rápido não viram descobertas; abrir Desaparecidos não gera prêmio; pista confirmada pelo tutor credita uma vez e notifica com destino correto; repost de cartaz alheio ativo credita pouco e uma vez; saldo, XP e itens concordam em todas as telas; perfil antigo só mostra galeria a amigos; o app permanece utilizável sem áudio, animação ou localização.

Medir primeiro registro válido, compreensão do Resultado, retorno à Coleção, visita/uso do Quintal após desbloqueio, conclusão voluntária de missão, correções de IA, duplicatas/créditos repetidos, abandono na Captura, uso de áudio e relatos de pressão ou risco para animais. Em teste qualitativo, pedir que uma pessoa explique o ganho, o próximo passo, a diferença entre alerta e conquista, a privacidade do Perfil e como desligar som. Sucesso depende de clareza, prazer de uso e confiança, não apenas de tempo de tela.
