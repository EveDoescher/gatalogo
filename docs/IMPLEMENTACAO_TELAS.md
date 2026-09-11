# Implementação dos fluxos do Gatálogo

Referência: GATALOGO_DOCUMENTACAO_TELAS.md fornecida pelo responsável pelo produto.
O tema Material 3 existente foi preservado. A comparação de imagens, pontuações e modo de avaliação não são apresentados ao jogador.

## Cobertura

| Identificador | Fluxo implementado | Código principal |
| --- | --- | --- |
| AUTH-01 | Entrar com e-mail, Google ou continuar localmente | lib/pages/auth_page.dart |
| AUTH-02 | Cadastro com confirmação de senha | lib/pages/auth_page.dart |
| AUTH-03 | Confirmação de e-mail, seis dígitos e reenvio com espera | lib/pages/auth_page.dart |
| AUTH-04 | Solicitar recuperação de senha | lib/pages/auth_page.dart |
| AUTH-05 | Verificar código e obter autorização temporária | lib/pages/auth_page.dart |
| AUTH-06 | Nova senha, autorização de uso único e revogação de sessões | lib/pages/auth_page.dart |
| MAIN-01 | Home, coleção recente, atalhos e indicador de notificações | lib/pages/home_page.dart |
| MAIN-02 | Preparação da captura e dicas | lib/pages/capture_page.dart |
| MAIN-03 | Câmera nativa do aparelho, via image_picker | lib/pages/capture_page.dart |
| MAIN-04 | Revisão, pré-filtro local, salvar e abrir descoberta | lib/pages/capture_page.dart |
| COL-01 | Coleção separada dos gatos próprios, busca e filtros | lib/pages/library_page.dart |
| COL-02 | Detalhe, nome, pelagem, localização, nova tentativa e exclusão | lib/pages/cat_details_page.dart |
| COL-03 | Galeria privada com ampliação e gestão das referências | lib/pages/cat_gallery_page.dart |
| PET-01 | Meus gatos, referências e indicação de alerta ativo | lib/pages/my_cats_page.dart |
| PET-02 | Cadastro de gato próprio com nome e foto | lib/pages/my_cats_page.dart |
| PET-03 | Perfil, edição, foto principal, referências e desaparecimento | lib/pages/my_cats_page.dart |
| PET-04 | Gestão de fotos de frente, esquerda, direita e costas | lib/pages/cat_gallery_page.dart |
| GAME-01 | Jornada, marcos, conquistas duráveis e compartilhamento explícito | lib/pages/journey_page.dart |
| EXP-01 | Mapa OSM, ponto, raio, data e observação do avistamento | lib/pages/location_page.dart |
| LOST-01 | Alertas ativos e concluídos | lib/pages/missing_cats_page.dart |
| LOST-02 | Criar alerta a partir de um gato próprio | lib/pages/missing_cats_page.dart |
| LOST-03 | Detalhe, mapa, ajuste de área e encerramento com histórico | lib/pages/missing_cats_page.dart |
| LOST-04 | Pistas com foto e distância aproximada | lib/pages/missing_cats_page.dart |
| LOST-05 | Detalhe da pista, reconhecer, descartar e contato permitido | lib/pages/missing_cats_page.dart |
| SOC-01 | Usuário social, convites, amizades e conquistas compartilhadas | lib/pages/social_page.dart |
| SOC-02 | Conversas entre amigos, contato e contexto de avistamento | lib/pages/conversation_page.dart |
| SOC-03 | Caixa de entrada, leitura e abertura do destino relacionado | lib/pages/notifications_page.dart |
| SET-01 | Conta, preferências, sincronização, senha, saída e desativação | lib/pages/account_page.dart |

As etapas de autenticação e captura são estados de fluxos compartilhados. As telas PET-04 e COL-03 reutilizam a galeria. Não foram criadas rotas vazias apenas para reproduzir os identificadores.

## Persistência e integração

- Banco local na versão 11, com classificação de gato próprio. Cadastros antigos continuam como descobertas; não há inferência de propriedade.
- Fotos, nomes, referências, exclusões e avistamentos são persistidos antes da rede.
- Avistamentos manuais guardam data, coordenadas e observação até o servidor confirmar; repetir o envio não cria outra ocorrência do mesmo evento.
- Dados de contas diferentes são filtrados localmente. Uma falha de conexão não remove uma sessão local já conhecida.
- A API fornece os dados das pistas e miniaturas autorizadas, removendo metadados EXIF das imagens entregues.
- A API impede alertas para descobertas comuns e reutiliza um alerta ativo existente do mesmo gato.
- Reconhecer uma pista não encerra automaticamente o alerta.
- Conquistas compartilhadas são publicadas apenas por uma ação explícita.
- A recuperação de senha separa verificação do código e definição da senha. A autorização expira e só pode ser usada uma vez.
- Migração da API necessária: 20260908_05.

## Decisões de produto

- A navegação principal tem Início, Gatalogar e Coleção.
- A galeria do aparelho só é oferecida para cadastrar ou trocar a foto de um gato próprio. A descoberta usa câmera.
- Os controles de flash, zoom e troca de câmera dependem da câmera nativa do aparelho.
- A aparência da pelagem usa descrições; o jogador não recebe diagnósticos, percentuais de identidade ou estados internos do reconhecimento.
- Atualmente há uma foto principal e uma referência por ângulo. Substituir uma referência mantém o ângulo identificado.
- Quatro marcos iniciais: primeira descoberta, fotos complementares, registros em dias distintos e contribuição reconhecida em uma busca.

## Configuração externa e limites de validação

- Google depende de credenciais OAuth válidas do projeto.
- E-mail real depende do SMTP configurado na API.
- A caixa de notificações interna está implementada; entrega push pelo Android/iOS e abertura do app a partir do push ainda precisam de integração/configuração do provedor. Registrar um token no servidor, por si só, não envia push.
- As preferências de avisos são guardadas por conta; o histórico da caixa de entrada permanece disponível.
- A API e os workers de análise/reconhecimento precisam estar em execução com banco migrado, modelos e armazenamento disponíveis.
- O reconhecimento conserva sua configuração de avaliação e critérios conservadores. As telas não alteram os critérios nem comprovam precisão biométrica. Não foram usados CSV/JSON preexistentes como identidades verdadeiras.
- Os testes de interface usam dados artificiais apenas para conferir navegação, separação de áreas e layout.
- Câmera, GPS, login Google, entrega de e-mail e uso com dois aparelhos devem ser conferidos em dispositivos reais. Não havia emulador Android configurado neste ambiente.

## Roteiro de teste manual

1. Continuar sem conta, gatalogar um gato e abrir o detalhe salvo. Reiniciar sem internet e conferir a foto.
2. Editar o nome e registrar um avistamento com data e observação offline. Reconectar à conta e conferir o envio.
3. Abrir Meus gatos, cadastrar um animal e adicionar fotos de diferentes ângulos. Confirmar que ele não aparece na Coleção.
4. Declarar esse gato desaparecido, escolher ponto e raio, abrir o alerta e ajustar a área.
5. Com outra conta, cadastrar uma foto diferente na região e aguardar os workers. Conferir possíveis pistas quando a API produzir uma sugestão.
6. Abrir a pista, conferir foto e contexto, reconhecer ou descartar. Confirmar que o alerta permanece ativo até encerramento explícito.
7. Adicionar um amigo pelo nome de usuário, aceitar o convite, conversar e abrir a mensagem pela caixa de entrada.
8. Abrir Jornada e compartilhar uma conquista desbloqueada. Conferir que nenhuma foto privada foi publicada.
9. Testar recuperação de senha, código incorreto, reenvio e tentativa de reutilizar a autorização consumida.


## Endereço da API no APK de desenvolvimento

O endereço padrão é http://10.0.2.2:8000, usado pelo emulador Android para alcançar o computador.
Para testar a API em um celular físico, gere o app com o endereço acessível na rede do aparelho:

```text
flutter run --dart-define=API_BASE_URL=http://ENDERECO_DO_SERVIDOR:8000
```

O modo local pode ser testado sem API. Um APK compilado não significa que câmera, GPS, Google ou push tenham sido testados em um aparelho real.


## Validação desta entrega

- API: 73 testes aprovados, incluindo PostgreSQL descartável com todas as migrações.
- Flutter: 11 testes funcionais aprovados; prévia visual executada separadamente com fonte e ícones.
- Análise estática Flutter: sem problemas.
- Layout conferido em 360 e 820 pixels, com texto ampliado; Home e perfil de gato renderizados e inspecionados.
- APK Android de desenvolvimento compilado. A configuração de assinatura permanece a de desenvolvimento.
