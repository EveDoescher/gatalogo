"""Publish captured shelter approach, rest and exit from Flutter fixtures."""
import argparse
import subprocess
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[1] / "build/galeria-visual/abrigos"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg")
    args = parser.parse_args()
    for name, count, fps in [("coop", 192, "5"), ("pasture", 192, "5"), ("scratch", 64, "10")]:
        frames = sorted((OUTPUT / name).glob("[0-9][0-9][0-9].png"))
        if len(frames) != count:
            raise ValueError(f"Expected {count} frames for {name}, got {len(frames)}")
        if args.ffmpeg:
            subprocess.run([args.ffmpeg, "-y", "-loglevel", "error", "-framerate", fps,
                "-i", str(OUTPUT / name / "%03d.png"), "-an", "-c:v", "libx264",
                "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUTPUT / f"{name}.mp4")], check=True)
    (OUTPUT / "index.html").write_text(HTML, encoding="utf-8")
    print(OUTPUT / "index.html")


HTML = r'''<!doctype html><html lang="pt-BR"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Quintal — entrada e descanso nos abrigos</title>
<style>body{margin:24px;background:#fbf6e8;color:#4b281b;font:16px/1.5 system-ui}main{max-width:840px;margin:auto}a{color:inherit}.grid{display:flex;flex-wrap:wrap;gap:24px}figure{margin:0;max-width:390px}video,img{max-width:100%;height:auto}input{accent-color:#52783c;width:240px}</style>
<main><a href="../galeria.html">Voltar à galeria</a><h1>Entrada e descanso nos abrigos</h1>
<p>Fixtures do galinheiro e celeiro no nível 2, renderizadas pelo Flutter em 390 × 844. A rampa muda a altura da galinha; fachada e telhado cobrem o residente dentro da construção, preservando a abertura da porta.</p>
<p>Cada sequência amostra 38,4 segundos de simulação em 192 quadros. Permite inspecionar entrada, descanso e saída; não mede a taxa de quadros do app nem substitui validação em aparelho.</p>
<div class="grid"><figure><figcaption>Galinheiro</figcaption><video controls preload="metadata" width="390" src="coop.mp4"></video></figure><figure><figcaption>Celeiro</figcaption><video controls preload="metadata" width="390" src="pasture.mp4"></video></figure></div>
<h2>Ciscar</h2><p>Uma rotina breve de passos e bicadas após o retorno, com 6,4 segundos amostrados em 64 quadros.</p><video controls preload="metadata" width="390" src="scratch.mp4"></video>
<p><label>Inspecionar quadro <input id="frame" type="range" min="0" max="191" value="0"></label> <output id="position">1 / 192</output></p>
<div class="grid"><img data-sequence="coop" width="390" src="coop/000.png" alt="Galinha entra pela rampa e descansa no galinheiro"><img data-sequence="pasture" width="390" src="pasture/000.png" alt="Vaca entra pela porta e descansa no celeiro"></div>
</main><script>const slider=document.querySelector('#frame');slider.addEventListener('input',()=>{for(const image of document.querySelectorAll('[data-sequence]'))image.src=image.dataset.sequence+'/'+String(slider.value).padStart(3,'0')+'.png';document.querySelector('#position').value=(Number(slider.value)+1)+' / 192';});</script></html>'''

if __name__ == "__main__":
    main()
