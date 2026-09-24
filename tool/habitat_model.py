"""Read the triangle meshes and palette textures used by the Habitat asset tools."""

import json
import struct
from dataclasses import dataclass
from pathlib import Path

import numpy as np

COMPONENTS = {5121: "u1", 5123: "<u2", 5125: "<u4", 5126: "<f4"}
WIDTHS = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}


@dataclass
class Mesh:
    positions: np.ndarray
    normals: np.ndarray
    uv: np.ndarray
    indices: np.ndarray
    texture: Path | None
    color: np.ndarray


def load_model(path: Path) -> list[Mesh]:
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<III", data)
    if magic != 0x46546C67 or version != 2 or total != len(data):
        raise ValueError(f"Expected a GLB 2.0 file: {path}")
    json_size = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + json_size])
    binary = data[28 + json_size:]

    def accessor(index: int) -> np.ndarray:
        entry = document["accessors"][index]
        view = document["bufferViews"][entry["bufferView"]]
        dtype = np.dtype(COMPONENTS[entry["componentType"]])
        width = WIDTHS[entry["type"]]
        return np.ndarray(
            (entry["count"], width), dtype=dtype, buffer=binary,
            offset=view.get("byteOffset", 0) + entry.get("byteOffset", 0),
            strides=(view.get("byteStride", width * dtype.itemsize), dtype.itemsize),
        )

    meshes = []

    def visit(index: int, parent: np.ndarray) -> None:
        node = document["nodes"][index]
        if "matrix" in node:
            local = np.array(node["matrix"]).reshape(4, 4).T
        else:
            x, y, z, w = node.get("rotation", [0, 0, 0, 1])
            local = np.eye(4)
            local[:3, :3] = np.array([
                [1 - 2 * (y*y + z*z), 2*(x*y - z*w), 2*(x*z + y*w)],
                [2*(x*y + z*w), 1 - 2*(x*x + z*z), 2*(y*z - x*w)],
                [2*(x*z - y*w), 2*(y*z + x*w), 1 - 2*(x*x + y*y)],
            ]) @ np.diag(node.get("scale", [1, 1, 1]))
            local[:3, 3] = node.get("translation", [0, 0, 0])
        transform = parent @ local
        if "mesh" in node:
            for primitive in document["meshes"][node["mesh"]]["primitives"]:
                if primitive.get("mode", 4) != 4:
                    raise ValueError(f"Expected triangle mesh: {path}")
                attributes = primitive["attributes"]
                positions = accessor(attributes["POSITION"])
                positions = (np.column_stack([positions, np.ones(len(positions))]) @ transform.T)[:, :3]
                normals = accessor(attributes["NORMAL"]) @ np.linalg.inv(transform[:3, :3])
                normals /= np.linalg.norm(normals, axis=1, keepdims=True).clip(1e-9)
                indices = accessor(primitive["indices"]).ravel() if "indices" in primitive else np.arange(len(positions))
                material = document.get("materials", [{}])[primitive.get("material", 0)].get("pbrMetallicRoughness", {})
                texture = None
                if "baseColorTexture" in material:
                    image_index = document["textures"][material["baseColorTexture"]["index"]]["source"]
                    image = document["images"][image_index]
                    if "uri" not in image:
                        raise ValueError(f"Expected an external palette texture: {path}")
                    texture = path.parent / image["uri"]
                meshes.append(Mesh(
                    positions, normals, accessor(attributes["TEXCOORD_0"]),
                    indices.reshape(-1, 3), texture,
                    np.array(material.get("baseColorFactor", [1, 1, 1, 1])),
                ))
        for child in node.get("children", []):
            visit(child, transform)

    for index in document["scenes"][document.get("scene", 0)]["nodes"]:
        visit(index, np.eye(4))
    ground = min(mesh.positions[:, 1].min() for mesh in meshes)
    for mesh in meshes:
        mesh.positions[:, 1] -= ground
    return meshes
