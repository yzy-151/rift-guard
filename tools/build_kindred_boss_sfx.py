import math, wave, struct, random
from pathlib import Path
ROOT = Path(r"C:\Users\23081\Desktop\codex\rift-guard\game\assets\sfx\boss")
ROOT.mkdir(parents=True, exist_ok=True)
SR = 44100
random.seed(7303)

def env(t, dur, attack=0.015, release=0.22):
    return min(1.0, t/max(attack,1e-4)) * min(1.0, max(0.0,dur-t)/max(release,1e-4))

def write(name, dur, synth):
    n=int(SR*dur)
    vals=[]
    for i in range(n):
        t=i/SR
        x=max(-1.0,min(1.0,synth(t,dur)*env(t,dur)))
        vals.append(struct.pack('<h',int(x*32767)))
    with wave.open(str(ROOT/name),'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(b''.join(vals))

write('kindred_dance.wav',0.82,lambda t,d: 0.28*math.sin(2*math.pi*(780+1400*t)*t)+0.18*math.sin(2*math.pi*1240*t)*math.exp(-8*t)+0.08*(random.random()*2-1)*math.exp(-4*t))
write('kindred_wolf.wav',1.18,lambda t,d: 0.34*math.sin(2*math.pi*(82+28*math.sin(t*7))*t)+0.16*math.sin(2*math.pi*164*t)+0.10*(random.random()*2-1)*(0.4+0.6*math.sin(math.pi*t/d)))
write('kindred_dread.wav',1.05,lambda t,d: sum(0.22*math.sin(2*math.pi*(240+380*(t-k))*max(0,t-k))*math.exp(-16*max(0,t-k)) for k in (0.0,0.24,0.48) if t>=k)+0.08*math.sin(2*math.pi*52*t))
write('kindred_hunt.wav',1.28,lambda t,d: 0.18*math.sin(2*math.pi*(420+2200*t)*t)+0.12*(random.random()*2-1)*(0.3+0.7*math.sin(math.pi*t/d))+0.13*math.sin(2*math.pi*96*t))
write('kindred_respite.wav',2.0,lambda t,d: 0.18*math.sin(2*math.pi*220*t)+0.15*math.sin(2*math.pi*330*t)+0.12*math.sin(2*math.pi*440*t)+0.07*math.sin(2*math.pi*(660+80*math.sin(t*2))*t))
print('generated kindred boss sfx')
