"""Use the repository's existing Git credential helper without printing secrets."""
import os
import subprocess
import sys

env = os.environ.copy()
env['GCM_INTERACTIVE'] = 'never'
env['GIT_TERMINAL_PROMPT'] = '0'
credential = subprocess.run(
    ['git', 'credential', 'fill'], input='protocol=https\nhost=github.com\n\n',
    text=True, capture_output=True, env=env, check=True,
)
fields = dict(line.split('=', 1) for line in credential.stdout.splitlines() if '=' in line)
if not fields.get('password'):
    raise SystemExit('GitHub credential unavailable; run gh auth login.')
env['GH_TOKEN'] = fields['password']
raise SystemExit(subprocess.run(['gh'] + sys.argv[1:], env=env).returncode)
