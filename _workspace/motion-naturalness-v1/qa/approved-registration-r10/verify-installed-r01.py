"""Verify the installed, user-approved runtime against frozen product inputs."""
from pathlib import Path
import hashlib,json,subprocess,re
ROOT=Path(__file__).resolve().parents[4];BASE=Path(__file__).resolve().parent
assert (ROOT/'project.godot').is_file()
paths={ROOT/'project.godot'}
for folder in ['assets','forest_arena','scripts','server','scenes','tests','tools','docs','.agents']:
 for p in (ROOT/folder).rglob('*'):
  rel=p.relative_to(ROOT)
  if p.is_file() and '__pycache__' not in rel.parts and p.suffix not in ['.pyc','.pyo'] and p.name!='.DS_Store':paths.add(p)
def fingerprints():return {str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(paths)}
before=fingerprints();(BASE/'full-inputs-r01.json').write_text(json.dumps(before,indent=2)+'\n')
log=BASE/'verify-installed-r01.log';assert not log.exists()
with log.open('w') as handle:r=subprocess.run(['./scripts/verify.sh'],cwd=ROOT,stdout=handle,stderr=subprocess.STDOUT)
after=fingerprints();s=log.read_text();errors=[line for line in s.splitlines() if line.startswith('ERROR:')];unexpected=[line for line in errors if not re.fullmatch(r'ERROR: \d+ resources still in use at exit \(run with --verbose for details\)\.',line)]
result={'status':'pass' if r.returncode==0 and before==after and 'Forest Arena verification passed.' in s and not any(x in s for x in ['SCRIPT ERROR','Traceback','FAIL']) and not unexpected else 'fix','exit_code':r.returncode,'inputs':len(before),'inputs_unchanged':before==after,'changed':[k for k,v in before.items() if after.get(k)!=v],'terminal_sentinel':'Forest Arena verification passed.' in s,'unexpected_errors':unexpected,'known_resource_exit_errors':len(errors)-len(unexpected),'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'scope':'full product verification after approved25 registration and one obsolete stage tag removal; no physical Android claim'}
(BASE/'verification-installed-r01.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));raise SystemExit(0 if result['status']=='pass' else 1)
