return await (async()=>{
 if(penpot.currentFile.id!=='d8ac01df-6646-81d2-8008-a3696fea940e')throw Error('Wrong Penpot file');
 const endpoint='http://127.0.0.1:4438',folder=endpoint+'/_workspace/premium-menu-v08/';
 const read=async(name,optional=false)=>{const r=await fetch(folder+name);if(!r.ok){if(optional)return null;throw Error(name+' '+r.status);}return await r.json();};
 const [base,spec,records]=await Promise.all([read('baseline-audit.json'),read('scene-spec.json'),read('export-records.json',true)]);
 const N=storage.v08={endpoint,base,spec,path:'Premium Menu v08',boards:{},snapshots:{},media:{},exportRecords:{},designExportRecords:{},comparisonExportRecords:{},comparisons:{}};
 N.post=async(name,data)=>{const r=await fetch(endpoint+'/record/'+name,{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(data)});if(!r.ok)throw Error('Record '+name+' '+r.status);return true;};
 const pages=penpot.currentFile.pages,top=pages.flatMap(p=>p.root.children.map(b=>({p,b}))),byId=new Map(top.map(x=>[x.b.id,x]));
 N.all=b=>penpotUtils.findShapes(()=>true,b);
 N.snap=b=>N.all(b).map(s=>({id:s.id,name:s.name,type:s.type,x:s.x,y:s.y,w:s.width,h:s.height,hidden:s.hidden,opacity:s.opacity??null,text:s.characters||null,children:s.children?.map(c=>c.id)||null,fills:s.fills?.map(f=>({color:f.fillColor??null,opacity:f.fillOpacity??null,image:f.fillImage?.id??null})),interactions:(s.interactions||[]).map(i=>({trigger:i.trigger,type:i.action.type,dest:i.action.destination?.id||null}))}));
 const names=new Set(spec.scenes.map(s=>s.name));
 for(const {b} of top){if(names.has(b.name)&&b.getPluginData('v08-ready')){N.boards[b.name]=b;const image=b.getPluginData('v08-snapshot-media');if(image)N.snapshots[b.name]=JSON.parse(image);}if(b.name.startsWith('CMP20 / MENU08 / '))N.comparisons[b.name]=b;}
 N.proto=penpotUtils.getPageByName('10_Prototype');if(!N.proto)throw Error('Prototype page missing');
 N.states=penpotUtils.getPageByName('12_Menu_States_v08');if(!N.states){N.states=penpot.createPage();N.states.name='12_Menu_States_v08';}
 N.protoMap=Object.fromEntries(N.proto.root.children.filter(b=>b.name.startsWith('PROTO / ')).map(b=>[b.name.slice(8),b]));
 const knownMedia={
  'character-room':'129977ce-683b-806a-8008-c9116a79097b',
  'accessory-workshop':'129977ce-683b-806a-8008-c9116bee8da8',
  'shop-market':'129977ce-683b-806a-8008-c9116d93d7cb',
  archive:'129977ce-683b-806a-8008-c9116f158d22',
  'social-lodge':'0f3fb038-01f9-8046-8008-c911709dfea2',
  observatory:'129977ce-683b-806a-8008-c911722138ef',
  'ja-hyun':'0f3fb038-01f9-8046-8008-c9117398715f',
  'myo-ryung':'129977ce-683b-806a-8008-c91174f9d6fb',
  nabi:'0f3fb038-01f9-8046-8008-c91176630fdd',
  'yu-ran':'129977ce-683b-806a-8008-c91177ce9f9a'
 };
 const keyByMedia=Object.fromEntries(Object.entries(knownMedia).map(([k,id])=>[id,k]));
 // Fourteen known source boards only; inspect direct art and one portrait nesting level.
 for(const old of base.boards.filter(x=>x.target)){
  const b=byId.get(old.id)?.b;if(!b)throw Error('Original source missing '+old.name);
  for(const child of b.children)for(const s of [child,...(child.children||[])])for(const fill of s.fills||[]){const media=fill.fillImage,key=media&&keyByMedia[media.id];if(key&&!N.media[key])N.media[key]=media;}
 }
 const missing=Object.keys(knownMedia).filter(k=>!N.media[k]);if(missing.length)throw Error('Missing known approved media: '+missing.join(','));
 for(const r of records?.scenes||[])N.exportRecords[r.name]=r;
 for(const r of records?.designExports||[])N.designExportRecords[r.name]=r;
 for(const r of records?.comparisons||[])N.comparisonExportRecords[r.name]=r;
 N.components=Object.fromEntries(penpot.library.local.components.filter(c=>c.path===N.path).map(c=>[c.name,c]));
 N.force=false;
 return {resumed:true,file:penpot.currentFile.id,scenes:spec.scenes.length,ready:Object.keys(N.boards).length,media:Object.keys(N.media),components:Object.keys(N.components).length,exports:Object.keys(N.exportRecords).length,designs:Object.keys(N.designExportRecords).length,snapshots:Object.keys(N.snapshots).length};
})();
