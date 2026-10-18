"""Read the triangle meshes and palette textures used by the Habitat asset tools."""

import json
import struct
from functools import lru_cache
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


@lru_cache(maxsize=64)
def read_document(path: Path) -> tuple[dict, bytes]:
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<III", data)
    if magic != 0x46546C67 or version != 2 or total != len(data):
        raise ValueError(f"Expected a GLB 2.0 file: {path}")
    json_size = struct.unpack_from("<I", data, 12)[0]
    document = json.loads(data[20:20 + json_size])
    binary = data[28 + json_size:]
    return document, binary


def sample_channel(times, values, time, *, rotation=False, interpolation="LINEAR"):
    """Sample glTF node transforms; quaternion interpolation follows glTF 2.0."""
    if interpolation not in ("LINEAR", "STEP"):
        raise ValueError(f"Unsupported animation interpolation: {interpolation}")
    index = max(0, min(int(np.searchsorted(times, time, side="right")) - 1, len(times) - 1))
    a = values[index].astype(float)
    if index == len(times) - 1 or interpolation == "STEP":
        return a
    weight = float(np.clip((time - times[index]) / (times[index + 1] - times[index]), 0, 1))
    b = values[index + 1].astype(float)
    if rotation:
        a /= np.linalg.norm(a)
        b /= np.linalg.norm(b)
        dot = float(a @ b)
        if dot < 0:
            b, dot = -b, -dot
        if dot < 0.9995:
            angle = np.arccos(np.clip(dot, -1, 1))
            return (np.sin((1 - weight) * angle) * a + np.sin(weight * angle) * b) / np.sin(angle)
    result = a * (1 - weight) + b * weight
    return result / np.linalg.norm(result) if rotation else result


def load_model(path: Path, *, animation: str | None = None, time: float = 0,
               ground: float | None = None, rotation: int = 0, play_time: float | None = None,
               flight_time: float | None = None) -> list[Mesh]:
    document, binary = read_document(path)

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

    poses = {}
    if animation is not None:
        clip = next((clip for clip in document.get("animations", []) if clip["name"] == animation), None)
        if clip is None:
            raise ValueError(f"Animation {animation!r} not found in {path}")
        for channel in clip["channels"]:
            sampler = clip["samplers"][channel["sampler"]]
            target = channel["target"]
            property_name = target["path"]
            if property_name not in ("translation", "rotation", "scale"):
                raise ValueError(f"Unsupported animated property: {property_name}")
            poses.setdefault(target["node"], {})[property_name] = sample_channel(
                accessor(sampler["input"]).ravel(), accessor(sampler["output"]), time,
                rotation=property_name == "rotation", interpolation=sampler.get("interpolation", "LINEAR"),
            )
    if play_time is not None:
        # Two deliberate paw taps separated by observation, with a stable body.
        for index, node in enumerate(document["nodes"]):
            if node.get("name") not in ("leg-front-left", "leg-front-right"):
                continue
            start = 0.6 if node["name"].endswith("left") else 2.1
            phase = (play_time - start) / 0.7
            lift = float(np.sin(np.pi * phase)) if 0 < phase < 1 else 0.0
            translation = np.array(node.get("translation", [0, 0, 0]), dtype=float)
            translation += [0, 0.15 * lift, -0.1 * lift]
            poses.setdefault(index, {})["translation"] = translation
    if flight_time is not None:
        for index, node in enumerate(document['nodes']):
            if node.get('name') not in ('wing-left', 'wing-right'):
                continue
            side = 1 if node['name'].endswith('left') else -1
            angle = side * (.25 + .55 * np.sin(flight_time * 2 * np.pi / .25))
            x, y, z, w = node.get('rotation', [0, 0, 0, 1])
            s, c = np.sin(angle / 2), np.cos(angle / 2)
            poses.setdefault(index, {})['rotation'] = [c*x-s*y, c*y+s*x, c*z+s*w, c*w-s*z]
    meshes = []

    def visit(index: int, parent: np.ndarray) -> None:
        node = document["nodes"][index] | poses.get(index, {})
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
                    if "uri" in image:
                        texture = path.parent / image["uri"]
                    else:
                        import hashlib
                        view = document['bufferViews'][image['bufferView']]
                        start = view.get('byteOffset', 0)
                        data = binary[start:start+view['byteLength']]
                        texture = Path(__file__).resolve().parents[1] / 'build/model-textures' / (hashlib.sha256(data).hexdigest()+'.png')
                        texture.parent.mkdir(parents=True, exist_ok=True)
                        if not texture.exists(): texture.write_bytes(data)
                meshes.append(Mesh(
                    positions, normals, accessor(attributes["TEXCOORD_0"]),
                    indices.reshape(-1, 3), texture,
                    np.array(material.get("baseColorFactor", [1, 1, 1, 1])),
                ))
        for child in node.get("children", []):
            visit(child, transform)

    for index in document["scenes"][document.get("scene", 0)]["nodes"]:
        visit(index, np.eye(4))
    if ground is None:
        ground = min(mesh.positions[:, 1].min() for mesh in meshes)
    angle = rotation * np.pi / 2
    turn = np.array([[np.cos(angle), 0, -np.sin(angle)], [0, 1, 0], [np.sin(angle), 0, np.cos(angle)]])
    for mesh in meshes:
        mesh.positions[:, 1] -= ground
        mesh.positions = mesh.positions @ turn.T
        mesh.normals = mesh.normals @ turn.T
    return meshes
