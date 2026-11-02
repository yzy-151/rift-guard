"""Serial source/release acceptance with isolated saves and exact result checks."""
import argparse
import json
import pathlib
import re
import subprocess
import time
import uuid
from datetime import datetime, timezone
from v101_evidence import identity

ROOT = pathlib.Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--phase', choices=['source', 'release'], required=True)
parser.add_argument('--engine', type=pathlib.Path)
parser.add_argument('--release', type=pathlib.Path)
parser.add_argument('--only', nargs='+', help='Rerun selected cases, preserving other recorded results')
args = parser.parse_args()
if (args.phase == 'source' and not args.engine) or (args.phase == 'release' and not args.release):
    parser.error('Source requires --engine; release requires --release')
if args.only and bool('restart-write' in args.only) != bool('restart-read' in args.only):
    parser.error('Cross-process restart must rerun both restart-write and restart-read together')
exe = (args.engine if args.phase == 'source' else args.release).resolve()
tested_identity = identity(exe, args.phase == 'release')
out = ROOT / 'docs' / 'v101-validation' / args.phase
out.mkdir(parents=True, exist_ok=True)
shared = ROOT / 'outputs' / ('v101-restart-' + uuid.uuid4().hex)
rows = json.loads((out / 'results.json').read_text(encoding='utf-8')) if args.only and (out / 'results.json').exists() else []
if rows and any(row.get('identity') != tested_identity for row in rows):
    parser.error('Source or binary changed: run the full phase instead of mixing stale results')

def run(name, options, headless=True, timeout=150):
    if args.only and name not in args.only:
        return True
    target = out / name
    target.mkdir(exist_ok=True)
    command = [str(exe)]
    if headless:
        command.append('--headless')
    if args.phase == 'source':
        command += ['--path', str(ROOT / 'game')]
    if options and options[0] == '--script':
        command += options[:2]
        options = options[2:]
    command += ['--', f'--qa-output={target}', *options]
    started = time.time()
    try:
        result = subprocess.run(command, cwd=exe.parent if args.phase == 'release' else ROOT,
                                capture_output=True, text=True, encoding='utf-8', errors='replace',
                                timeout=timeout, creationflags=subprocess.CREATE_NO_WINDOW)
        log, code = result.stdout + result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        log = str(error)
        code = -1
    (target / 'run.log').write_text(log, encoding='utf-8')
    summaries = [line for line in log.splitlines() if re.search(r'\d+ checks, \d+ failures|checks=\d+ failures=\d+|PASS|passed', line, re.I)]
    success_marker = bool(re.search(r'[1-9]\d* checks, 0 failures|checks=[1-9]\d* failures=0|\bPASS\b|\bpassed\b', log, re.I))
    ok = code == 0 and success_marker and not re.search(r'(^|\n)(SCRIPT ERROR:|ERROR:|FAIL:)|\bchecks,\s*[1-9]\d* failures\b|\bfailures=[1-9]\d*\b', log)
    row = dict(name=name, ok=ok, exit_code=code, seconds=round(time.time()-started, 2), summary=summaries[-3:], validated_at=datetime.now(timezone.utc).isoformat(), identity=tested_identity)
    rows[:] = [previous for previous in rows if previous['name'] != name]
    rows.append(row)
    (out / 'results.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps(row, ensure_ascii=True), flush=True)
    return ok

if args.phase == 'source':
    for name, script in [('scenarios', 'tests/qa_v101_scenarios.gd'),
                         ('workshop', 'tests/qa_v93_workshop.gd'),
                         ('toolbar', 'tests/qa_v94_workshop_toolbar.gd'),
                         ('ui-lab', 'editor/ui_lab/tests/ui_lab_validation.gd')]:
        run(name, ['--script', 'res://' + script])
for mode in ['write', 'read']:
    run('restart-' + mode, ['--v101-test', '--qa-scenario-mode=' + mode,
                           '--qa-scenario-directory=' + str(shared)])
restart_reports = [json.loads((out / ('restart-' + mode) / 'report.json').read_text(encoding='utf-8'))
                   for mode in ['write', 'read']]
if restart_reports[0]['pid'] == restart_reports[1]['pid']:
    raise RuntimeError('Restart validation must use two different processes')
for size in ['1280x720', '1920x1080']:
    run('workshop-' + size, ['--v101-test', '--qa-size=' + size], headless=False)
for name, flag, headless in [('simulation', '--v95-simulation-test', True),
                             ('pause', '--v95-pause-test', False),
                             ('dialogue', '--v95-dialogue-test', False),
                             ('explosion', '--v95-explosion-test', False),
                             ('endflow', '--v94-endflow-test', False),
                             ('classic', '--classic-release-test', False)]:
    run(name, [flag], headless=headless)
if identity(exe, args.phase == 'release') != tested_identity:
    raise RuntimeError('Source or binary changed during acceptance; evidence is not releasable')
raise SystemExit(0 if all(row['ok'] for row in rows) else 1)
