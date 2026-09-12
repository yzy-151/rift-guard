"""Exercise checkpoint persistence across three real game processes."""
from pathlib import Path
import argparse
import json
import re
import subprocess
import uuid

root = Path(__file__).resolve().parents[1]


def run_restart_checks(executable, release=False):
    out = root / 'docs/v33-validation'
    out.mkdir(parents=True, exist_ok=True)
    session = 'run_' + uuid.uuid4().hex
    prefix = 'release' if release else 'source'
    results = []
    for role in ['write', 'resume', 'settled']:
        logfile = out / f'{prefix}-restart-{role}.log'
        args = [str(executable), '--log-file', str(logfile), '--quit-after', '9000']
        args += ['--resolution', '1280x720'] if release else ['--headless', '--path', str(root / 'game')]
        args += ['--', '--v33-restart-test', f'--qa-session={session}', f'--qa-role={role}']
        result = subprocess.run(args, cwd=executable.parent if release else root,
                                capture_output=True, text=True, encoding='utf-8',
                                errors='replace', timeout=90)
        log = logfile.read_text(encoding='utf-8-sig') if logfile.exists() else result.stdout + result.stderr
        summary = re.findall(r'V33 RESTART QA COMPLETE: (\d+) checks, (\d+) failures', log)
        process = re.search(rf'V33 RESTART PROCESS: (\d+) {role}', log)
        pid = int(process[1]) if process else None
        ok = (result.returncode == 0 and len(summary) == 1 and int(summary[0][0]) > 0
              and summary[0][1] == '0' and 'ERROR:' not in log
              and pid is not None and pid not in [row['pid'] for row in results])
        row = {'role': role, 'pid': pid, 'session': session, 'exit_code': result.returncode,
               'ok': ok, 'checks': int(summary[0][0]) if summary else 0}
        results.append(row)
        print(json.dumps(row), flush=True)
        if not ok:
            break
    (out / f'{prefix}-restart-results.json').write_text(json.dumps(results, indent=2) + '\n', encoding='utf-8')
    return len(results) == 3 and all(row['ok'] for row in results)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--release', action='store_true')
    options = parser.parse_args()
    exe = (root / 'builds/rift-guard-v33/RiftGuard-V33.exe' if options.release else
           root.parent / '.tools/godot/Godot_v4.4.1-stable_win64_console.exe')
    raise SystemExit(0 if run_restart_checks(exe, options.release) else 1)
