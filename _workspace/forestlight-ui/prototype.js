const F=storage.fa;
F.preparePrototype=async()=>{
 const p=penpotUtils.getPageByName('10_Prototype');await penpot.openPage(p);F.proto=F.proto||{};
 const names=Object.keys(F.boards).filter(n=>!n.startsWith('CMP'));
 for(const [i,name]of names.entries()){
  const prior=p.root.children.find(s=>s.name==='PROTO / '+name);if(prior){F.proto[name]=prior.id;continue;}
  const snapshot=F.snapshots[name];if(!snapshot)throw Error('Export missing: '+name);
  const b=F.board(p.root,'PROTO / '+name,(i%5)*2040,1200+Math.floor(i/5)*1200);
  const image=F.rect(b,'SOURCE SNAPSHOT / '+name,0,0,1920,1080,F.C.paper,0);image.fills=[{fillImage:snapshot.media,fillOpacity:1}];
  b.setPluginData('forestlight-source',F.boards[name]);F.proto[name]=b.id;
 }
 return {prototypeBoards:Object.keys(F.proto).length};
};
F.connectPrototype=async()=>{
 const p=penpotUtils.getPageByName('10_Prototype');await penpot.openPage(p);
 const backTargets={SCR_05_CharacterDetail:'SCR_04_CharacterCollection',SCR_07_AccessoryDetail:'SCR_06_AccessoryCollection',SCR_10_PartyLobby:'SCR_09_ModeSelect',SCR_11_Matchmaking:'SCR_10_PartyLobby',SCR_12_MatchFound:'SCR_10_PartyLobby',SCR_13_CharacterSelect:'SCR_09_ModeSelect',SCR_14_AccessorySelect:'EXT_01_JobSelect',SCR_15_Loading:'EXT_02_ArenaSelect',EXT_01_JobSelect:'SCR_13_CharacterSelect',EXT_02_ArenaSelect:'SCR_14_AccessorySelect',EXT_03_StoryChapters:'SCR_09_ModeSelect',EXT_04_AISetup:'SCR_09_ModeSelect',EXT_05_PracticeSetup:'SCR_09_ModeSelect',CBT_08_Settings:'EXT_06_GeneralSettings'};
 for(const l of F.links){if(l.x===1600&&l.y===30&&backTargets[l.screen])l.target=backTargets[l.screen];if(l.screen==='SCR_15_Loading'&&l.trigger)l.target='STATE_Countdown';if(l.screen==='SCR_11_Matchmaking'&&l.x===604)l.target='STATE_CancelMatch';}
 let index=p.root.children.find(s=>s.name==='REVIEW INDEX');if(!index){index=F.board(p.root,'REVIEW INDEX',0,0);F.text(index,'Title','Forest Arena · 숲빛 UI 검토',64,56,48,1792,F.C.ink,'800');F.text(index,'Help','이미지 원본은 각 설계 페이지에서 편집합니다. 아래 목록은 화면·상태로 바로 이동합니다.\n전투의 검토 버튼은 상태 예시를 확인하는 도구이며 실제 게임 UI가 아닙니다.',64,136,24,1792);}
 for(const s of [...index.children])if(['Index item','Index name'].includes(s.name)||s.name.startsWith('NAV /'))s.remove();
 let links=0;
 const connect=(b,target,x,y,w,h,label)=>{const hit=F.rect(b,'NAV / '+label,x,y,w,h,F.C.paper,0,0);hit.setPluginData('forestlight-target',target);hit.addInteraction('click',{type:'navigate-to',destination:p.getShapeById(F.proto[target])});links++;};
 for(const [i,[name,id]]of Object.entries(F.proto).entries()){
  const b=p.getShapeById(id);for(const s of [...b.children])if(s.name!=='SOURCE SNAPSHOT / '+name)s.remove();for(const interaction of [...b.interactions])b.removeInteraction(interaction);
  for(const l of F.links.filter(l=>l.screen===name)){
   if(!F.proto[l.target])throw Error('Unresolved target '+l.target);
   if(l.trigger)b.addInteraction(l.trigger,{type:'navigate-to',destination:p.getShapeById(F.proto[l.target])},l.delay);else connect(b,l.target,l.x,l.y,l.w,l.h,l.target);
  }
  F.rect(b,'REVIEW NAV',852,4,216,36,F.C.green,18);F.text(b,'Review label','검토 목록',868,9,18,184,F.C.paper,'600','center');const review=F.rect(b,'REVIEW HIT',852,4,216,36,F.C.paper,0,0);review.addInteraction('click',{type:'navigate-to',destination:index});
  if(/^CBT_0[1234]/.test(name))for(const [j,[label,target]]of [['승리 예시','SCR_16_Victory'],['패배 예시','STATE_Defeat'],['복귀 확인','CBT_06_Resume']].entries()){const x=608+j*240;F.rect(b,'Review pill',x,1034,224,36,F.C.green,18);F.text(b,'Review action',label,x+8,1039,18,208,F.C.paper,'600','center');connect(b,target,x,1034,224,36,'검토: '+label);}
  const x=64+(i%5)*360,y=240+Math.floor(i/5)*76;F.rect(index,'Index item',x,y,336,60,i%2?F.C.sky:F.C.lime,16);F.text(index,'Index name',name,x+12,y+20,16,312,F.C.ink,'600','center');connect(index,name,x,y,336,60,name);
 }
 if(!p.flows.length){p.createFlow('전체 화면 검토',index);p.createFlow('실행부터 오프라인 전투까지',p.getShapeById(F.proto.SCR_01_Splash));}
 F.prototypeIndex=index.id;return {boards:Object.keys(F.proto).length,clickLinks:links,flows:p.flows.length,index:index.id};
};
return {prototypeTools:true};
