"""Publish captured Flutter frames without substituting or modifying their artwork."""
import argparse
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "build/galeria-visual/ancoragem"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg", help="Optional local FFmpeg executable for MP4 export")
    args = parser.parse_args()
    for name in ("coop", "pasture_milk"):
        frames = sorted((OUTPUT / name).glob("*.png"))
        if len(frames) != 64:
            raise ValueError(f"Expected 64 captured frames for {name}, found {len(frames)}")
        if args.ffmpeg:
            subprocess.run([
                args.ffmpeg, "-y", "-loglevel", "error", "-framerate", "16",
                "-i", str(OUTPUT / name / "%03d.png"), "-an", "-c:v", "libx264",
                "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUTPUT / f"{name}.mp4"),
            ], check=True)
    videos = "".join(
        f'<video controls preload="metadata" width="390" style="max-width:100%;height:auto" src="{name}.mp4"></video>'
        for name in ("coop", "pasture_milk") if (OUTPUT / f"{name}.mp4").exists()
    )
    (OUTPUT / "index.html").write_text(HTML.replace("<!--VIDEOS-->", videos), encoding="utf-8")
    print(OUTPUT / "index.html")


HTML = r'''<!doctype html><html lang="pt-BR"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Quintal — ações ancoradas no mundo</title>
<style>
body{margin:0;background:#fbf6e8;color:#4b281b;font:16px/1.5 system-ui,sans-serif}
main{max-width:940px;margin:auto;padding:24px}a{color:inherit}
.grid{display:flex;flex-wrap:wrap;gap:24px}figure{margin:0;flex:1 1 320px;max-width:390px}
img{display:block;width:100%;height:auto}figcaption{margin-bottom:12px;font-weight:700}
button,input{font:inherit;accent-color:#52783c}button{padding:10px 18px;min-height:48px;color:inherit;background:#fff9ec;border:1px solid #bca381;border-radius:12px}
button:focus-visible,input:focus-visible{outline:3px solid #52783c;outline-offset:3px}
.controls{display:flex;gap:16px;align-items:center;flex-wrap:wrap;margin:24px 0}
@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto}}
</style><main><a href="../galeria.html">Voltar à galeria</a>
<h1>Ações acompanham o mundo</h1>
<p>Fixtures capturadas pelo renderizador Flutter em 390 × 844. A seleção enquadra a câmera automaticamente; durante o arrasto e o zoom, o balão mantém a posição relativa ao objeto. A segunda sequência acompanha uma vaca em movimento.</p>
<p>64 quadros por sequência, com tempo de simulação de 4 segundos. A cadência desta página não mede o desempenho do app. Não é uma validação de toque, API ou aparelho real.</p>
<!--VIDEOS-->
<div class="controls"><button id="play">Reproduzir</button><label>Quadro <input id="frame" type="range" min="0" max="63" value="0"></label><output id="position">1 / 64</output></div>
<div class="grid"><figure><figcaption>Comedouro: arrasto e zoom</figcaption><img data-sequence="coop" src="coop/000.png" alt="Ações do comedouro ligadas à sua posição no Quintal"></figure>
<figure><figcaption>Vaca selecionada: movimento e câmera</figcaption><img data-sequence="pasture_milk" src="pasture_milk/000.png" alt="Ações de ordenha e nome acompanham a vaca selecionada"></figure></div>
</main><script>
const slider=document.querySelector('#frame'),play=document.querySelector('#play'),position=document.querySelector('#position');
const images=[...document.querySelectorAll('[data-sequence]')];
let playing=false,last=0;
function show(value){slider.value=value;position.value=`${value+1} / 64`;for(const img of images)img.src=`${img.dataset.sequence}/${String(value).padStart(3,'0')}.png`;}
function stop(){playing=false;play.textContent='Reproduzir';}
slider.addEventListener('input',()=>{stop();show(Number(slider.value));});
play.addEventListener('click',()=>{playing=!playing;play.textContent=playing?'Pausar':'Reproduzir';last=performance.now();});
document.addEventListener('visibilitychange',()=>{if(document.hidden)stop();});
function tick(now){if(playing&&now-last>=62.5){show((Number(slider.value)+1)%64);last=now;}requestAnimationFrame(tick);}requestAnimationFrame(tick);
</script></html>'''


if __name__ == "__main__":
    main()
