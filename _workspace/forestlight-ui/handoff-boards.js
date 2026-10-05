const F=storage.fa,C=F.C;
F.docsBoard=async(page,name,w=1920,h=1080)=>{const p=penpotUtils.getPageByName(page);await penpot.openPage(p);let b=p.root.children.find(s=>s.name===name);if(b)return b;return F.board(p.root,name,40,40,w,h);};
F.composeLibrary=async()=>{
 const p=penpotUtils.getPageByName('02_Components');await penpot.openPage(p);F.composed={};
 for(const [index,name,w,h]of [[0,'Damage',100,48],[1,'Chances',76,32],[2,'ParticipantCompact',184,140],[3,'ParticipantWide',464,140],[4,'ParticipantSlot',500,152],[5,'Dialog',976,548]].map((a,i)=>a)){
  const prior=penpot.library.local.components.find(c=>c.path==='Forestlight/Composed'&&c.name===name);if(prior){F.composed[name]=prior.id;continue;}
  const b=F.board(p.root,'CMP / '+name,3400,1000+index*650,w,h);b.fills=[];
  if(name==='Damage')F.text(b,'Damage','48%',0,0,29,100,C.green,'800');
  if(name==='Chances')for(let i=0;i<3;i++)F.icon(b,'seed',i*22,4,20);
  if(name.startsWith('Participant')&&name!=='ParticipantSlot'){
   F.panel(b,'Surface',0,0,w,h);F.chip(b,'P1',14,10,w-28);F.text(b,'Fighter name','자현',16,57,22,w-32,C.ink,'700');
   const damage=penpot.library.local.components.find(c=>c.id===F.composed.Damage).instance();F.put(b,damage,16,90);
   const chances=penpot.library.local.components.find(c=>c.id===F.composed.Chances).instance();F.put(b,chances,w-76,90);
  }
  if(name==='ParticipantSlot'){F.panel(b,'Slot',0,0,w,h);F.icon(b,'profile',24,36,64);F.text(b,'Slot name','참가자',112,24,28,350,C.ink,'700');F.text(b,'Slot state','준비 중',112,76,22,350,C.muted);}
  if(name==='Dialog'){F.panel(b,'Surface',0,0,w,h);F.text(b,'Dialog title','계속 진행할까요?',76,148,46,824,C.ink,'800','center');F.text(b,'Dialog body','진행 내용을 확인해 주세요.',76,228,27,824,C.muted,'500','center');F.button(b,'취소',108,410,null,'secondary');F.button(b,'확인',540,410,null);}
  const c=penpot.library.local.createComponent([b]);c.name=name;c.path='Forestlight/Composed';F.composed[name]=c.id;
 }
 return {composed:F.composed};
};
F.bindHUD=async()=>{
 const p=penpotUtils.getPageByName('06_Combat');await penpot.openPage(p);let count=0;
 for(const b of p.root.children.filter(s=>/^(CBT_0[1234]|STATE_(Countdown|Hit|Ringout|Respawn|Eliminated|Defeat))/.test(s.name))){
  const hud=b.children.filter(s=>s.name.startsWith('HUD / P'));
  for(const h of hud){
   const x=h.parentX,y=h.parentY,w=h.width,wide=w>200;
   const shapes=b.children.filter(s=>s.parentX>=x-.1&&s.parentX+s.width<=x+w+.1&&s.parentY>=y-.1&&s.parentY+s.height<=y+140+.1);
   const value=n=>shapes.find(s=>s.name===n)?.characters;
   const damage=value('Damage'),fighter=value('Fighter name'),badge=value('Badge label');
   const stocks=shapes.filter(s=>s.name==='UI / icon-seed').map(s=>s.opacity);
   const c=penpot.library.local.components.find(c=>c.id===F.composed[wide?'ParticipantWide':'ParticipantCompact']);
   const instance=c.instance();instance.name='HUD INSTANCE / '+badge;F.put(b,instance,x,y);
   const nodes=F.walk(instance);for(const n of nodes){if(n.name==='Damage'&&n.type==='text')n.characters=damage||'0%';if(n.name==='Fighter name')n.characters=fighter||'참가자';if(n.name==='Badge label')n.characters=badge||'P1';if(n.name==='Badge / P1'&&badge?.includes('B'))n.fills=[{fillColor:C.sky,fillOpacity:1}];}
   nodes.filter(s=>s.name==='UI / icon-seed').forEach((s,i)=>s.opacity=stocks[i]??1);
   for(const s of shapes)s.remove();count++;
  }
 }
 return {bound:count};
};
F.foundations=async()=>{
 const b=await F.docsBoard('01_Foundations','FORESTLIGHT / 색상과 서체');if(b.children.length)return {exists:true};
 F.text(b,'Title','숲빛 유리 · 잎 장식',80,64,56,1700,C.ink,'800');F.text(b,'Subtitle','Forest Arena • 밝은 비픽셀 판타지 숲',80,148,28,1700,C.green,'600');
 for(const [i,[key,color]]of Object.entries(C).entries()){const x=80+(i%5)*352,y=240+Math.floor(i/5)*176;F.rect(b,'Color / '+key,x,y,304,92,color,24);F.text(b,'Token',key+'  '+color,x,y+106,23,330);let c=penpot.library.local.colors.find(c=>c.path==='Forestlight'&&c.name===key);if(!c)c=penpot.library.local.createColor();c.name=key;c.path='Forestlight';c.color=color;c.opacity=1;}
 F.text(b,'Type','Noto Sans KR • 제목 46–64 / 화면 제목 32 / 본문 24–28 / 보조 18–22',80,654,28,1760,C.ink,'600');
 F.text(b,'Rules','8px 간격 • 16:9 1920×1080 • Godot 1280×720 (2/3 환산)\n잎 장식은 모서리에만 사용 • 글자 뒤 무늬 최소화\n기본 / 눌림 / 선택 / 사용 불가를 명암·테두리·표시로 구분\n금색은 주요 행동, 산호색은 위험·나가기 • 장신구 등급 표현 없음',80,740,27,1760);
 for(const [name,size,weight] of [['Title','48','800'],['Body','26','500'],['Caption','20','500']]){let t=penpot.library.local.typographies.find(t=>t.path==='Forestlight'&&t.name===name);if(!t)t=penpot.library.local.createTypography();t.name=name;t.path='Forestlight';t.setFont(F.font,F.font.variants.find(v=>v.fontWeight===weight));t.fontSize=size;t.lineHeight='1.35';}
 const p=penpot.currentPage;for(const s of p.root.children)if(s.id!==b.id&&!s.name.startsWith('ARCHIVE')){s.name='ARCHIVE v00 / '+s.name;penpotUtils.setParentXY(s,s.x+12000,s.y);}
 return {foundation:b.id};
};
F.handoff=async()=>{
 const b=await F.docsBoard('09_Dev_Handoff','FORESTLIGHT / 개발 전달',1920,1680);if(b.children.length)return {exists:true};
 F.text(b,'Title','Forest Arena · 개발 전달',80,64,48,1700,C.ink,'800');
 const rows=[['화면','SCR 24 + CBT 8 + EXT 6 + STATE 12 = 편집 원본 50개'],['프로토타입','10_Prototype • 같은 페이지의 PNG + 실제 클릭 영역 • 원본은 별도 편집 가능'],['이동 흐름','실행 → 로그인 → 로비 → 모드 → 조건/선택 → 로딩 → 전투 → 결과 → 재시도'],['범위','오프라인 우선 • 온라인·상점·성장·랭크는 미래 설계 • 보상·가격·직업 정책 미정'],['기준','1920×1080 / 8px • 1280×720으로 2/3 환산 • 자유 이동 편집 제외'],['안전 영역','16:9 x125..1795 y54..1026 • 20:9 중앙 1920 플레이 영역, 좌우 240 여백'],['버튼 좌표 x/y/w/h','방향 152/690/320/320 • 약 1584/804/176/176 • 강 1408/648/144/144'],['나머지 조작','특수 1616/616/144/144 • 점프 1384/872/128/128 • 대시 1200/848/120/120'],['터치 영역','방향패드는 바깥 8px 확장, 행동은 4px 확장 • 서로 겹치지 않음'],['앵커','조작: 좌/우 하단 • HUD: 상단 • 중앙 전투: 카메라 영역 • 20:9는 중앙 고정 설계'],['중단 / 재개','입력 해제 → 오프라인 정지 → 복귀 확인 → 재개 • 온라인 메뉴는 경기 정지 안 함'],['실기기 재검사','TOUCH-01 동시 입력 • TOUCH-02 경계 이탈 • LIFECYCLE-01 중단·복귀'],['시각 재검사','HUD-08 8명·팀 기호·최대 줌아웃 • SAFE-20 노치·제스처·손가락 가림'],['자산 / 상태','87 SVG + 투명 PNG • native 한국어 텍스트 • 컴포넌트 ID로 연결'],['제품 미정','크기 85–110% / 투명도 60–100%는 검토 범위 • 가격·보상·성장 수치 미정'],['실행 변경 없음','Godot 화면·입력 코드·저장 형식 변경 없음 • Android 실기기 통과 기록 아님']];
 rows.forEach(([label,value],i)=>{const y=176+i*88;F.rect(b,'Row',64,y,1792,76,i%2?C.paper:'#E5F0E0',12);F.text(b,'Key',label,88,y+19,24,340,C.green,'700');F.text(b,'Value',value,436,y+20,22,1360);});
 return {handoff:b.id};
};
F.compare=async name=>{
 const p=penpotUtils.getPageById(F.pageFor[name]);await penpot.openPage(p);const title='CMP20 / '+name;let b=p.root.children.find(s=>s.name===title);if(b)return {exists:true};const original=p.getShapeById(F.boards[name]);b=original.clone();b.name=title;
 const children=b.children.map(s=>({s,x:s.parentX,y:s.parentY,w:s.width,h:s.height}));b.resize(2400,1080);for(const a of children){a.s.resize(a.w,a.h);penpotUtils.setParentXY(a.s,a.x+240,a.y);}penpotUtils.setParentXY(b,6400,40);b.fills=[{fillColor:C.green,fillOpacity:1}];
 F.text(b,'Aspect annotation','20:9\n중앙\n플레이 영역',24,440,28,190,C.paper,'700','center');F.text(b,'Aspect annotation','시스템\n안전 영역\n별도 적용',2184,440,28,190,C.paper,'700','center');
 F.boards[title]=b.id;F.pageFor[title]=p.id;return {name:title,id:b.id};
};
return {handoffTools:true};
