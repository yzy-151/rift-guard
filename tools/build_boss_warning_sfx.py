from __future__ import annotations
import math, random, struct, wave
from pathlib import Path
RATE=48_000
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/"game"/"assets"/"sfx"/"boss"

def env(t,d,a=0.01,r=0.15):
    return min(1.0,t/a)*min(1.0,max(0.0,d-t)/r)

def render(name,duration,voice):
    rng=random.Random(name); frames=bytearray()
    for i in range(int(duration*RATE)):
        t=i/RATE
        v=max(-1.0,min(1.0,voice(t,duration,rng)))
        pan=0.97+0.025*math.sin(t*13.0)
        frames.extend(struct.pack("<hh",int(v*28000),int(v*pan*28000)))
    OUT.mkdir(parents=True,exist_ok=True)
    with wave.open(str(OUT/f"{name}.wav"),"wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(RATE); w.writeframes(frames)

def warning(t,d,rng):
    siren=math.sin(2*math.pi*(520+90*math.sin(2*math.pi*1.9*t))*t)*0.15
    pulse=0.0
    for onset in (0.04,0.28,0.61,0.85):
        local=t-onset
        if 0<=local<0.18:
            pulse+=math.sin(2*math.pi*(920-260*local)*local)*math.exp(-local*14)*0.54
            pulse+=math.sin(2*math.pi*118*local)*math.exp(-local*20)*0.18
    return env(t,d,0.006,0.18)*(siren+pulse)

def slime_attack(t,d,rng):
    spring=math.sin(2*math.pi*(180+110*math.exp(-t*8))*t)*math.exp(-t*4.5)*0.38
    wet=(rng.random()*2-1)*math.exp(-t*24)*0.25
    impact_t=max(0.0,t-0.19)
    impact=0.0
    if t>=0.19:
        impact=math.sin(2*math.pi*(72-20*impact_t)*impact_t)*math.exp(-impact_t*8)*0.68
        impact+=(rng.random()*2-1)*math.exp(-impact_t*28)*0.20
    return env(t,d,0.004,0.18)*(spring+wet+impact)

render("boss_warning_eva",1.16,warning)
render("slime_attack",0.72,slime_attack)
print("generated boss_warning_eva.wav and slime_attack.wav")
