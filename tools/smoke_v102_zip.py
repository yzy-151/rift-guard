"""Verify ZIP contents and launch its extracted EXE/PCK with a graphics context."""
import json
from pathlib import Path
import subprocess
import uuid
import zipfile
from v101_evidence import sha256

ROOT = Path(__file__).resolve().parents[1]
package = ROOT / 'releases/V102-20261103'
report = json.loads((ROOT / 'docs/v102-validation/release-report.json').read_text())
target = ROOT / 'releases' / ('V102-zip-smoke-' + uuid.uuid4().hex[:8])
target.mkdir()
evidence = ROOT / 'docs/v102-validation/evidence'
with zipfile.ZipFile(package / 'RiftGuard-V102-Windows.zip') as bundle:
    assert bundle.testzip() is None
    for name in ['RiftGuard-V102.exe', 'RiftGuard-V102.pck']:
        bundle.extract(name, target)
        assert sha256(target / name) == report['identity']['binaries'][name]
logfile = evidence / 'zip-startup.log'
command = [str(target / 'RiftGuard-V102.exe'), '--resolution', '1280x720', '--quit-after', '120',
           '--log-file', str(logfile), '--', '--qa-native-zip']
result = subprocess.run(command, cwd=target, capture_output=True, timeout=45,
                        creationflags=subprocess.CREATE_NO_WINDOW)
log = logfile.read_text(encoding='utf-8')
ok = result.returncode == 0 and 'OpenGL' in log and 'ERROR:' not in log
row = dict(ok=ok, exit_code=result.returncode, directory=str(target),
           zip_sha256=sha256(package / 'RiftGuard-V102-Windows.zip'), identity=report['identity'])
(evidence / 'zip-smoke.json').write_text(json.dumps(row, indent=2), encoding='utf-8')
print(json.dumps(row, indent=2))
raise SystemExit(0 if ok else 1)
