"""Run the complete product verifier against a frozen set of product inputs."""
from pathlib import Path
import hashlib,json,subprocess
ROOT=Path(__file__).resolve().parents[3];BASE=Path(__file__).resolve().parent
paths=set(json.loads((ROOT/'_workspace/nabi-claw-vfx-v2/qa/clock-integrated-inputs-r02.json').read_text()))
paths.update(['scripts/launch_release_clock.gd','tests/launch_release_presentation.gd','docs/content/motion-action-review.md'])
def hashes(): return {p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in sorted(paths) if (ROOT/p).is_file()}
before=hashes();(BASE/'verify-current-release-inputs-r03.json').write_text(json.dumps(before,indent=2)+'\n')
log=BASE/'verify-current-release-r03.log';assert not log.exists()
with log.open('w') as handle: p=subprocess.run(['./scripts/verify.sh'],cwd=ROOT,stdout=handle,stderr=subprocess.STDOUT)
after=hashes();text=log.read_text();errors=[s for s in ['SCRIPT ERROR','Traceback','FAIL'] if s in text]
result={'status':'pass' if p.returncode==0 and not errors and before==after else 'fix','exit_code':p.returncode,'input_count':len(before),'inputs_unchanged':before==after,'changed':[k for k,v in before.items() if after.get(k)!=v],'failure_markers':errors,'log_sha256':hashlib.sha256(log.read_bytes()).hexdigest(),'known_resource_exit_messages':'inspect log separately; no device claim','scope':'current product source/full verify; unapproved candidate artwork remains uninstalled'}
(BASE/'verification-current-release-r03.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2));raise SystemExit(0 if result['status']=='pass' else 1)
