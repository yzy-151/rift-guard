from pathlib import Path
import subprocess,json,hashlib,time,re
from validate_v33_restart import run_restart_checks
root=Path(__file__).resolve().parents[1]
exe=root/'builds/rift-guard-v33/RiftGuard-V33.exe'
out=root/'docs/v33-validation'
results=[]
for name,args in [
    ('release-headless-v33',['--headless','--','--v33-test']),
    ('release-visual-v33',['--resolution','1920x1080','--','--v33-test',f'--qa-output={(out/"release").as_posix()}']),
    ('release-visual-v33-ui',['--resolution','1920x1080','--','--v33-ui-test',f'--qa-output={(out/"release-ui").as_posix()}']),
    ('release-visual-v17',['--resolution','1280x720','--','--v17-test']),
]:
    logfile=out/f'{name}.log'
    start=time.time()
    result=subprocess.run([str(exe),'--log-file',str(logfile),'--quit-after','9000',*args],cwd=exe.parent,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
    log=logfile.read_text(encoding='utf-8-sig') if logfile.exists() else result.stdout+result.stderr
    summary=[line for line in log.splitlines() if 'QA COMPLETE' in line]
    ok=result.returncode==0 and bool(summary) and re.fullmatch(r'V(?:33|17)(?: UI)? QA COMPLETE: [1-9][0-9]* checks, 0 failures', summary[-1]) is not None and 'ERROR:' not in log
    row={'suite':name,'exit_code':result.returncode,'ok':ok,'summary':summary,'seconds':round(time.time()-start,2)}
    results.append(row);print(json.dumps(row),flush=True)
logfile=out/'release-normal-startup.log'
start=time.time()
result=subprocess.run([str(exe),'--log-file',str(logfile),'--resolution','1280x720','--quit-after','90','--','--qa-startup'],cwd=exe.parent,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=30)
log=logfile.read_text(encoding='utf-8-sig') if logfile.exists() else result.stdout+result.stderr
ok=result.returncode==0 and 'Godot Engine' in log and 'ERROR:' not in log and 'QA COMPLETE' not in log
row={'suite':'release-normal-startup','exit_code':result.returncode,'ok':ok,'seconds':round(time.time()-start,2)}
results.append(row);print(json.dumps(row),flush=True)
restart_ok = run_restart_checks(exe, release=True)
manifest={'executable':str(exe),'bytes':exe.stat().st_size,'sha256':hashlib.sha256(exe.read_bytes()).hexdigest().upper(),'checks':results,'restart_ok':restart_ok,'restart_checks':json.loads((out/'release-restart-results.json').read_text(encoding='utf-8'))}
(out/'release-results.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'bytes':manifest['bytes'],'sha256':manifest['sha256']}),flush=True)
raise SystemExit(0 if all(row['ok'] for row in results) and restart_ok else 1)
