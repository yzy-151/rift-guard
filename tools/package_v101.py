"""Package verified V101 artifacts; keep executable hashes separate from ZIP hash."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import re
import shutil
import zipfile
import argparse
from v101_evidence import identity, source_digest

ROOT = Path(__file__).resolve().parents[1]
VALIDATION = ROOT / 'docs/v101-validation'
EVIDENCE = VALIDATION / 'evidence'
parser = argparse.ArgumentParser()
parser.add_argument('--package', type=Path, default=ROOT / 'releases/V101')
args = parser.parse_args()
PACKAGE = args.package.resolve()
EVIDENCE.mkdir(exist_ok=True)

def metadata(path):
    digest = hashlib.sha256()
    with path.open('rb') as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b''):
            digest.update(chunk)
    return dict(name=path.name, bytes=path.stat().st_size, sha256=digest.hexdigest())

report = dict(version='101.0.0', source_base='18082a8151a66fa0df21f3dd1d8e51dcb04b5ccc',
              validated_at=datetime.now(timezone.utc).isoformat(), engine='Godot 4.6 stable', phases={}, source_sha256=source_digest())
release_identity = identity(PACKAGE / 'RiftGuard-V101.exe', True)
assert json.loads((PACKAGE / 'build-identity.json').read_text(encoding='utf-8')) == release_identity, 'Build changed since export'
for phase, expected in [('source', 14), ('release', 10)]:
    results = json.loads((VALIDATION / phase / 'results.json').read_text(encoding='utf-8'))
    assert len(results) == expected and all(row['ok'] and row['exit_code'] == 0 for row in results)
    assert len({row['name'] for row in results}) == expected, 'Duplicate test cases'
    assert all(row.get('identity', {}).get('source_sha256') == report['source_sha256'] for row in results), 'Stale source evidence: rerun acceptance'
    if phase == 'release':
        assert all(row['identity'] == release_identity for row in results), 'Package differs from tested binaries'
    count = 0
    for row in results:
        case = VALIDATION / phase / row['name']
        log = (case / 'run.log').read_text(encoding='utf-8')
        assert not re.search(r'(^|\n)(SCRIPT ERROR:|ERROR:|FAIL:)', log)
        match = re.findall(r'(\d+) checks, 0 failures|checks=(\d+) failures=0', log)
        if match:
            checks = int(next(value for value in match[-1] if value))
        else:
            result = json.loads((case / 'pause-results.json').read_text(encoding='utf-8'))
            assert not result['failures']
            checks = result['checks']
        row['checks'] = checks
        count += checks
        shutil.copy2(case / 'run.log', EVIDENCE / f'{phase}-{row["name"]}.log')
    (EVIDENCE / f'{phase}-results.json').write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding='utf-8')
    report['phases'][phase] = dict(processes=len(results), assertions=count, failures=0)
    processes = [json.loads((VALIDATION / phase / f'restart-{mode}/report.json').read_text(encoding='utf-8'))['pid'] for mode in ['write', 'read']]
    assert len(set(processes)) == 2
    report['phases'][phase]['restart_processes'] = processes

for size in ['1280x720', '1920x1080']:
    for name in ['03-restored-scenario', '05-backup-confirmation']:
        shutil.copy2(VALIDATION / 'release' / f'workshop-{size}' / f'{name}.png', EVIDENCE / f'{size}-{name}.png')
shutil.copy2(VALIDATION / 'source/scenarios/v101_scenarios_report.json', EVIDENCE / 'logic-report.json')
shutil.copy2(ROOT / 'outputs/build-v101.log', EVIDENCE / 'build.log')
shutil.copy2(VALIDATION / 'normal-startup/run.log', EVIDENCE / 'normal-startup.log')
report['artifacts'] = [metadata(PACKAGE / name) for name in ['RiftGuard-V101.exe', 'RiftGuard-V101.pck']]
(PACKAGE / 'SHA256SUMS.txt').write_text(''.join(f'{row["sha256"]}  {row["name"]}\n' for row in report['artifacts']), encoding='utf-8')
shutil.copy2(ROOT / 'docs/v101-release-notes.md', PACKAGE / 'V101-游玩与改动.md')
shutil.copytree(EVIDENCE, PACKAGE / 'validation', dirs_exist_ok=True)
(PACKAGE / 'validation/release-report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
archive = PACKAGE / 'RiftGuard-V101-Windows.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
    for file in sorted(PACKAGE.rglob('*')):
        if file.is_file() and file != archive:
            bundle.write(file, file.relative_to(PACKAGE))
with zipfile.ZipFile(archive) as bundle:
    assert bundle.testzip() is None
report['artifacts'].append(metadata(archive))
(VALIDATION / 'release-report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
