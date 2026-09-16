# Gatálogo — Roadmap Consolidado de Correções e Adições

> Roadmap derivado do relatório de análise do Gatálogo.  
> Objetivo: transformar os achados do relatório em uma ordem prática de implementação, agrupando itens que compartilham dependências, contexto ou entregam valor conjunto.
>
> **Princípio de priorização:** primeiro eliminar bloqueadores, bugs que quebram confiança e gargalos técnicos; depois tornar captura, resgate e comunicação realmente utilizáveis; em seguida ativar os loops de retenção/social; por fim adicionar diferenciação, polimento e o metajogo 3D.

---

## Visão geral das etapas

| Etapa | Foco | Objetivo |
|---|---|---|
| **Etapa 1** | Fundação, bugs críticos e lançamento | Deixar o app confiável, publicável e sem dead-ends críticos |
| **Etapa 2** | Captura e catálogo | Garantir que fotografar/catalogar seja simples e recuperável |
| **Etapa 3** | Resgate e localização | Tornar o fluxo de gato perdido funcional em situações reais |
| **Etapa 4** | Chat e comunicação | Transformar o chat em ferramenta real de coordenação de resgate |
| **Etapa 5** | Feed, compartilhamento e social | Corrigir performance e criar um social acessível |
| **Etapa 6** | Gamificação base | Ativar XP, streaks, missões e conquistas como motor de hábito |
| **Etapa 7** | Grafo social e comunidade | Criar descoberta, perfis e crescimento orgânico |
| **Etapa 8** | UX, qualidade de vida e retenção | Refinar experiência e aumentar retorno diário |
| **Etapa 9** | Diferenciação e metajogo 3D | Transformar a coleção em uma experiência de jogo mais profunda |

---

# ETAPA 1 — Fundação, bugs críticos e preparação para lançamento

**Prioridade: P0 / bloqueadora**

A primeira etapa não deve adicionar complexidade. Deve corrigir o que pode impedir publicação, quebrar funcionalidades ou induzir o usuário ao erro.

### 1.1 Autenticação, conta e requisitos de lançamento

- [x] Implementar **Apple Sign-In**.
- [x] Adicionar **Termos de Serviço** e **Política de Privacidade** no cadastro, com consentimento.
- [x] Corrigir o bloqueio de login client-side causado pela exigência de senha mínima de 12 caracteres para contas antigas.
- [x] Adicionar evento/feedback de **sessão expirada**, evitando logout silencioso.
- [x] Corrigir fluxo de OTP de desativação de conta:
  - [x] Criar/usar endpoint específico de desativação.
  - [x] Remover uso de `requestPasswordReset(email)`.
  - [x] Não avançar o fluxo quando o envio do OTP falhar.
  - [x] Corrigir inconsistência entre código de 4 e 6 dígitos.
  - [x] Trocar o texto técnico "OTP" por linguagem compreensível.

### 1.2 Push notifications

- [x] Remover plataforma hardcoded como `'android'`.
- [x] Detectar corretamente Android/iOS no registro do token.
- [x] Validar registro e recebimento de push em ambas as plataformas.

### 1.3 Correções que quebram confiança

- [x] Corrigir `LeafDecoration` e o caminho dos assets.
- [x] Corrigir o indicador de raridade para usar estrela preenchida/contornada corretamente.
- [x] Corrigir o falso **✓✓ de leitura** no chat.
- [x] Corrigir o status online hardcoded.
- [x] Corrigir notificações de convite para abrir `FriendsPage`, não o feed.
- [x] Corrigir "Tipo de pelagem" para não exibir `primaryColor` como `coatType`.
- [x] Corrigir botões de compartilhamento que hoje exibem sucesso sem realizar compartilhamento.
- [x] Corrigir guest que aparece como conta conectada com e-mail fictício.
- [x] Desabilitar ações de edição de perfil para guest e mostrar CTA de login.

### 1.4 Critério de conclusão da Etapa 1

O app deve conseguir passar por:

**Cadastro/login → sessão → push → navegação → desativação de conta → logout/login novamente**

sem mock enganoso, dead-end ou falha crítica.

---

# ETAPA 2 — Captura e catálogo sem atrito

**Prioridade: P0/P1**

O catálogo é a principal fonte de dados do matching. A captura precisa ser rápida e tolerante a diferentes situações.

### 2.1 Corrigir o fluxo de entrada de fotos

- [x] Adicionar **Galeria** na `CapturePage`.
- [x] Expor o método `_escolherFoto(ImageSource.gallery)` que já existe.
- [x] Permitir catalogar uma foto já existente sem exigir nova fotografia.
- [x] Melhorar feedback de rejeição de imagem:
  - [x] Substituir SnackBar volátil por feedback persistente/modal.
  - [x] Explicar por que a foto foi rejeitada.
  - [x] Explicar como tirar uma foto melhor.

### 2.2 Recuperação de análise

- [x] Expor o botão **Tentar novamente** quando a análise de IA falhar.
- [x] Conectar `retryAnalysis(catId)` já existente no `CatStore`.
- [x] Garantir estados claros: analisando → sucesso → falha → retry.

### 2.3 Melhorar qualidade das fotos

- [x] Criar overlay/silhueta para orientar as quatro poses.
- [x] Exibir bounding box do TFLite na pré-visualização.
- [x] Corrigir/organizar a tela de fotos adicionais para refletir corretamente a foto de cadastro.
- [x] Adicionar filtros avançados à biblioteca por cor, padrão, bairro e status da análise.

### 2.4 Compartilhamento real do gato

- [x] Implementar compartilhamento nativo com `share_plus`.
- [x] Criar card visual com:
  - foto;
  - nome;
  - número do Gatálogo;
  - stats da IA;
  - informações relevantes.
- [x] Substituir todos os mocks de share existentes.

### 2.5 Critério de conclusão

O usuário deve conseguir:

**Escolher câmera ou galeria → catalogar → receber resultado → corrigir/repetir em caso de falha → visualizar → compartilhar**

sem ficar preso em nenhuma etapa.

---

# ETAPA 3 — Gatos perdidos, mapa e resgate

**Prioridade: P0/P1**

Esta etapa transforma o principal propósito social do app em um fluxo de emergência utilizável.

### 3.1 Localização

- [x] Implementar **busca de endereço por texto / geocodificação direta**.
- [x] Remover o fallback geográfico hardcoded em Limeira/SP.
- [x] Usar localização aproximada por GPS/IP/cidade do perfil quando necessário.
- [x] Omitir número residencial da geocodificação exibida.
- [x] Garantir que o endereço exibido privilegie rua/bairro em vez do endereço exato.

### 3.2 Alerta de gato perdido

- [x] Criar **fluxo simplificado de emergência**.
- [x] Permitir iniciar alerta rapidamente com foto, mesmo sem pet totalmente cadastrado.
- [x] Manter opção de completar informações depois.
- [x] Adicionar informações úteis ao perfil do pet:
  - [x] microchip;
  - [x] coleira;
  - [x] marcas características.

### 3.3 Gestão das pistas

- [x] Criar **mapa consolidado de todas as pistas**.
- [x] Adicionar timeline dos avistamentos.
- [x] Permitir registrar avistamento manual sem foto.
- [x] Adicionar desfazer/confirmação antes de descartar uma pista.

### 3.4 Mobilização

- [x] Criar **cartaz/panfleto digital**.
- [x] Incluir foto, nome, contato e QR Code.
- [x] Permitir compartilhar/imprimir.
- [x] Implementar geofencing para alertas de proximidade.

### 3.5 Critério de conclusão

Fluxo alvo:

**Gato desapareceu → alerta rápido → área de busca → comunidade encontra pista → localização/foto → comparação → comunicação → confirmação**

---

# ETAPA 4 — Chat como ferramenta de resgate

**Prioridade: P0/P1**

O relatório identifica o chat como ponte entre avistamento e resgate. Ele não deve ser tratado apenas como mensageria social.

### 4.1 Inbox

- [x] Criar **Conversas Recentes**.
- [x] Acesso em 1 toque.
- [x] Cada conversa deve mostrar:
  - avatar real;
  - nome/@username;
  - última mensagem;
  - horário;
  - badge de não lidas;
  - contexto de pista quando aplicável.

### 4.2 Mensagens essenciais para resgate

- [x] Envio de **fotos**.
- [x] Envio de **localização/pin**.
- [x] Compartilhamento de **ficha de gato** como mensagem rica.
- [x] Manter banner "Pista de avistamento" coerente com essas capacidades.

### 4.3 Estado real da conversa

- [x] Implementar confirmação de leitura real.
- [x] Implementar status online/visto por último real.
- [x] Implementar indicador de digitação via WebSocket.
- [x] Remover polling redundante de 30s quando WebSocket estiver disponível.
- [x] Inserir mensagens recebidas pontualmente em vez de recarregar a lista inteira.

### 4.4 Recursos secundários

- [x] Reações com ícones vetoriais (Lucide).
- [x] Reply/citar mensagem.
- [x] Copiar mensagem.
- [x] Apagar mensagem.
- [x] Editar mensagem.
- [x] Silenciar conversa.
- [x] Buscar mensagens.
- [x] Bloquear/denunciar contato.
- [x] Áudio, documentos e stickers ficam depois dos recursos diretamente ligados ao resgate.

### 4.5 Critério de conclusão

O usuário deve conseguir responder a:

> **"Vi um gato parecido. Onde você está? Pode me mandar uma foto?"**

sem sair do fluxo do chat. (Concluído e validado com testes integrados de unidade e widgets).

---

# ETAPA 5 — Feed, compartilhamento e infraestrutura social

**Prioridade: P0/P1**

Antes de expandir o social, corrigir a infraestrutura que fará o feed escalar.

### 5.1 Performance do feed

- [x] Substituir **Base64 em JSON** por upload multipart + URL/CDN.
- [x] Comprimir/redimensionar imagens antes do upload.
- [x] Remover `base64Decode()` da UI thread.
- [x] Adicionar cache de imagens de rede.
- [x] Implementar **paginação/infinite scroll**.

### 5.2 Compartilhamento

- [x] Corrigir share de posts.
- [x] Corrigir share de gatos.
- [x] Corrigir share de conquistas para gerar preview visual.
- [x] Permitir compartilhamento externo real para WhatsApp/redes sociais via OS share sheet.

### 5.3 Feed e cold start

- [x] Definir estratégia para feed vazio:
  - [x] conteúdo inicial/oficial;
  - [x] posts da comunidade com opt-in;
  - [x] dicas e onboarding;
  - [x] sugestões para catalogar o primeiro gato.
- [x] Não deixar o novo usuário diante de uma "cidade fantasma".

### 5.4 Critério de conclusão

O feed deve funcionar bem com crescimento de volume e não depender de uma rede de amigos já existente para ter conteúdo. (Concluído e validado com testes integrados de unidade e widgets).

---

# ETAPA 6 — Gamificação base: ativar o loop de hábito

**Prioridade: P1**

Só depois da captura e do resgate estarem sólidos vale transformar o uso diário em progressão.

O relatório aponta que existem widgets de gamificação prontos, mas XP/Níveis não possuem modelo, persistência ou endpoint. Também existem apenas 6 conquistas. fileciteturn2file0L192-L201

### 6.1 Fundamento de XP

- [ ] Criar modelo de XP.
- [ ] Persistir XP localmente.
- [ ] Criar sincronização/API.
- [ ] Ativar `GatalogoXPBar`.
- [ ] Criar níveis:
  - Curioso;
  - Explorador;
  - Observador;
  - Catalogador;
  - Guardião;
  - Protetor;
  - Lenda Felina.
- [ ] Definir recompensas por nível.

### 6.2 Streaks

- [ ] Criar streak diário.
- [ ] Ações qualificadoras:
  - fotografar;
  - registrar avistamento;
  - interagir no feed.
- [ ] Multiplicador progressivo.
- [ ] Escudo/congelamento semanal.
- [ ] Exibir streak na Home e perfil.

### 6.3 Missões

- [ ] 3 missões diárias.
- [ ] 1 missão semanal.
- [ ] Missão bônus eventual.
- [ ] Recompensar principalmente comportamentos que alimentam o matching/resgate.

### 6.4 Conquistas

- [ ] Corrigir progresso local da conquista `helper`.
- [ ] Adicionar celebração instantânea.
- [ ] Exibir `unlocked_at`.
- [ ] Permitir curtidas/comentários em conquistas publicadas.
- [ ] Criar compartilhamento visual.
- [ ] Expandir de 6 para 25+ conquistas.
- [ ] Criar conquistas para:
  - coleção;
  - consistência;
  - social;
  - resgate;
  - exploração;
  - pets/álbuns.

### 6.5 Critério de conclusão

Loop alvo:

**Fotografar → ganhar XP → avançar streak → completar missão → desbloquear conquista → compartilhar → receber reconhecimento → voltar amanhã**

---

# ETAPA 7 — Grafo social e crescimento da comunidade

**Prioridade: P1**

O gargalo social identificado é exigir username exato. O relatório também aponta ausência de perfis públicos e de mecanismos de descoberta. fileciteturn2file0L279-L304

### 7.1 Descoberta de amigos

- [ ] QR Code de perfil.
- [ ] Link de convite compartilhável.
- [ ] Busca por nome parcial/autocomplete.
- [ ] Mostrar convites enviados.
- [ ] Sugestões de pessoas.
- [ ] "Exploradores perto de você" de forma anônima/opt-in.
- [ ] Amigos em comum.

### 7.2 Perfis públicos

- [ ] Criar perfil público.
- [ ] Avatar.
- [ ] Bio.
- [ ] Nível/XP.
- [ ] Quantidade de gatos.
- [ ] Conquistas.
- [ ] Streak.
- [ ] Galeria pública com consentimento.
- [ ] Botão de mensagem.

### 7.3 Prova social

- [ ] Permitir interação em conquistas.
- [ ] Mostrar badges de raridade.
- [ ] Mostrar progresso relevante no perfil.
- [ ] Criar leaderboard semanal entre amigos somente após a base social estar funcionando.

### 7.4 Feed global

- [ ] Criar feed comunitário/global com opt-in.
- [ ] Definir privacidade e exposição de conteúdo.
- [ ] Criar conteúdo inicial para evitar cold start.

---

# ETAPA 8 — UX, qualidade de vida e retenção

**Prioridade: P1/P2**

Aqui entram melhorias importantes, mas que não devem bloquear o núcleo do produto.

### 8.1 Navegação

- [ ] Dar acesso direto a conversas.
- [ ] Separar Perfil de Configurações.
- [ ] Adicionar badges na navegação.
- [ ] Dar destaque visual ao botão central **Gatalogar**.
- [ ] Reduzir caminhos de 3–5 toques para ações frequentes.

### 8.2 Perfil e configurações

- [ ] Troca de senha logado.
- [ ] Troca de e-mail.
- [ ] Exportação de dados.
- [ ] Suporte/feedback/bug report.
- [ ] CTA claro de login para guest.
- [ ] Versão dinâmica via `package_info_plus`.

### 8.3 Feedback e atualização

- [ ] Pull-to-refresh em Home, Perfil, Feed, Notificações e Pistas.
- [ ] Tratamento global de erros.
- [ ] Retry consistente em operações de rede.
- [ ] Remover catches silenciosos.

### 8.4 Catálogo e coleção

- [ ] Filtros avançados.
- [ ] Favoritos sincronizados na nuvem.
- [ ] Notas/diário do gato.
- [ ] Histórico de reavistamentos.
- [ ] Reidentificação automática de gatos já catalogados.
- [ ] Visualização Pokédex com slots preenchidos/vazios.

### 8.5 Diferenciação visual

- [ ] Dark Mode.
- [ ] Saudação personalizada.
- [ ] "Gato do Dia".
- [ ] Cards colecionáveis com molduras de raridade.
- [ ] Avatar 3D quando a infraestrutura estiver pronta.

---

# ETAPA 9 — Metajogo 3D e diferenciação

**Prioridade: P2 / expansão**

Esta etapa só deve começar depois que o loop principal estiver funcionando. O relatório identifica centenas de assets GLB locais e propõe um metajogo de habitat, economia e coleção. fileciteturn4file0L9-L9

### 9.1 Habitat do gato

- [ ] Ativar `animal-cat.glb` como avatar 3D.
- [ ] Criar habitat/diorama individual.
- [ ] Variar o ambiente conforme contexto/localização.
- [ ] Aplicar variações visuais relacionadas à pelagem.
- [ ] Permitir decoração.

### 9.2 Economia

- [ ] Criar CatCoins.
- [ ] Recompensar catalogação, streaks e resgates.
- [ ] Criar loja.
- [ ] Adicionar itens de comida e decoração.
- [ ] Criar progressão de itens.

### 9.3 Coleção e troféus

- [ ] Transformar Journey em sala de troféus.
- [ ] Criar celebrações/unboxing visuais.
- [ ] Criar troféus por raridade.
- [ ] Criar recompensa visual especial para resgates reais.

### 9.4 Loop 3D

**Fotografar gato real → ganhar XP/moedas → visitar habitat → comprar item → decorar gato → compartilhar diorama → receber interação social → voltar a catalogar**

---

# Itens transversais — fazer continuamente

Esses itens não precisam ficar presos a uma única etapa:

- [ ] Testes unitários para lógica crítica.
- [ ] Testes de integração dos fluxos de autenticação.
- [ ] Testes de push Android/iOS.
- [ ] Testes de offline/online e sincronização.
- [ ] Logging de erros.
- [ ] Monitoramento de crashes.
- [ ] Validação de acessibilidade.
- [ ] Testes de performance do feed.
- [ ] Testes de privacidade da localização.
- [ ] Verificação de estados vazios/loading/error.
- [ ] Remover código morto e widgets órfãos quando sua função tiver sido substituída.
- [ ] Consolidar componentes duplicados da Home (`GatalogoCard`, `GatalogoStatCard`, `GatalogoProgressBar` etc.).

---

# Ordem resumida de execução

## Sprint/Bloco 1 — "Pode lançar?"

1. Apple Sign-In.
2. Termos/Privacidade.
3. Push multiplataforma.
4. Correção do fluxo de desativação.
5. Correções de mocks/estados falsos.
6. Correções dos bugs críticos de UI/navegação.
7. Sessão expirada e tratamento de erros críticos.

## Sprint/Bloco 2 — "Consigo catalogar?"

8. Galeria.
9. Retry de análise.
10. Feedback de rejeição.
11. Overlay das poses.
12. Bounding box.
13. Correção das fotos adicionais.
14. Share real do gato.

## Sprint/Bloco 3 — "Consigo encontrar um gato perdido?"

15. Busca de endereço.
16. Privacidade da localização.
17. Alerta de emergência simplificado.
18. Mapa consolidado.
19. Avistamento manual.
20. Cartaz digital.
21. Geofencing.

## Sprint/Bloco 4 — "Consigo coordenar o resgate?"

22. Inbox.
23. Foto no chat.
24. Localização no chat.
25. Ficha de gato no chat.
26. Read receipts.
27. Status online.
28. Typing indicator.
29. Otimização WebSocket.

## Sprint/Bloco 5 — "O social aguenta crescer?"

30. CDN/multipart.
31. Paginação.
32. Cache de imagens.
33. Share externo real.
34. Feed global/cold start.
35. QR Code/link de convite.
36. Busca de amigos.

## Sprint/Bloco 6 — "Por que volto amanhã?"

37. XP.
38. Níveis.
39. Streaks.
40. Missões.
41. Celebração de conquistas.
42. Expansão de conquistas.
43. Recompensas ligadas a resgate.

## Sprint/Bloco 7 — "Quero conhecer outras pessoas"

44. Perfis públicos.
45. Discovery social.
46. Feed comunitário.
47. Badges.
48. Prova social.
49. Leaderboard.

## Sprint/Bloco 8 — "Vamos polir"

50. Dark Mode.
51. Gato do Dia.
52. Cards colecionáveis.
53. Pokédex visual.
54. Pull-to-refresh.
55. Favoritos sincronizados.
56. Diário/notas.
57. Reidentificação.
58. Tratamento global de erros.
59. Componentes compartilhados/limpeza arquitetural.

## Sprint/Bloco 9 — "Metajogo"

60. Avatar 3D.
61. Habitat.
62. CatCoins.
63. Loja.
64. Decoração.
65. Troféus 3D.
66. Compartilhamento do diorama.

---

# Dependências importantes

### XP antes de recompensas complexas

**XP/Níveis → Streaks → Missões → Conquistas expandidas → Economia/CatCoins → Habitat 3D**

### Social antes de competição

**Inbox + perfis + discovery → prova social → leaderboard**

### Infraestrutura antes de escala

**CDN/multipart + paginação + cache → feed global → maior volume de conteúdo**

### Resgate antes de gamificação avançada

**Localização + alerta + mapa + chat com foto/GPS → geofencing → recompensas por resgate**

---

# O que NÃO fazer cedo

Para evitar dispersão:

- Não começar pelo metajogo 3D.
- Não criar leaderboard antes de existir uma comunidade ativa.
- Não investir pesado em stickers/áudio/documentos antes de foto + localização no chat.
- Não expandir dezenas de conquistas antes de existir XP/streak/missões.
- Não criar feed global antes de corrigir Base64, paginação e cache.
- Não polir excessivamente telas enquanto existirem mocks que afirmam que algo foi feito quando não foi.

---

# Resultado esperado

Ao final das etapas prioritárias, o Gatálogo deve ter este ciclo funcional:

**Descobrir gato → Fotografar → IA analisa → Catalogar → Ganhar progresso → Compartilhar → Conhecer/conectar com outros usuários → Receber/registrar avistamento → Comunicar foto + localização → Encontrar gato perdido → Receber reconhecimento → Voltar a catalogar.**

O relatório identifica justamente esse ciclo como a direção estratégica do produto: aumentar a frequência de fotografias, tornar o social útil e acessível, recompensar a participação em resgates e eliminar os dead-ends. fileciteturn1file4L197-L209

---

## Fonte

Este roadmap foi organizado exclusivamente a partir do relatório **Relatório de Análise Completa — Gatálogo**, incluindo a matriz de prioridades, problemas técnicos/UX, análise de gamificação/social e proposta de metajogo 3D. A matriz original separa itens em crítica, alta e média prioridade; este documento reorganiza esses itens por **dependência funcional e ordem de implementação**, agrupando correções e adições relacionadas. fileciteturn1file2L93-L139
