"""Render selected original models from the 3D branch without changing checkout."""
from pathlib import Path, PurePosixPath
import json, posixpath
import numpy as np
from functools import lru_cache
from PIL import Image
from build_model_asset_gallery import GitAssets
from habitat_model import load_model, read_document, Mesh
from render_habitat_models import framing, render_meshes

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/quintal/production"
CACHE = ROOT / "build/quintal-models"
NAMES = ["crops_cornStageA", "crops_cornStageB", "crops_cornStageC", "crops_cornStageD", "crops_wheatStageA", "crops_wheatStageB", "crops_leafsStageA", "crops_leafsStageB", "crops_dirtSingle", "crop_carrot", "crop_turnip", "crop_pumpkin", "crop_melon", "structure-platform-dock", "platform-planks", "structure-fence", "structure-fence-sides", "animal-chick", "animal-cow", "egg", "carton", "fish", "pot-stew", "apple", "pear", "turkey", "meat-raw"]

@lru_cache(maxsize=1)
def chick_reference():
    return load_model(next(CACHE.rglob('animal-chick.glb')))


@lru_cache(maxsize=2)
def feather_palette(variant):
    target = OUT / ('hen-' + variant + '-palette.png')
    image = np.array(Image.open(chick_reference()[2].texture).convert('RGBA'))
    yellow = (image[:, :, 0] > 150) & (image[:, :, 1] > 105) & (image[:, :, 2] < 100)
    image[yellow, :3] = [244, 237, 213] if variant == 'white' else [161, 98, 51]
    Image.fromarray(image).save(target)
    return target


@lru_cache(maxsize=1)
def chick_tuft_vertices():
    """Identify separate feather geometry without cutting the head's top face."""
    mesh = chick_reference()[2]
    parents = list(range(len(mesh.positions)))
    def root(i):
        while parents[i] != i:
            parents[i] = parents[parents[i]]
            i = parents[i]
        return i
    welded = {}
    for i, point in enumerate(mesh.positions):
        key = tuple(np.round(point, 5))
        if key in welded:
            parents[root(i)] = root(welded[key])
        else:
            welded[key] = i
    for a, b, c in mesh.indices:
        parents[root(b)] = root(a)
        parents[root(c)] = root(a)
    groups = {}
    for i in range(len(parents)):
        groups.setdefault(root(i), []).append(i)
    mask = np.zeros(len(parents), dtype=bool)
    for indices in groups.values():
        if mesh.positions[indices, 1].min() > 1.2:
            mask[indices] = True
    return mask


def comb_mesh(transform):
    """Three low-poly teeth follow the same rigid animated head as the face."""
    vertices, faces = [], []
    for z, height in [(-.19, .18), (0, .25), (.19, .19)]:
        base = len(vertices)
        vertices.extend([[-.065, 1.42, z-.12], [.065, 1.42, z-.12],
                         [-.065, 1.42+height, z], [.065, 1.42+height, z],
                         [-.065, 1.42, z+.12], [.065, 1.42, z+.12]])
        faces.extend([[base+i for i in face] for face in
                      [(0,2,4),(1,5,3),(0,1,3),(0,3,2),(2,3,5),(2,5,4),(0,4,5),(0,5,1)]])
    vertices = np.array(vertices)
    vertices = np.column_stack([vertices, np.ones(len(vertices))]) @ transform
    points = vertices[np.array(faces)].reshape(-1, 3)
    triangles = points.reshape(-1, 3, 3)
    normals = np.cross(triangles[:,1]-triangles[:,0], triangles[:,2]-triangles[:,0])
    normals /= np.linalg.norm(normals, axis=1, keepdims=True).clip(1e-9)
    return Mesh(points, np.repeat(normals, 3, axis=0), np.zeros((len(points),2)),
                np.arange(len(points)).reshape(-1,3), None, np.array([.78,.18,.15,1.]))


def adult(meshes, variant, direction=0):
    # Preserve the pack's square chick silhouette and its original animation.
    # Adult identity comes only from feather colors and a small red comb.
    rest = chick_reference()
    converted = []
    for index, mesh in enumerate(meshes):
        if index in (0, 1):
            converted.append(mesh)
            continue
        indices = mesh.indices.copy()
        if index == 2:
            # Replace the yellow tuft, but keep the square head and all face UVs.
            source = rest[2].positions
            indices = indices[~chick_tuft_vertices()[indices].any(axis=1)]
            beak = (source[indices,2] > .66).any(axis=1)
            converted.append(Mesh(mesh.positions.copy(), mesh.normals.copy(), mesh.uv.copy(),
                                  indices[beak], mesh.texture, mesh.color.copy()))
            indices = indices[~beak]
        converted.append(Mesh(mesh.positions.copy(), mesh.normals.copy(), mesh.uv.copy(),
                              indices, feather_palette(variant), mesh.color.copy()))
    body = np.linalg.lstsq(np.column_stack([rest[2].positions, np.ones(len(rest[2].positions))]),
                           meshes[2].positions, rcond=None)[0]
    converted.append(comb_mesh(body))
    return converted

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    git = GitAssets("feature/etapa9-3d-metagame")
    index = {}
    try:
        for name in NAMES:
            candidates = [p for p in git.paths if PurePosixPath(p).stem == name and p.endswith(".glb") and p.startswith("assets/")]
            if not candidates:
                print("Unavailable:", name)
                continue
            path = candidates[0]
            local = CACHE / path
            local.parent.mkdir(parents=True, exist_ok=True)
            local.write_bytes(git.read(path))
            doc, _ = read_document(local)
            for image in doc.get("images", []):
                if "uri" not in image: continue
                relative = posixpath.normpath(str(PurePosixPath(path).parent / image["uri"]))
                texture = CACHE / relative
                texture.parent.mkdir(parents=True, exist_ok=True)
                texture.write_bytes(git.read(relative))
            meshes = load_model(local)
            origin, scale = framing(meshes, size=320)
            render_meshes(meshes, origin, scale, size=320, supersample=2).save(OUT / (name + ".png"))
            index[name] = {"source": path, "origin": origin.tolist(), "scale": float(scale)}
            if name == "animal-chick":
                for variant in ("white", "brown"):
                    shape = adult(meshes, variant)
                    anchor, factor = framing(shape, size=320)
                    render_meshes(shape, anchor, factor, size=320, supersample=2).save(OUT / ("hen-" + variant + ".png"))
                    index["hen-" + variant] = {"source": path, "origin": anchor.tolist(), "scale": float(factor)}
        (OUT / "manifest.json").write_text(json.dumps(index, ensure_ascii=False, indent=2), encoding="utf-8")
        print("Rendered", len(index), "production assets")
    finally: git.close()

if __name__ == "__main__": main()

