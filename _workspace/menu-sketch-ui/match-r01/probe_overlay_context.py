from pathlib import Path
import json
from bootstrap import call
P=Path(__file__).resolve().parent
code="const S=storage.match09;const x=(k,n)=>S.boards[k].children.find(c=>c.name===n),clear=c=>{for(const i of c.interactions||[])i.remove();},open=k=>({type:'open-overlay',destination:S.boards[k],position:'center',closeWhenClickOutside:false,addBackgroundOverlay:false});for(const [k,n]of [['rooms','CODE / open'],['code-input','CODE / field'],['code-filled','CODE / cancel']])clear(x(k,n));x('rooms','CODE / open').addInteraction('click',open('code-input'));x('code-input','CODE / field').addInteraction('click',{type:'close-overlay'});x('code-input','CODE / field').addInteraction('click',open('code-filled'));x('code-filled','CODE / cancel').addInteraction('click',{type:'close-overlay'});return{pair:x('code-input','CODE / field').interactions.map(i=>({trigger:i.trigger,type:i.action.type}))};"
(P/'probe-overlay-context.js').write_text(code);r=call(code);print(r);(P/'overlay-probe.json').write_text(json.dumps(r,indent=2)+'\n');print(call("const v=await penpot.currentFile.saveVersion('MENU09 대전 준비 · 폼 반환 개선 검토');return{label:v.label,revn:penpot.currentFile.revn};"))
