# Revisão visual: referências cozy

As 14 imagens reunidas pela usuária em `C:/Users/Evelynn_Doescher/Downloads/refs` foram inspecionadas em 28/09/2026. Elas orientam a linguagem visual; não foram copiadas para os assets do aplicativo.

## O que as referências acrescentam

| Referência | Princípio aplicado |
| --- | --- |
| `1c2392e7-ddd1-40de-a653-ee288c72947b.jfif` e `23e74610318576198f0430530a579c87.jpg` | Caderno como organização da interface: encadernação, páginas, abas e fotos presas com fita. |
| `051d7ff6911dddd82d499ea1ff5b1b79.jpg` e `8d44895be0ed9b2476f8ffbb0d824182.jpg` | Contornos quentes, controles arredondados legíveis e recursos visíveis. |
| `f86e42f0-7287-424c-adef-131281709645.jfif` e `596d4c1f-9e8f-4901-bfce-d1d920a0b619.jfif` | Painéis de tarefas pertencem ao mundo do jogo, com condição, progresso e resultado no mesmo lugar. |
| `4c75ca40-dff7-4277-8963-78c0cff3f135.jfif` | Conteúdo e imagem têm prioridade; a moldura sustenta a leitura. |
| `c5154232-ce64-42f7-baba-9907798727b2.jfif` e `e3decb8b-4b1c-4697-a1e2-a7ef00fc716c.jfif` | Objetos e ambiente dão presença ao jogo. A entrada do Quintal usa os próprios assets já existentes. |

## Implementação desta rodada

- Home: caderno aberto com álbum e Quintal em páginas equivalentes, progresso confirmado, missão e ação Gatalogar.
- Coleção: abas de capítulos; desafios em páginas encadernadas, peças alcançáveis, medalhas e prêmios. Duas colunas em telas largas, uma em celulares.
- Resultado: foto em moldura de papel com fita, atributos, revisão, créditos confirmados e arte do item realmente liberado. Foto limitada em tablets.
- Captura: câmera e galeria como ações equivalentes, instruções em papel com contorno.
- Perfil: progresso em caderno e biografia como bilhete; removido atalho redundante para o próprio perfil no cabeçalho.
- Navegação: controles em papel com contorno; rosa identifica captura.
- Componentes: `GameNotebook`, `GameNote`, `GameTape`, `GamePhotoCard`, `GameButton`, `GameSeal`, `GameProgress` e `GameReward` em `lib/widgets/game_components.dart`.

O Quintal e a loja continuam com seus controles e organização existentes. A pequena vinheta da Home é uma porta de entrada ilustrada, não uma representação do layout salvo. As fotos reais do acervo continuam aparecendo no aplicativo; a ilustração usada no teste é uma substituição declarada.

## Evidência e limites

As capturas em `build/restructure/` são renderizações dos widgets Flutter, com fontes empacotadas e dados sintéticos. Foram exercitadas larguras de 320, 390 e 820 pixels e texto em 100% e 150%. Não são screenshots de aparelho e não comprovam som, câmera, gestos nem integração nativa.

A revisão independente registrou **disposition: recapture** para a evidência nativa. ADB não encontrou aparelho conectado e o SDK local não tem executável do emulador. Também não há validação iOS. Isso permanece uma etapa necessária antes de declarar a versão pronta para distribuição.

As duas correções visuais apontadas nessa revisão foram aplicadas: material coerente em Captura/Perfil e espaço para o título do Perfil em celular estreito. Os logs de execução atualizados ficam em `build/restructure-all-tests.log`, `build/restructure-final-visual.log`, `build/restructure-analyze.log` e `build/restructure-apk.log`.

Esta revisão não equivale à conclusão de todas as etapas do plano, nem à aprovação visual da usuária ou ao estudo de compreensão previsto para a liberação da nova economia.
