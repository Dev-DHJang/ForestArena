const F=storage.fa,C=F.C;
F.controls=[{key:'light',label:'약',x:1584,y:804,size:176},{key:'heavy',label:'강',x:1408,y:648,size:144},{key:'special',label:'특수',x:1616,y:616,size:144},{key:'jump',label:'점프',x:1384,y:872,size:128},{key:'dash',label:'대시',x:1200,y:848,size:120}];
F.combat=async(id,index,mode,players)=>{
 const existing=penpotUtils.findShape(s=>s.name===id);if(existing?.getPluginData('forestlight-v01')==='complete'){F.boards[id]=existing.id;return{id,skipped:true};}
 const s=await F.newScreen('06_Combat',id,index,mode,players>2);for(const child of [...s.children])child.remove();
 F.background(s,'lobby',.78);F.text(s,'Mode',mode,128,42,27,980,C.green,'800');F.text(s,'Match rule','3번 링아웃되면 탈락',1160,48,21,632,C.muted,'500','right');
 for(let i=0;i<players;i++){
  const x=players===2?(i===0?128:1328):128+i*208,w=players===2?464:184;F.panel(s,'HUD / P'+(i+1),x,110,w,140);
  const team=mode.includes('Team')?(i<4?'A':'B'):null;F.chip(s,(team?'TEAM '+team+' · ':'')+'P'+(i+1),x+14,120,w-28,team==='B');
  F.text(s,'Fighter name',['자현','묘령','나비'][i%3],x+16,167,22,w-32,C.ink,'700');F.text(s,'Damage',`${[48,32,64,12,88,26,53,0][i]}%`,x+16,200,29,w-86,C.green,'800');
  for(let stock=0;stock<3;stock++){const seed=F.icon(s,'seed',x+w-76+stock*22,204,20);if(stock===2&&i%2===0)seed.opacity=.25;}
 }
 const pause=F.button(s,'메뉴',1568,278,'CBT_05_Pause','secondary',224,'default','pause');
 F.rect(s,'Arena platform',440,620,1040,40,'#78A977',16);F.rect(s,'Left platform',550,444,232,24,'#91D5EF',12);F.rect(s,'Right platform',1154,444,232,24,'#91D5EF',12);
 F.text(s,'Risk left','← 링아웃 경계',160,456,21,250,C.danger);F.text(s,'Risk right','링아웃 경계 →',1560,456,21,232,C.danger,'500','right');
 const drawCount=players===2?2:8;for(let i=0;i<drawCount;i++){const x=players===2?650+i*480:480+i*122;F.portrait(s,['ja-hyun','myo-ryung','nabi'][i%3],x,players===2?424:494,players===2?128:74,players===2?176:110);F.chip(s,'P'+(i+1),x,players===2?384:454,players===2?128:74,i>=4);}
 const dp=F.asset(s,'dpad-default',152,690,320,320);dp.name='CONTROL / move_4way';dp.setPluginData('touch-rect',JSON.stringify({x:144,y:682,w:336,h:336}));
 for(const a of F.controls){const hit=F.board(s,'CONTROL / '+a.key,a.x,a.y,a.size,a.size);hit.fills=[];hit.clipContent=false;F.asset(hit,'action-'+a.key+'-default',0,0,a.size,a.size);F.text(hit,'Action label',a.label,8,a.size*.73,18,a.size-16,C.ink,'700','center');hit.setPluginData('touch-rect',JSON.stringify({x:a.x-4,y:a.y-4,w:a.size+8,h:a.size+8}));}
 if(mode==='Practice'){F.button(s,'연습 다시 시작',728,278,'CBT_04_Practice','secondary',400);F.text(s,'Input guidance','이동 + 공격 · 두 손가락으로 함께 눌러 보세요',550,946,24,610,C.green,'600','center');}
 if(players>2)F.chip(s,'미래 전투 구성 · 설계안',750,278,410,true);
 return F.finish(s);
};
F.overlay=async(id,index,title,body,primary,target,secondary='취소',back='CBT_01_Match_1v1')=>{
 const e=penpotUtils.findShape(s=>s.name===id);if(e?.getPluginData('forestlight-v01')==='complete'){F.boards[id]=e.id;return{id,skipped:true};}
 const s=await F.newScreen('06_Combat',id,index,title);for(const c of [...s.children])c.remove();F.background(s,'lobby',.66);F.rect(s,'Dim backdrop',0,0,1920,1080,C.ink,0,.22);
 F.panel(s,'Modal',472,256,976,548);F.icon(s,id.includes('Leave')?'ringout':'pause',888,294,96);F.text(s,'Modal title',title,548,418,46,824,C.ink,'800','center');F.text(s,'Modal body',body,548,494,27,824,C.muted,'500','center');F.button(s,secondary,580,666,back,'secondary');F.button(s,primary,1012,666,target,id.includes('Leave')?'danger':'primary');return F.finish(s);
};
F.controlSettings=async()=>{
 const s=await F.newScreen('06_Combat','CBT_08_Settings',7,'조작 설정');F.note(s,'기본 배치를 유지하며 버튼 크기와 투명도를 조절합니다.');
 F.panel(s,'Preview',128,254,1000,560);F.asset(s,'dpad-default',172,526,240,240);for(const a of F.controls){F.asset(s,'action-'+a.key+'-default',128+(a.x-700)*.58,300+(a.y-400)*.7,a.size*.75,a.size*.75);}F.text(s,'Preview label','조작 미리보기',168,282,30,780,C.ink,'700');
 F.panel(s,'Settings controls',1168,254,624,560);F.text(s,'Size','버튼 크기 100%',1212,320,30,500,C.ink,'700');F.asset(s,'slider',1220,396,500,64);F.text(s,'Opacity','버튼 투명도 85%',1212,524,30,500,C.ink,'700');F.asset(s,'slider',1220,596,500,64);F.text(s,'Limits','예시 범위 · 크기 85–110% / 투명도 60–100%',1212,712,20,524,C.muted);
 F.button(s,'기본값 복원',128,914,'STATE_SettingsReset','secondary');F.button(s,'적용',1472,914,'EXT_06_GeneralSettings');return F.finish(s);
};
F.stateSpecs=[
 ['STATE_Countdown','시작까지','3','CBT_01_Match_1v1','시작'],['STATE_Hit','피격','피해율 48% → 62%','CBT_01_Match_1v1','계속'],['STATE_Ringout','링아웃','남은 기회 2회','STATE_Respawn','복귀 보기'],['STATE_Respawn','경기장으로 복귀','다시 한 번 기회를 잡으세요','CBT_01_Match_1v1','재개'],['STATE_Eliminated','이번 경기는 여기까지','남은 참가자의 전투를 확인합니다','SCR_17_ResultSummary','결과 보기'],['STATE_Defeat','아쉬운 패배','다음 한 판에서 다시 도전하세요','SCR_17_ResultSummary','결과 보기'],
 ['STATE_SelectionRequired','캐릭터를 선택해 주세요','선택을 마치면 다음 단계로 이동합니다','SCR_13_CharacterSelect','선택으로'],['STATE_EmptyList','아직 목록이 비어 있습니다','친구가 추가되면 이곳에 표시됩니다','SCR_22_Social','돌아가기'],['STATE_ConnectionError','연결하지 못했습니다','연결 상태를 확인한 뒤 다시 시도하세요','SCR_02_Login','다시 시도'],['STATE_SettingsReset','기본값으로 되돌릴까요?','버튼 크기 100% · 투명도 85%로 돌아갑니다','CBT_08_Settings','복원'],['STATE_OnlineMenu','온라인 경기 메뉴','메뉴를 열어도 경기는 계속됩니다','CBT_03_Match_Team4v4','경기로'],['STATE_CancelMatch','매치 찾기를 취소할까요?','현재 파티와 편성은 유지됩니다','SCR_10_PartyLobby','찾기 취소']
];
return {combat:true,states:F.stateSpecs.length};
