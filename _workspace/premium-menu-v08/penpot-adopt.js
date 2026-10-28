const N=storage.v08,out=[];
for(const p of penpot.currentFile.pages){for(const b of p.root.children){
 if(!['SCR_03_Lobby','SCR_05_CharacterDetail','SCR_19_Shop','EXT_06_GeneralSettings'].includes(b.name))continue;
 const spec=N.spec.scenes.find(s=>s.name===b.name),shapes=b.children.filter(s=>!s.hidden);
 if(shapes.length!==spec.elements.length||shapes.some((s,i)=>s.name!==spec.elements[i].name))throw Error('Cannot adopt '+b.name);
 for(let i=0;i<shapes.length;i++){const s=shapes[i],e=spec.elements[i];s.setPluginData('premium-menu-v08','true');if(e.kind==='image')s.setPluginData('v08-image-slot',e.slot||'IMG/bg/'+e.key);if(['button','hotspot'].includes(e.kind))s.setPluginData('v08-control',JSON.stringify({dest:e.dest||null,state:e.state||'default',legacy:e.legacy||e.name}));}
 b.setPluginData('v08-ready','true');b.setPluginData('v08-spec-name',spec.name);N.boards[b.name]=b;out.push(b.name);
}}
await N.post('local-connection-adoption.json',{reason:'Official local MCP plugin has a different plugin-data namespace from integrated MCP; adopted existing four visible native element sequences after exact names/order/count check',adopted:out,at:new Date().toISOString()});
return {adopted:out};
