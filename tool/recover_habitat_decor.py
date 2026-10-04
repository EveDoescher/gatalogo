"""Recover only approved GLBs, palettes, nature sprites and pack licenses."""

import subprocess
from pathlib import Path

from habitat_assets import DECORATIONS
from habitat_model import read_document

ROOT = Path(__file__).resolve().parents[1]
SOURCE = "feature/etapa9-3d-metagame"


def recover(relative):
    path = ROOT / relative
    if not path.exists():
        data = subprocess.check_output(["git", "show", f"{SOURCE}:{relative}"], cwd=ROOT)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    return path


def main():
    for asset in DECORATIONS:
        base = f"assets/3d_assets/{asset.pack}"
        model = recover(asset.model_path.as_posix())
        document, _ = read_document(model)
        for image in document.get("images", []):
            recover((model.parent / image["uri"]).relative_to(ROOT).as_posix())
        recover(f"{base}/License.txt")
        if asset.pack == "kenney_nature-kit":
            for direction in ("NE", "SE", "SW", "NW"):
                recover(f"{base}/Isometric/{asset.name}_{direction}.png")
    print(f"Recovered {len(DECORATIONS)} selected models with palettes and licenses")


if __name__ == "__main__":
    main()
