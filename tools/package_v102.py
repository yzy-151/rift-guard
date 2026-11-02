"""Package only the exact binaries accepted by both V102 phases."""
import argparse
import json
from pathlib import Path
import shutil
import zipfile
from datetime import datetime, timezone
from v101_evidence import identity, sha256, source_digest

ROOT = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser()
parser.add_argument('--package', type=Path, default=ROOT / 'releases/V102')
parser.add_argument('--build-identity', action='store_true')
args = parser.parse_args()
package = args.package.resolve()
binary = identity(package / 'RiftGuard-V102.exe', True)
if args.build_identity:
    (package / 'build-identity.json').write_text(json.dumps(binary, indent=2), encoding='utf-8')
    raise SystemExit(0)
assert binary == json.loads((package / 'build-identity.json').read_text()), 'Build changed'
validation = ROOT / 'docs/v102-validation'
evidence = validation / 'evidence'
evidence.mkdir(exist_ok=True)
report = dict(version='102.0.0', base='fde715d06c1945164d55e83dc4fd5a26e3c2c560',
              validated_at=datetime.now(timezone.utc).isoformat(), identity=binary, phases={})
for phase, count in [('source', 12), ('release', 10)]:
    rows = json.loads((validation / phase / 'results.json').read_text())
    assert len(rows) == count and len({row['name'] for row in rows}) == count
    assert all(row['ok'] and row['checks'] > 0 and row['exit_code'] == 0 for row in rows)
    assert all(row['identity']['source_sha256'] == source_digest() for row in rows)
    if phase == 'release': assert all(row['identity'] == binary for row in rows)
    for row in rows:
        shutil.copy2(validation / phase / row['name'] / 'run.log', evidence / f'{phase}-{row["name"]}.log')
    shutil.copy2(validation / phase / 'results.json', evidence / f'{phase}-results.json')
    report['phases'][phase] = dict(processes=count, checks=sum(row['checks'] for row in rows), failures=0)
for size in ['1280x720', '1920x1080']:
    for file in (validation / 'release' / ('modes-' + size)).glob('*.png'):
        shutil.copy2(file, evidence / f'{size}-{file.name}')
    shutil.copy2(validation / 'release' / ('pause-' + size) / '02-pause-full.png', evidence / f'{size}-pause-full.png')
for case in ['dialogue', 'endflow']:
    for file in (validation / 'release' / case).glob('*.png'):
        shutil.copy2(file, evidence / f'{case}-{file.name}')
shutil.copy2(validation / 'baseline.log', evidence / 'baseline.log')
shutil.copy2(validation / 'build.log', evidence / 'build.log')
shutil.copy2(validation / 'README.md', package / '测试记录.md')
shutil.copytree(evidence, package / 'validation', dirs_exist_ok=True)
def meta(path): return dict(name=path.name, bytes=path.stat().st_size, sha256=sha256(path))
report['artifacts'] = [meta(package / ('RiftGuard-V102' + ext)) for ext in ['.exe', '.pck']]
(package / 'SHA256SUMS.txt').write_text(''.join(f'{r["sha256"]}  {r["name"]}\n' for r in report['artifacts']), encoding='utf-8')
(package / 'validation/release-report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
archive = package / 'RiftGuard-V102-Windows.zip'
with zipfile.ZipFile(archive, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as bundle:
    for file in sorted(package.rglob('*')):
        if file.is_file() and file != archive: bundle.write(file, file.relative_to(package))
with zipfile.ZipFile(archive) as bundle: assert bundle.testzip() is None
report['artifacts'].append(meta(archive))
(validation / 'release-report.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
print(json.dumps(report, indent=2))
