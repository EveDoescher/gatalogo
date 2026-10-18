"""Build an offline categorized gallery from a Git ref without switching branches."""
from pathlib import Path, PurePosixPath
from collections import Counter
from io import BytesIO
import argparse, json, re, struct, subprocess, hashlib
import numpy as np
from PIL import Image
from habitat_model import Mesh
from render_habitat_models import framing, render_meshes

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/galeria-visual/modelos"

class GitAssets:
    def __init__(self, ref):
        self.ref = subprocess.check_output(["git","rev-parse",ref],cwd=ROOT).decode().strip()
        self.paths = subprocess.check_output(["git","ls-tree","-r","--name-only",self.ref],cwd=ROOT).decode().splitlines()
        self.process = subprocess.Popen(["git","cat-file","--batch"],cwd=ROOT,stdin=subprocess.PIPE,stdout=subprocess.PIPE)
    def read(self, path):
        self.process.stdin.write((self.ref+":"+path+"\n").encode()); self.process.stdin.flush()
        header=self.process.stdout.readline().decode().strip().split()
        if header[-1]=="missing": raise FileNotFoundError(path)
        data=self.process.stdout.read(int(header[-1]));self.process.stdout.read(1)
        return data
    def close(self):
        self.process.stdin.close();self.process.wait()

def category(path):
    name=PurePosixPath(path).stem.lower()
    if path.startswith("third_party/"): return "Modelos de exemplo"
    if name.startswith("animal-") or "cat_low_poly" in name: return "Animais"
    if name.startswith(("character-",)): return "Personagens"
    if name.startswith(("crop_", "crops_")): return "Cultivos e canteiros"
    if name.startswith(("tree","palm")): return "Árvores"
    if name.startswith(("rock","stone","cliff")): return "Pedras e penhascos"
    if name.startswith(("plant","grass","flower","cactus","lily","hanging","mushroom")): return "Plantas e flores"
    if name.startswith(("log","stump")): return "Troncos e madeira"
    if "river" in name or "waterfall" in name: return "Água e rios"
    if "dock" in name or name.startswith(("bridge","path","ground_path")): return "Pontes, píeres e caminhos"
    if name.startswith(("ground","platform","patch","hole")) or name in ("floor","floor-detail","dirt"): return "Terrenos e plataformas"
    if "fence" in name or name.startswith(("gate",)): return "Cercas e portões"
    if name.startswith(("bed","chair","table","bench","tent","planter","pot_")): return "Móveis e descanso"
    if "kenney_food-kit" in path:
        cookware=("bottle","bowl","cup","mug","plate","pot","pan","cooking","knife","fork","spoon","chop","cutting","skewer","carton","bag","can","glass","barrel","tray","utensil","rolling","whisk","blender","frying","saucepan")
        if name == "egg-cup" or any(name == token or name.startswith(token+"-") for token in cookware) and name not in ("bowl-broth","bowl-cereal","bowl-soup"): return "Cozinha e utensílios"
        fruit=("apple","avocado","advocado","banana","beet","broccoli","cabbage","carrot","cauliflower","celery","cherries","coconut","corn","cucumber","eggplant","grapes","lemon","lettuce","mushroom","onion","orange","pear","pepper","pineapple","potato","pumpkin","radish","strawberry","tomato","watermelon")
        if name.startswith(fruit) and name!="corn-dog": return "Frutas e vegetais"
        return "Comidas e ingredientes"
    if name.startswith(("boat","ship","canoe","mast","tool-paddle")): return "Barcos e navegação"
    if name.startswith(("building","castle","tower","structure","column","roof","wall","window","door")): return "Construções e estruturas"
    if "city-kit-roads" in path: return "Estradas e infraestrutura"
    return "Objetos e decoração"

def render_extra(git, path, target):
    """Read static glTF geometry, including embedded images and external buffers."""
    raw=git.read(path); parent=PurePosixPath(path).parent
    if path.endswith(".glb"):
        size=struct.unpack_from("<I",raw,12)[0]; doc=json.loads(raw[20:20+size]); binaries=[raw[28+size:]]
    else:
        doc=json.loads(raw);binaries=[git.read(str(parent/b["uri"])) for b in doc["buffers"]]
    texture_dir=OUTPUT/"textures";texture_dir.mkdir(exist_ok=True)
    textures={}
    for i,img in enumerate(doc.get("images",[])):
        if "uri" in img: data=git.read(str(parent/img["uri"]))
        else:
            view=doc["bufferViews"][img["bufferView"]]; start=view.get("byteOffset",0);data=binaries[view.get("buffer",0)][start:start+view["byteLength"]]
        texture=texture_dir/(target.stem+"-"+str(i)+".png")
        Image.open(BytesIO(data)).convert("RGBA").save(texture);textures[i]=texture
    types={5120:"i1",5121:"u1",5122:"<i2",5123:"<u2",5125:"<u4",5126:"<f4"}
    widths={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT4":16}
    def accessor(i):
        a=doc["accessors"][i];v=doc["bufferViews"][a["bufferView"]];dt=np.dtype(types[a["componentType"]]);w=widths[a["type"]]
        data=np.ndarray((a["count"],w),dtype=dt,buffer=binaries[v.get("buffer",0)],offset=v.get("byteOffset",0)+a.get("byteOffset",0),strides=(v.get("byteStride",w*dt.itemsize),dt.itemsize)).copy()
        if a.get("normalized") and dt.kind in "iu": data=data.astype(float)/np.iinfo(dt).max
        return data
    meshes=[]
    def visit(i,parent_matrix):
        node=doc["nodes"][i]
        if "matrix" in node: local=np.array(node["matrix"]).reshape(4,4).T
        else:
            x,y,z,w=node.get("rotation",[0,0,0,1]);local=np.eye(4)
            local[:3,:3]=np.array([[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]])@np.diag(node.get("scale",[1,1,1]))
            local[:3,3]=node.get("translation",[0,0,0])
        transform=parent_matrix@local
        if "mesh" in node:
            for p in doc["meshes"][node["mesh"]]["primitives"]:
                attrs=p["attributes"]; pos=accessor(attrs["POSITION"]);pos=(np.column_stack([pos,np.ones(len(pos))])@transform.T)[:,:3]
                indices=(accessor(p["indices"]).ravel() if "indices" in p else np.arange(len(pos))).reshape(-1,3)
                if "NORMAL" in attrs: normals=accessor(attrs["NORMAL"])@np.linalg.inv(transform[:3,:3])
                else:
                    normals=np.zeros_like(pos);face=np.cross(pos[indices[:,1]]-pos[indices[:,0]],pos[indices[:,2]]-pos[indices[:,0]])
                    for col in range(3):np.add.at(normals,indices[:,col],face)
                normals/=np.linalg.norm(normals,axis=1,keepdims=True).clip(1e-9)
                uv=accessor(attrs["TEXCOORD_0"]) if "TEXCOORD_0" in attrs else np.zeros((len(pos),2))
                mat=doc.get("materials",[{}])[p.get("material",0)].get("pbrMetallicRoughness",{})
                texture=None
                if "baseColorTexture" in mat: texture=textures[doc["textures"][mat["baseColorTexture"]["index"]]["source"]]
                meshes.append(Mesh(pos,normals,uv,indices,texture,np.array(mat.get("baseColorFactor",[1,1,1,1]))))
        for child in node.get("children",[]):visit(child,transform)
    for i in doc["scenes"][doc.get("scene",0)]["nodes"]:visit(i,np.eye(4))
    origin,scale=framing(meshes,size=320,padding=28);render_meshes(meshes,origin,scale,size=320,supersample=1).save(target)

def main():
    parser=argparse.ArgumentParser();parser.add_argument("--ref",default="feature/etapa9-3d-metagame");args=parser.parse_args()
    OUTPUT.mkdir(parents=True,exist_ok=True);(OUTPUT/"imagens").mkdir(exist_ok=True)
    git=GitAssets(args.ref);paths=set(git.paths);models={};order={".glb":0,".gltf":1,".fbx":2,".obj":3}
    for f in git.paths:
        p=PurePosixPath(f);suffix=p.suffix.lower()
        if suffix not in order:continue
        pack=f.split("/Models/")[0] if "/Models/" in f else str(p.parent);key=(pack,p.stem)
        if key not in models:models[key]={"path":f,"formats":[],"pack":("Exemplos interactive_3d" if f.startswith("third_party/") else "Gatos do app" if pack=="assets/models" else pack.split("/")[-1])}
        models[key]["formats"].append(suffix[1:])
        if order[suffix]<order[PurePosixPath(models[key]["path"]).suffix.lower()]:models[key]["path"]=f
    entries=[]
    try:
        for i,((prefix,name),model) in enumerate(sorted(models.items())):
            path=model["path"];ident=hashlib.sha1(path.encode()).hexdigest()[:12];target=OUTPUT/"imagens"/(ident+".png")
            candidates=[prefix+"/Previews/"+name+".png",prefix+"/Isometric/"+name+"_NE.png"]
            source=next((p for p in candidates if p in paths),None)
            if source:
                im=Image.open(BytesIO(git.read(source))).convert("RGBA")
                box=im.getbbox()
                if not box: raise ValueError("Empty image: "+source)
                im=im.crop(box);im.thumbnail((320,320));im.save(target)
            else:
                print("RENDER "+path,flush=True);render_extra(git,path,target)
            entry={"id":ident,"name":name,"pack":model["pack"],"path":path,"formats":sorted(set(model["formats"])),"category":category(path),"image":"imagens/"+ident+".png","preview":"Prévia original do pacote" if source else "Renderização estática do modelo","source":source}
            entries.append(entry)
            if i%100==0:print(f"INDEX {i+1}/{len(models)}",flush=True)
    finally:git.close()
    payload={"ref":args.ref,"commit":git.ref,"models":entries,"counts":dict(Counter(e["category"] for e in entries))}
    (OUTPUT/"inventario.json").write_text(json.dumps(payload,ensure_ascii=False,indent=2),encoding="utf-8")
    template=(ROOT/"tool/model_asset_gallery.html").read_text(encoding="utf-8")
    (OUTPUT/"index.html").write_text(template.replace("__INVENTORY__",json.dumps(payload,ensure_ascii=False).replace("</","<\\/")),encoding="utf-8")
    print(json.dumps({"models":len(entries),"categories":payload["counts"],"output":str(OUTPUT/"index.html")},ensure_ascii=False),flush=True)

if __name__=="__main__":main()
