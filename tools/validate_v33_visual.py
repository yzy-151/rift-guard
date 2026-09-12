from pathlib import Path
import subprocess,json,re
root=Path(__file__).resolve().parents[1]
engine=root.parent/'.tools/godot/Godot_v4.4.1-stable_win64_console.exe'
out=root/'docs/v33-validation'
results=[]
for resolution in ['1280x720','1600x900','1920x1080']:
    destination=out/resolution
    result=subprocess.run([str(engine),'--path',str(root/'game'),'--resolution',resolution,'--quit-after','9000','--','--v33-test',f'--qa-output={destination.as_posix()}'],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=120)
    log=result.stdout+result.stderr
    (out/f'visual-{resolution}.log').write_text(log,encoding='utf-8')
    summary=[line for line in log.splitlines() if 'QA COMPLETE' in line]
    ok=result.returncode==0 and bool(summary) and re.fullmatch(r'V33 QA COMPLETE: [1-9][0-9]* checks, 0 failures', summary[-1]) is not None and 'ERROR:' not in log
    row={'resolution':resolution,'ok':ok,'exit_code':result.returncode,'summary':summary}
    results.append(row);print(json.dumps(row),flush=True)
(out/'visual-results.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
raise SystemExit(0 if all(row['ok'] for row in results) else 1)
