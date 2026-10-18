# Verificação direta das fotos

Todas as evidências foram recalculadas dos pixels. Nenhuma planilha, CSV ou JSON anterior foi usado.

**As identidades são desconhecidas.** Estes números não medem acurácia nem probabilidade de ser o mesmo gato.

| Foto | Qualidade técnica | Detalhes locais | Patches do gato |
|---|---:|---:|---:|
| [IMG_20240907_203726.jpg](C:/Users/Evelynn_Doescher/Documents/Projetos/flutter/gatalogo-ai-api/data/own-cats/images/IMG_20240907_203726.jpg) | 0.998 | 82 | 192 |
| [IMG_20240907_203728.jpg](C:/Users/Evelynn_Doescher/Documents/Projetos/flutter/gatalogo-ai-api/data/own-cats/images/IMG_20240907_203728.jpg) | 0.977 | 56 | 192 |
| [IMG_20250207_185323.jpg](C:/Users/Evelynn_Doescher/Documents/Projetos/flutter/gatalogo-ai-api/data/own-cats/images/IMG_20250207_185323.jpg) | 0.897 | 20 | 192 |
| [IMG_20260213_162801.jpg](C:/Users/Evelynn_Doescher/Documents/Projetos/flutter/gatalogo-ai-api/data/own-cats/images/IMG_20260213_162801.jpg) | 0.998 | 143 | 192 |
| [IMG_20250504_133623.jpg](C:/Users/Evelynn_Doescher/Documents/Projetos/flutter/gatalogo-ai-api/data/own-cats/images/IMG_20250504_133623.jpg) | 1.000 | 108 | 192 |
| [IMG_20250504_133627.jpg](C:/Users/Evelynn_Doescher/Documents/Projetos/flutter/gatalogo-ai-api/data/own-cats/images/IMG_20250504_133627.jpg) | 1.000 | 100 | 192 |

| Fotos | Global | Densa | Pares densos distintos | Inliers densos | Geometria densa | Inliers RootSIFT | Quase duplicada |
|---|---:|---:|---:|---:|---|---:|---|
| IMG_20240907_203726 / IMG_20240907_203728 | 0.8355 | 0.8686 | 5 | 0 | não | 0 | não |
| IMG_20240907_203726 / IMG_20250207_185323 | 0.2349 | 0.5389 | 0 | 0 | não | 0 | não |
| IMG_20240907_203726 / IMG_20260213_162801 | 0.3410 | 0.6836 | 1 | 0 | não | 0 | não |
| IMG_20240907_203726 / IMG_20250504_133623 | 0.5830 | 0.7394 | 2 | 0 | não | 0 | não |
| IMG_20240907_203726 / IMG_20250504_133627 | 0.5753 | 0.7546 | 1 | 0 | não | 0 | não |
| IMG_20240907_203728 / IMG_20250207_185323 | 0.2725 | 0.5411 | 0 | 0 | não | 0 | não |
| IMG_20240907_203728 / IMG_20260213_162801 | 0.2433 | 0.6269 | 1 | 0 | não | 0 | não |
| IMG_20240907_203728 / IMG_20250504_133623 | 0.5349 | 0.7365 | 0 | 0 | não | 0 | não |
| IMG_20240907_203728 / IMG_20250504_133627 | 0.5120 | 0.7437 | 1 | 0 | não | 0 | não |
| IMG_20250207_185323 / IMG_20260213_162801 | 0.4230 | 0.5834 | 1 | 0 | não | 0 | não |
| IMG_20250207_185323 / IMG_20250504_133623 | 0.3212 | 0.5242 | 0 | 0 | não | 0 | não |
| IMG_20250207_185323 / IMG_20250504_133627 | 0.3248 | 0.5261 | 0 | 0 | não | 0 | não |
| IMG_20260213_162801 / IMG_20250504_133623 | 0.4356 | 0.6805 | 1 | 0 | não | 0 | não |
| IMG_20260213_162801 / IMG_20250504_133627 | 0.4613 | 0.6742 | 2 | 0 | não | 0 | não |
| IMG_20250504_133623 / IMG_20250504_133627 | 0.9515 | 0.9324 | 9 | 6 | não | 19 | não |

Detalhes locais ausentes são inconclusivos, especialmente com pelagem uniforme ou mudança de pose. Geometria consistente também não comprova identidade.
As correspondências densas também são semânticas: regiões comuns a gatos diferentes podem ser semelhantes. Somente uma avaliação com identidade conhecida permite calibrar esse sinal.
Para avaliar identificação entre dias e ambientes será necessário confirmar os indivíduos e separar fotos de cadastro das fotos de teste.
