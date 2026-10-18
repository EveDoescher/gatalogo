"""Publish actual Flutter scene captures; no artwork is substituted."""
import argparse
import subprocess
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[1] / "build/galeria-visual/brincadeira"


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--ffmpeg")
    args = parser.parse_args()
    frames = sorted(OUTPUT.glob("[0-9][0-9][0-9].png"))
    if len(frames) != 48:
        raise ValueError(f"Expected 48 captured frames, got {len(frames)}")
    if args.ffmpeg:
        subprocess.run([
            args.ffmpeg, "-y", "-loglevel", "error", "-framerate", "10",
            "-i", str(OUTPUT / "%03d.png"), "-an", "-c:v", "libx264",
            "-pix_fmt", "yuv420p", "-movflags", "+faststart",
            str(OUTPUT / "brincadeira.mp4"),
        ], check=True)
    (OUTPUT / "index.html").write_text(HTML, encoding="utf-8")
    print(OUTPUT / "index.html")


HTML = r'''<!doctype html><html lang="pt-BR"><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Quintal — brincar na cena</title>
<style>body{margin:24px;background:#fbf6e8;color:#4b281b;font:16px/1.5 system-ui}main{max-width:780px;margin:auto}a{color:inherit}video,img{max-width:100%;height:auto}input{accent-color:#52783c;width:240px}</style>
<main><a href="../galeria.html">Voltar à galeria</a><h1>Brincar com o gato no Quintal</h1>
<p>Fixture no renderizador Flutter em 390 × 844. Dois toques na área da cena controlam a varinha. O gato usa sua pelagem, posição e profundidade no mundo e percorre apenas células livres.</p>
<p>Sequência de 48 quadros, apresentada a 10 quadros por segundo para inspeção. O intervalo inclui o custo da captura; este vídeo não mede a taxa de quadros do app e não comprova API conectada ou toque em aparelho.</p>
<video controls preload="metadata" width="390" src="brincadeira.mp4"></video>
<p><label>Inspecionar quadro <input id="frame" type="range" min="0" max="47" value="0"></label> <output id="position">1 / 48</output></p>
<img id="capture" width="390" src="000.png" alt="Gato e varinha na própria cena do Quintal">
</main><script>const slider=document.querySelector('#frame');slider.addEventListener('input',()=>{document.querySelector('#capture').src=String(slider.value).padStart(3,'0')+'.png';document.querySelector('#position').value=(Number(slider.value)+1)+' / 48';});</script></html>'''

if __name__ == "__main__":
    main()
