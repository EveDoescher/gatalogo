"""Publish simultaneous kitchen states captured from the Flutter scene."""
import argparse
import subprocess
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[1] / "build/galeria-visual/cozinha"
LABELS = {"simultaneous": "Cozinha nível 2: preparo, ingredientes reservados e prato pronto"}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg")
    args = parser.parse_args()
    cards = []
    for name, label in LABELS.items():
        frames = sorted((OUTPUT / name).glob("[0-9][0-9][0-9].png"))
        if len(frames) != 64:
            raise ValueError(f"Expected 64 frames for {name}, got {len(frames)}")
        if args.ffmpeg:
            subprocess.run([args.ffmpeg, "-y", "-loglevel", "error", "-framerate", "10",
                "-i", str(OUTPUT / name / "%03d.png"), "-an", "-c:v", "libx264",
                "-pix_fmt", "yuv420p", "-movflags", "+faststart", str(OUTPUT / f"{name}.mp4")], check=True)
        cards.append(f'<figure><figcaption>{label}</figcaption><video controls preload="metadata" width="390" src="{name}.mp4"></video><img data-sequence="{name}" width="390" src="{name}/000.png" alt="{label}: quadro da cozinha"></figure>')
    (OUTPUT / "index.html").write_text(HTML.replace("CARDS", "".join(cards)), encoding="utf-8")
    print(OUTPUT / "index.html")


HTML = r'''<!doctype html><html lang="pt-BR"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Quintal — cozinha em atividade</title>
<style>body{margin:24px;background:#fbf6e8;color:#4b281b;font:16px/1.5 system-ui}main{max-width:840px;margin:auto}a{color:inherit}.grid{display:flex;flex-wrap:wrap;gap:24px}figure{margin:0;max-width:390px}video,img{max-width:100%;height:auto}input{accent-color:#52783c;width:240px}</style>
<main><a href="../galeria.html">Voltar à galeria</a><h1>Cozinha em atividade</h1>
<p>Um preparo ativo na panela, ingredientes do próximo na bandeja e refeição pronta em recipiente separado. Indicadores acima da chaminé deixam tampa, vapor e bancada visíveis. O término do tempo não coleta nem credita alimentos automaticamente.</p>
<p>Fixture Flutter em 390 × 844: 64 quadros a intervalos de 100 ms. Movimento reduzido, próximo preparo e expansão estão na galeria principal. Não comprovam execução em aparelho ou API conectada.</p>
<p><label>Inspecionar quadro <input id="frame" type="range" min="0" max="63" value="0"></label> <output id="position">1 / 64</output></p>
<div class="grid">CARDS</div></main>
<script>const slider=document.querySelector('#frame');slider.addEventListener('input',()=>{for(const image of document.querySelectorAll('[data-sequence]'))image.src=image.dataset.sequence+'/'+String(slider.value).padStart(3,'0')+'.png';document.querySelector('#position').value=(Number(slider.value)+1)+' / 64';});</script></html>'''

if __name__ == "__main__":
    main()
