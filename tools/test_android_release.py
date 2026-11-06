import json,os,subprocess,time,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];T=Path('C:/Users/23081/Desktop/codex/.tools/android-release')
p=json.loads((T/'paths.json').read_text(encoding='utf8'));sdk=Path(p['sdk'])
avd=Path('E:/RiftGuard-Android-Test-20261106/avd')
env=os.environ.copy();env['JAVA_HOME']=p['jdk'];env['PATH']=p['jdk']+'/bin;'+env['PATH'];env['ANDROID_AVD_HOME']=str(avd);env['ANDROID_HOME']=str(sdk)
avd.mkdir(exist_ok=True,parents=True)
shutil.copytree(sdk/'cmdline-tools/bootstrap/cmdline-tools',sdk/'cmdline-tools/latest',dirs_exist_ok=True)
env['ANDROID_SDK_ROOT']=str(sdk)
manager=sdk/'cmdline-tools/latest/bin/avdmanager.bat'
if not (avd/'RiftGuardRelease20261106.ini').exists():
    subprocess.run([str(manager),'create','avd','-n','RiftGuardRelease20261106','-k','system-images;android-34;google_apis;x86_64','-d','pixel_4'],input='no\n',text=True,env=env,check=True)
cfg=avd/'RiftGuardRelease20261106.avd/config.ini'
import re
cfg.write_text(re.sub(r'disk.dataPartition.size=.*','disk.dataPartition.size=4G',cfg.read_text()),encoding='utf8')
info=subprocess.STARTUPINFO();info.dwFlags|=subprocess.STARTF_USESHOWWINDOW;info.wShowWindow=0
log=(ROOT/'qa/release-20261106/emulator.log').open('w',encoding='utf8')
proc=subprocess.Popen([str(sdk/'emulator/emulator.exe'),'-avd','RiftGuardRelease20261106','-port','5580','-no-window','-no-audio','-no-snapshot','-no-boot-anim','-no-metrics','-gpu','host','-memory','3072','-cores','4'],env=env,stdout=log,stderr=log,startupinfo=info)
(T/'emulator-pid.txt').write_text(str(proc.pid))
adb=str(sdk/'platform-tools/adb.exe')
for i in range(90):
    r=subprocess.run([adb,'-s','emulator-5580','shell','getprop','sys.boot_completed'],capture_output=True,text=True)
    if r.stdout.strip()=='1':break
    if proc.poll() is not None:raise RuntimeError('Emulator exited; inspect emulator.log')
    time.sleep(2)
else:raise RuntimeError('Emulator boot timeout')
for args in [['shell','settings','put','system','accelerometer_rotation','0'],['shell','settings','put','system','user_rotation','1'],['shell','input','keyevent','82']]:
    subprocess.run([adb,'-s','emulator-5580']+args,check=True)
print('EMULATOR READY emulator-5580',flush=True)
