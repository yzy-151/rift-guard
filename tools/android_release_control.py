"""Small reproducible adb helper for the isolated release-test emulator."""
import json
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
paths = json.loads((ROOT.parent / '.tools/android-release/paths.json').read_text(encoding='utf8'))
ADB = [str(Path(paths['sdk']) / 'platform-tools/adb.exe'), '-s', 'emulator-5580']
subprocess.run(ADB + ['wait-for-device'], check=True, timeout=40)
if sys.argv[1] == 'snap':
    if len(sys.argv) > 3: time.sleep(float(sys.argv[3]))
    out = ROOT / 'qa/release-20261106' / (sys.argv[2] + '.png')
    out.write_bytes(subprocess.check_output(ADB + ['exec-out', 'screencap', '-p']))
    print(out)
else:
    subprocess.run(ADB + sys.argv[1:], check=True)
