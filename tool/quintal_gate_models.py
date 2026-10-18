"""An articulated, full-width gate made from the original Kenney gate meshes."""
import numpy as np
from build_quintal_compositions import source
from habitat_model import Mesh
from quintal_model_authoring import Model, transform


def gate_post(side):
    model = Model()
    for index, mesh in enumerate(source('fence_gate', 'nature-kit')[:2]):
        xs = mesh.positions[mesh.indices, 0] * side
        faces = mesh.indices[np.all((xs >= .1499) & (xs <= .2201), axis=1)]
        if not len(faces):
            continue
        indices = np.unique(faces)
        lookup = {old: new for new, old in enumerate(indices)}
        selected = Mesh(mesh.positions[indices].copy(), mesh.normals[indices].copy(),
            mesh.uv[indices].copy(), np.array([[lookup[v] for v in f] for f in faces]),
            mesh.texture, mesh.color.copy())
        # Keep the original post width and palette; move it to the tile boundary.
        model.add(f'post-{index}', transform(selected, at=(side*.28, 0, 0), scale=(1,1.6,1)))
    return model


def gate_leaf(step):
    model = Model()
    pivot = np.array([-.43, 0, -.465])
    for index, mesh in enumerate(source('fence_gate', 'nature-kit')[2:]):
        widened = transform(mesh, scale=(.43/.15, 1.6, 1))
        local = transform(widened, at=-pivot)
        # Swing outward onto the path, away from the approaching resident.
        model.add(f'leaf-{index}', transform(local, at=pivot, angles=(0, step*22.5, 0)))
    return model
