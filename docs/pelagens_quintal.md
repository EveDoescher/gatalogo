# Pelagens dos gatos no Quintal

O Quintal conserva o modelo quadrado original do gato, sua escala e suas animações. A aparência aproxima a pelagem registrada pelo detector; não reconstrói manchas individuais da fotografia e não altera a análise do gato.

## Escolha pela ficha

`HabitatCatCoat.resolve` combina a cor principal, o tipo de pelagem e as cores secundárias. Há 35 variações nos grupos sólido, rajado, bicolor, tuxedo, tricolor, escaminha e colorpoint. O conjunto inclui explicitamente rajado cinza, laranja e branco, todo laranja e branco com manchas marrons.

A API envia `primary_color`, `coat_type` e `coat_colors` no snapshot do Quintal. Os campos principais da análise têm prioridade; `pattern_map` complementa dados ausentes. O armazenamento local preserva esses atributos para uso offline. Fichas antigas continuam compatíveis: cor conhecida sem padrão usa pelagem sólida; sem evidências utilizáveis, cinza sólido. Não há sorteio de aparência. Uma análise corrigida passa a valer ao atualizar o snapshot.

A mesma resolução é utilizada no cenário, na bandeja de gatos, durante o arraste, na ficha de cuidados e na brincadeira com a varinha.

## Modelo e renderização

`tool/render_quintal_cat_coats.py` lê o `animal-cat.glb` original da branch `feature/etapa9-3d-metagame`, com cache em `build/quintal-models`, sem trocar a branch de trabalho. As marcas são aplicadas às coordenadas de repouso do modelo: acompanham membros e poses em todas as orientações. Olhos, nariz, boca e interior das orelhas mantêm as cores originais.

O gerador produz prévias e oito animações para cada pelagem em `assets/habitat/cat_coats`. Dimensões, duração, enquadramento e sombras são compartilhados com o gato original. O chão de referência é fixo durante toda a animação, preservando saltos e oscilações.

O jogo carrega os sprites das pelagens presentes no cenário; movimentos adicionais são decodificados quando usados. Gatos da mesma pelagem compartilham os sprites e todas as variações compartilham as sombras originais.

## Galeria e verificações

`build/galeria-visual/pelagens/index.html` apresenta as 35 pelagens e permite alternar animações e orientações. A galeria de telas aponta para essa página. A captura `quintal_world_cat_coats.png` usa quatro gatos de demonstração exclusivamente no teste visual, sem modificar contas reais.

Os testes cobrem a resolução das combinações da taxonomia, compatibilidade do snapshot, preservação do enquadramento das animações e compartilhamento de sombras. O teste da API verifica a leitura dos atributos e sua atualização sem modificar a análise. A comparação dos canais alfa confirmou silhuetas idênticas ao original nos oito movimentos.
