"""Static scene geometry/text-width audit. PNG/Penpot validation is recorded separately."""
import json, math
from pathlib import Path
from PIL import ImageFont
TASK=Path(__file__).resolve().parent
p=json.loads((TASK/'scene-spec.json').read_text());errors=[];warnings=[]
fontroot=Path.home()/'Library/Fonts';fonts={}
for scene in p['scenes']:
 for e in scene['elements']:
  tag=scene['name']+' / '+e['name']
  if min(e['w'],e['h'])<=0:errors.append([tag,'nonpositive size'])
  if e['x']<0 or e['y']<0 or e['x']+e['w']>1920.01 or e['y']+e['h']>1080.01:errors.append([tag,'outside frame',e['x'],e['y'],e['w'],e['h']])
  if e['kind'] in ['button','hotspot'] and min(e['w'],e['h'])<72:errors.append([tag,'touch smaller than72'])
  if e['kind']=='text':
   ft='Bold' if int(e.get('weight',500))>=700 else 'Regular';k=(ft,e['size'])
   if k not in fonts:fonts[k]=ImageFont.truetype(str(fontroot/f'NotoSansCJKkr-{ft}.otf'),e['size'])
   f=fonts[k]
   for line in e['text'].splitlines():
    length=f.getlength(line)
    if length>e['w']+1:errors.append([tag,'line too wide',round(length,1),e['w'],line])
   if e['y']+e['h']>1032.1:errors.append([tag,'text below safe margin',e['y']+e['h']])
   if e['x']<96 or e['x']+e['w']>1824.1:errors.append([tag,'text outside horizontal safe area'])
  if e.get('dest') and e['dest'] not in set(s['name'] for s in p['scenes'])|set(p['externalDestinations']):errors.append([tag,'unresolved destination',e['dest']])
# Ignore obscured source layers below the modal scrim; compare visible native text boxes.
for scene in p['scenes']:
 es=scene['elements'];start=next((i for i,e in enumerate(es) if e['name']=='MODAL / scrim'),0);es=es[start:]
 ts=[e for e in es if e['kind']=='text'];bs=[e for e in es if e['kind']=='button']
 for i,a in enumerate(ts):
  for b in ts[i+1:]+bs:
   ix=min(a['x']+a['w'],b['x']+b['w'])-max(a['x'],b['x']);iy=min(a['y']+a['h'],b['y']+b['h'])-max(a['y'],b['y'])
   if ix>2 and iy>2:errors.append([scene['name'],'visible text box overlaps text/button',a['name'],b['name'],ix,iy])
# Behavior-level invariants for selection, category retention, and empty preset validation.
byname={s['name']:s for s in p['scenes']}
for scene in p['scenes']:
 name=scene['name']
 if name=='SCR_05_CharacterDetail' or name.startswith('MENU08 / SCR_05_CharacterDetail / '):
  hero=next(e['key'] for e in scene['elements'] if e['kind']=='image' and e['x']==264 and e['w']==856)
  action=next(e for e in scene['elements'] if e['name']=='BUTTON / 편성에 넣기');target=byname[action['dest']]
  if target.get('selection',{}).get('character')!=hero:errors.append([name,'selected character lost on preset action'])
 if '-filter-' in name and any(v in name for v in ['SCR_06_AccessoryCollection','SCR_07_AccessoryDetail']):
  category=name.split('-filter-',1)[1]
  if category!='전체':
   names={'이동':{'균형 장신구','도약 장갑','활공 장신구'},'방어':{'철갑옷'},'기술':{'복싱 글러브','집중 장신구'}}[category]
   for e in scene['elements']:
    if e['kind']=='hotspot' and e['name'].startswith('SELECT / '):
     if e['name'].split('SELECT / ',1)[1] not in names:errors.append([name,'item outside category',e['name']])
     if not e['dest'].endswith('-filter-'+category):errors.append([name,'category lost on item click'])
    if e['name']=='BUTTON / 상세 · 비교' or ('SCR_07_AccessoryDetail' in name and e['name']=='BUTTON / 뒤로'):
     if not e['dest'].endswith('-filter-'+category):errors.append([name,'category lost on detail/back'])
 if scene.get('selection') and name.startswith('MENU08 / SCR_08_Preset / '):
  selected=scene['selection']['character']
  for e in scene['elements']:
   if e.get('dest') in byname and (e['name'] in ['BUTTON / 취소','BUTTON / 저장','BUTTON / 편성 적용','BUTTON / 저장 확인','BUTTON / 적용 확인','BUTTON / 뒤로','SELECT / 편성 1']):
    target=byname[e['dest']]
    if target.get('selection') and target['selection']['character']!=selected:errors.append([name,'character changed across save/apply/cancel/back',e['name']])
for i in [1,2,3]:
 name='MENU08 / SCR_08_Preset / slot-'+str(i)
 for e in byname[name]['elements']:
  if e['name'] in ['BUTTON / 저장','BUTTON / 편성 적용'] and e.get('dest')!='MENU08 / SelectionRequired':errors.append([name,'empty preset signals success'])

# Settings examples must preserve the applied values and restore the actual runtime defaults.
# Category combinations are outside this finite prototype; each category round-trip is checked.
settingsBase='EXT_06_GeneralSettings'
def sn(tag):return 'MENU08 / '+settingsBase+' / '+tag
def visible_action(scene,label):
 es=scene['elements'];start=max((i for i,e in enumerate(es) if e['name']=='MODAL / scrim'),default=-1)
 return next(e for i,e in enumerate(es) if i>start and e['name']=='BUTTON / '+label)
def follow(scene,label):return byname[visible_action(scene,label)['dest']]
def expect(scene,values,what):
 if scene.get('settingsState',{}).get('values')!=values:errors.append([scene['name'],what,scene.get('settingsState',{}).get('values'),values])
settingCases=[('소리','소리',{'music':40,'effects':40,'muted':True},{'music':60,'effects':80,'muted':False}),('화면 효과','화면 효과',{'reduce_visual_effects':True},{'reduce_visual_effects':False}),('접근성','접근성',{'text_scale':1.15,'haptics_enabled':False},{'text_scale':1.0,'haptics_enabled':True}),('미니맵','미니맵',{'transparency':50,'marker_style':'dot','show_names':False},{'transparency':30,'marker_style':'face','show_names':True}),('접근성-large','접근성',{'text_scale':1.3,'haptics_enabled':False},{'text_scale':1.0,'haptics_enabled':True})]
for tag,tab,changed,defaults in settingCases:
 dirty=byname[sn('접근성-large' if tag=='접근성-large' else tab+'-off')]
 applied=follow(dirty,'적용');saved=follow(applied,'닫기')
 expect(applied,changed,'applied overlay lost changed settings');expect(saved,changed,'closing applied overlay lost saved settings')
 if saved.get('settingsState',{}).get('stage')!='saved':errors.append([saved['name'],'applied result is still dirty'])
 reset=follow(saved,'기본값 복원');expect(follow(reset,'취소'),changed,'cancel reset lost applied settings')
 restored=follow(reset,'기본값 복원');expect(restored,defaults,'restore does not match runtime defaults')
 if restored.get('settingsState',{}).get('savedValues')!=changed:errors.append([restored['name'],'restored draft forgot previous saved values'])
 discard=follow(restored,'취소');expect(follow(discard,'취소'),defaults,'cancel discard did not keep restored draft');expect(follow(discard,'변경 버리기'),changed,'discard did not return previous saved settings')
 defaultApplied=follow(restored,'적용');defaultSaved=follow(defaultApplied,'닫기');expect(defaultSaved,defaults,'applying restored defaults lost defaults')
for tab in ['소리','미니맵']:
 for kind,baselineTag in [('default-draft-from-initial-',None),('changed-from-default-','default-saved-')]:
  scene=byname[sn(kind+tab)];expected=byname[(settingsBase if tab=='소리' else sn(tab)) if baselineTag is None else sn(baselineTag+tab)]
  if follow(follow(scene,'취소'),'변경 버리기')['name']!=expected['name']:errors.append([scene['name'],'draft cancel lost its own saved baseline'])
large=byname[sn('접근성-large')]
if follow(follow(large,'취소'),'변경 버리기')['name']!=sn('접근성'):errors.append([large['name'],'maximum text draft cancel lost saved accessibility'])
for floating,info,reset,fixed in [('MENU08 / ControlsFloatingFromLobby','MENU08 / ControlsParametersFloatingLobby','MENU08 / SettingsResetFloatingLobby','MENU08 / ControlsFromLobby'),('MENU08 / CBT_08_Settings / floating','MENU08 / ControlsParametersFloating','MENU08 / SettingsResetFloating','CBT_08_Settings')]:
 for label in ['취소','확인']:
  if follow(byname[info],label)['name']!=floating:errors.append([info,'floating info lost source on '+label])
 if follow(byname[reset],'취소')['name']!=floating:errors.append([reset,'floating reset cancel lost source'])
 if follow(byname[reset],'복원')['name']!=fixed:errors.append([reset,'restore did not return fixed defaults'])
nickname=byname['MENU08 / NicknameEdit'];nicknameResult=follow(nickname,'변경 확인');nicknameProfile=follow(nicknameResult,'프로필로')
if not any(e['name']=='INPUT / value' and e['text']=='숲빛 여행자' for e in nickname['elements']):errors.append(['NicknameEdit','missing editable input example'])
if not any(e['name']=='PROFILE / name' and e['text']=='숲빛 여행자' for e in nicknameProfile['elements']):errors.append(['NicknameEdit','confirmation did not show changed nickname'])

report={'scope' :'static geometry and representative behavior; not a PNG/Penpot visual pass','base':len(p['base']),'scenes':len(p['scenes']),'legacyMapping':len(p['legacyMapping']),'errors':errors,'warnings':warnings}
(TASK/'geometry-audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2));print(json.dumps(report,ensure_ascii=False,indent=2));raise SystemExit(bool(errors))
