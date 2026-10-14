const N=storage.v07;
N.syncScene=(spec)=>{
 const b=N.boards[spec.name],previous=N.previousSpec.scenes.find(s=>s.name===spec.name),a=b.children.filter(c=>c.getPluginData('premium-menu-v07')==='true'),offset=b.children.length-a.length;
 if(a.length!==previous.elements.length)throw Error('Cannot sync element order '+spec.name);
 let changed=0;for(let i=0;i<Math.max(a.length,spec.elements.length);i++){
  if(i<a.length&&i<spec.elements.length&&JSON.stringify(previous.elements[i])===JSON.stringify(spec.elements[i]))continue;
  if(i<a.length&&i<spec.elements.length){
   const old=previous.elements[i],e=spec.elements[i],ignore=['x','y','dest','legacy'];if(e.kind==='text')ignore.push('text');
   const core=o=>Object.fromEntries(Object.entries(o).filter(([k])=>!ignore.includes(k)));
   if(JSON.stringify(core(old))===JSON.stringify(core(e))){
    const s=a[i];if(old.x!==e.x||old.y!==e.y)penpotUtils.setParentXY(s,e.x,e.y);
    if(e.kind==='text'&&old.text!==e.text)s.characters=e.text;
    if((e.kind==='button'||e.kind==='hotspot')&&(old.dest!==e.dest||old.legacy!==e.legacy))s.setPluginData('v07-control',JSON.stringify({dest:e.dest||null,state:e.state||'default',legacy:e.legacy||e.name}));
    changed++;continue;
   }
  }
  if(a[i])a[i].remove();if(spec.elements[i]){N.draw(b,{name:spec.name,elements:[spec.elements[i]]});b.children[b.children.length-1].setParentIndex(offset+i);}changed++;
 }
 b.setPluginData('v07-spec-name',spec.name);N.synced=N.synced||{};N.synced[spec.name]=true;return {name:spec.name,changed};
};
return {syncHelper:true};
