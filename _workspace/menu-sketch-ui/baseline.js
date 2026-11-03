const S=storage.menu09=storage.menu09||{};
S.hash=(o)=>{let h=2166136261;for(const c of JSON.stringify(o)){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return(h>>>0).toString(16);};
S.snap=(s)=>({id:s.id,name:s.name,type:s.type,x:s.x,y:s.y,w:s.width,h:s.height,hidden:s.hidden,opacity:s.opacity,fill:s.fills,stroke:s.strokes,text:s.type==='text'?s.characters:undefined,children:s.children?.map(S.snap)});
S.originalPages=penpotUtils.getPages();
S.baseline=S.originalPages.map(p=>{const page=penpotUtils.getPageById(p.id);return{id:p.id,name:p.name,boards:page.root.children.map(b=>({id:b.id,name:b.name,width:b.width,height:b.height,childCount:b.children?.length||0,hash:/^SCR_\d\d_/.test(b.name)?S.hash(S.snap(b)):null}))};});
S.originalComponents=penpot.library.local.components.map(c=>({id:c.id,name:c.name,path:c.path}));
S.media={};const source=penpotUtils.getPageByName('19_Menu_States_v08_08').root.children.find(b=>b.name==='MENU08 / SCR_03_Lobby / applied-myo-ryung');
for(const s of penpotUtils.findShapes(s=>s.fills?.some(f=>f.fillImage),source)){S.media[s.name.replace('ART / ','')]=s.fills.find(f=>f.fillImage).fillImage;}
for(const id of ['ja-hyun','nabi','yu-ran']){const s=penpotUtils.findShape(s=>s.name==='ART / '+id&&s.getPluginData('v08-image-slot')&&s.fills?.some(f=>f.fillImage));if(s)S.media[id]=s.fills.find(f=>f.fillImage).fillImage;}
S.components=Object.fromEntries(penpot.library.local.components.filter(c=>c.path==='Premium Menu v08').map(c=>[c.name,c]));
return {pages:S.baseline,components:S.originalComponents,media:S.media};
