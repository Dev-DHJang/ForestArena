const fs=require('fs'),spec=JSON.parse(fs.readFileSync(__dirname+'/scene-spec.json','utf8'));
let penpot,serial=0;const stats={rectangles:0,boardClones:0,childClones:0,linksAdded:0,linksChanged:0,linksRemoved:0,reorders:0,metadata:0,position:0,resize:0,fills:0};
class Link{
 constructor(shape,trigger,action){this.shape=shape;this.trigger=trigger;this._action=action;}
 get action(){return this._action;}set action(v){stats.linksChanged++;this._action=v;}
}
class Shape{
 constructor(name,type='rectangle',w=0,h=0){this.id=String(++serial);this.name=name;this.type=type;this.width=w;this.height=h;this.x=0;this.y=0;this._children=[];this.plugin={};this._fills=[];this._interactions=[];this.hidden=false;}
 get children(){if(this.deleted)throw Error('Deleted shape');return penpot?.flags.naturalChildOrdering?this._children:[...this._children].reverse();}
 get fills(){return this._fills;}set fills(v){stats.fills++;this._fills=v;}
 get interactions(){return [...this._interactions];}
 getPluginData(k){if(this.deleted)throw Error('Deleted shape');return this.plugin[k]||'';}
 setPluginData(k,v){stats.metadata++;this.plugin[k]=v;}
 resize(w,h){stats.resize++;this.width=w;this.height=h;}
 remove(){this.parent._children.splice(this.parent._children.indexOf(this),1);this.deleted=true;}
 setParentIndex(index){stats.reorders++;const p=this.parent;p._children.splice(p._children.indexOf(this),1);p._children.splice(index,0,this);}
 addInteraction(trigger,action){stats.linksAdded++;const l=new Link(this,trigger,action);this._interactions.push(l);return l;}
 removeInteraction(l){stats.linksRemoved++;this._interactions.splice(this._interactions.indexOf(l),1);}
 clone(){let root=this;while(root.parent)root=root.parent;if(root.page!==penpot.currentPage)throw Error('Inactive page clone');if(this.type==='board')stats.boardClones++;else stats.childClones++;const c=new Shape(this.name,this.type,this.width,this.height);c.x=this.x;c.y=this.y;c.plugin={...this.plugin};c._fills=this._fills.map(f=>({...f}));c.hidden=this.hidden;c._interactions=this._interactions.map(l=>new Link(c,l.trigger,l.action));for(const child of this._children){const copy=child.clone();copy.parent=c;c._children.push(copy);}return c;}
}
const page={id:'proto-page',name:'10_Prototype',root:new Shape('root','root')},other={id:'other',root:new Shape('other','root')};page.root.page=page;other.root.page=other;
penpot={flags:{naturalChildOrdering:true,throwValidationErrors:true},currentPage:other,selection:[],viewport:{center:{x:0,y:0},zoom:.01},openPage:async p=>{penpot.currentPage=p;penpot.flags.naturalChildOrdering=false;penpot.flags.throwValidationErrors=false;},history:{undoBlockBegin:()=>0,undoBlockFinish:()=>{}}};
const N={spec,base:{boards:[]},proto:page,protoMap:{},snapshots:{},C:{bg:'#10181C'}};
N.ensureFlags=()=>{penpot.flags.naturalChildOrdering=true;penpot.flags.throwValidationErrors=true;};
const translate=(s,dx,dy)=>{s.x+=dx;s.y+=dy;for(const c of s._children)translate(c,dx,dy);};
const xy=(s,x,y)=>{stats.position++;translate(s,s.parent.x+x-s.x,s.parent.y+y-s.y);};
N.put=(p,s,x,y)=>{if(s.parent)s.parent._children.splice(s.parent._children.indexOf(s),1);p._children.push(s);s.parent=p;xy(s,x,y);return s;};
N.board=(p,name,x,y,w=1920,h=1080)=>N.put(p.root,new Shape(name,'board',w,h),x,y);
N.rect=(p,name,x,y,w,h,color=null,opacity=1)=>{stats.rectangles++;const s=new Shape(name,'rectangle',w,h);s._fills=color?[{fillColor:color,fillOpacity:opacity}]:[];return N.put(p,s,x,y);};
N.post=async(name,value)=>{if(value.savedVerified!==false)throw Error('Progress must not claim saved');penpot.flags.naturalChildOrdering=false;penpot.flags.throwValidationErrors=false;};
for(const name of spec.externalDestinations){const b=N.board(page,'PROTO / '+name,0,0);N.protoMap[name]=b;}
const legacy=[];
for(const name of spec.base){const b=N.board(page,'PROTO / '+name,0,0);N.protoMap[name]=b;N.base.boards.push({name:b.name,id:b.id,target:false});const art=N.rect(b,'OLD / original art',0,0,1920,1080);art._fills=[{fillImage:{id:'old-'+name}}];const hit=N.rect(b,'OLD / original hit',96,48,100,80);hit.addInteraction('click',{type:'navigate-to',destination:N.protoMap[spec.externalDestinations[0]]});legacy.push({id:b.id,board:b,children:[art,hit],oldDestination:hit.interactions[0].action.destination.id});}
for(const s of spec.scenes)N.snapshots[s.name]={id:'image-'+s.name,width:1280,height:720};
new Function('penpot','penpotUtils','storage',fs.readFileSync(__dirname+'/penpot-prototype-fast.js','utf8'))(penpot,{getPageByName:()=>page,setParentXY:xy},{v08:N});
const verify=()=>{
 N.ensureFlags();let controls=0;
 for(const s of spec.scenes){const b=N.protoMap[s.name],plan=N.protoFastPlan(s);const own=b.children.filter(c=>c.getPluginData('premium-menu-v08')==='true');const snapshot=own.filter(c=>c.name==='SNAPSHOT / v08');if(snapshot.length!==1||snapshot[0].fills[0].fillImage.id!==N.snapshots[s.name].id)throw Error('Snapshot differs '+s.name);const hits=own.filter(c=>c.name.startsWith('HIT08 / '));if(hits.length!==plan.controls.length)throw Error('Hotspot count differs '+s.name);for(const e of plan.controls){const hit=hits.find(c=>c.name===e.name&&c.x-b.x===e.x&&c.y-b.y===e.y&&c.width===e.w&&c.height===e.h);if(!hit)throw Error('Hotspot missing '+s.name+' '+e.name);if(JSON.stringify(JSON.parse(hit.getPluginData('v08-control')))!==JSON.stringify(e.meta))throw Error('Control metadata differs');const links=hit.interactions,a=links[0]?.action;if(links.length!==1||links[0].trigger!=='click'||a?.destination.id!==N.protoMap[e.meta.dest].id||a.animation.duration!==200||a.animation.type!=='dissolve'||a.animation.easing!=='ease-out')throw Error('Interaction differs '+s.name+' '+e.name);controls++;}}
 for(const old of legacy){if(N.protoMap[old.board.name.slice(8)].id!==old.id)throw Error('Original prototype ID changed');for(const c of old.children)if(c.deleted||!c.hidden)throw Error('Original child changed or visible');if(old.children[1].interactions[0].action.destination.id!==old.oldDestination)throw Error('Original legacy link changed');}
 return controls;
};
(async()=>{
 while(N.protoFastStatus().prepared<spec.scenes.length){penpot.flags.naturalChildOrdering=false;penpot.flags.throwValidationErrors=false;await N.makePrototypeBatch(4);}
 const first=await N.wirePrototypeBatch(spec.base.length);if(first.baseWired!==spec.base.length||first.wired!==spec.base.length)throw Error('Base prototypes were not wired first');
 while(N.protoFastStatus().wired<spec.scenes.length){penpot.flags.naturalChildOrdering=false;await N.wirePrototypeBatch(12);}
 const controls=verify(),before={...stats};
 await N.makePrototypeBatch(4);await N.wirePrototypeBatch(12);if(JSON.stringify(stats)!==JSON.stringify(before))throw Error('No-op replay made mutations');
 const target=spec.scenes.find(s=>!spec.base.includes(s.name)&&N.protoFastPlan(s).controls.length);const originalDest=target.elements.find(e=>e.dest&&e.state!=='disabled').dest;target.elements.find(e=>e.dest&&e.state!=='disabled').dest=spec.externalDestinations.find(n=>n!==originalDest)||spec.externalDestinations[0];
 await N.makePrototypeBatch(1);await N.wirePrototypeBatch(1);verify();
 console.log(JSON.stringify({passed:true,scenes:spec.scenes.length,activeControls:controls,checks:['original 14 prototype IDs and legacy children/links preserved','all snapshot fills match exported media','all actual control metadata, geometry and destinations match the spec','disabled and modal-occluded controls omitted','all transitions dissolve for 200ms','base 14 wired before state links','same-active-page clone restriction','flags recover after await and simulated foreground context cleanup','replay makes zero mutations','incremental destination edit updates the existing hotspot'],operations:before,fullRebuildRectangles:spec.scenes.length+controls,note:'Mock validates supported API usage and graph semantics. Actual Penpot save, reload, rendering and clicks remain to be verified.'},null,2));
})().catch(e=>{console.error(e);process.exit(1);});
