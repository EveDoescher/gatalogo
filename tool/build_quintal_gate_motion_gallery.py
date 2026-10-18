"""Publish the gate passage frames captured from the real Flutter renderer."""
import argparse
import subprocess
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[1] / "build/galeria-visual/portoes"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg")
    args = parser.parse_args()
    for name in ("coop", "pasture"):
        frames = sorted((OUTPUT / name).glob("[0-9][0-9][0-9].png"))
        if len(frames) != 96:
            raise ValueError(f"Expected 96 captured frames for {name}, got {len(frames)}")
        if args.ffmpeg:
            subprocess.run([
                args.ffmpeg, "-y", "-loglevel", "error", "-framerate", "10/3",
                "-i", str(OUTPUT / name / "%03d.png"), "-an", "-c:v", "libx264",
                "-pix_fmt", "yuv420p", "-movflags", "+faststart",
                str(OUTPUT / f"{name}.mp4"),
            ], check=True)
    (OUTPUT / "index.html").write_text(HTML, encoding="utf-8")
    print(OUTPUT / "index.html")


HTML = r'''<!doctype html><html lang="pt-BR"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Quintal — passagem pelos portões</title>
<style>body{margin:24px;background:#fbf6e8;color:#4b281b;font:16px/1.5 system-ui}main{max-width:840px;margin:auto}a{color:inherit}.grid{display:flex;flex-wrap:wrap;gap:24px}figure{margin:0;max-width:390px}video,img{max-width:100%;height:auto}input{accent-color:#52783c;width:240px}</style>
<main><a href="../galeria.html">Voltar à galeria</a><h1>Passagem pelos portões</h1>
<p>Fixtures no renderizador Flutter em 390 × 844. A folha abre antes da passagem, permanece aberta enquanto o animal ocupa o acesso e fecha depois. Postes e folha têm profundidade própria.</p>
<p>Cada sequência amostra 28,8 segundos de simulação em 96 quadros. Serve para inspecionar trajeto e oclusão; não mede a taxa de quadros do app nem substitui validação em aparelho.</p>
<div class="grid"><figure><figcaption>Galinheiro no nível 2</figcaption><video controls preload="metadata" width="390" src="coop.mp4"></video></figure><figure><figcaption>Pasto com duas vacas</figcaption><video controls preload="metadata" width="390" src="pasture.mp4"></video></figure></div>
<p><label>Inspecionar quadro <input id="frame" type="range" min="0" max="95" value="0"></label> <output id="position">1 / 96</output></p>
<div class="grid"><img data-sequence="coop" width="390" src="coop/000.png" alt="Galinha usa a abertura do portão"><img data-sequence="pasture" width="390" src="pasture/000.png" alt="Vaca usa a abertura do portão"></div>
</main><script>const slider=document.querySelector('#frame');slider.addEventListener('input',()=>{for(const image of document.querySelectorAll('[data-sequence]'))image.src=image.dataset.sequence+'/'+String(slider.value).padStart(3,'0')+'.png';document.querySelector('#position').value=(Number(slider.value)+1)+' / 96';});</script></html>'''

if __name__ == "__main__":
    main()
