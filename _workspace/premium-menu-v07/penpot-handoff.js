const N=storage.v07;
N.makeAssetMapping=()=>{
 const p=penpot.currentPage;if(p.name!=='08_Assets_Mapping')throw Error('Open Assets Mapping first');
 let b=p.root.children.find(b=>b.name==='MENU07 / Actual forest backgrounds');if(b)return {existing:true};
 b=N.board(p,'MENU07 / Actual forest backgrounds',14080,0,1920,1080);
 N.text(b,'Title','로비 하위 메뉴 / 실제 배경 매핑',96,48,1700,48,N.C.text,'700');
 N.text(b,'Scope','설계 전용 이미지 · 런타임 리소스 등록 없음',96,118,1700,30,N.C.muted);
 ['character-room','accessory-workshop','shop-market','archive','social-lodge','observatory'].forEach((key,i)=>{
  const x=96+(i%3)*584,y=204+Math.floor(i/3)*392;
  N.draw(b,{name:b.name,elements:[{kind:'image',name:'DESIGN/bg/'+key,key,x,y,w:552,h:310,slot:'DESIGN/bg/'+key}]});
  N.text(b,'Mapping / '+key,'DESIGN/bg/'+key,x,y+326,552,25,N.C.text);
 });
 const c=N.board(p,'MENU07 / Approved character originals and vector icons',14080,1280,1920,1080);
 N.text(c,'Title','승인 캐릭터 원본 · 자체 벡터 아이콘',96,48,1700,48,N.C.text,'700');
 ['ja-hyun','myo-ryung','nabi','yu-ran'].forEach((key,i)=>{
  const x=96+i*430,slot={'ja-hyun':'IMG/char/mouse/full','myo-ryung':'IMG/char/rabbit/full','nabi':'DESIGN/char/nabi/full','yu-ran':'DESIGN/char/yu-ran/full'}[key];N.draw(c,{name:c.name,elements:[{kind:'image',name:'ART / '+key,key,x,y:160,w:340,h:360,slot}]});
  N.text(c,'Character mapping / '+key,key+'\n'+slot,x,536,340,24,N.C.text,'500','center');
 });
 const icons=Object.keys(N.components).filter(k=>k.startsWith('icon-'));
 icons.forEach((key,i)=>{const x=96+(i%8)*212,y=640+Math.floor(i/8)*190;N.icon(c,key.slice(5),x+56,y,72,72);N.text(c,'Icon mapping / '+key,key.slice(5),x,y+88,184,26,N.C.muted,'500','center');});
 N.text(c,'Asset status','v07 사용 자산 누락 0 / 배경 6 · 승인 원본 4 · 벡터 아이콘 16\n기존 미제작 자산 목록은 별도 보존합니다.',96,960,1700,27,N.C.muted);
 return {boards:[b.id,c.id],media:10,icons:icons.length};
};
N.makeHandoff=()=>{
 const p=penpot.currentPage;if(p.name!=='09_Dev_Handoff')throw Error('Open Dev Handoff first');
 let b=p.root.children.find(b=>b.name==='MENU07 / Native component and delivery contract');if(b)return {existing:true};
 b=N.board(p,'MENU07 / Native component and delivery contract',14000,0,1920,1080);
 N.text(b,'Title','프리미엄 메뉴 v07 / 개발 전달',96,48,1700,48,N.C.text,'700');
 N.text(b,'Scope','13개 기본 메뉴 + 68개 상태 · 로비·전투·결과 보존',96,124,1700,32,N.C.muted);
 N.text(b,'Geometry','설계 1920×1080 / PNG 1280×720\n안전 여백 좌우 96 · 상하 48 / 터치 영역 72×72 이상\n새 화면 이동 200ms dissolve / Noto Sans KR',96,208,1700,32,N.C.text);
 const styles=['default','primary','ghost','selected','pressed','disabled','owned','equipped','danger'];
 styles.forEach((state,i)=>{const x=96+(i%3)*584,y=440+Math.floor(i/3)*172;N.surface(b,'COMPONENT / surface-'+state,x,y,536,88,state);N.text(b,'State label / '+state,state,x,y+100,536,27,N.C.muted,'500','center');});
 N.text(b,'Integration','이미지와 한국어 텍스트를 분리해 구현 · ForestArenaResources의 승인 ID 사용\nStory·보상·가격·등급·네트워크 기능 추가 없음 / Android 기기 확인 미수행',96,972,1700,27,N.C.muted);
 const c=N.board(p,'MENU07 / Actual state index',14000,1280,3600,2400);
 N.text(c,'Title','실제 원본 및 프로토타입 / 81개 화면',96,48,3400,48,N.C.text,'700');
 N.text(c,'State guidance','편집 가능한 텍스트·벡터·컴포넌트는 각 원본에 유지합니다. 10_Prototype은 실제 PNG와 클릭 영역으로 연결합니다.',96,124,3400,30,N.C.muted);
 N.spec.scenes.forEach((s,i)=>{const x=96+Math.floor(i/27)*1160,y=208+(i%27)*76;N.text(c,'STATE / '+s.name,(i+1).toString().padStart(2,'0')+'  '+s.name,x,y,1100,24,N.spec.base.includes(s.name)?N.C.gold:N.C.text);});
 N.text(c,'Export manifest','실제 PNG 81개 + 20:9 비교 4개 / export-records.json에 원본 ID·고유 파일명·출력 크기 기록',96,2292,3400,30,N.C.muted);
 const d=N.board(p,'MENU07 / Preserved behavior and state rules',14000,3880,1920,1080);
 N.text(d,'Title','메뉴 동작과 보존 범위',96,48,1700,48,N.C.text,'700');
 N.text(d,'Behavior','선택 상태는 금빛 선과 체크 표시를 함께 사용합니다.\n사용 불가 행동은 버튼과 클릭 영역을 함께 막습니다.\n팝업에서는 마지막 팝업의 두 행동만 클릭할 수 있습니다.\n로비에서 연 조작 설정은 로비 설정으로 돌아갑니다.\n전투에서 연 조작 설정은 기존 일시정지 화면으로 돌아갑니다.',96,192,1700,34,N.C.text);
 N.text(d,'Preservation','기존 연결 287개의 도형 ID·목적지 보존\n기존 컴포넌트 536개의 ID 보존\n범위 밖 원본 42개와 프로토타입을 변경 전 기록과 비교',96,544,1700,32,N.C.muted);
 N.text(d,'Asset warning','장신구 등급·희귀도와 미정 가격·보상·성장 수치를 만들지 않습니다.\n친구 이름·접속·보유 정보는 설계 예시입니다.\n생성 배경은 기존 승인 캐릭터나 런타임 자산을 대체하지 않습니다.',96,812,1700,32,N.C.muted);
 return {boards:[b.id,c.id,d.id],nativeStates:N.spec.scenes.length,components:styles.length};
};
return {handoffHelper:true};
