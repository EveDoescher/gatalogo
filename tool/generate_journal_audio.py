"""Original procedural audio; no samples or third-party recordings."""
from pathlib import Path
import math, struct, wave
out = Path(__file__).resolve().parents[1]/'assets/audio'
out.mkdir(parents=True,exist_ok=True)
def render(name, seconds, melody, spacing, volume):
    rate=22050
    with wave.open(str(out/name),'wb') as f:
        f.setparams((1,2,rate,0,'NONE','not compressed'))
        data=[]
        for i in range(int(seconds*rate)):
            t=i/rate
            value=0.0
            for index,note in enumerate(melody):
                dt=t-index*spacing
                if 0<=dt<3:
                    envelope=min(1,dt/.025)*math.exp(-dt*2)*min(1,(seconds-t)/.2)
                    freq=440*2**((note-69)/12)
                    value+=envelope*(math.sin(2*math.pi*freq*dt)+.2*math.sin(2*math.pi*2*freq*dt))
            data.append(struct.pack('<h',int(max(-1,min(1,value*volume))*32767)))
        f.writeframes(b''.join(data))
render('garden.wav',24,[60,64,67,71,67,64,62,65,69,72,69,65],1.7,.16)
render('discovery.wav',1.1,[72,76,79],.16,.15)
(out/'LICENSE.md').write_text('''# Áudio do Gatálogo

garden.wav e discovery.wav são composições procedurais originais criadas para este projeto em 27/09/2026, sem samples ou gravações de terceiros.

Disponibilizados sob CC0 1.0 Universal (domínio público): https://creativecommons.org/publicdomain/zero/1.0/

O gerador reproduzível está em tool/generate_journal_audio.py.
''',encoding='utf-8')
