const fs=require('fs'),crypto=require('crypto');let nextId=0,penpot;
const checks=[];
const assert=(ok,message)=>{if(!ok)throw Error(message);};
class Shape{
 constructor(name,type='board'){this.id='shape-'+(++nextId);this.name=name;this.type=type;this.x=400;this.y=120;this.width=1920;this.height=1080;this._children=[];this.data={};this.hidden=false;}
 get children(){return penpot.flags.naturalChildOrdering?this._children:[...this._children].reverse();}
 getPluginData(k){return this.data[k]||'';}
 setPluginData(k,v){assert(this.page===penpot.currentPage,'Metadata changed on inactive page');this.data[k]=v;}
 remove(){assert(this.page===penpot.currentPage,'Shape removed from inactive page');this.parent._children.splice(this.parent._children.indexOf(this),1);this.deleted=true;}
}
const page=name=>({id:name,name,root:new Shape(name,'root')});
const pages=[page('base'),page('state-1'),page('state-2'),page('prototype'),page('other')];for(const p of pages)p.root.page=p;
penpot={flags:{naturalChildOrdering:true,throwValidationErrors:true},currentPage:pages[4],selection:[],viewport:{center:{x:0,y:0},zoom:.5},history:{undoBlockBegin:()=>0,undoBlockFinish:()=>{}},openPage:async p=>{penpot.currentPage=p;penpot.flags.naturalChildOrdering=false;penpot.flags.throwValidationErrors=false;}};
const add=(parent,child)=>{child.parent=parent;child.page=parent.page;parent._children.push(child);return child;};
const scenes=Array.from({length:5},(_,i)=>({name:'scene-'+i,date:'2026-10-20',elements:[{kind:'text',name:'TITLE',text:'이름 '+i,font:'Noto Sans KR'},{kind:'button',name:'BUTTON',text:'적용',state:'primary',font:'Noto Sans KR'}]}));
const N={spec:{scenes},boards:{},protoMap:{},protoFastInfo:{},snapshots:{unchanged:{id:'media'}},exportRecords:{unchanged:{sha256:'keep'}},designExportRecords:{unchanged:{sha256:'keep'}},drawCalls:[],postCalls:[]};
N.ensureFlags=()=>{penpot.flags.naturalChildOrdering=true;penpot.flags.throwValidationErrors=true;};
N.pageForExport=board=>pages.find(p=>p.root._children.includes(board));
N.sha256=()=>{throw Error('PNG-only digest must not be used for text specs');};
N.nativeSpecHash=name=>{let h=2166136261;for(const c of JSON.stringify(N.spec.scenes.find(s=>s.name===name))){h^=c.charCodeAt(0);h=Math.imul(h,16777619);}return (h>>>0).toString(16);};
N.draw=(board,spec)=>{assert(board.page===penpot.currentPage,'Drawing on inactive page');assert(penpot.flags.naturalChildOrdering&&penpot.flags.throwValidationErrors,'Flags lost');N.drawCalls.push(spec.name);for(const e of spec.elements){const s=add(board,new Shape(e.name,e.kind==='text'?'text':'board'));s.data['premium-menu-v08']='true';if(e.kind==='text'){s.characters=e.text;s.fontFamily=e.font;}else{const label=add(s,new Shape('Label','text'));label.characters=e.text;label.fontFamily=e.font;}}};
N.post=async(name,row)=>{assert(row.savedVerified===false,'Progress claimed save');N.postCalls.push({name,row});penpot.flags.naturalChildOrdering=false;};
const originals=[];
scenes.forEach((spec,i)=>{const board=add(pages[i<1?0:i<3?1:2].root,new Shape(spec.name));board.data['v08-ready']='true';const legacy=add(board,new Shape('legacy'));legacy.hidden=true;legacy.characters='preserve';const old=add(board,new Shape('old-v08'));old.data['premium-menu-v08']='true';N.boards[spec.name]=board;const proto=add(pages[3].root,new Shape('PROTO / '+spec.name));proto.data['v08-fast-prepared']='old';proto.data['v08-wired']='true';N.protoMap[spec.name]=proto;N.protoFastInfo[spec.name]={old:true};originals.push({board,id:board.id,page:board.page,x:board.x,y:board.y,w:board.width,h:board.height,legacy,old});});
const exported=JSON.stringify([N.snapshots,N.exportRecords,N.designExportRecords]);
new Function('storage','penpot',fs.readFileSync(__dirname+'/penpot-semantic-redraw.js','utf8'))({v08:N},penpot);
const changes={changedExisting:scenes.map(s=>({name:s.name,afterSha256:'f'.repeat(64)}))};
(async()=>{
 const fullSpec=JSON.parse(fs.readFileSync(__dirname+'/scene-spec.json','utf8'));
 const hashVectors=['','abc','한글 숲 메뉴 🌲',...Array.from({length:75},(_,n)=>'x'.repeat(n)), 'a'.repeat(1000000),JSON.stringify(fullSpec),...fullSpec.scenes.map(spec=>JSON.stringify(spec))];
 for(const text of hashVectors){const actual=N.semanticSha256UTF8(text),expected=crypto.createHash('sha256').update(text,'utf8').digest('hex');assert(actual===expected,'Local SHA256 differs from Node for text length '+text.length);}
 assert(N.semanticSha256UTF8('')==='e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855','Empty known vector differs');
 assert(N.semanticSha256UTF8('abc')==='ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad','abc known vector differs');
 checks.push('pure JavaScript SHA256 matches empty and abc published vectors','SHA256 padding lengths 0–74 and million-a match Node crypto','SHA256 Korean and supplementary Unicode match Node crypto','whole spec and all '+fullSpec.scenes.length+' serialized scenes match Node crypto','PNG-only digest endpoint is never called for text specs');
 let r;do{r=await N.redrawSemanticBatch(changes,2);assert(r.out.length<=2,'Batch cap failed');assert(new Set(r.out.map(x=>x.page)).size<=1,'Batch crossed native pages');}while(r.completed<changes.changedExisting.length);
 for(const old of originals){const b=old.board;assert(b.id===old.id&&b.page===old.page&&b.x===old.x&&b.y===old.y&&b.width===old.w&&b.height===old.h,'Identity/page/geometry changed');assert(b.getPluginData('v08-ready')==='true','Ready marker changed');assert(!old.legacy.deleted&&old.legacy.hidden&&old.legacy.characters==='preserve','Legacy child changed');assert(old.old.deleted,'Old owned child not removed');const own=b.children.filter(s=>s.getPluginData('premium-menu-v08')==='true');assert(own.map(s=>s.name).join('|')==='TITLE|BUTTON','Draw order differs');assert(own[0].type==='text'&&own[0].fontFamily==='Noto Sans KR','Text not editable/font differs');assert(own[1].children[0].type==='text'&&own[1].children[0].fontFamily==='Noto Sans KR','Button text not editable/font differs');const proto=N.protoMap[b.name];assert(!proto.getPluginData('v08-fast-prepared')&&!proto.getPluginData('v08-wired')&&!N.protoFastInfo[b.name],'Prototype not invalidated');}
 checks.push('existing source IDs, original pages, geometry and ready markers preserved','only owned children removed; legacy child IDs, hidden states and content preserved','native element order/count and editable Noto Sans KR labels preserved','prototype metadata invalidated only on active prototype page','one native page per batch, maximum two scenes, flags restored after awaits');
 assert(JSON.stringify([N.snapshots,N.exportRecords,N.designExportRecords])===exported,'Exports/snapshots changed');checks.push('existing export records and snapshot media unchanged');
 const before=N.drawCalls.length;const replay=await N.redrawSemanticBatch(changes,2);assert(replay.completed===5&&!replay.out.length&&N.drawCalls.length===before,'Resume redrew complete scene');checks.push('exact saved spec signature skips completed redraws');
 scenes[0].date='2026-10-21';await N.redrawSemanticBatch(changes,2);assert(N.drawCalls.length===before+1&&N.drawCalls.at(-1)==='scene-0','Date-only spec change not detected');checks.push('date-only current-spec change invalidates old marker');
 changes.changedExisting[1].afterSha256='a'.repeat(64);await N.redrawSemanticBatch(changes,2);assert(N.drawCalls.length===before+2&&N.drawCalls.at(-1)==='scene-1','Updated manifest not detected');checks.push('updated manifest digest invalidates old marker');
 for(const bad of [0,3,1.5]){let threw=false;try{await N.redrawSemanticBatch(changes,bad);}catch(e){threw=true;}assert(threw,'Invalid batch accepted');}checks.push('invalid batch sizes rejected');
 let threw=false;try{await N.redrawSemanticBatch({changedExisting:[{name:'unknown'}]},1);}catch(e){threw=true;}assert(threw,'Missing scene accepted');checks.push('missing source rejected before drawing');
 const bytes=N.semanticUtf8('한글🌲');assert(Buffer.from(bytes).equals(Buffer.from('한글🌲','utf8')),'Unicode encoding differs');checks.push('UTF-8 Korean and supplementary Unicode digest input correct');
 const result={passed:true,tests:checks.length,checks,note:'Local mock only. No Penpot API, save, reload, rendering or clicks executed.'};fs.writeFileSync(__dirname+'/semantic-redraw-check.json',JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
})().catch(e=>{console.error(e);process.exit(1);});
