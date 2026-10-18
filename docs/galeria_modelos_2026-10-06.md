# Galeria dos modelos — 2026-10-06

Inventário da branch `feature/etapa9-3d-metagame`, revisão `75e9b587bd756c203d549d433631d5624bb6ffba`.

Foram identificados 874 modelos únicos: versões GLB/GLTF, FBX e OBJ do mesmo asset são agrupadas. Há 20 categorias, filtro por pacote, busca por nome original e termos em português, janela de ampliação e cópia do caminho de origem. Modelos de exemplo de bibliotecas estão separados dos assets do jogo. Os dois modelos personalizados de gato estão identificados como Gatos do app.

868 modelos usam prévias originais do pacote, e seis usam renderização estática de sua geometria GLTF/GLB, incluindo texturas externas ou incorporadas. Todos os 874 PNGs foram decodificados e verificados como não vazios; caminhos únicos e contagens foram conferidos. O JavaScript passou na verificação de sintaxe do Node. A abertura automatizada do HTML local foi bloqueada pela política do navegador; não foi realizado teste interativo no navegador.

A escala da imagem é independente por modelo e as cores são originais. A galeria não representa animações nem a paleta aplicada no Quintal.

Saída: `build/galeria-visual/modelos/index.html`. Inventário: `build/galeria-visual/modelos/inventario.json`.

O link permanece em `test/support/visual_gallery.dart` para futuras atualizações da galeria de telas. Para regenerar: executar `tool/build_model_asset_gallery.py --ref feature/etapa9-3d-metagame` com o Python do ambiente da API, que contém NumPy e Pillow. A leitura ocorre diretamente pelo Git, sem trocar a branch ou importar todos os modelos para os assets do app.
