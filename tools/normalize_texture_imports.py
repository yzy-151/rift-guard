from pathlib import Path
import re,json
# Run from the repository root; source PNGs remain unchanged.
root=Path('game/assets'); changes=[]
Path('outputs/optimization-v88').mkdir(parents=True,exist_ok=True)
for p in root.rglob('*.png.import'):
 s=p.read_text(encoding='utf-8'); rel=p.as_posix(); mode=None; limit=0
 if '/sequences/' in rel: mode=2 if any('/'+k+'/' in rel for k in ['hilichurl_brute','shielded']) else 1
 elif any(k in rel for k in ['/dialogue_portraits/','/illustrations_v2/','/transitions/']):mode=1;limit=1536
 if mode is None:continue
 s=re.sub(r'compress/mode=\d+',f'compress/mode={mode}',s)
 s=re.sub(r'compress/lossy_quality=[\d.]+','compress/lossy_quality=0.88',s)
 s=re.sub(r'process/size_limit=\d+',f'process/size_limit={limit}',s)
 p.write_text(s,encoding='utf-8');changes.append({'path':rel,'mode':mode,'max_size':limit})
Path('outputs/optimization-v88/import-policy.json').write_text(json.dumps(changes,indent=2))
print('Import settings normalized:',len(changes))
