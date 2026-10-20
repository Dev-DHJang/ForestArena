const N=storage.v08;
N.cropEligible=(spec,e)=>/(SCR_04_CharacterCollection|SCR_05_CharacterDetail|SCR_19_Shop|SCR_20_Collection)/.test(spec.name)&&e.kind==='image'&&['ja-hyun','myo-ryung','nabi','yu-ran'].includes(e.key)&&e.w<=300&&e.h<=300;
N.portrait=(b,e)=>{
 N.ensureFlags();
 const m=N.media[e.key],frame=penpot.createBoard();frame.name=e.name;frame.resize(e.w,e.h);frame.fills=[];frame.clipContent=true;N.put(b,frame,e.x,e.y);
 const h=e.h*2,w=m.width/m.height*h;
 const art=N.rect(frame,'Approved original / '+e.key,(e.w-w)/2,-h*.05,w,h,null,1,0);art.fills=[{fillImage:m,fillOpacity:1}];
 frame.setPluginData('premium-menu-v08','true');frame.setPluginData('v08-portrait-crop','upper-body,2x-height,5-percent-top');frame.setPluginData('v08-image-slot',e.slot||'IMG/character/'+e.key+'/concept');
 return frame;
};
if(!N.originalDraw)N.originalDraw=N.draw;
N.draw=(b,spec)=>{N.ensureFlags();for(const e of spec.elements){if(N.cropEligible(spec,e))N.portrait(b,e);else N.originalDraw(b,{name:spec.name,elements:[e]});}b.setPluginData('v08-spec-name',spec.name);b.exports=[{type:'png',scale:2/3,suffix:'-v08'}];};
N.fixPortraits=(spec)=>{
 N.ensureFlags();
 const b=N.boards[spec.name],a=b.children.filter(c=>c.getPluginData('premium-menu-v08')==='true');let n=0;
 for(let i=0;i<spec.elements.length;i++){const e=spec.elements[i],s=a[i];if(!N.cropEligible(spec,e)||s.getPluginData('v08-portrait-crop'))continue;const index=b.children.findIndex(c=>c.id===s.id);s.remove();const frame=N.portrait(b,e);frame.setParentIndex(index);n++;}
 return {name:spec.name,crops:n};
};
return {portraitHelper:true};
