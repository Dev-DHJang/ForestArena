const F=storage.fa,C=F.C;
F.portrait=(s,key,x,y,w,h)=>{const m=F.media[key],r=m.width/m.height;const iw=Math.min(w,h*r),ih=iw/r;F.image(s,key,x+(w-iw)/2,y+(h-ih)/2,iw,ih);};
F.note=(s,txt)=>F.text(s,'Context',txt,128,176,22,1620,C.muted);
F.smallCard=(s,label,desc,icon,x,y,w=500,h=190,target)=>{F.panel(s,'Card / '+label,x,y,w,h);F.icon(s,icon,x+24,y+30,48);F.text(s,'Card title',label,x+96,y+24,28,w-156,C.ink,'700');F.text(s,'Card description',desc,x+96,y+76,21,w-136,C.muted);if(target){const hit=F.rect(s,'LINK / '+label,x,y,w,h,C.paper,24,0);F.links.push({id:hit.id,target});}};
F.filters=(s,labels,x=128,y=230)=>{let dx=x;labels.forEach((v,i)=>{const width=Math.max(168,Math.ceil((v.length*26+56)/8)*8);F.button(s,v,dx,y,null,'tab',width,i===0?'selected':'default');dx+=width+16;});};
F.nav=(s)=>{[['캐릭터','character','SCR_04_CharacterCollection'],['장신구','accessory','SCR_06_AccessoryCollection'],['프리셋','job','SCR_08_Preset'],['미션','mission','SCR_21_Mission'],['친구','social','SCR_22_Social'],['상점','shop','SCR_19_Shop']].forEach((a,i)=>F.button(s,a[0],128+i*214,914,a[2],'secondary',196,'default',a[1]));};
F.selection=(s,kind,target)=>{
 F.note(s,kind==='character'?'나에게 맞는 전투 동료를 선택하세요.':'등급 없이, 기능과 궁합으로 장신구를 고르세요.');
 F.filters(s,kind==='character'?['전체','균형','거리']:['전체','이동','공격','방어']);
 F.panel(s,'Selection grid',128,338,830,532);
 const names=kind==='character'?['자현','묘령','나비']:['바람 장갑','잎 차크람','덩굴 검','정령 등불','질풍 장화','가시 방패'];
 names.forEach((v,i)=>{const x=152+(i%3)*264,y=362+Math.floor(i/3)*236;F.rect(s,'Option '+v,x,y,240,208,i===0?'#DFF0CB':'#EDF4ED',24);if(kind==='character')F.portrait(s,['ja-hyun','myo-ryung','nabi'][i],x+44,y+8,152,152);else F.icon(s,['dash','special','heavy','leaf','jump','seed'][i],x+86,y+34,64);F.text(s,'Option name',v,x+12,y+160,24,216,C.ink,'700','center');if(i===0)F.icon(s,'check',x+192,y+16,28);});
 F.panel(s,'Selection detail',1000,230,792,640);
 if(kind==='character'){F.portrait(s,'ja-hyun',1060,258,280,390);F.text(s,'Selected name','자현',1400,300,46,330,C.ink,'800');F.text(s,'Role','균형 · 간격 조절',1400,372,25,330);F.text(s,'Description','짧은 연속 공격과\n리본으로 거리 만들기',1400,430,23,320,C.muted);F.button(s,'기술 살펴보기',1360,580,'SCR_05_CharacterDetail','secondary',320);}else{F.icon(s,'dash',1080,330,152);F.text(s,'Selected name','바람 장갑',1320,304,42,420,C.ink,'800');F.text(s,'Description','빠른 접근을 돕는 장신구\n궁합: 이동 · 거리 조절',1320,388,24,410,C.muted);F.button(s,'연습해 보기',1320,530,'CBT_04_Practice','secondary',320);}
 F.chip(s,'선택됨',1040,756,144);F.button(s,kind==='character'?'이 캐릭터 선택':'장착하기',1472,914,target);
};
F.run=async function(name){
 const d=F.specs.find(a=>a[0]===name);if(!d)throw Error(name);const [id,page,index,title,future]=d;
 const existing=penpotUtils.findShape(x=>x.name===id);if(existing?.getPluginData('forestlight-v01')==='complete'){F.boards[id]=existing.id;return {skipped:id};}
 const s=await F.newScreen(page,id,index,title,future);
 if(id==='SCR_01_Splash'||id==='SCR_02_Login'){
  for(const child of [...s.children])child.remove();F.image(s,'splash',0,0,1920,1080);F.rect(s,'Logo readability',450,176,1020,640,C.paper,40,.88);F.icon(s,'leaf',880,216,160);F.text(s,'Wordmark','FOREST\nARENA',560,388,84,800,C.green,'800','center');
  if(id==='SCR_01_Splash'){F.asset(s,'loading',640,884,640,40);F.text(s,'Progress','숲의 문을 여는 중…',650,950,25,620,C.paper,'700','center');F.links.push({id:s.id,target:'SCR_02_Login',trigger:'after-delay',delay:1800});}
  else{F.button(s,'게스트로 시작',800,790,'SCR_03_Lobby','primary',320,'default','play');F.button(s,'계정 로그인',800,902,'STATE_ConnectionError','secondary',320);F.text(s,'Account note','계정 연결은 미래 기능입니다.',590,1010,19,740,C.paper,'500','center');}
 }else if(id==='SCR_03_Lobby'){
  for(const child of [...s.children])child.remove();F.background(s,'lobby',.14);F.rect(s,'Top glass',64,44,1792,96,C.paper,28,.93);F.icon(s,'leaf',88,65,52);F.text(s,'Brand','FOREST ARENA',160,67,32,430,C.green,'800');F.button(s,'프로필',1336,48,'SCR_24_Profile','secondary',232,'default','profile');F.button(s,'설정',1592,48,'EXT_06_GeneralSettings','secondary',232,'default','settings');
  F.panel(s,'Preset summary',128,242,420,484);F.chip(s,'현재 프리셋 01',156,272,238);F.text(s,'Preset title','바람을 가르는\n첫 번째 발걸음',160,352,38,340,C.ink,'800');F.text(s,'Loadout','자현 / 시험 직업\n바람 장갑',160,490,24,340,C.muted);F.button(s,'편성 바꾸기',160,602,'SCR_08_Preset','secondary',320);
  F.portrait(s,'ja-hyun',640,178,510,680);F.chip(s,'자현 · 균형',788,826,240);
  F.smallCard(s,'연습부터 시작','이동과 공격을 익혀 보세요.','practice',1280,250,512,180,'EXT_05_PracticeSetup');F.smallCard(s,'숲의 이야기','새로운 여정 · 콘텐츠 준비 중','story',1280,458,512,180,'EXT_03_StoryChapters');F.button(s,'플레이',1312,756,'SCR_09_ModeSelect','primary',480,'default','play');F.nav(s);
 }else if(['SCR_04_CharacterCollection','SCR_13_CharacterSelect'].includes(id)){
  F.selection(s,'character',id==='SCR_04_CharacterCollection'?'SCR_05_CharacterDetail':'EXT_01_JobSelect');
  if(id==='SCR_13_CharacterSelect')F.text(s,'Participants','선택 예시 · 참가자 1–8 · 남은 시간 18초',128,882,19,1100,C.muted);
 }else if(['SCR_06_AccessoryCollection','SCR_14_AccessorySelect'].includes(id))F.selection(s,'accessory',id==='SCR_06_AccessoryCollection'?'SCR_07_AccessoryDetail':'EXT_02_ArenaSelect');
 else if(id==='SCR_05_CharacterDetail'){
  F.portrait(s,'ja-hyun',128,218,500,660);F.text(s,'Character','자현',720,216,64,630,C.ink,'800');F.chip(s,'균형 · 간격',724,312,224);F.filters(s,['기술','연계','이야기'],720,384);
  F.smallCard(s,'약공격','짧은 연속 공격으로 다음 기회를 만듭니다.','light',720,510,1072,144);F.smallCard(s,'강공격 · 특수','밀어내기와 거리 조절로 전장을 읽습니다.','heavy',720,680,1072,144);
  F.button(s,'연습하기',1116,914,'CBT_04_Practice','secondary');F.button(s,'편성에 넣기',1472,914,'SCR_08_Preset');
 }else if(id==='SCR_07_AccessoryDetail'){
  F.panel(s,'Accessory hero',128,224,640,610);F.icon(s,'dash',320,360,240);F.chip(s,'이동 · 거리',320,698,240);
  F.text(s,'Accessory name','바람 장갑',856,250,56,800,C.ink,'800');F.text(s,'Description','기동력을 중심으로 전투 흐름을 구성합니다.\n캐릭터와의 궁합을 연습에서 확인하세요.',856,356,28,850,C.muted);F.smallCard(s,'궁합','희귀도 대신 기능과 플레이 방식을 비교합니다.','leaf',856,500,936,220);
  F.button(s,'연습하기',1116,914,'CBT_04_Practice','secondary');F.button(s,'장착하기',1472,914,'SCR_08_Preset');
 }else if(id==='SCR_08_Preset'){
  F.note(s,'캐릭터·직업·장신구를 한 판의 편성으로 준비하세요.');F.filters(s,['프리셋 1','프리셋 2','프리셋 3','프리셋 4']);F.portrait(s,'ja-hyun',180,370,360,480);
  [['캐릭터','자현 · 균형','character','SCR_04_CharacterCollection'],['직업','시험 직업 · 추가 직업은 준비 중','job','EXT_01_JobSelect'],['장신구','바람 장갑 · 이동','accessory','SCR_06_AccessoryCollection']].forEach((a,i)=>F.smallCard(s,a[0],a[1],a[2],680,354+i*176,1112,152,a[3]));F.button(s,'편성으로 플레이',1472,914,'SCR_09_ModeSelect');
 }else if(id==='SCR_09_ModeSelect'){
  F.note(s,'바로 즐기는 연습과 AI 대전, 함께할 미래의 전장');
  [['Story','이야기 속 전투','story','EXT_03_StoryChapters'],['Solo','최대 8명 개인전','solo','SCR_10_PartyLobby'],['Team','팀당 1–4명 / 최대 8명','team','SCR_10_PartyLobby'],['AI','혼자 준비하는 AI 대전','ai','EXT_04_AISetup'],['Practice','자유롭게 연습하기','practice','EXT_05_PracticeSetup']].forEach((a,i)=>{const x=128+i*336;F.panel(s,'Mode '+a[0],x,300,312,510);F.icon(s,a[2],x+98,350,112);F.text(s,'Mode name',a[0],x+18,512,34,276,C.ink,'800','center');F.text(s,'Mode rule',a[1],x+24,580,23,264,C.muted,'500','center');F.button(s,'선택',x+28,682,a[3],i>=3?'primary':'secondary',256);if(i<3)F.chip(s,'미래 설계',x+70,246,168,true);});
 }else if(id==='SCR_10_PartyLobby'){
  F.note(s,'팀당 1–4명, 전체 최대 8명 · 아래 참가자는 배치 검토용 예시입니다.');
  ['A','B'].forEach((team,row)=>{F.chip(s,'TEAM '+team,128,268+row*280,164,row===1);for(let j=0;j<4;j++){const x=128+j*424,y=330+row*280;F.panel(s,'Participant '+team+j,x,y,396,212);F.icon(s,'character',x+28,y+30,52);F.text(s,'Player name',(row===0&&j===0?'방장 · 나':'참가자 '+(row*4+j+1)),x+104,y+28,26,250,C.ink,'700');F.text(s,'Ready',j<2?'✓ 준비 완료':'+ 참가 대기',x+104,y+92,22,250,C.muted);}});
  F.button(s,'친구 초대',128,914,'SCR_22_Social','secondary');F.button(s,'준비 완료',1116,914,'SCR_11_Matchmaking','secondary');F.button(s,'매치 찾기',1472,914,'SCR_11_Matchmaking');
 }else if(['SCR_11_Matchmaking','SCR_12_MatchFound','SCR_15_Loading'].includes(id)){
  const found=id==='SCR_12_MatchFound',loading=id==='SCR_15_Loading';F.panel(s,'Match glass',500,230,920,560);F.icon(s,loading?'arena':found?'check':'solo',868,268,184);F.text(s,'Match status',loading?'전투를 준비합니다':found?'전장이 열렸습니다':'상대를 찾는 중',580,490,44,760,C.ink,'800','center');F.text(s,'Match detail',loading?'자현  VS  묘령':found?'수락 5 / 8 · 남은 시간 8초':'Solo · 자현 / 바람 장갑 · 00:24',580,566,26,760,C.muted,'500','center');F.asset(s,'loading',760,662,400,40);
  if(found){F.button(s,'거절',604,866,'SCR_10_PartyLobby','danger');F.button(s,'수락',1000,866,'SCR_13_CharacterSelect');}else if(loading){F.text(s,'Tip','팁 · 피해율이 높을수록 더 멀리 밀려납니다.',430,850,26,1060,C.green,'600','center');F.links.push({id:s.id,target:'CBT_01_Match_1v1',trigger:'after-delay',delay:1600});}else{F.button(s,'찾기 취소',604,866,'SCR_10_PartyLobby','secondary');F.button(s,'발견 상태 보기',1000,866,'SCR_12_MatchFound');}
 }else if(['SCR_16_Victory','SCR_17_ResultSummary','SCR_18_MVP'].includes(id)){
  if(id==='SCR_17_ResultSummary'){
   F.text(s,'Result headline','좋은 한 판이었습니다!',128,218,50,1300,C.ink,'800');F.panel(s,'Result table',128,330,1080,500);F.text(s,'Table head','플레이어                 링아웃        남은 기회',168,364,25,980,C.muted,'700');['자현','묘령'].forEach((v,i)=>{F.rect(s,'Result row',160,442+i*144,1016,120,i===0?'#E2EFCD':'#E4F2F4',20);F.icon(s,'character',188,478+i*144,48);F.text(s,'Stats',v+'                         '+(i===0?'3               2':'1               0'),276,478+i*144,30,850,C.ink,'700');});F.smallCard(s,'보상 안내','보상·랭크 변화는 해당 모드 정책 확정 후 제공됩니다.','trophy',1248,330,544,500);
  }else{F.portrait(s,'ja-hyun',280,252,430,575);F.icon(s,'trophy',1160,246,132);F.text(s,'Result title',id==='SCR_16_Victory'?'승리!':'이번 경기의 MVP',824,432,64,880,C.green,'800','center');F.text(s,'Result sub','자현 · 끝까지 지켜낸 한 번의 기회',830,544,27,860,C.muted,'500','center');if(id==='SCR_18_MVP')F.button(s,'좋아요',1092,648,'SCR_24_Profile','secondary');}
  F.button(s,'로비로',128,914,'SCR_03_Lobby','secondary');F.button(s,id==='SCR_16_Victory'?'결과 보기':id==='SCR_17_ResultSummary'?'MVP 보기':'다시 플레이',1472,914,id==='SCR_16_Victory'?'SCR_17_ResultSummary':id==='SCR_17_ResultSummary'?'SCR_18_MVP':'SCR_09_ModeSelect');
 }else if(['SCR_19_Shop','SCR_20_Collection','SCR_21_Mission','SCR_22_Social','SCR_23_Rank','SCR_24_Profile'].includes(id)){
  F.meta(s,id);
 }else if(id.startsWith('EXT_'))F.extra(s,id);
 return F.finish(s);
};
F.meta=(s,id)=>{
 if(id==='SCR_19_Shop'){F.note(s,'획득 전에 연습하세요. 가격과 획득 방식은 아직 정하지 않았습니다.');F.filters(s,['추천','장신구','캐릭터']);['바람 장갑','잎 차크람','정령 등불'].forEach((v,i)=>{const x=128+i*568;F.panel(s,v,x,352,536,474);F.icon(s,['dash','special','leaf'][i],x+202,398,132);F.text(s,'Item',v,x+40,564,32,456,C.ink,'700','center');F.button(s,'연습하기',x+108,668,'CBT_04_Practice','secondary');});}
 else if(id==='SCR_20_Collection'){F.note(s,'보유 표시와 수집 진행은 설계 예시입니다.');F.filters(s,['캐릭터','장신구','전체']);['자현','묘령','나비'].forEach((v,i)=>{const x=128+i*568;F.panel(s,v,x,354,536,470);F.portrait(s,['ja-hyun','myo-ryung','nabi'][i],x+128,378,280,328);F.text(s,'Name',v,x+40,730,30,456,C.ink,'700','center');});}
 else if(id==='SCR_21_Mission'){F.note(s,'강요 없이 즐기는 목표 · 보상 수치는 미확정입니다.');F.filters(s,['일일','주간','업적']);[['연습장에서 한 판','진행 0 / 1'],['새로운 동료 알아보기','진행 1 / 3'],['끝까지 도전하기','진행 2 / 5']].forEach((a,i)=>{F.smallCard(s,a[0],a[1],'mission',128,348+i*176,1664,150);F.asset(s,'loading',1220,406+i*176,440,32);});}
 else if(id==='SCR_22_Social'){F.note(s,'접속·초대·관전은 온라인 구현 이후 제공됩니다.');F.filters(s,['친구','최근 플레이어']);['숲길친구','푸른바람','나뭇잎'].forEach((v,i)=>{F.smallCard(s,v,i===2?'오프라인':'접속 중 · 로비','social',128,346+i*170,1100,146);F.button(s,i===2?'접속 대기':'초대',1330,374+i*170,'SCR_10_PartyLobby','secondary',320,i===2?'disabled':'default');});F.button(s,'친구 찾기',1472,914,'STATE_EmptyList','secondary');}
 else if(id==='SCR_23_Rank'){F.panel(s,'Season',128,250,780,570);F.icon(s,'trophy',430,310,176);F.text(s,'Season title','다음 시즌의 숲',200,526,42,636,C.ink,'800','center');F.text(s,'Season status','등급·진행·시즌 보상 정책 준비 중',200,610,25,636,C.muted,'500','center');F.smallCard(s,'랭크 진행','현재는 랭크 대전을 시작할 수 없습니다.','solo',964,250,828,250);F.button(s,'랭크 대전 준비 중',1272,626,null,'primary',520,'disabled');}
 else{F.portrait(s,'ja-hyun',160,260,420,560);F.text(s,'Player','숲의 여행자',700,254,56,1000,C.ink,'800');F.chip(s,'대표 파이터 · 자현',700,354,310);F.smallCard(s,'즐겨 쓰는 편성','자현 / 시험 직업 / 바람 장갑','job',700,460,1092,190,'SCR_08_Preset');F.smallCard(s,'플레이어 기록','누적 전적과 진행은 저장 기능 구현 후 제공됩니다.','profile',700,680,1092,170);}
 F.button(s,'로비로',128,914,'SCR_03_Lobby','secondary');
};
F.extra=(s,id)=>{
 if(id==='EXT_06_GeneralSettings'){
  F.note(s,'편안하게 즐길 수 있도록 소리와 화면 효과를 조절하세요.');F.panel(s,'Settings',128,246,1664,584);
  [['음악','sound'],['효과음','sound'],['화면 흔들림','settings'],['번쩍임 효과','settings'],['진동','settings']].forEach((a,i)=>{F.icon(s,a[1],168,288+i*100,38);F.text(s,'Setting',a[0],236,286+i*100,27,700);F.asset(s,i<2?'slider':'toggle-on',i<2?1192:1600,278+i*100,i<2?440:104,i<2?64:56);});F.button(s,'조작 설정',1472,914,'CBT_08_Settings');F.button(s,'기본값 복원',128,914,'STATE_SettingsReset','secondary');
 }else{const config={EXT_01_JobSelect:['직업을 선택하세요','현재 시험 직업을 사용합니다. 추가 전직은 준비 중입니다.',['시험 직업','추가 직업 준비 중'],'job','SCR_14_AccessorySelect'],EXT_02_ArenaSelect:['경기장을 선택하세요','개발용 경기장을 기준으로 위험 경계와 발판을 확인하세요.',['훈련 경기장','추가 경기장 준비 중'],'arena','SCR_15_Loading'],EXT_03_StoryChapters:['이야기를 따라 숲으로','챕터 구성과 해금·보상은 미확정입니다.',['첫 번째 여정','다음 여정 준비 중'],'story','SCR_13_CharacterSelect'],EXT_04_AISetup:['AI 대전 준비','아래 조건은 UI 설계용 예시이며 난이도 정책은 미확정입니다.',['기본 상대','추가 난이도 준비 중'],'ai','SCR_13_CharacterSelect'],EXT_05_PracticeSetup:['연습 조건','동작을 반복하며 이동과 공격을 익혀 보세요.',['기본 연습','입력 안내 켜기'],'practice','CBT_04_Practice']}[id];
  F.note(s,config[1]);F.text(s,'Setup heading',config[0],128,258,42,1500,C.ink,'800');config[2].forEach((v,i)=>{F.smallCard(s,v,i===0?'선택됨':'준비 중인 항목',config[3],128+i*852,380,812,310);F.chip(s,i===0?'✓ 선택됨':'잠김',172+i*852,604,180,i===1);});F.button(s,'선택 확인',1472,914,config[4]);}
};
F.specs=[
 ['SCR_01_Splash','03_Launch',0,'시작',false],['SCR_02_Login','03_Launch',1,'로그인',false],
 ['SCR_03_Lobby','04_Lobby_Meta',0,'로비',false],['SCR_04_CharacterCollection','04_Lobby_Meta',1,'캐릭터',false],['SCR_05_CharacterDetail','04_Lobby_Meta',2,'캐릭터 상세',false],['SCR_06_AccessoryCollection','04_Lobby_Meta',3,'장신구',false],['SCR_07_AccessoryDetail','04_Lobby_Meta',4,'장신구 상세',false],['SCR_08_Preset','04_Lobby_Meta',5,'프리셋',false],
 ['SCR_09_ModeSelect','05_Match_Flow',0,'모드 선택',false],['SCR_10_PartyLobby','05_Match_Flow',1,'파티 대기실',true],['SCR_11_Matchmaking','05_Match_Flow',2,'매치 찾기',true],['SCR_12_MatchFound','05_Match_Flow',3,'매치 발견',true],['SCR_13_CharacterSelect','05_Match_Flow',4,'캐릭터 선택',false],['SCR_14_AccessorySelect','05_Match_Flow',5,'장신구 선택',false],['SCR_15_Loading','05_Match_Flow',6,'전투 준비',false],
 ['SCR_16_Victory','07_Result',0,'승리',false],['SCR_17_ResultSummary','07_Result',1,'전투 결과',false],['SCR_18_MVP','07_Result',2,'MVP',false],
 ['SCR_19_Shop','04_Lobby_Meta',6,'상점',true],['SCR_20_Collection','04_Lobby_Meta',7,'컬렉션',true],['SCR_21_Mission','04_Lobby_Meta',8,'미션',true],['SCR_22_Social','04_Lobby_Meta',9,'친구',true],['SCR_23_Rank','04_Lobby_Meta',10,'랭크',true],['SCR_24_Profile','04_Lobby_Meta',11,'프로필',true],
 ['EXT_01_JobSelect','05_Match_Flow',7,'직업 선택',false],['EXT_02_ArenaSelect','05_Match_Flow',8,'경기장 선택',false],['EXT_03_StoryChapters','05_Match_Flow',9,'Story 챕터',true],['EXT_04_AISetup','05_Match_Flow',10,'AI 대전 조건',false],['EXT_05_PracticeSetup','05_Match_Flow',11,'연습 조건',false],['EXT_06_GeneralSettings','04_Lobby_Meta',12,'설정',false]
];
return {specs:F.specs.length};
