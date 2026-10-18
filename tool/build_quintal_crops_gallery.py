"""Compose real model renders at a shared world scale to review crop progression."""
import json
import math
from pathlib import Path
from PIL import Image,ImageDraw,ImageFont

ROOT=Path(__file__).resolve().parents[1]
ASSETS=ROOT/'assets/quintal/production'
OUT=ROOT/'build/galeria-visual/modelos-novos'
CROPS=[('wheat','Trigo'),('corn','Milho'),('carrot','Cenoura'),('turnip','Nabo'),('pumpkin','Abóbora'),('melon','Melão')]
STAGES=['Broto','Crescendo','Imaturo','Pronto para colher']


def main():
    manifest=json.loads((ASSETS/'manifest.json').read_text(encoding='utf-8'))
    font_path=Path('C:/Windows/Fonts/segoeui.ttf')
    font=ImageFont.truetype(str(font_path),21)
    small=ImageFont.truetype(str(font_path),17)
    width,height=1100,1780
    sheet=Image.new('RGBA',(width,height),'#f6efdc');draw=ImageDraw.Draw(sheet)
    draw.text((30,20),'Plantações do Quintal — quatro estágios',font=ImageFont.truetype(str(font_path),30),fill='#4d3828')
    draw.text((30,65),'Mesma escala, câmera e canteiro. Modelos 3D reais; sem alterar tempos de cultivo.',font=small,fill='#6b6650')
    # Pixels per projected metre. The shared origin preserves growth differences.
    scale=140
    def place(key,origin,lift=0):
        meta=manifest[key];ratio=scale/meta['scale']
        image=Image.open(ASSETS/(key+'.png')).convert('RGBA')
        image=image.resize((round(image.width*ratio),round(image.height*ratio)),Image.Resampling.LANCZOS)
        x=round(origin[0]-meta['origin'][0]*ratio)
        y=round(origin[1]-meta['origin'][1]*ratio-lift*scale*math.sqrt(3)/2)
        sheet.alpha_composite(image,(x,y))
    for row,(kind,label) in enumerate(CROPS):
        top=110+row*275
        draw.text((30,top),label,font=font,fill='#466344')
        for stage in range(4):
            left=24+stage*269
            draw.rounded_rectangle((left,top+32,left+255,top+262),radius=18,fill='#e8ecd5',outline='#ccd3b5')
            origin=(left+127,top+181)
            place('crafted-garden-bed-dry-planted-NE',origin)
            place(f'crafted-crop-{kind}-{stage}-NE',origin,lift=.055)
            draw.text((left+127,top+247),STAGES[stage],font=small,fill='#4d3828',anchor='mm')
    sheet.convert('RGB').save(OUT/'cultivos-estagios.jpg',quality=94)
    cards=''.join(f'<section><h2>{label}</h2><div class="stages">'+''.join(
        f'<figure><img src="../../../assets/quintal/production/crafted-crop-{kind}-{s}-NE.png" alt="{label}: {STAGES[s]}"><figcaption>{STAGES[s]} · <a href="../../../art/quintal/models/crafted-crop-{kind}-{s}.glb">GLB</a></figcaption></figure>' for s in range(4))+'</div></section>' for kind,label in CROPS)
    (OUT/'cultivos.html').write_text('''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Plantações do Quintal</title><style>
body{background:#f6efdc;color:#4d3828;font:17px/1.5 system-ui;margin:0}main{max-width:1160px;margin:auto;padding:24px}a{color:#466344}.overview{width:100%;height:auto}.stages{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:12px}figure{margin:0;padding:12px;background:#e8ecd5;border-radius:16px}figure img{width:100%}section{margin:28px 0}</style><main><a href="index.html">Todos os modelos</a><h1>Plantações do Quintal</h1><p>O quadro usa a mesma escala entre os estágios. As prévias ampliadas abaixo mostram os detalhes de cada modelo.</p><a href="cultivos-estagios.jpg"><img class="overview" src="cultivos-estagios.jpg" alt="Seis cultivos, cada um em quatro estágios na mesma escala"></a>'''+cards+'</main></html>',encoding='utf-8')
    print(OUT/'cultivos.html')


if __name__=='__main__':main()
