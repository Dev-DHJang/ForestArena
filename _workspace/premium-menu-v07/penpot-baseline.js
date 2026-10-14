const N=storage.v07;
N.names=['SCR_04_CharacterCollection','SCR_05_CharacterDetail','SCR_06_AccessoryCollection','SCR_07_AccessoryDetail','SCR_08_Preset','SCR_19_Shop','SCR_20_Collection','SCR_21_Mission','SCR_22_Social','SCR_23_Rank','SCR_24_Profile','EXT_06_GeneralSettings','CBT_08_Settings'];
N.all=s=>penpotUtils.findShapes(()=>true,s);
N.sources=()=>penpot.currentFile.pages.flatMap(p=>p.root.children.filter(s=>/^(SCR_|EXT_|CBT_|STATE_|DEMO_|CMP20 \/ )/.test(s.name)).map(b=>({p,b})));
N.snapshot=b=>N.all(b).map(s=>({id:s.id,name:s.name,type:s.type,x:s.x,y:s.y,w:s.width,h:s.height,hidden:s.hidden,opacity:s.opacity,characters:s.characters||null,fontSize:s.fontSize||null,children:s.children?.map(c=>c.id)||null,fills:s.fills?.map(f=>({color:f.fillColor,opacity:f.fillOpacity,image:f.fillImage?.id})),strokes:s.strokes?.map(f=>({color:f.strokeColor,w:f.strokeWidth}))}));
N.links=p=>N.all(p.root).flatMap(s=>(s.interactions||[]).map((i,index)=>({id:s.id,index,name:s.name,trigger:i.trigger,type:i.action.type,destination:i.action.destination?.id||null,destinationName:i.action.destination?.name||null,animation:i.action.animation||null})));
N.post=async(name,data)=>{const r=await fetch(N.endpoint+'/record/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});if(!r.ok)throw Error('Record failed '+r.status);};
N.baseline={file:penpot.currentFile.id,revn:penpot.currentFile.revn,pages:penpotUtils.getPages(),components:penpot.library.local.components.map(c=>({id:c.id,name:c.name,path:c.path})),sources:N.sources().map(({p,b})=>({id:b.id,name:b.name,page:p.name,w:b.width,h:b.height,target:N.names.includes(b.name),shapes:N.snapshot(b)})),links:N.links(penpotUtils.getPageByName('10_Prototype'))};
N.media={};
for(const name of ['ja-hyun','myo-ryung','nabi']){const s=penpotUtils.findShape(s=>s.name==='ART / '+name&&s.fills?.some(f=>f.fillImage));if(s)N.media[name]=s.fills.find(f=>f.fillImage).fillImage;}
N.proto=penpotUtils.getPageByName('10_Prototype');
await N.post('baseline-audit.json',N.baseline);
return {sources:N.baseline.sources.length,target:N.baseline.sources.filter(s=>s.target).length,links:N.baseline.links.length,media:Object.keys(N.media),recorded:true};
