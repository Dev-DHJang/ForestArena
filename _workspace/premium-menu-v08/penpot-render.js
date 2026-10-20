if(penpot.currentFile.id!=='d8ac01df-6646-81d2-8008-a3696fea940e')throw Error('Wrong file');
const N=storage.v08;
N.ensureFlags=()=>{penpot.flags.naturalChildOrdering=true;penpot.flags.throwValidationErrors=true;};
N.ensureFlags();
N.path='Premium Menu v08';N.C={bg:'#10181C',panel:'#1C282C',text:'#F2F3ED',muted:'#BBC6C6',gold:'#D9C58E',mint:'#8CBFB2',line:'#455455',danger:'#DD9B92'};
N.font=penpot.fonts.findByName('Noto Sans KR');if(!N.font)throw Error('Noto Sans KR missing');
N.put=(p,s,x,y)=>{p.appendChild(s);penpotUtils.setParentXY(s,x,y);return s;};
N.rect=(p,name,x,y,w,h,color=N.C.panel,opacity=1,r=8,stroke=null)=>{const s=penpot.createRectangle();s.name=name;s.resize(w,h);s.fills=color?[{fillColor:color,fillOpacity:opacity}]:[];s.borderRadius=r;if(stroke)s.strokes=[{strokeColor:stroke,strokeWidth:1,strokeAlignment:'inner',strokeStyle:'solid'}];return N.put(p,s,x,y);};
N.text=(p,name,txt,x,y,w,size=32,color=N.C.text,weight='500',align='left')=>{const s=penpot.createText(txt);s.name=name;s.fontId=N.font.fontId;s.fontFamily=N.font.fontFamily;s.fontWeight=weight;s.fontVariantId=N.font.variants.find(v=>v.fontWeight===weight)?.fontVariantId||'regular';s.fontSize=String(size);s.lineHeight='1.35';s.fills=[{fillColor:color,fillOpacity:1}];s.resize(w,size*1.45*(txt.split('\n').length));s.growType='auto-height';s.align=align;return N.put(p,s,x,y);};
N.board=(page,name,x,y,w=1920,h=1080)=>{const b=penpot.createBoard();b.name=name;b.resize(w,h);b.clipContent=true;b.fills=[{fillColor:N.C.bg,fillOpacity:1}];N.put(page.root,b,x,y);return b;};
N.componentIndex=()=>Object.fromEntries(penpot.library.local.components.filter(c=>c.path===N.path).map(c=>[c.name,c]));
N.surface=(p,name,x,y,w,h,state='default')=>{const c=N.components['surface-'+state]||N.components['surface-default'];const s=c.instance();s.name=name;N.put(p,s,x,y);s.resize(w,h);const bg=s.children.find(c=>c.name==='Surface');bg.resize(w,h);penpotUtils.setParentXY(bg,0,0);return s;};
N.icon=(p,key,x,y,w,h)=>{const c=N.components['icon-'+key];if(!c)throw Error('Missing icon '+key);const s=c.instance();s.name='ICON / '+key;N.put(p,s,x,y);s.resize(w,h);const g=s.children.find(c=>c.type==='group');if(g){g.resize(w,h);penpotUtils.setParentXY(g,0,0);}return s;};
N.button=(p,e)=>{const b=penpot.createBoard();b.name=e.name;b.resize(e.w,e.h);b.fills=[];b.clipContent=false;N.put(p,b,e.x,e.y);N.surface(b,'UI / '+e.state,0,0,e.w,e.h,e.state);const off=e.icon?(e.w<=160?56:76):24;if(e.icon){const z=e.w<=160?32:48;N.icon(b,e.icon,12,(e.h-z)/2,z,z);}const labelSize=e.w<=200?28:30;N.text(b,'Label',e.text,off,(e.h-labelSize*1.35)/2,e.w-off-16,labelSize,e.state==='primary'?N.C.bg:e.state==='disabled'?N.C.muted:N.C.text,'500',e.icon?'left':'center');if(e.state==='selected'){N.rect(b,'Selected marker',0,8,4,e.h-16,N.C.gold,1,0);N.text(b,'Selected check','✓',e.w-40,(e.h-34)/2,28,26,N.C.gold);}
 b.setPluginData('v08-control',JSON.stringify({dest:e.dest||null,legacy:e.legacy||e.name,state:e.state}));return b;};
N.draw=(b,spec)=>{
 N.ensureFlags();
 for(const e of spec.elements){let s;
 if(e.kind==='rect')s=N.rect(b,e.name,e.x,e.y,e.w,e.h,e.color,e.opacity,e.r,e.stroke);
 else if(e.kind==='text')s=N.text(b,e.name,e.text,e.x,e.y,e.w,e.size,e.color,e.weight,e.align);
 else if(e.kind==='surface')s=N.surface(b,e.name,e.x,e.y,e.w,e.h,e.state);
 else if(e.kind==='button')s=N.button(b,e);
 else if(e.kind==='svg')s=N.icon(b,e.key,e.x,e.y,e.w,e.h);
 else if(e.kind==='circle'){s=penpot.createEllipse();s.name=e.name;s.resize(e.w,e.h);s.fills=[{fillColor:e.color,fillOpacity:1}];N.put(b,s,e.x,e.y);}
 else if(e.kind==='image'){
  const m=N.media[e.key];if(!m)throw Error('Missing media '+e.key);
  let w=e.w,h=e.h,x=e.x,y=e.y;
  if(!['character-room','accessory-workshop','shop-market','archive','social-lodge','observatory'].includes(e.key)){const scale=Math.min(w/m.width,h/m.height);w=m.width*scale;h=m.height*scale;x+=.5*(e.w-w);y+=.5*(e.h-h);}
  s=N.rect(b,e.name,x,y,w,h,null,1,0);s.fills=[{fillImage:m,fillOpacity:1}];s.setPluginData('v08-image-slot',e.slot||'DESIGN/bg/'+e.key);
 }
 else if(e.kind==='hotspot'){s=N.rect(b,e.name,e.x,e.y,e.w,e.h,null,1,0);s.setPluginData('v08-control',JSON.stringify({dest:e.dest,state:'default',legacy:e.name}));}
 if(s)s.setPluginData('premium-menu-v08','true');
 }
 b.setPluginData('premium-menu-v08','2026-10-14');b.setPluginData('v08-spec-name',spec.name);b.exports=[{type:'png',scale:2/3,suffix:'-v08'}];
};
N.boards=N.boards||{};N.proto=penpotUtils.getPageByName('10_Prototype');N.states=penpotUtils.getPageByName('12_Menu_States_v08');if(!N.states){N.states=penpot.createPage();N.states.name='12_Menu_States_v08';}
N.make=async(spec)=>{
 N.ensureFlags();
 let original=N.base.boards.find(s=>s.name===spec.name&&s.target),b,page;
 if(original){page=penpotUtils.getPageByName(original.page);if(penpot.currentPage.id!==page.id)await penpot.openPage(page);N.ensureFlags();b=page.root.children.find(s=>s.id===original.id);}
 else{page=N.states;if(penpot.currentPage.id!==page.id)await penpot.openPage(page);N.ensureFlags();b=page.root.children.find(s=>s.name===spec.name);if(!b){const i=page.root.children.length;b=N.board(page,spec.name,(i%5)*2120,Math.floor(i/5)*1280);}}
 if(b.getPluginData('v08-ready')&&!N.force){N.boards[spec.name]=b;return {name:spec.name,existing:true};}
 for(const c of b.children){if(c.getPluginData('premium-menu-v08')==='true')c.remove();else{if(!c.getPluginData('v08-before-hidden'))c.setPluginData('v08-before-hidden',String(c.hidden));c.hidden=true;}}
 N.draw(b,spec);b.setPluginData('v08-ready','true');N.boards[spec.name]=b;return {name:spec.name,id:b.id,elements:spec.elements.length};
};
N.components=N.componentIndex();
return {helpers:true,media:Object.keys(N.media),states:N.states.id};
