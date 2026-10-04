"""Record tight transparent bounds for the selected Kenney sprites.

Run with Pillow installed when source artwork changes. The app only ships the
generated JSON and PNG files; it does not need Python at runtime.
"""

import json
from pathlib import Path

from PIL import Image
from habitat_assets import DECORATIONS


ROOT = Path(__file__).resolve().parents[1] / "assets" / "3d_assets"
SPRITES = ROOT / "kenney_nature-kit" / "Isometric"
NAMES = (
    "ground_grass", "bed", "tree_default", "plant_bushSmall",
    "flower_redA", "flower_yellowA", "grass", "rock_smallA",
    "fence_simple", "ground_pathTile", "tree_oak", "plant_flatShort",
    "bed_floor",
    "log_large", "rock_largeA", "tree_detailed", "tree_pineTallA", "tree_pineDefaultA",
    "tent_smallOpen", "tent_detailedOpen", "path_stone",
    "path_stoneCorner", "path_stoneEnd", "path_stoneCircle",
    "path_wood", "path_woodCorner", "path_woodEnd",
    "fence_corner", "fence_gate",
) + tuple(asset.name for asset in DECORATIONS if asset.pack == 'kenney_nature-kit')


def bounds(path: Path) -> list[int]:
    with Image.open(path) as image:
        box = image.convert("RGBA").getchannel("A").getbbox()
    if box is None:
        raise ValueError(f"Sprite has no visible pixels: {path}")
    left, top, right, bottom = box
    return [left, top, right - left, bottom - top]


def main() -> None:
    manifest = {
        f"{name}_{direction}": bounds(SPRITES / f"{name}_{direction}.png")
        for name in NAMES
        for direction in ("NE", "NW", "SE", "SW")
    }
    manifest["animal-cat"] = bounds(
        ROOT.parent / "habitat" / "animal-cat.png"
    )
    for key, path in {
        "building-type-a": ROOT.parent / "habitat" / "building-type-a.png",
        "building-type-f": ROOT.parent / "habitat" / "building-type-f.png",
        "coin": ROOT / "kenney_mini-dungeon" / "Previews" / "coin.png",
        "chest": ROOT / "kenney_mini-dungeon" / "Previews" / "chest.png",
    }.items():
        manifest[key] = bounds(path)
    (SPRITES / "habitat_bounds.json").write_text(
        json.dumps(manifest, ensure_ascii=False, separators=(",", ":")),
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
