from pathlib import Path
from collections import defaultdict
import json
root=Path('game');groups=defaultdict(int);files=[]
for p in root.rglob('*'):
 if p.is_file():
  size=p.stat().st_size
  key='/'.join(p.parts[:4]) if p.parts[1]=='assets' else '/'.join(p.parts[:2])
  groups[key]+=size
  if '.godot' not in p.parts:files.append((size,str(p)))
print('GROUPS MB');print('\n'.join(f'{v/1048576:.1f} {k}' for k,v in sorted(groups.items(),key=lambda x:-x[1])[:25]))
print('FILES MB');print('\n'.join(f'{s/1048576:.1f} {p}' for s,p in sorted(files,reverse=True)[:25]))
Path('outputs/optimization-v88').mkdir(exist_ok=True)
Path('outputs/optimization-v88/source-size-before.json').write_text(json.dumps({'groups':groups,'files':sorted(files,reverse=True)},indent=2),encoding='utf-8')
