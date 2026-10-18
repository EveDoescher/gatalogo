"""Publish confirmed watering and feeding tools captured from the Flutter scene."""
import argparse
import subprocess
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[1] / "build/galeria-visual/ferramentas"
LABELS = {"coop_water_effect": "Água das galinhas", "garden_water_effect": "Rega do canteiro", "cat_water_effect": "Água do gato", "cat_food_effect": "Ração do gato", "coop_food_effect": "Ração das galinhas", "pasture_food_effect": "Feno das vacas", "coop_water_reduced": "Movimento reduzido"}


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
            subprocess.run([args.ffmpeg, "-y", "-loglevel", "error", "-framerate", "20",
                "-i", str(OUTPUT / name / "%03d.png"), "-an", "-c:v", "libx264",
                "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUTPUT / f"{name}.mp4")], check=True)
        cards.append(f'<figure><figcaption>{label}</figcaption><video controls preload="metadata" width="390" src="{name}.mp4"></video><img data-sequence="{name}" width="390" src="{name}/000.png" alt="{label}: quadro do abastecimento confirmado"></figure>')
    (OUTPUT / "index.html").write_text(HTML.replace("CARDS", "".join(cards)), encoding="utf-8")
    print(OUTPUT / "index.html")


HTML = r'''<!doctype html><html lang="pt-BR"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Quintal — rega e abastecimento</title>
<style>body{margin:24px;background:#fbf6e8;color:#4b281b;font:16px/1.5 system-ui}main{max-width:840px;margin:auto}a{color:inherit}.grid{display:flex;flex-wrap:wrap;gap:24px}figure{margin:0;max-width:390px}video,img{max-width:100%;height:auto}input{accent-color:#52783c;width:240px}</style>
<main><a href="../galeria.html">Voltar à galeria</a><h1>Rega e abastecimento</h1>
<p>O regador, a pá de ração e o forcado aparecem somente após a confirmação da API. Água, grãos e feno saem da ponta da ferramenta e chegam ao alvo. Movimento reduzido mantém a ferramenta parada, com um retorno discreto no recipiente.</p>
<p>Fixtures Flutter em 390 × 844, com 32 quadros a intervalos de 50 ms. Não medem desempenho nem comprovam toque ou API conectada. A animação não concede recursos.</p>
<p><label>Inspecionar quadro <input id="frame" type="range" min="0" max="31" value="0"></label> <output id="position">1 / 32</output></p>
<div class="grid">CARDS</div></main>
<script>const slider=document.querySelector('#frame');slider.addEventListener('input',()=>{for(const image of document.querySelectorAll('[data-sequence]'))image.src=image.dataset.sequence+'/'+String(slider.value).padStart(3,'0')+'.png';document.querySelector('#position').value=(Number(slider.value)+1)+' / 32';});</script></html>'''

if __name__ == "__main__":
    main()
