const F=storage.fa;
F.assets=[];
F.walk=s=>[s,...(s.children||[]).flatMap(F.walk)];
F.fixPage=async name=>{
 const p=penpotUtils.getPageByName(name);if(penpot.currentPage.id!==p.id)await penpot.openPage(p);
 const boards=p.root.children.filter(s=>/^(SCR_|CBT_|EXT_|STATE_)/.test(s.name)).sort((a,b)=>a.name.localeCompare(b.name));
 for(let i=0;i<boards.length;i++){
  const b=boards[i];penpotUtils.setParentXY(b,40+(i%3)*2040,40+Math.floor(i/3)*1200);
  const rename=(old,label,target)=>{const s=b.children.find(s=>s.name==='BUTTON / '+old);if(!s)return;s.name='BUTTON / '+label;const t=s.children.find(s=>s.name==='Label');if(t)t.characters=label;F.links=F.links.filter(l=>l.id!==s.id);F.links.push({id:s.id,screen:b.name,target,x:s.parentX,y:s.parentY,w:s.width,h:s.height});};
  if(b.name==='CBT_05_Pause')rename('다시 시작','계속하기','CBT_01_Match_1v1');
  if(b.name==='CBT_06_Resume')rename('전투 재개','전투 재개','STATE_Countdown');
  if(b.name==='STATE_SettingsReset')rename('로비로','취소','CBT_08_Settings');
  if(b.name==='STATE_CancelMatch')rename('로비로','계속 찾기','SCR_11_Matchmaking');
  if(b.name==='STATE_OnlineMenu')rename('로비로','나가기 확인','CBT_07_LeaveConfirm');
  for(const s of b.children.filter(s=>s.name==='BUTTON / 로비로'||s.name==='BUTTON / 메뉴'))if(!F.links.some(l=>l.id===s.id))F.links.push({id:s.id,screen:b.name,target:s.name.includes('메뉴')?'CBT_05_Pause':'SCR_03_Lobby',x:s.parentX,y:s.parentY,w:s.width,h:s.height});
  if(b.name==='SCR_22_Social'){const s=b.children.find(s=>s.name==='BUTTON / 최근 플레이어');s.resize(264,88);s.children.find(s=>s.name==='Label').resize(224,40);s.children.find(s=>s.name.startsWith('UI /')).resize(264,88);}
  for(const s of F.walk(b))for(const interaction of [...s.interactions])s.removeInteraction(interaction);
  for(const l of F.links.filter(l=>l.screen===b.name)){const s=p.getShapeById(l.id);if(s)s.setPluginData('forestlight-target',l.target);}
 }
 return {page:name,boards:boards.length};
};
F.exportOne=async name=>{
 const p=penpotUtils.getPageById(F.pageFor[name]);if(penpot.currentPage.id!==p.id)await penpot.openPage(p);
 const b=p.getShapeById(F.boards[name]);const bytes=await b.export({type:'png',scale:.5});
 F.snapshots=F.snapshots||{};const media=await penpot.uploadMediaData('Prototype / '+name,bytes,'image/png');
 F.snapshots[name]={media,w:b.width,h:b.height,links:F.links.filter(l=>l.screen===name)};
 let raw='';for(let i=0;i<bytes.length;i+=16384)raw+=String.fromCharCode(...bytes.slice(i,i+16384));
 return {name,base64:btoa(raw)};
};
return {ready:true};
