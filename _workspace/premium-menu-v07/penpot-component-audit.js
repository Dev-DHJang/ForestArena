const N=storage.v07;
N.auditComponents=async()=>{
 const issues=[],byScene=[];let primary=0,additional=0,total=0;
 for(const spec of N.spec.scenes){
  const b=N.boards[spec.name],a=b.children.filter(s=>s.getPluginData('premium-menu-v07')==='true');let bindings=0,icons=0;
  for(let i=0;i<spec.elements.length;i++){
   const e=spec.elements[i],s=a[i];if(!['surface','svg','button'].includes(e.kind))continue;
   const key=e.kind==='svg'?'icon-'+e.key:'surface-'+(e.state||'default'),instance=e.kind==='button'?s.children.find(c=>c.name==='UI / '+(e.state||'default')):s;
   if(instance?.component()?.id!==N.components[key]?.id)issues.push({scene:spec.name,name:e.name,expected:key,reason:'primary component reference differs'});else{bindings++;primary++;}
   if(e.kind==='button'&&e.icon){const icon=s.children.find(c=>c.name==='ICON / '+e.icon);if(icon?.component()?.id!==N.components['icon-'+e.icon]?.id)issues.push({scene:spec.name,name:e.name,expected:'icon-'+e.icon,reason:'button icon reference differs'});else{icons++;additional++;}}
  }
  const heads=N.all(b).filter(s=>s.isComponentHead()&&s.component()?.path===N.path).length;total+=heads;
  if(heads!==bindings+icons)issues.push({scene:spec.name,reason:'component instance count differs',actual:heads,expected:bindings+icons});
  byScene.push({name:spec.name,primaryBindings:bindings,additionalButtonIcons:icons,totalInstances:heads});
 }
 N.componentUsage=primary;N.componentIssues=issues;N.actualComponentInstanceUsage=total;N.additionalButtonIconInstances=additional;
 await N.post('component-usage.json',{usage:primary,primaryBindings:primary,additionalButtonIconInstances:additional,totalInstances:total,issues,byScene});return {primary,additional,total,issues:issues.length};
};
return {componentAuditHelper:true};
