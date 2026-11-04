from pathlib import Path
import json,copy
P=Path(__file__).resolve().parent;old=json.loads((P.parent/'scene-spec.json').read_text());scenes=[]
def el(k,n,x,y,w,h,**kw):return dict(kind=k,name=n,x=x,y=y,w=w,h=h,**kw)
def t(n,v,x,y,w,size=28,color='text',weight='500',align='left'):return el('text',n,x,y,w,round(size*1.45*len(v.split('\n'))),text=v,size=size,color=color,weight=weight,align=align)
def r(n,x,y,w,h,c='panel',o=1,rad=12):return el('rect',n,x,y,w,h,color=c,opacity=o,radius=rad)
def b(n,v,x,y,w,h,d=None,state='default',size=30):return el('button',n,x,y,w,h,text=v,dest=d,state=state,size=size,icon=None)
def add(s):scenes.append(s);return s
def base(k,title,canonical,note='내용·이름·상태는 설계 예시'):
 return dict(key=k,name='MENU09 / Life-r01 / '+k,canonical=canonical,title=title,revision='life-r01',w=1920,h=1080,elements=[el('image','IMG / character-room',0,0,1920,1080,key='character-room',slot='IMG/bg/character-room'),r('ATMOSPHERE',0,0,1920,1080,'bg',.82,0),r('HEADER',0,0,1920,160,'bg',.94,0),r('FOOTER',0,912,1920,168,'bg',.96,0),b('BACK','←',96,48,80,80,'life-entry','ghost',36),t('TITLE',title,208,48,1200,52,weight='700'),t('HEADER / note',note,208,112,1456,26,'muted')])
def tabs(e,items,sel,w=264):
 for i,(k,l,d) in enumerate(items):e.append(b('TAB / '+k,l,96,224+i*112,w,88,None if sel==k else d,'selected' if sel==k else 'default',30))
friendtabs=[('list','친구','friends'),('received','받은 신청','friends-received'),('sent','보낸 신청','friends-sent'),('recent','최근 상대','friends-recent'),('invites','받은 초대','friends-invites')]
for key,sel in [('friends','list'),('friends-received','received'),('friends-sent','sent'),('friends-recent','recent'),('friends-query','list'),('friends-result','list'),('friends-invites','invites'),('friends-invites-busy','invites')]:
 s=base(key,'친구','SCR_22_Social');e=s['elements'];tabs(e,friendtabs,sel);query=key in ['friends-query','friends-result']
 e.extend([b('SEARCH / input','새솔 · 입력 예시' if query else '정확한 닉네임 입력 (1~12자)',408,208,1048,88,'friends-query','selected' if query else 'default',30),b('SEARCH / submit','검색',1488,208,336,88,'friends-result' if query else 'friends-input','primary',32)])
 if sel=='list' and key!='friends-result':
  e.append(t('LIST / context','내 LAN 대기방의 방장 상태 예시 · 친구만 초대 가능',408,328,1416,28,'gold'));rows=[('솔잎','접속 중','초대','friend-invite','삭제','friend-remove'),('느티','오프라인','초대','friend-invite','삭제','friend-remove')]
 elif sel=='received':rows=[('물결','받은 친구 신청','수락','friend-accept','거절','friend-reject'),('새벽','받은 친구 신청','수락','friend-accept','거절','friend-reject')]
 elif sel=='invites':rows=[('솔잎','대전 중 · 참가 불가' if key.endswith('busy') else '대기 중인 LAN 방 · 초대120초','참가',None if key.endswith('busy') else 'friend-invite-join','거절','friend-invite-reject'),('느티','만료된 초대','참가',None,'상태 보기','friend-invite-unavailable'),('물결','이미 닫힌 방','참가',None,'상태 보기','friend-invite-unavailable')]
 elif sel=='sent':rows=[('별숲','보낸 친구 신청','요청 취소','friend-cancel',None,None)]
 elif sel=='recent':rows=[('이슬','최근 LAN 상대','친구 신청','friend-request',None,None)]
 else:rows=[('새솔','정확한 닉네임 검색 결과 · 친구 아님','친구 신청','friend-request',None,None)]
 for i,(name,status,a,d,c,cd) in enumerate(rows):
  y=384+i*168 if sel=='invites' else 392+i*192;e.extend([r('PERSON / '+str(i),408,y,1416,144 if sel=='invites' else 160,'panel',.96,16),r('AVATAR / '+str(i),432,y+32,96,96,'bg',1,48),t('AVATAR / initial '+str(i),name[0],440,y+56,80,32,'mint',align='center'),t('PERSON / name '+str(i),name,560,y+24,560,34,weight='600'),t('PERSON / status '+str(i),status,560,y+88,560,26,'muted'),b('PERSON / action '+str(i),a,1168,y+40,288 if c else 608,88,d,'default' if d else 'disabled',28)])
  if c:e.append(b('PERSON / extra '+str(i),c,1488,y+40,288,88,cd,'ghost',28))
 e.extend([t('FOOTER / note','초대는120초 후 만료돼요. 진행 중인 대전에는 자동 참가하지 않아요.',408,912,1416,26,'muted'),b('FOOTER / refresh','새로고침',408,984,344,72,'friends-loading','ghost',28)]);e[-1]['y']=960;add(s)
# Shared non-success dialogs retain source context on close.
def overlay(key,title,body,blocked=None):
 s=dict(key=key,name='MENU09 / Life-r01 / '+key,canonical='EXT_MENU09_LifeState',title=title,revision='life-r01',w=1920,h=1080,overlay=True,elements=[r('MODAL / scrim',0,0,1920,1080,'bg',.86,0),r('MODAL / panel',400,248,1120,584,'panel',1,20),t('MODAL / eyebrow','FOREST ARENA · 설계 검토',448,288,1024,24,'gold'),t('MODAL / title',title,448,336,1024,42,weight='700'),t('MODAL / body',body,448,424,1024,30,'muted'),b('MODAL / close','닫기',448,704,496 if blocked else 1024,80,None,'primary',30)]);s['elements'][-1]['action']='close-overlay'
 if blocked:s['elements'].append(b('MODAL / blocked',blocked,976,704,496,80,None,'disabled',28))
 add(s)
for k,title,body in [('friends-input','닉네임을 입력해 주세요','정확한 닉네임1~12자로 검색해요.\n시안에서는 새솔을 입력한 예시를 살펴볼 수 있어요.'),('friend-request','친구 신청 확인','선택한 상대에게 친구 신청을 보냅니다.\n반대 방향 신청이 있어도 자동으로 친구가 되지 않아요.\n본인·이미 친구·중복 신청은 보낼 수 없어요.\n이 시안에서는 실제 신청을 보내지 않습니다.'),('friend-accept','친구 신청 수락','선택한 받은 신청을 수락하는 확인 화면입니다.\n이 시안에서는 실제 친구 관계를 변경하지 않습니다.'),('friend-reject','친구 신청 거절','선택한 받은 신청을 거절하는 확인 화면입니다.\n이 시안에서는 실제 신청을 변경하지 않습니다.'),('friend-cancel','보낸 신청 취소','선택한 보낸 신청을 취소하는 확인 화면입니다.\n이 시안에서는 실제 신청을 변경하지 않습니다.'),('friend-remove','친구 삭제 확인','선택한 친구를 목록에서 삭제하는 확인 화면입니다.\n이 시안에서는 실제 친구를 삭제하지 않습니다.'),('friend-invite-join','LAN 대기방 참가','아직 대기 중인 친구의 방에 참가하는 동선입니다.\n초대가 만료되거나 방이 닫혔으면 참가할 수 없어요.\n이미 대전 중이거나 LAN 방에 있다면 참가하지 않습니다.'),('friend-invite-reject','받은 초대 거절','선택한 대기방 초대를 거절하는 확인 화면입니다.\n이 시안에서는 실제 초대 상태를 변경하지 않습니다.'),('friend-invite-unavailable','참가할 수 없는 초대','초대가 만료되었거나 방이 이미 닫혔어요.\n친구가 새 초대를 보내면 다시 확인해 주세요.'),('friend-invite','대기방으로 초대','내가 방장인 LAN 대기방으로 친구를 초대해요.\n초대는120초 후 만료되며 닫힌 방에는 참가할 수 없어요.\n이 시안에서는 실제 초대를 보내지 않습니다.')]:overlay(k,title,body)
# Mail selection and detail keep the sketch's time column and bulk actions.
for mask in range(8):
 key='mailbox' if mask==0 else 'mailbox-selected' if mask==1 else 'mailbox-selected-'+str(mask);selected=bool(mask)
 s=base(key,'우편함','EXT_MENU09_Mailbox','우편·보상·시간은 설계 예시 · 운영·수령·삭제 조건 미정');e=s['elements'];
 if mask:s['clone_of']='mailbox'
 e.extend([t('MAIL / heading','선택',96,208,128,28,'gold'),t('MAIL / title-heading','우편 내용',256,208,1152,28,'gold'),t('MAIL / time-heading','남은 시간 · 예시',1440,208,384,28,'gold',align='right')])
 for i,(title,sub,time) in enumerate([('안내 우편 A','보상 포함 여부 미정','시간 미정'),('안내 우편 B','내용과 발송 조건 미정','시간 미정'),('읽은 우편 C','읽음 표시 예시','시간 미정')]):
  y=288+i*184;nextmask=mask^(1<<i);nextkey='mailbox' if nextmask==0 else 'mailbox-selected' if nextmask==1 else 'mailbox-selected-'+str(nextmask);e.extend([r('MAIL / row '+str(i),96,y,1728,160,'panel',.96,16),b('MAIL / select '+str(i),'✓' if mask&(1<<i) else '□',112,y+40,96,80,nextkey,'selected' if mask&(1<<i) else 'default',32),b('MAIL / open '+str(i),title,240,y+24,1096,72,'mail-detail-'+str(i),'ghost',32),t('MAIL / sub '+str(i),sub,264,y+104,1048,26,'muted'),t('MAIL / time '+str(i),time,1400,y+64,376,28,'muted',align='right')])
 e.extend([t('MAIL / selection',f'선택{mask.bit_count()}개 · 예시' if selected else '선택한 우편 없음',96,872,1728,26,'muted'),b('MAIL / claim-all','모두 받기',96,944,560,88,'mail-claim','primary',32),b('MAIL / delete','지우기',680,944,560,88,'mail-delete' if selected else None,'default' if selected else 'disabled',32),b('MAIL / delete-all','모두 지우기',1264,944,560,88,'mail-delete-all','default',32)]);add(s)
for i,title in enumerate(['안내 우편 A','안내 우편 B','읽은 우편 C']):overlay('mail-detail-'+str(i),title,'우편 본문을 표시하는 영역입니다.\n발신자·만료 시각·보상과 운영 조건은 미정입니다.\n닫으면 원래 목록의 선택 상태를 유지합니다.','받기 · 미정')
for k,ttl,body,blocked in [('mail-claim','우편 보상 수령 조건','보상 종류·수량·만료·중복 수령과 실패 복구는 미정입니다.\n이 시안에서는 실제 보상을 지급하지 않습니다.','수령 · 미정'),('mail-delete','선택 우편 삭제 확인','선택한 우편을 지우는 확인 화면입니다.\n보상 미수령 우편의 삭제·복구 규칙은 미정입니다.\n이 시안에서는 실제 우편을 삭제하지 않습니다.','삭제 · 미정'),('mail-delete-all','모든 우편 삭제 확인','전체 우편 삭제 범위와 보관·복구 규칙은 미정입니다.\n이 시안에서는 실제 우편을 삭제하지 않습니다.','모두 삭제 · 미정')]:overlay(k,ttl,body,blocked)
noticetabs=[('notices','공지사항','notices'),('events','진행 이벤트','notices-events'),('past','지난 이벤트','notices-past')]
for key,tab in [('notices','notices'),('notices-second','notices'),('notices-events','events'),('notices-past','past')]:
 s=base(key,'공지사항','EXT_MENU09_Notices','공지·이벤트 내용과 일정은 설계 예시');e=s['elements'];tabs(e,noticetabs,tab);e.append(b('CLOSE','×',1744,48,80,80,'life-entry','ghost',36))
 e.extend([r('NOTICE / panel',408,224,1416,640,'panel',.96,16)])
 if tab=='notices':
  e.extend([b('NOTICE / first','안내 A',440,256,640,80,'notices','selected' if key=='notices' else 'default',30),b('NOTICE / second','안내 B',1112,256,680,80,'notices-second','selected' if key!='notices' else 'default',30),t('NOTICE / title','플레이 안내 · 예시 A' if key=='notices' else '업데이트 안내 · 예시 B',456,400,1320,40,'gold',weight='600'),t('NOTICE / body','공지 본문을 표시하는 영역입니다.\n현재 게시된 실제 공지나 점검 일정은 아닙니다.\n목록·선택·본문·닫기 배치를 검토해 주세요.',456,512,1320,32,'muted')])
 else:e.extend([t('NOTICE / title','진행 이벤트 준비 중' if tab=='events' else '지난 이벤트가 없어요',456,392,1320,42,'gold',weight='600'),t('NOTICE / body','이벤트 내용·기간·참가 조건·보상은 미정입니다.\n실제 진행 중인 이벤트를 뜻하지 않습니다.',456,512,1320,32,'muted'),b('NOTICE / info','운영 안내',456,704,688,88,'notice-info','default',30)])
 e.append(t('FOOTER / note','공지와 이벤트는 준비된 내용을 읽는 화면입니다.',408,952,1416,28,'muted'));add(s)
overlay('notice-info','공지·이벤트 운영 안내','게시 내용·노출 기간·이벤트 참가와 보상 조건은 미정입니다.\n외부 링크나 영상은 준비되지 않았습니다.')
# Settings keep the sketch's six groups and the current six functional categories.
settingtabs=[('profile','프로필','settings-profile'),('sound','사운드','settings-sound'),('view','화면·조작','settings-effects'),('notifications','알림','settings-notifications'),('account','계정','settings-account'),('info','정보','settings-info')]
subtabs=[('effects','화면 효과'),('accessibility','접근성'),('minimap','미니맵'),('controls','조작'),('debug','임시 디버깅')]
def setting_base(key,group,sub=None,dirty=False):
 s=base(key,'설정','EXT_06_GeneralSettings','설정 값은 시안 예시 · 실제 기기에는 저장하지 않아요');e=s['elements'];tabs(e,settingtabs,group)
 if sub:
  for i,(k,l) in enumerate(subtabs):e.append(b('SUBTAB / '+k,l,408+i*288,208,264,80,None if k==sub else 'settings-'+k,'selected' if k==sub else 'default',28))
 e.extend([t('SETTING / state','변경 사항 있음 · 예시' if dirty else '분류별로 적용·취소·기본값을 확인하세요.',408,864,1416,26,'gold' if dirty else 'muted'),b('SETTING / defaults','기본값',408,944,440,88,'settings-defaults','ghost',30),b('SETTING / cancel','취소',880,944,440,88,'settings-sound' if dirty else None,'default' if dirty else 'disabled',30),b('SETTING / apply','적용',1352,944,472,88,'settings-sound-applied' if dirty else None,'primary' if dirty else 'disabled',32)])
 if group not in ['sound','view']:
  e[:]=[x for x in e if x['name'] not in ['SETTING / defaults','SETTING / cancel','SETTING / apply']]
  e.extend([b('SETTING / logout','로그아웃',408,944,688,88,'settings-logout','default',30),b('SETTING / exit','게임 종료',1128,944,696,88,'settings-exit','default',30)])
 return s
def setting_row(e,n,title,value,y,sub='',dest='settings-values'):
 e.extend([r('SETTING / row '+n,408,y,1416,144,'panel',.96,16),t('SETTING / title '+n,title,440,y+24,792,32,weight='600'),t('SETTING / description '+n,sub,440,y+80,792,24,'muted'),b('SETTING / value '+n,('✓ ' if value=='켜짐' else '□ ' if value=='꺼짐' else '')+value,1296,y+16,480,80,dest,'default',30)])
 if value.endswith('%') and n!='font':
  current=float(value[:-1]);low=100 if n=='size' else 0;high=120 if n=='size' else 90 if '미니맵 전체' in title else 50 if '버튼 투명도' in title else 100;pct=max(0,min(1,(current-low)/(high-low)))
  e.append(r('SLIDER / track '+n,1296,y+112,448,8,'line',1,4))
  if pct:e.append(r('SLIDER / fill '+n,1296,y+112,448*pct,8,'mint',1,4))
  e.append(r('SLIDER / thumb '+n,1288+448*pct,y+104,16,24,'gold',1,8))
for key,group,sub in [('settings-profile','profile',None),('settings-sound','sound',None),('settings-effects','view','effects'),('settings-accessibility','view','accessibility'),('settings-minimap','view','minimap'),('settings-controls','view','controls'),('settings-debug','view','debug'),('settings-notifications','notifications',None),('settings-account','account',None),('settings-info','info',None),('settings-sound-dirty','sound',None),('settings-sound-applied','sound',None)]:
 dirty=key=='settings-sound-dirty';s=setting_base(key,group,sub,dirty);e=s['elements']
 if group=='profile':
  e.extend([r('PROFILE / panel',408,224,1416,608,'panel',.96,16),t('PROFILE / title','프로필 정보',456,272,1320,42,'gold',weight='600'),t('PROFILE / name','닉네임 · 숲의 여행자',456,384,1320,34),t('PROFILE / note','프로필 표시 예시\n닉네임과 연결 상태는 프로필 관리에서 확인해요.',456,472,1320,30,'muted'),b('PROFILE / manage','프로필 관리',456,680,1272,88,'profile-info','default',32)])
 elif group=='sound':
  setting_row(e,'music','배경 음악','65%' if key.endswith(('dirty','applied')) else '60%',256,'0~100% · 5% 간격 / 기본60%','settings-sound' if dirty else 'settings-values' if key.endswith('applied') else 'settings-sound-dirty');setting_row(e,'effects','효과음','80%',432,'0~100% · 5% 간격 / 기본80%');setting_row(e,'mute','음소거','꺼짐',608,'기본 꺼짐')
  if key.endswith('applied'):next(x for x in e if x['name']=='SETTING / state')['text']='65% 적용 후 표시 예시 · 실제 저장 없음'
 elif sub=='effects':setting_row(e,'flashes','피격 번쩍임 줄이기','꺼짐',360,'켜짐/꺼짐 · 강한 번쩍임을 줄여요.')
 elif sub=='accessibility':
  setting_row(e,'font','글자 크기','100%',336,'100% / 115% / 130%');setting_row(e,'vibration','진동','켜짐',512,'기본 켜짐')
 elif sub=='minimap':
  setting_row(e,'opacity','미니맵 전체 투명도','30%',336,'0~90% / 기본30%');setting_row(e,'faces','미니맵 표시','얼굴',504,'얼굴 / 점 · 기본 얼굴');setting_row(e,'names','이름 표시','켜짐',672,'켜짐 / 꺼짐 · 기본 켜짐')
 elif sub=='controls':
  setting_row(e,'joystick','조이스틱 방식','고정',336,'고정 / 플로팅');setting_row(e,'size','버튼 크기','100%',504,'100~120% · 5% 간격');setting_row(e,'opacity','버튼 투명도','0%',672,'0~50% · 5% 간격')
 elif sub=='debug':
  setting_row(e,'ranges','타격·피격 범위 표시','꺼짐',360,'타격 빨강 · 피격 파랑 / 다시 실행하면 꺼져요.');e.append(t('DEBUG / note','임시 디버깅 값은 기기·계정에 저장하지 않아요.',440,560,1320,28,'muted'))
 elif group=='notifications':
  e.extend([r('NOTIFY / panel',408,256,1416,560,'panel',.96,16),t('NOTIFY / title','알림 설정 준비 중',456,320,1320,42,'gold',weight='600'),t('NOTIFY / body','알림 종류·수신 조건·기기 권한은 미정입니다.\n이 시안에서 기기 알림 권한을 요청하지 않습니다.',456,432,1320,32,'muted'),b('NOTIFY / blocked','알림 허용 · 미정',456,648,1272,88,None,'disabled',32)])
 elif group=='account':
  e.extend([r('ACCOUNT / panel',408,256,1416,560,'panel',.96,16),t('ACCOUNT / title','계정 관리',456,320,1320,42,'gold',weight='600'),t('ACCOUNT / body','연결 상태·닉네임은 프로필 관리에서 확인해요.\n로그아웃 동작과 계정 운영 조건은 아직 정하지 않았어요.',456,432,1320,30,'muted'),b('ACCOUNT / profile','프로필 관리',456,648,600,88,'profile-info','default',30),b('ACCOUNT / status','연결 상태',1088,648,640,88,'profile-info','default',30)])
 else:
  e.extend([r('INFO / panel',408,256,1416,560,'panel',.96,16),t('INFO / title','FOREST ARENA',456,320,1320,48,'gold',weight='700'),t('INFO / body','게임 정보·버전·이용 안내를 표시하는 영역입니다.\n현재 버전 표시와 외부 링크는 연결 전입니다.',456,432,1320,32,'muted'),b('INFO / exit','게임 종료',456,648,1272,88,'settings-exit','default',32)])
 add(s)
# Dirty sound is the representative edit/apply/cancel/discard prototype.
origin=next(s for s in scenes if s['key']=='settings-sound-dirty')
for x in origin['elements']:
 if x['name']=='BACK':x['dest']='settings-discard-entry'
 elif x['name'].startswith('TAB /') and x.get('dest'):x['dest']='settings-discard-'+x['name'].split(' / ')[1]
for suffix,dest in [('entry','life-entry'),('profile','settings-profile'),('view','settings-effects'),('notifications','settings-notifications'),('account','settings-account'),('info','settings-info')]:
 s=copy.deepcopy(origin);s.update(key='settings-discard-'+suffix,name='MENU09 / Life-r01 / settings-discard-'+suffix,clone_of='settings-sound-dirty',modal=True)
 for x in s['elements']:
  if x['kind']=='button':x['dest']=None
 s['elements'].extend([r('MODAL / scrim',0,0,1920,1080,'bg',.86,0),r('MODAL / panel',400,288,1120,504,'panel',1,20),t('MODAL / title','변경 사항을 버릴까요?',448,352,1024,44,weight='700'),t('MODAL / body','적용하지 않은 설정 값이 있어요.\n변경을 버리면 원래 값으로 돌아가요.',448,456,1024,32,'muted'),b('MODAL / cancel','계속 편집',448,656,496,88,'settings-sound-dirty','default',30),b('MODAL / discard','변경 버리기',976,656,496,88,dest,'primary',30)]);add(s)
for k,ttl,body,block in [('settings-values','설정 값 조절 안내','분류에 표시된 선택 값과 범위를 검토해 주세요.\n이 시안의 대표 값 변경은 배경 음악60%→65%입니다.\n다른 값의 연속 조절·저장은 실제 개발 뒤 확인합니다.',None),('settings-defaults','기본값 복원 확인','소리60/80%, 음소거 꺼짐, 진동 켜짐\n미니맵 얼굴·이름 켜짐·투명30%, 조작 고정100/0%\n분류별 복원을 검토하는 시안이며 실제 값은 바꾸지 않습니다.',None),('profile-info','프로필 관리 연결','프로필에서 닉네임과 연결 상태를 확인하는 동선입니다.\n현재 시안은 계정 연결과 개인 정보를 입력하지 않습니다.',None),('settings-logout','로그아웃 확인','로그아웃 동작과 계정 운영 조건은 미정입니다.\n이 시안에서 실제 계정의 로그인을 해제하지 않습니다.','로그아웃 · 미정'),('settings-exit','게임 종료 확인','게임 종료 확인 화면의 배치와 닫기를 검토해요.\n이 시안에서 앱이나 브라우저를 닫지 않습니다.','게임 종료 · 시안')]:overlay(k,ttl,body,block)
# Empty/error states are distinct from successful persistence or relationship changes.
for key,title,body,returnto,canon in [('friends-empty','친구가 없어요','정확한 닉네임으로 친구를 찾아보세요.','friends','SCR_22_Social'),('friends-no-result','검색 결과가 없어요','입력한 닉네임을 다시 확인해 주세요.','friends-query','SCR_22_Social'),('friends-error','친구 목록을 불러오지 못했어요','연결 실패를 친구 없음과 구분해 표시해요.\n마지막 확인 정보는 예시이며 접속 상태를 보장하지 않아요.','friends','SCR_22_Social'),('mailbox-empty','우편함이 비어 있어요','실제 우편·보상 조건은 아직 정하지 않았어요.','mailbox','EXT_MENU09_Mailbox'),('mailbox-error','우편함을 불러오지 못했어요','조회 실패는 우편 없음과 구분해 표시해요.','mailbox','EXT_MENU09_Mailbox'),('notices-error','공지를 불러오지 못했어요','잠시 후 다시 시도해 주세요.','notices','EXT_MENU09_Notices'),('settings-save-error','설정을 저장하지 못했어요','변경 전 값은 유지돼요. 다시 시도하거나 편집을 계속하세요.','settings-sound-dirty','EXT_06_GeneralSettings')]:
 s=base(key,title,canon);e=s['elements'];e.extend([r('STATE / panel',96,256,1728,576,'panel',.96,16),t('STATE / title',title,144,320,1632,44,'gold',weight='600'),t('STATE / body',body,144,440,1632,32,'muted'),b('STATE / retry','편집으로 돌아가기' if key=='settings-save-error' else '다시 시도' if 'error' in key else '돌아가기',144,672,1632,88,returnto,'primary',32)]);add(s)
# Loading is a full state with no active background controls.
s=copy.deepcopy(next(s for s in scenes if s['key']=='friends'));s.update(key='friends-loading',name='MENU09 / Life-r01 / friends-loading',clone_of='friends',modal=True)
for x in s['elements']:
 if x['kind']=='button':x['dest']=None
s['elements'].extend([r('MODAL / scrim',0,0,1920,1080,'bg',.86,0),r('MODAL / panel',464,336,992,416,'panel',1,20),t('MODAL / title','친구 목록을 불러오는 중',512,392,896,40,weight='600'),t('MODAL / body','로딩 상태 예시 · 실제 조회를 호출하지 않아요.',512,488,896,28,'muted'),b('MODAL / close','검토 닫기',512,616,896,80,'friends','primary',30)]);add(s)
s=copy.deepcopy(next(s for s in old['scenes'] if s['key']=='lobby'));s.update(key='life-entry',name='MENU09 / Life-r01 / life-entry',revision='life-r01')
for x in s['elements']:
 if x['kind']=='button':x['dest']={'NAV / 친구':'friends','NOTICE':'notices','MAIL':'mailbox','SETTINGS':'settings-profile'}.get(x['name'],'life-entry-pending')
add(s);overlay('life-entry-pending','다른 메뉴 안내','다른 메뉴는 기존 승인 영역과 후속 묶음에서 검토해요.')
s=base('life-handoff','생활 메뉴 · 검토 안내','EXT_MENU09_Handoff');e=s['elements'];e.extend([t('GUIDE / title','life-r01 · 친구·우편함·공지사항·설정',96,208,1728,42,'gold',weight='600'),t('GUIDE / body','참조18·14·01·11 대응 · 기존 친구/설정 기능 소비\n우편·공지·알림·로그아웃 운영 조건은 미정\n1920×1080 / 8px / 여백96·48 / 터치72 이상\n실제 Android·서버·저장·보상 지급은 별도입니다.',96,296,1728,30,'muted')])
for i,(key,label) in enumerate([('friends','친구'),('mailbox','우편함'),('notices','공지사항'),('settings-profile','설정'),('friends-empty','친구 없음'),('friends-no-result','검색 없음'),('friends-error','친구 오류'),('mailbox-empty','빈 우편함'),('notices-error','공지 오류'),('settings-save-error','저장 실패'),('friends-loading','로딩'),('settings-sound-dirty','설정 변경'),('friends-invites','받은 초대'),('friends-invites-busy','대전 중 초대'),('mailbox-selected-7','다중 선택'),('mailbox-error','우편 오류')]):e.append(b('GUIDE / '+key,label,96+i%4*440,568+i//4*104,408,80,key,'primary' if i==0 else 'default',28))
e.append(t('GUIDE / assets','MISSING ASSETS · 새 필수 이미지 없음 / 기존 배경·기본 요소 재사용',96,1000,1728,22,'muted'));add(s)
for key in ['friends','mailbox','notices','settings-profile']:
 s=copy.deepcopy(next(s for s in scenes if s['key']==key));s.update(key=key+'-wide',name='MENU09 / Life-r01 / '+key+'-wide',comparison_of=key,w=2400)
 for x in s['elements']:
  if x['name'] in ['IMG / character-room','ATMOSPHERE','HEADER','FOOTER']:x['w']=2400
  else:x['x']+=240
  if x['kind']=='button':x['dest']=None
 add(s)
# Reuse compatible pending layouts while preserving approved sources.
for s in scenes:
 k=s['key']
 if s.get('overlay') and k!='friends-input':s['clone_of']='friends-input'
 elif k.startswith('friends-') and not s.get('modal') and not s.get('comparison_of') and k not in ['friends-empty','friends-no-result','friends-error']:s['clone_of']='friends'
 elif k in ['notices-second','notices-events','notices-past']:s['clone_of']='notices'
 elif k in ['settings-sound-dirty','settings-sound-applied']:s['clone_of']='settings-sound'
 elif k in ['settings-accessibility','settings-minimap','settings-controls','settings-debug']:s['clone_of']='settings-effects'
 elif k in ['friends-no-result','friends-error','mailbox-empty','mailbox-error','notices-error','settings-save-error']:s['clone_of']='friends-empty'
for scene in scenes:
 for e in scene['elements']:
  if e.get('dest')==scene['key']:e['dest']=None
j=dict(revision='life-r01',colors=old['colors'],base_keys=['friends','mailbox','notices','settings-profile'],missing_assets=[],runtime_approved=False,scenes=scenes)
(P/'scene-spec.json').write_text(json.dumps(j,ensure_ascii=False,indent=2)+'\n');print('boards',len(scenes))
