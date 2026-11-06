import json,os,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
T=Path('C:/Users/23081/Desktop/codex/.tools/android-release')
config=json.loads((T/'release-signing.json').read_text(encoding='utf8'));paths=json.loads((T/'paths.json').read_text(encoding='utf8'))
env=os.environ.copy();env['JAVA_HOME']=paths['jdk'];env['PATH']=paths['jdk']+'/bin;'+env['PATH']
env['GODOT_ANDROID_KEYSTORE_RELEASE_PATH']=config['keystore']
env['GODOT_ANDROID_KEYSTORE_RELEASE_USER']=config['alias']
env['GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD']=config['password']
exe='C:/Users/23081/Desktop/codex/.tools/godot/Godot_v4.4.1-stable_win64_console.exe'
for platform,out in [('Windows Desktop','RiftGuard.exe'),('Android','RiftGuard-Android.apk')]:
    if len(sys.argv)>1 and sys.argv[1]!=platform:continue
    with (ROOT/'qa/release-20261106-r2'/('export-'+platform.split()[0]+'.log')).open('w',encoding='utf8') as log:
        result=subprocess.run([exe,'--headless','--path',str(ROOT/'game'),'--export-release',platform,str(ROOT/'builds/release-20261106-r2'/out)],env=env,stdout=log,stderr=log)
    print(platform,'exit',result.returncode,flush=True)
    if result.returncode:sys.exit(result.returncode)
