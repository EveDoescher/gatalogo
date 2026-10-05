"""Export an offline preview of the exact runtime atlases, not substitute artwork."""
import json
import shutil
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'build/galeria-visual'
ANIMALS = {'cat': 'Gato · brincadeira', 'dog': 'Cachorro', 'bee': 'Abelha',
           'bunny': 'Coelho', 'chick': 'Pintinho', 'deer': 'Cervo', 'fox': 'Raposa',
           'beaver': 'Castor', 'parrot': 'Papagaio', 'fish': 'Peixe'}


def main():
    OUTPUT.mkdir(parents=True, exist_ok=True)
    frames = [Image.open(path).convert('RGB').quantize(colors=192)
              for path in sorted((OUTPUT / 'visit-frames').glob('*.png'))]
    if frames:
        frames[0].save(OUTPUT / 'habitat-visita.gif', save_all=True,
                       append_images=frames[1:], duration=175, loop=0, disposal=2)
    data = {}
    for animal, label in ANIMALS.items():
        source = ROOT / f'assets/habitat/{animal}'
        metadata = json.loads((source / 'animations.json').read_text())
        clips = {'play': metadata['clips']['play']} if animal == 'cat' else metadata['clips']
        target = OUTPUT / f'motion/{animal}'
        target.mkdir(parents=True, exist_ok=True)
        for clip in clips:
            for filename in (f'{clip}.png', f'{clip}-shadow.png'):
                shutil.copyfile(source / filename, target / filename)
        data[animal] = {**metadata, 'clips': clips, 'label': label}
    html = '''<!doctype html><html lang="pt-BR"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Gatálogo · animais em movimento</title><style>
body{margin:0;background:#fbf6e8;color:#4b281b;font:16px/1.6 system-ui}main{max-width:1200px;margin:auto;padding:24px}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(270px,1fr));gap:20px}article{background:#fff9ec;border:1px solid #d8c6a5;border-radius:22px;padding:18px}
canvas{display:block;width:100%;height:auto;background:#a3c47e;border-radius:18px}button,select{font:inherit;padding:8px;border:1px solid #7d9a57;border-radius:12px;background:#f9f3df;color:#4b281b;margin:4px}
a{color:inherit}button:focus-visible,select:focus-visible{outline:3px solid #de8494}h2{font-size:20px}
</style><main><a href="galeria.html">← Voltar à galeria</a><h1>Animais e brincadeira em movimento</h1>
<p>Estes são os atlases reais usados pelo app, com sombra e quatro direções. Selecione uma ação e uma direção para observar o movimento. Esta prévia não mede o desempenho no aparelho.</p>
<h2>Chegada, entrega e saída no próprio cenário</h2><p>Sequência do renderizador Flutter com um encontro de teste. Tempo acelerado em 4× para mostrar a rotina; o baú permanece disponível e a animação não concede moedas.</p><img id="visit" src="visit-frames/044.png" alt="Visitantes exploram o cenário e uma abelha entrega um baú externo que permanece até a coleta" style="max-width:600px;width:100%;border-radius:20px">
<p id="status" role="status"></p><button id="pause">Pausar animações</button><div class="grid" id="grid"></div></main><script>
const data=__DATA__;
let paused=matchMedia('(prefers-reduced-motion: reduce)').matches, total=0, previous=performance.now();
const cards=[];
for(const [species, definition] of Object.entries(data)){
 const node=document.createElement('article');node.innerHTML=`<h2>${definition.label}</h2><canvas width="320" height="260" aria-label="Prévia animada de ${definition.label}"></canvas><label>Ação <select class="clip"></select></label><label>Direção <select class="direction"><option value="0">Nordeste</option><option value="1">Sudeste</option><option value="2">Sudoeste</option><option value="3">Noroeste</option></select></label>`;
 const select=node.querySelector('.clip');for(const clip of Object.keys(definition.clips)){const option=document.createElement('option');option.value=clip;option.textContent=({idle:'Descanso / observar',walk:species==='fish'?'Nadar':species==='bee'||species==='parrot'?'Voo':'Caminhar',eat:species==='chick'?'Bicar':'Beber / forragear',play:'Brincar'})[clip]||clip;select.append(option);}
 const images={};for(const clip of Object.keys(definition.clips)){images[clip]=[new Image(),new Image()];images[clip][0].src=`motion/${species}/${clip}.png`;images[clip][1].src=`motion/${species}/${clip}-shadow.png`;}
 document.querySelector('#grid').append(node);cards.push({node,definition,select,images});
}
function label(){document.querySelector('#pause').textContent=paused?'Reproduzir animações':'Pausar animações';document.querySelector('#status').textContent=paused?'Animações pausadas.':'Animações em reprodução.';document.querySelector('#visit').src=paused?'visit-frames/044.png':'habitat-visita.gif';}label();
document.querySelector('#pause').onclick=()=>{paused=!paused;label();};
function render(now){if(!paused)total+=(now-previous)/1000;previous=now;
 for(const c of cards){const canvas=c.node.querySelector('canvas'),ctx=canvas.getContext('2d'),clip=c.select.value,d=c.definition.clips[clip],direction=Number(c.node.querySelector('.direction').value),frame=Math.floor(total%d.duration/d.duration*d.count),size=c.definition.size,scale=1.05,origin=c.definition.origin;
 ctx.clearRect(0,0,320,260);const elevation=c.definition.label==='Abelha'?35:0;for(let i=1;i>=0;i--){const img=c.images[clip][i];if(img.complete&&img.naturalWidth)ctx.drawImage(img,frame*size,direction*size,size,size,160-origin[0]*scale,205-origin[1]*scale-(i===0?elevation:0),size*scale,size*scale);}
 }requestAnimationFrame(render);
}requestAnimationFrame(render);
</script></html>'''
    (OUTPUT / 'movimentos.html').write_text(html.replace('__DATA__', json.dumps(data, ensure_ascii=False)), encoding='utf-8')
    print(f'Motion gallery: {len(data)} animals, actual atlases in four directions.')


if __name__ == '__main__':
    main()
