if (penpot.currentFile.id !== 'd8ac01df-6646-81d2-8008-a3696fea940e') throw new Error('Unexpected target file');
storage.fa = storage.fa || {};
const F = storage.fa;
F.C={ink:'#183D35',green:'#27634D',lime:'#B8DE78',sky:'#91D5EF',paper:'#F4F9EE',muted:'#55766A',gold:'#EBC978',danger:'#CB6E61'};
F.font=penpot.fonts.findByName('Noto Sans KR');
F.put=(p,s,x,y)=>{p.appendChild(s);penpotUtils.setParentXY(s,x,y);return s;};
F.rect=(p,n,x,y,w,h,c=F.C.paper,r=24,opacity=1)=>{const s=penpot.createRectangle();s.name=n;s.resize(w,h);s.fills=[{fillColor:c,fillOpacity:opacity}];s.borderRadius=r;return F.put(p,s,x,y);};
F.text=(p,n,v,x,y,size=24,w=600,color=F.C.ink,weight='500',align='left')=>{const s=penpot.createText(v);s.name=n;F.font.applyToText(s,F.font.variants.find(a=>a.fontWeight===weight));s.fontSize=String(size);s.lineHeight='1.35';s.fills=[{fillColor:color,fillOpacity:1}];s.resize(w,size*1.5);s.growType='auto-height';s.align=align;return F.put(p,s,x,y);};
F.board=(p,n,x,y,w=1920,h=1080)=>{const s=penpot.createBoard();s.name=n;s.resize(w,h);s.clipContent=true;s.fills=[{fillColor:F.C.paper,fillOpacity:1}];return F.put(p,s,x,y);};
F.asset=(p,key,x,y,w,h)=>{const c=penpot.library.local.components.find(c=>c.id===F.componentIds[key]);if(!c)throw new Error('Missing component '+key);const s=c.instance();s.name='UI / '+key;const a=F.assets.find(a=>a.name===key);F.put(p,s,x,y);if(w&&h){s.resize(w,h);}return s;};
F.icon=(p,key,x,y,size=40)=>F.asset(p,'icon-'+key,x,y,size,size);
F.links=F.links||[];F.boards=F.boards||{};F.layout=F.layout||[];
F.button=(p,label,x,y,target,kind='primary',w=320,state='default',icon)=>{
 const hit=F.board(p,'BUTTON / '+label,x,y,w,88);hit.fills=[];hit.clipContent=false;
 F.asset(hit,kind+'-'+state,0,0,w,88);F.text(hit,'Label',label,icon?66:20,25,26,w-(icon?90:40),F.C.ink,'700','center');if(icon)F.icon(hit,icon,24,25,34);
 if(target&&state!=='disabled')F.links.push({id:hit.id,target});return hit;
};
F.panel=(p,n,x,y,w,h)=>{const r=F.rect(p,n,x,y,w,h,F.C.paper,30,.94);r.strokes=[{strokeColor:'#B6D4BD',strokeWidth:2,strokeAlignment:'inner',strokeStyle:'solid'}];F.icon(p,'leaf',x+w-60,y+14,34);return r;};
F.chip=(p,label,x,y,w=200,sky=false)=>{F.rect(p,'Badge / '+label,x,y,w,40,sky?F.C.sky:F.C.lime,20);F.text(p,'Badge label',label,x+12,y+7,18,w-24,F.C.ink,'700','center');};
F.image=(p,key,x,y,w,h)=>{const image=F.media?.[key];if(!image)throw new Error('Missing media '+key);const s=F.rect(p,'ART / '+key,x,y,w,h,F.C.paper,0);s.fills=[{fillImage:image,fillOpacity:1}];return s;};
F.header=(s,title,future=false,back='SCR_03_Lobby')=>{
 F.rect(s,'Header glass',0,0,1920,144,F.C.paper,0,.94);F.icon(s,'leaf',64,55,42);F.text(s,'Brand','FOREST ARENA',124,48,28,420,F.C.green,'800');
 F.text(s,'Screen title',title,620,49,32,670,F.C.ink,'700','center');
 if(future)F.chip(s,'미래 기능 · 설계안',1310,55,240,true);
 const b=F.button(s,'뒤로',1600,30,back,'secondary',240,'default','back');
};
F.background=(s,key='lobby',opacity=.88)=>{F.image(s,key,0,0,1920,1080);F.rect(s,'Forestlight veil',0,0,1920,1080,F.C.paper,0,opacity);};
F.newScreen=async(pageName,name,index,title,future=false)=>{
 const p=penpotUtils.getPageByName(pageName);await penpot.openPage(p);
 let s=p.root.children.find(s=>s.name===name);
 if(s&&!s.getPluginData('forestlight-v01')){const old=s.clone();old.name='ARCHIVE v00 / '+name;F.put(p.root,old,12000+(index%2)*2050,Math.floor(index/2)*1220);for(const c of [...s.children])c.remove();}
 else if(s?.getPluginData('forestlight-v01'))return s;
 if(!s)s=F.board(p.root,name,40+(index%2)*2040,40+Math.floor(index/2)*1200);
 s.resize(1920,1080);s.clipContent=true;s.fills=[{fillColor:F.C.paper,fillOpacity:1}];s.setPluginData('forestlight-v01','building');F.boards[name]=s.id;
 F.background(s,'lobby',.9);F.header(s,title,future);return s;
};
F.finish=s=>{s.setPluginData('forestlight-v01','complete');return {name:s.name,id:s.id,children:s.children.length};};
return {helpers:true};
