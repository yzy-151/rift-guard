from pathlib import Path
import subprocess,json,time,re
from validate_v33_restart import run_restart_checks
root=Path(__file__).resolve().parents[1]
engine=root.parent/'.tools/godot/Godot_v4.4.1-stable_win64_console.exe'
out=root/'docs/v33-validation'
out.mkdir(parents=True,exist_ok=True)
results=[]
for version in [33,32,31,30,29,28,26,25,20,17]:
    start=time.time()
    result=subprocess.run([str(engine),'--headless','--path',str(root/'game'),'--quit-after','9000','--',f'--v{version}-test'],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
    log=result.stdout+result.stderr
    (out/f'headless-v{version}.log').write_text(log,encoding='utf-8')
    summary=[line for line in log.splitlines() if 'QA COMPLETE' in line]
    ok=result.returncode==0 and bool(summary) and re.fullmatch(rf'V{version} QA COMPLETE: [1-9][0-9]* checks, 0 failures', summary[-1]) is not None and 'SCRIPT ERROR' not in log and 'ERROR:' not in log
    row={'suite':f'V{version}','exit_code':result.returncode,'ok':ok,'summary':summary,'seconds':round(time.time()-start,2)}
    results.append(row); print(json.dumps(row,ensure_ascii=False),flush=True)
for test in ['test_run_state','test_core_loop_v2','test_game_database','test_stage_runtime','test_card_pool_v2','test_mechanic_cards','test_crystal_progression','test_story']:
    start=time.time()
    result=subprocess.run([str(engine),'--headless','--path',str(root/'game'),'--script',f'res://tests/{test}.gd'],capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=90)
    log=result.stdout+result.stderr
    (out/f'{test}.log').write_text(log,encoding='utf-8')
    ok=result.returncode==0 and 'PASS' in log.upper() and 'ERROR:' not in log
    row={'suite':test,'exit_code':result.returncode,'ok':ok,'summary':[line for line in log.splitlines() if 'PASS' in line.upper()],'seconds':round(time.time()-start,2)}
    results.append(row); print(json.dumps(row,ensure_ascii=False),flush=True)
(out/'regression-results.json').write_text(json.dumps(results,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
restart_ok = run_restart_checks(engine)
raise SystemExit(0 if all(row['ok'] for row in results) and restart_ok else 1)
