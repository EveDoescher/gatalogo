"""Publish confirmed garden expansion and foliage captured from the Flutter scene."""
import argparse
import subprocess
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[1] / "build/galeria-visual/horta"
LABELS = {"expand_8": "Ampliação para oito canteiros", "expand_12": "Ampliação para doze canteiros", "foliage": "Balanço discreto das seis culturas"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg")
    args = parser.parse_args()
    cards = []
    for name, label in LABELS.items():
        frames = sorted((OUTPUT / name).glob("[0-9][0-9][0-9].png"))
        if len(frames) != 32:
            raise ValueError(f"Expected 32 frames for {name}, got {len(frames)}")
        if args.ffmpeg:
            subprocess.run([args.ffmpeg, "-y", "-loglevel", "error", "-framerate", "5" if name == "foliage" else "20",
                "-i", str(OUTPUT / name / "%03d.png"), "-an", "-c:v", "libx264",
                "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUTPUT / f"{name}.mp4")], check=True)
        cards.append(f'<figure><figcaption>{label}</figcaption><video controls preload="metadata" width="390" src="{name}.mp4"></video><img data-sequence="{name}" width="390" src="{name}/000.png" alt="{label}: quadro da horta"></figure>')
    (OUTPUT / "index.html").write_text(HTML.replace("CARDS", "".join(cards)), encoding="utf-8")
    print(OUTPUT / "index.html")


HTML = r'''<!doctype html><html lang="pt-BR"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Quintal — horta e ampliações</title>
<style>body{margin:24px;background:#fbf6e8;color:#4b281b;font:16px/1.5 system-ui}main{max-width:840px;margin:auto}a{color:inherit}.grid{display:flex;flex-wrap:wrap;gap:24px}figure{margin:0;max-width:390px}video,img{max-width:100%;height:auto}input{accent-color:#52783c;width:240px}</style>
<main><a href="../galeria.html">Voltar à galeria</a><h1>Horta e ampliações</h1>
<p>A publicação confirmada de novos canteiros inicia a retirada gradual dos elementos de obra. Terra e plantas existentes mantêm a origem e o estoque não muda. A folhagem cresce com a escala já aprovada; vento discreto não move o solo nem revela raízes.</p>
<p>Fixtures Flutter em 390 × 844: 32 quadros por sequência. Ampliações a intervalos de 50 ms; folhagem a intervalos de 200 ms. Movimento reduzido aparece na galeria principal. Não comprovam execução em aparelho ou API conectada.</p>
<p><label>Inspecionar quadro <input id="frame" type="range" min="0" max="31" value="0"></label> <output id="position">1 / 32</output></p>
<div class="grid">CARDS</div></main>
<script>const slider=document.querySelector('#frame');slider.addEventListener('input',()=>{for(const image of document.querySelectorAll('[data-sequence]'))image.src=image.dataset.sequence+'/'+String(slider.value).padStart(3,'0')+'.png';document.querySelector('#position').value=(Number(slider.value)+1)+' / 32';});</script></html>'''

if __name__ == "__main__":
    main()
