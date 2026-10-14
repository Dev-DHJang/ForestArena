const N=storage.v07;
N.makeVariant=async(spec)=>{
 let b=N.boards[spec.name];if(b)return {name:spec.name,existing:true};
 let best=null,score=-1;
 for(const name of N.spec.base){const a=N.spec.scenes.find(s=>s.name===name);let equal=0;for(let i=0;i<Math.min(a.elements.length,spec.elements.length);i++)if(JSON.stringify(a.elements[i])===JSON.stringify(spec.elements[i]))equal++;if(equal>score){score=equal;best=a;}}
 if(score<10)return await N.make(spec);
 const source=N.boards[best.name];if(!source)throw Error('Missing base '+best.name);
 const page=penpotUtils.getPageByName(N.baseline.sources.find(s=>s.name===best.name).page);if(penpot.currentPage.id!==page.id)await penpot.openPage(page);
 const incomplete=page.root.children.find(b=>b.name===spec.name);if(incomplete)incomplete.remove();
 b=source.clone();b.name=spec.name;page.root.appendChild(b);const pos=page.root.children.filter(b=>b.name.startsWith('MENU07 /')).length-1;penpotUtils.setParentXY(b,90000+(pos%5)*2120,Math.floor(pos/5)*1280);
 const old=b.children.filter(c=>c.getPluginData('premium-menu-v07')==='true');const offset=b.children.length-old.length;let changed=0;
 for(let i=0;i<Math.max(old.length,spec.elements.length);i++){
  if(i<old.length&&i<spec.elements.length&&JSON.stringify(best.elements[i])===JSON.stringify(spec.elements[i]))continue;
  if(old[i])old[i].remove();
  if(spec.elements[i]){N.draw(b,{name:spec.name,elements:[spec.elements[i]]});const c=b.children[b.children.length-1];c.setParentIndex(offset+i);}
  changed++;
 }
 b.setPluginData('v07-spec-name',spec.name);N.boards[spec.name]=b;return {name:spec.name,id:b.id,changed,base:best.name};
};
return {variantHelper:true};
