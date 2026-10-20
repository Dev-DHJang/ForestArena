const N=storage.v08;await penpot.openPage(penpotUtils.getPageByName('02_Components'));
const page=penpot.currentPage;
for(const [i,state] of ['default','primary','ghost','selected','pressed','disabled','owned','equipped','danger'].entries()){
 if(N.components['surface-'+state])continue;
 const b=N.board(page,'V08 / surface-'+state,92000+(i%3)*720,Math.floor(i/3)*320,640,240);b.fills=[];
 const color=state==='primary'?N.C.gold:state==='pressed'?'#304143':N.C.panel;
 const edge=['selected','equipped'].includes(state)?N.C.gold:state==='danger'?N.C.danger:N.C.line;
 const s=N.rect(b,'Surface',0,0,640,240,color,state==='ghost'?.42:.94,6,edge);
 s.shadows=[{style:'drop-shadow',offsetX:0,offsetY:8,blur:24,spread:0,color:{color:N.C.bg,opacity:.28}}];
 const c=penpot.library.local.createComponent([b]);c.name='surface-'+state;c.path=N.path;N.components[c.name]=c;
}
for(const [i,entry] of Object.entries(storage.iconSource).entries()){
 const [key,svg]=entry;if(N.components['icon-'+key])continue;
 const b=N.board(page,'V08 / icon-'+key,92000+(i%8)*176,1200+Math.floor(i/8)*208,128,128);b.fills=[];
 const g=penpot.createShapeFromSvg(svg);g.name='Glyph';N.put(b,g,0,0);
 const c=penpot.library.local.createComponent([b]);c.name='icon-'+key;c.path=N.path;N.components[c.name]=c;
}
await penpot.openPage(penpotUtils.getPageByName('01_Foundations'));
let board=penpot.currentPage.root.children.find(s=>s.name==='Premium Menu v08 / Foundations');if(!board)board=N.board(penpot.currentPage,'Premium Menu v08 / Foundations',76000,0,1920,1080);if(!board.getPluginData('v08-foundation-ready')){
 N.text(board,'Title','어두운 숲 메뉴 / Premium Menu v08',96,72,1728,52,N.C.text,'700');
 for(const [i,[key,color]] of Object.entries(N.C).entries()){const x=96+i%4*432,y=220+Math.floor(i/4)*240;N.rect(board,'Color / '+key,x,y,392,112,color);N.text(board,'Color label',key+' / '+color,x,y+136,392,30);const c=penpot.library.local.createColor();c.name='Menu08 / '+key;c.color=color;}
 N.text(board,'Typography','Noto Sans KR · 제목 48–56 · 본문 30–34\n8px 간격 · 터치 최소 72×72 · 안전 여백 96/48\n180–240ms 전환 · 숲 공간과 큰 승인 원화',96,794,1728,34);
 const catalog=penpot.library.local.tokens;let set=catalog.sets.find(s=>s.name==='Menu08');if(!set)set=catalog.addSet({name:'Menu08'});
 for(const [key,value] of Object.entries(N.C)){if(!set.tokens.find(t=>t.name==='menu08.color.'+key))set.addToken({type:'color',name:'menu08.color.'+key,value});}
 for(const [key,value] of [['space','8'],['touch','72'],['radius','6']])if(!set.tokens.find(t=>t.name==='menu08.'+key))set.addToken({type:key==='radius'?'borderRadius':'dimension',name:'menu08.'+key,value});
 for(const [label,size,weight] of [['Title',52,'700'],['Body',32,'500'],['Caption',28,'500']]){const t=penpot.library.local.createTypography();t.name='Menu08 / '+label;t.fontId=N.font.fontId;t.fontFamily=N.font.name;t.fontSize=String(size);t.fontWeight=weight;}
}
board.setPluginData('v08-foundation-ready','true');
return {v08Components:Object.keys(N.components).length,totalComponents:penpot.library.local.components.length,foundation:board.id};
