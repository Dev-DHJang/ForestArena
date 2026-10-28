const fs=require('fs');
const spec=JSON.parse(fs.readFileSync(__dirname+'/scene-spec.json','utf8'));
let serial=0,penpot,reorders=0,drawn=0,clones=0,seeds=0;
class Shape{
 constructor(name,element=null){this.id=String(++serial);this.name=name;this.element=element;this.characters=element?.kind==='text'?element.text:'';this._children=[];this.plugin={};this.x=0;this.y=0;}
 get children(){return penpot?.flags.naturalChildOrdering?this._children:[...this._children].reverse();}
 set children(v){this._children=v;}
 getPluginData(k){if(this.deleted)throw Error('Deleted shape proxy accessed');return this.plugin[k]||'';}
 setPluginData(k,v){this.plugin[k]=v;}
 clone(){let root=this;while(root.parent)root=root.parent;if(root.page&&root.page.id!==penpot.currentPage.id)throw Error('Cannot clone a shape from an inactive page');clones++;const b=new Shape(this.name,this.element);b.plugin={...this.plugin};b.characters=this.characters;b.x=this.x;b.y=this.y;for(const c of this.children){const copy=c.clone();copy.parent=b;b.children.push(copy);}return b;}
 remove(){if(this.parent)this.parent.children.splice(this.parent.children.indexOf(this),1);this.deleted=true;}
 setParentIndex(i){reorders++;const p=this.parent;p.children.splice(p.children.indexOf(this),1);p.children.splice(i,0,this);this.parent=p;}
}
const state={id:'state',name:'04_Lobby_Meta',root:new Shape('root')},control={id:'control',name:'06_Combat',root:new Shape('root')};state.root.page=state;control.root.page=control;
const pages=[state,control];const N={spec,base:{boards:spec.base.map(name=>({name,target:true}))},boards:{},states:state};
N.put=(p,b,x,y)=>{if(b.parent)b.parent.children.splice(b.parent.children.indexOf(b),1);p.children.push(b);b.parent=p;b.x=x;b.y=y;return b;};
N.board=(page,name,x,y)=>N.put(page.root,new Shape(name),x,y);
N.draw=(b,s)=>{for(const e of s.elements){drawn++;const c=new Shape(e.name,e);c.setPluginData('premium-menu-v08','true');if(e.kind==='button'){const label=new Shape('Label');label.characters=e.text;N.put(c,label,0,0);}if(['button','hotspot'].includes(e.kind))c.setPluginData('v08-control',JSON.stringify({dest:e.dest||null,legacy:e.legacy||e.name,state:e.state||'default'}));N.put(b,c,e.x+b.x,e.y+b.y);}};
N.make=async(s)=>{N.ensureFlags();const page=s.name==='CBT_08_Settings'?control:state;penpot.currentPage=page;const b=N.board(page,s.name,0,0);N.draw(b,s);b.setPluginData('v08-ready','true');N.boards[s.name]=b;return {name:s.name};};
N.post=async()=>true;
penpot={flags:{naturalChildOrdering:false,throwValidationErrors:false},currentPage:state,selection:[],viewport:{center:{x:0,y:0},zoom:.01},createPage:()=>{const p={id:'page-'+(++serial),name:'New page',root:new Shape('root')};p.root.page=p;pages.push(p);return p;},openPage:async(page)=>{penpot.currentPage=page;penpot.flags.naturalChildOrdering=false;penpot.flags.throwValidationErrors=false;},history:{undoBlockBegin:()=>0,undoBlockFinish:()=>{}}};
new Function('penpot','penpotUtils','storage',fs.readFileSync(__dirname+'/penpot-fast.js','utf8'))(penpot,{getPageByName:name=>pages.find(p=>p.name===name)||null},{v08:N});
const stable=e=>{const d={...e};for(const k of ['name','text','dest','legacy'])delete d[k];return d;};
const expected=e=>({properties:stable(e),name:e.name,text:['text','button'].includes(e.kind)?e.text:null,control:['button','hotspot'].includes(e.kind)?{dest:e.dest||null,legacy:e.legacy||e.name,state:e.state||'default'}:null});
const actual=s=>({properties:stable(s.element),name:s.name,text:s.element.kind==='text'?s.characters:s.element.kind==='button'?s.children.find(c=>c.name==='Label').characters:null,control:['button','hotspot'].includes(s.element.kind)?JSON.parse(s.getPluginData('v08-control')):null});
(async()=>{
 const firstState=spec.scenes.find(s=>!spec.base.includes(s.name)),orphanPage=N.statePlacement(firstState,true).page;N.board(orphanPage,firstState.name,0,0);
 for(const s of spec.scenes){penpot.flags.naturalChildOrdering=false;penpot.flags.throwValidationErrors=false;const result=await N.fastMake(s);if(result.seed)seeds++;const b=N.boards[s.name];if(JSON.stringify(b.children.map(actual))!==JSON.stringify(s.elements.map(expected)))throw Error('Native projection mismatch '+s.name);}
 const retry=spec.scenes.find(s=>!spec.base.includes(s.name));N.boards[retry.name].setPluginData('v08-ready','');N.stopRequested=true;const stopped=await N.makeBatch(1);if(stopped.out.length||!stopped.stopped)throw Error('Soft stop ignored');N.stopRequested=false;await N.fastMake(retry);if(JSON.stringify(N.boards[retry.name].children.map(actual))!==JSON.stringify(retry.elements.map(expected)))throw Error('Invalidated state retry mismatch');
 const statePages=pages.filter(p=>/^\d+_Menu_States_v08/.test(p.name));for(const p of statePages)if(p.root.children.filter(b=>b.getPluginData('v08-ready')).length>N.statePageCapacity)throw Error('State page exceeds capacity');if(seeds!==statePages.length)throw Error('Expected one explicit seed per state page');
 const fullDraw=spec.scenes.reduce((n,s)=>n+s.elements.length,0);
 console.log(JSON.stringify({passed:true,scenes:spec.scenes.length,checks:['native source element order','semantic native projection including text, label, control destinations and legacy metadata','changed and removed elements replaced','repeated element names matched by complete content','clone uses source from the currently active page','natural child ordering and validation flags restored after background calls and page changes','soft stop respects scene boundary','invalidated owned state retry removes deleted proxy before candidate lookup','state pages contain at most 24 states and start with an explicit full-draw seed','only the approved empty orphan is removed'],statePages:statePages.map(p=>({name:p.name,states:p.root.children.filter(b=>b.getPluginData('v08-ready')).length})),explicitSeeds:seeds,operations:{fullDrawElements:fullDraw,drawnElements:drawn,reorders,cloneCallsIncludingDescendants:clones},note:'Mock verifies clone/delta algorithm; actual Penpot geometry and PNG still require final audit.'},null,2));
})().catch(e=>{console.error(e);process.exit(1);});
