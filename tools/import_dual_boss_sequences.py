"""Import master-provided green-screen footage; original videos remain untouched."""
import json, subprocess, math
from pathlib import Path
import cv2
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
SRC=Path(r"C:/Users/23081/Desktop/游戏素材/加里奥-降落")
FFMPEG=Path(r"C:/Users/23081/Desktop/序列帧工坊-BAT便携版/vendor/ffmpeg/ffmpeg.exe")
OUT=ROOT/'outputs/boss-video-import';OUT.mkdir(parents=True,exist_ok=True)
CELL=320

def read(name):
    path=SRC/(name+'.mp4')
    raw=subprocess.run([str(FFMPEG),'-v','error','-i',str(path),'-vf','fps=24,scale=320:320','-f','rawvideo','-pix_fmt','rgb24','-'],capture_output=True,check=True).stdout
    frames=np.frombuffer(raw,np.uint8).reshape(-1,CELL,CELL,3).copy()
    result=[]
    for rgb in frames:
        f=rgb.astype(np.float32);r,g,b=f[:,:,0],f[:,:,1],f[:,:,2]
        # Saturated green plate, retain cyan spells and golden armor.
        excess=g-np.maximum(r,b)
        a=np.clip((1-(excess-12)/62),0,1)
        a[(g>140)&(g>r*1.8)&(g>b*1.8)]=0
        # Remove spill without turning cyan spell effects transparent.
        f[:,:,1]=np.where(excess>8,np.minimum(g,np.maximum(r,b)+8),g)
        out=np.dstack([f,np.round(a*255)]).astype(np.uint8)
        out[a<0.02]=0
        result.append(Image.fromarray(out))
    return result

def loop_segment(frames):
    small=np.array([np.asarray(f.resize((64,64))).astype(np.float32)/255 for f in frames])
    small[:,:,:,:3]*=small[:,:,:,3:4]
    best=None
    for i in range(10,85):
        for period in range(20,73):
            j=i+period
            if j+2>=len(frames):continue
            score=float(np.mean(abs(small[i]-small[j-1]))) / max(0.002,float(np.median(np.mean(abs(small[i+1:j]-small[i:j-1]),axis=(1,2,3)))))
            if best is None or score<best[0]:best=(score,i,j)
    _,i,j=best
    data=small[i:j];seam=float(np.mean(abs(data[-1]-data[0])))
    typical=float(np.median(np.mean(abs(data[1:]-data[:-1]),axis=(1,2,3))))
    selected=frames[i:j]
    # Optical-flow bridge closes AI-generated nonperiodic footage without reversing gait.
    a=np.asarray(selected[-1]).astype(np.float32);b=np.asarray(selected[0]).astype(np.float32)
    ga=cv2.cvtColor(a[:,:,:3].astype(np.uint8),cv2.COLOR_RGB2GRAY)
    gb=cv2.cvtColor(b[:,:,:3].astype(np.uint8),cv2.COLOR_RGB2GRAY)
    ab=cv2.calcOpticalFlowFarneback(ga,gb,None,.5,4,25,4,7,1.5,0)
    ba=cv2.calcOpticalFlowFarneback(gb,ga,None,.5,4,25,4,7,1.5,0)
    yy,xx=np.mgrid[:CELL,:CELL].astype(np.float32)
    for t in np.linspace(0,1,8,dtype=np.float32)[1:-1]:
        wa=cv2.remap(a,xx-ab[:,:,0]*t,yy-ab[:,:,1]*t,cv2.INTER_LINEAR)
        wb=cv2.remap(b,xx-ba[:,:,0]*(1-t),yy-ba[:,:,1]*(1-t),cv2.INTER_LINEAR)
        selected.append(Image.fromarray(np.clip(wa*(1-t)+wb*t,0,255).astype(np.uint8)))
    seam_after=float(np.mean(abs(np.asarray(selected[-1]).astype(float)-np.asarray(selected[0]).astype(float)))/255)
    return selected,{'bridge_frames':6,'closed_seam_error':seam_after,'start_frame':i,'end_frame_exclusive':j,'seam_error':seam,'median_step_error':typical,'seam_ratio':seam/max(typical,1e-6)}

manifest_path=ROOT/'game/data/v2/enemy_sequences.json'
manifest=json.loads(manifest_path.read_text(encoding='utf-8-sig'))
# 24 FPS frame ranges; trim lead-ins, repeated actions and long final holds.
specs={
 'boss_galio':{'run':('加里奥-走路',None),'idle':('加里奥-护盾',(0,10)),
 'attack':('加里奥-后撤并冲击',(44,76)),'punch_charge':('加里奥-后撤并冲击',(9,57)),
 'punch':('加里奥-后撤并冲击',(57,78)), 'winds':('加里奥-技能1-截取到激光发射前',(9,49)),
 'durand':('加里奥-护盾',(9,49)),'takeoff':('加里奥-降落',(5,24)),
 'landing':('加里奥-降落',(41,67)),'down':('加里奥-阵亡',(15,68))},
 'boss_03':{'run':('千珏-走路',None),'idle':('千珏-普通攻击',(0,12)),
 'attack':('千珏-普通攻击',(13,37)),'dance_charge':('千珏-射击翻滚',(13,54)),
 'dance':('千珏-射击翻滚',(80,119)),'spirit':('千珏-技能',(18,62)),
 'down':('千珏-阵亡',(9,53))}}
report={};preview=[]
for boss,states in specs.items():
    folder=ROOT/'game/assets/enemies/sequences'/boss/'video_v1';folder.mkdir(parents=True,exist_ok=True)
    entry={'cell':[384,384],'pivot':[192,302],'native_facing':1.0,'display_size':300 if boss=='boss_galio' else 285,'states':{}}
    cache={}
    for state,(name,span) in states.items():
        if name not in cache:cache[name]=read(name)
        raw=cache[name]
        if span is None:frames,info=loop_segment(raw)
        else:frames=raw[span[0]:span[1]];info={'start_frame':span[0],'end_frame_exclusive':span[1]}
        # Fixed source coordinates per clip; never crop/recenter individual poses.
        bb=raw[0].getchannel('A').point(lambda a:255 if a>180 else 0).getbbox()
        dx=160-round((bb[0]+bb[2])/2);dy=270-bb[3]
        aligned=[]
        for f in frames:
            c=Image.new('RGBA',(384,384));c.paste(f,(dx+32,dy+32));aligned.append(c)
        frames=aligned
        if state=='spirit':
            frames=frames+frames[-2::-1] # remove old final 20 frames, then unwind once
            info['reverse_return']=True
        if state=='idle':
            frames=frames+frames[-2:0:-1] # subtle breathing loop, never reverse a walking cycle
        sheet=Image.new('RGBA',(384*8,384*math.ceil(len(frames)/8)))
        for i,f in enumerate(frames):sheet.paste(f,((i%8)*384,(i//8)*384))
        path=folder/(state+'.png');sheet.save(path)
        entry['states'][state]={'texture':'res://'+str(path.relative_to(ROOT/'game')).replace(chr(92),'/'),'frames':len(frames),'columns':8,'fps':24.0,'loop':state in ['run','idle']}
        report[boss+'/'+state]={'source':name+'.mp4',**info,'frames':len(frames),'alignment':[dx,dy]}
        row=Image.new('RGB',(960,180),'#272536');d=ImageDraw.Draw(row)
        for k in range(6):
            f=frames[min(len(frames)-1,round(k*(len(frames)-1)/5))].resize((160,160));row.paste(f,(k*160,0),f)
        d.text((4,162),boss+'/'+state,fill='white');preview.append(row)
        print(boss,state,len(frames),info,flush=True)
    manifest[boss]=entry
manifest_path.write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(OUT/'import-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
contact=Image.new('RGB',(960,len(preview)*180))
for i,row in enumerate(preview):contact.paste(row,(0,i*180))
contact.save(OUT/'keyed-contact.jpg')
