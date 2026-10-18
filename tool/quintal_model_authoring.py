"""Small, reproducible low-poly mesh tools for Quintal's original assets.

Coordinates are metres, Y up. Every component has an editable glTF node name.
The same meshes feed GLB export and the game's established offline renderer.
"""
from pathlib import Path
import json
import math
import struct
import numpy as np
from habitat_model import Mesh


def rgba(hex_color):
    return np.array([int(hex_color[i:i+2], 16)/255 for i in (0, 2, 4)] + [1.])


WOOD = rgba('b87951')
WOOD_LIGHT = rgba('d59b6b')
WOOD_DARK = rgba('855738')
CREAM = rgba('e7d3a2')
STRAW = rgba('cbb371')
WATER = rgba('86b5b2')
LEAF = rgba('779952')
SOIL = rgba('91633e')


def mesh_faces(vertices, faces, color):
    vertices = np.asarray(vertices, dtype=float)
    triangles = []
    for face in faces:
        for i in range(1, len(face)-1):
            triangles.append(vertices[[face[0], face[i], face[i+1]]])
    triangles = np.asarray(triangles)
    normals = np.cross(triangles[:, 1]-triangles[:, 0], triangles[:, 2]-triangles[:, 0])
    valid = np.linalg.norm(normals, axis=1) > 1e-10
    triangles, normals = triangles[valid], normals[valid]
    normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-10)
    positions = triangles.reshape(-1, 3)
    return Mesh(positions, np.repeat(normals, 3, axis=0), np.zeros((len(positions), 2)),
                np.arange(len(positions)).reshape(-1, 3), None, np.asarray(color))


def box(dims, color=WOOD, at=(0, 0, 0)):
    x, y, z = np.asarray(dims)/2
    v = np.array([[-x,-y,-z],[x,-y,-z],[x,y,-z],[-x,y,-z],
                  [-x,-y,z],[x,-y,z],[x,y,z],[-x,y,z]]) + at
    return mesh_faces(v, [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),
                           (3,7,6,2),(0,1,5,4)], color)


def bevel_box(dims, color=WOOD, at=(0,0,0), bevel=.02):
    """Small planar bevels catch light without smoothing away the pack's facets."""
    x,y,z=np.asarray(dims)/2
    b=min(bevel,x*.35,y*.35,z*.35)
    def ring(rx,rz,c,h):
        return [(rx-c,h,-rz),(rx,h,-rz+c),(rx,h,rz-c),(rx-c,h,rz),
                (-rx+c,h,rz),(-rx,h,rz-c),(-rx,h,-rz+c),(-rx+c,h,-rz)]
    vertices=ring(x-b,z-b,b*.45,-y)+ring(x,z,b,-y+b)+ring(x,z,b,y-b)+ring(x-b,z-b,b*.45,y)
    faces=[tuple(range(8)),tuple(range(31,23,-1))]
    for level in range(3):
        for i in range(8):
            j=(i+1)%8
            faces.append((level*8+i,(level+1)*8+i,(level+1)*8+j,level*8+j))
    return mesh_faces(np.asarray(vertices)+at,faces,color)


def transform(mesh, at=(0,0,0), angles=(0,0,0), scale=(1,1,1)):
    x,y,z = np.radians(angles)
    rx = np.array([[1,0,0],[0,math.cos(x),-math.sin(x)],[0,math.sin(x),math.cos(x)]])
    ry = np.array([[math.cos(y),0,math.sin(y)],[0,1,0],[-math.sin(y),0,math.cos(y)]])
    rz = np.array([[math.cos(z),-math.sin(z),0],[math.sin(z),math.cos(z),0],[0,0,1]])
    rotation = rz @ ry @ rx
    normals = mesh.normals / np.array(scale) @ rotation.T
    normals /= np.maximum(np.linalg.norm(normals, axis=1, keepdims=True), 1e-10)
    return Mesh(mesh.positions*np.array(scale) @ rotation.T + at, normals,
                mesh.uv.copy(), mesh.indices.copy(), mesh.texture, mesh.color.copy())


def lathe(profile, color, segments=10, aspect=(1,1), at=(0,0,0)):
    """Revolve (radius, height) cross section. Profile ordering controls normals."""
    vertices = [[r*math.cos(i*math.tau/segments)*aspect[0], y,
                 r*math.sin(i*math.tau/segments)*aspect[1]]
                for r,y in profile for i in range(segments)]
    faces = []
    for j in range(len(profile)-1):
        for i in range(segments):
            n = (i+1)%segments
            faces.append((j*segments+i,(j+1)*segments+i,(j+1)*segments+n,j*segments+n))
    return mesh_faces(np.array(vertices)+at, faces, color)


def ellipsoid(dims, color, at=(0,0,0), segments=8, rings=5):
    profile = [(math.sin(t), -math.cos(t)*dims[1]/2)
               for t in np.linspace(0, math.pi, rings+1)]
    return lathe(profile, color, segments, (dims[0]/2, dims[2]/2), at)


def beam(a, b, thickness, color=WOOD):
    a,b = np.asarray(a),np.asarray(b)
    up = b-a
    length = np.linalg.norm(up)
    up /= length
    side = np.cross(up, [0,0,1] if abs(up[2]) < .9 else [1,0,0])
    side /= np.linalg.norm(side)
    other = np.cross(side, up)
    rotation = np.column_stack([side,up,other])
    m = box((thickness,length,thickness), color)
    return Mesh(m.positions @ rotation.T + (a+b)/2, m.normals @ rotation.T,
                m.uv, m.indices, None, m.color)


class Model:
    def __init__(self):
        self.parts = []

    def add(self, name, meshes):
        meshes = meshes if isinstance(meshes, list) else [meshes]
        for i,m in enumerate(meshes):
            key = name if len(meshes)==1 else f'{name}-{i}'
            existing = {n for n,_ in self.parts}
            suffix = 1
            unique = key
            while unique in existing:
                unique = f'{key}-{suffix}'
                suffix += 1
            self.parts.append((unique,m))
        return self

    @property
    def meshes(self):
        return [mesh for _,mesh in self.parts]

    def export(self, path: Path):
        """Self-contained GLB with embedded source textures; no external paths."""
        blob = bytearray()
        doc = {'asset':{'version':'2.0','generator':'Gatalogo Quintal model authoring'},
               'scene':0,'scenes':[{'nodes':[]}], 'nodes':[], 'meshes':[],
               'materials':[], 'buffers':[{}], 'bufferViews':[], 'accessors':[]}
        texture_ids = {}

        def view(data, target=None):
            while len(blob)%4: blob.append(0)
            offset = len(blob); blob.extend(data)
            result = {'buffer':0,'byteOffset':offset,'byteLength':len(data)}
            if target: result['target']=target
            doc['bufferViews'].append(result)
            return len(doc['bufferViews'])-1

        def accessor(array, kind, component, target):
            data = np.asarray(array, dtype='<f4' if component==5126 else '<u4')
            result = {'bufferView':view(data.tobytes(),target),'componentType':component,
                      'count':len(data),'type':kind}
            if kind=='VEC3': result.update(min=data.min(0).tolist(), max=data.max(0).tolist())
            doc['accessors'].append(result)
            return len(doc['accessors'])-1

        for name,mesh in self.parts:
            pbr = {'baseColorFactor':mesh.color.tolist(),'metallicFactor':0,'roughnessFactor':1}
            if mesh.texture:
                key = str(mesh.texture)
                if key not in texture_ids:
                    images = doc.setdefault('images',[])
                    images.append({'bufferView':view(Path(key).read_bytes()),'mimeType':'image/png'})
                    textures = doc.setdefault('textures',[])
                    textures.append({'source':len(images)-1})
                    texture_ids[key]=len(textures)-1
                pbr['baseColorTexture']={'index':texture_ids[key]}
            doc['materials'].append({'name':name,'pbrMetallicRoughness':pbr,'doubleSided':True})
            attrs = {key:accessor(value,kind,5126,34962) for key,value,kind in [
                ('POSITION',mesh.positions,'VEC3'),('NORMAL',mesh.normals,'VEC3'),
                ('TEXCOORD_0',mesh.uv,'VEC2')]}
            primitive={'attributes':attrs,'indices':accessor(mesh.indices.ravel(),'SCALAR',5125,34963),
                       'material':len(doc['materials'])-1}
            doc['meshes'].append({'name':name,'primitives':[primitive]})
            doc['nodes'].append({'name':name,'mesh':len(doc['meshes'])-1})
            doc['scenes'][0]['nodes'].append(len(doc['nodes'])-1)
        while len(blob)%4: blob.append(0)
        doc['buffers'][0]['byteLength']=len(blob)
        text=json.dumps(doc,separators=(',',':')).encode()
        text+=b' '*((-len(text))%4)
        size=12+8+len(text)+8+len(blob)
        path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(struct.pack('<III',0x46546C67,2,size)+struct.pack('<II',len(text),0x4E4F534A)+text+
                         struct.pack('<II',len(blob),0x004E4942)+blob)
