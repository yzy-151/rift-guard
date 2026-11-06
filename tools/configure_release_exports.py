import json,os,re,secrets,subprocess,shutil
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];G=ROOT/'game'
T=Path('C:/Users/23081/Desktop/codex/.tools/android-release')
p=json.loads((T/'paths.json').read_text(encoding='utf8'))
settings=Path('C:/Users/23081/AppData/Roaming/Godot/editor_settings-4.4.tres')
if not (T/'editor-settings-before.tres').exists():shutil.copy2(settings,T/'editor-settings-before.tres')
s=settings.read_text(encoding='utf8')
for key,value in {'export/android/java_sdk_path':p['jdk'],'export/android/android_sdk_path':p['sdk'],'export/windows/rcedit':'C:/Users/23081/Desktop/codex/.tools/rcedit-v2.0.0/rcedit.exe'}.items():
    s=re.sub(re.escape(key)+r' = .*',key+' = '+json.dumps(value.replace('\\','/')),s)
settings.write_text(s,encoding='utf8')
sign=T/'release-signing.json'
env=os.environ.copy();env['JAVA_HOME']=p['jdk'];env['PATH']=p['jdk']+'/bin;'+env['PATH']
if not sign.exists():
    config={'keystore':str(T/'rift-guard-release.keystore'),'alias':'riftguard','password':secrets.token_urlsafe(32)}
    env['RIFT_SIGN_PASSWORD']=config['password']
    subprocess.run([p['jdk']+'/bin/keytool.exe','-genkeypair','-keystore',config['keystore'],'-alias',config['alias'],'-storepass:env','RIFT_SIGN_PASSWORD','-keypass:env','RIFT_SIGN_PASSWORD','-keyalg','RSA','-keysize','3072','-validity','10000','-dname','CN=Rift Guard, OU=Game, O=Rift Guard, C=CN'],env=env,check=True,capture_output=True)
    sign.write_text(json.dumps(config),encoding='utf8')
presets=(G/'export_presets.cfg').read_text(encoding='utf8')
presets=presets.replace('res://assets/ui/rift_guard_emblem_v1.ico','res://assets/ui/release_20261106/icon.ico')
presets=re.sub(r'application/(file_version|product_version)="[^"]+"',lambda m:'application/'+m[1]+'="2026.11.7.1"',presets)
presets=re.sub(r'application/file_description="[^"]+"','application/file_description="Rift Guard Three Chapter Demo"',presets)
presets=re.sub(r'version/code=\d+','version/code=20261108',presets)
presets=re.sub(r'version/name="[^"]+"','version/name="2026.11.7.1"',presets)
presets=presets.replace('package/unique_name="com.riftguard.game"','package/unique_name="com.riftguard.demo"').replace('package/name="Rift Guard"','package/name="裂隙守望"')
presets=presets.replace('architectures/x86_64=false','architectures/x86_64=true')
# Keep both platforms' exact data/asset inclusion and exclusion lists identical.
first=presets.split('[preset.1]')[0]
include=re.search(r'^include_filter=(.*)$',first,re.M)[1]
exclude=re.search(r'^exclude_filter=(.*)$',first,re.M)[1]
presets=re.sub(r'^include_filter=.*$',lambda m:'include_filter='+include,presets,flags=re.M)
presets=re.sub(r'^exclude_filter=.*$',lambda m:'exclude_filter='+exclude,presets,flags=re.M)
presets=presets.replace('../builds/rift-guard-v97-readable/RiftGuard-Windows.exe','../builds/release-20261107/RiftGuard.exe').replace('../builds/rift-guard-v97-readable/RiftGuard-Android.apk','../builds/release-20261107/RiftGuard-Android.apk')
if 'launcher_icons/main_192x192' not in presets:presets+='\nlauncher_icons/main_192x192="res://assets/ui/release_20261106/icon.png"\nlauncher_icons/adaptive_foreground_432x432="res://assets/ui/release_20261106/icon.png"\n'
(G/'export_presets.cfg').write_text(presets,encoding='utf8')
(ROOT/'builds/release-20261107').mkdir(exist_ok=True,parents=True)
print('EXPORTS CONFIGURED; private signing material stays outside repository')
