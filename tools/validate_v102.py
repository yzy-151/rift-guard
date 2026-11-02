"""Serial source and release UI acceptance bound to source and binary hashes."""
import argparse
import json
from pathlib import Path
import re
import subprocess
import time
from datetime import datetime, timezone
from v101_evidence import identity

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--phase', choices=['source', 'release'], required=True)
parser.add_argument('--executable', type=Path, required=True)
parser.add_argument('--only', nargs='+', help='Retry named cases only if source and binary identity are unchanged')
args = parser.parse_args()
exe = args.executable.resolve()
release = args.phase == 'release'
fingerprint = identity(exe, release)
out = ROOT / 'docs/v102-validation' / args.phase
out.mkdir(parents=True, exist_ok=True)
cases = []
if not release:
    cases += [('ui-lab', ['--script', 'res://editor/ui_lab/tests/ui_lab_validation.gd'], True),
              ('scenarios', ['--script', 'res://tests/qa_v101_scenarios.gd'], True)]
for size in ['1280x720', '1920x1080']:
    cases += [('modes-' + size, ['--v102-test', '--qa-size=' + size], False),
              ('pause-' + size, ['--v95-pause-test', '--qa-size=' + size], False)]
cases += [(name, [flag], headless) for name, flag, headless in [
    ('simulation', '--v95-simulation-test', True),
    ('dialogue', '--v95-dialogue-test', False),
    ('endflow', '--v94-endflow-test', False),
    ('classic', '--classic-release-test', False),
    ('explosion', '--v95-explosion-test', False),
    ('workshop', '--v101-test', False)]]
rows = json.loads((out / 'results.json').read_text()) if args.only and (out / 'results.json').exists() else []
if rows and any(row['identity'] != fingerprint for row in rows):
    parser.error('Cannot combine evidence from different sources or binaries')
if args.only and not set(args.only).issubset({case[0] for case in cases}):
    parser.error('Unknown case name')
for name, options, headless in cases:
    if args.only and name not in args.only:
        continue
    target = out / name
    target.mkdir(exist_ok=True)
    command = [str(exe)] + (['--headless'] if headless else [])
    if not release:
        command += ['--path', str(ROOT / 'game')]
    if options[0] == '--script':
        command += options[:2]
        options = options[2:]
    command += ['--', f'--qa-output={target}', *options]
    start = time.monotonic()
    try:
        result = subprocess.run(command, cwd=exe.parent if release else ROOT, capture_output=True,
                                text=True, encoding='utf-8', errors='replace', timeout=180,
                                creationflags=subprocess.CREATE_NO_WINDOW)
        log, code = result.stdout + result.stderr, result.returncode
    except subprocess.TimeoutExpired as error:
        log, code = str(error), -1
    (target / 'run.log').write_text(log, encoding='utf-8')
    match = re.findall(r'(\d+) checks, 0 failures|checks=(\d+) failures=0', log)
    count = int(next(value for value in match[-1] if value)) if match else 0
    if name.startswith('pause-') and (target / 'pause-results.json').exists():
        report = json.loads((target / 'pause-results.json').read_text(encoding='utf-8'))
        count = report['checks'] if not report['failures'] else 0
    ok = code == 0 and count > 0 and not re.search(r'ERROR:|\bFAIL\b|instances leaked|resources still in use', log)
    row = dict(name=name, ok=ok, exit_code=code, checks=count, seconds=round(time.monotonic()-start, 2),
               identity=fingerprint, validated_at=datetime.now(timezone.utc).isoformat())
    rows[:] = [old for old in rows if old['name'] != name]
    rows.append(row)
    (out / 'results.json').write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in row.items() if k != 'identity'}), flush=True)
if identity(exe, release) != fingerprint:
    raise RuntimeError('Sources or binaries changed during acceptance')
raise SystemExit(0 if all(row['ok'] for row in rows) else 1)
