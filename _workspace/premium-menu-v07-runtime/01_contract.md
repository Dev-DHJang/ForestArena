# 메뉴 런타임 공용 연결 약속 v1

## 범위와 역할

UI: scripts/premium_menu/premium_menu_theme.gd, premium_menu_view.gd, premium_menu_router.gd.
계약·터치: scripts/premium_menu/local_menu_state_store.gd, scripts/touch_command_source.gd 및 해당단위검사.
root: 자산·카탈로그, LocalAiApp 연결, 기존검사/Android 실행도구 통합.
QA: 독립화면·흐름검사와 검토기록. 서로 소유한 파일은 별도전달 전 수정하지 않는다.

## UI와 앱 연결

PremiumMenuRouter extends RefCounted. _init(app), open(menu_id:String, params:Dictionary={}), handle_back()->bool, reset()를 제공한다. state:Dictionary, view:Control, busy:bool을 공개한다. state.id는 character_collection, character_detail, accessory_collection, accessory_detail, preset, shop, collection, mission, social, rank, profile, settings, controls 중 하나다. params/state에 selected_id/filter/tab/category/scroll/entry_context를 보존한다.

앱은 menu_router, menu_store를 유지하며 _display_premium_view(view:Control, menu_id:String)로page와screen을갱신한다. shop은기존screen=shop, settings는기존screen=accessibility, 나머지는menu_id와같다. view에는menu_screen_id 공식설계ID metadata를넣는다. 기존 layer/page/store/catalog/db_mode/db_client/storage_busy/_change_profile/_show_home/_show_prepare/start_match/_text_scale은UI에서연결한다.

앱 _menu_owner_key()->String은기기모드device, DB모드는접속주소+player_id의SHA-256 기반db 키를반환한다. UI는 menu_store.load_presets(key,{character:store.data.selected_character,accessory:store.data.selected_accessory})를사용한다. 저장경로는app.save_path.get_base_dir()를따라 QA경로도분리한다.

UI의 선택·구매·닉네임·접근성·미니맵 저장은 await app._change_profile(action,payload)로처리한다. 기존purchase/<id> QA ID를유지하고 새조작에는안정적인menu/<menu>/<action> ID를붙인다. router.open은이전선택/탭/필터상태를보존한다. 상세뒤로는진입한목록으로돌아간다. 하위메뉴공통전체메뉴는13화면군진입을제공한다. 전환200ms·저장중중복입력차단 및모달최우선뒤로처리한다.

## 로컬 메뉴 저장

LocalMenuStateStore extends RefCounted. _init(base_dir:String='user://', catalog:LocalPlayCatalog=null). error:String, slots:Array[Dictionary](항상4), selected_slot:int, controls:Dictionary를제공한다.
load_presets(owner:String,current:Dictionary)->bool, save_slot(index:int,character:String,accessory:String)->bool, set_active_slot(index:int)->bool, load_controls()->bool, save_controls(next:Dictionary)->bool, static default_controls()->Dictionary를제공한다.

menu_presets_v01.json은schema_version1과owner별4슬롯/선택슬롯을저장한다. 처음owner는첫슬롯current/나머지{}로시작한다. 각슬롯은{} 또는{character,accessory}다. 기존LocalPlayerStore v3는변경하지않는다. 메뉴는적용직전보유및catalog유효성을검사하며 실제선택저장은기존select를사용한다.
menu_controls_v01.json은schema_version1과controls를저장한다. controls={joystick_mode:'fixed'|'floating',button_scale:1.0..1.2(0.05간격),button_transparency:0..50(5간격)}이며기본은fixed/1.0/0이다. 임시파일·백업으로저장하며실패시메모리기존값을유지한다. 알수없는필드/잘못된형식/버전은복구또는오류로분리한다.

TouchCommandSource.apply_menu_controls(settings:Dictionary)를추가한다. 기본값의기존위치·크기는변경하지않는다. 그림과입력영역을함께크기조정하고투명도는1-value/100이다. 플로팅은왼쪽예약영역의첫손가락으로시작하며안전영역을벗어나지않는다. 설정변경·초점상실·손가락해제에입력을정리한다. 전투명령·피해·승패는변경하지않는다.

## 자산 ID

배경: fa.ui.menu.v07.background.<파일key>, 아이콘: fa.ui.menu.v07.icon.<파일key>, 승인원화: fa.ui.menu.v07.character.<character-id>, 폰트: fa.font.menu.v07.noto_sans_kr.
원본6배경/16SVG/4approved-source PNG를바이트보존으로forest_arena/assets/ui/premium-menu-v07에등록한다. font는fonts 하위공식TTF/OFL을보관하며resource_path(logical_id)로해결한다. 일반메뉴자산은공통품질이며high/medium/low에서모두같은논리ID를검사한다. 기존승인/전투자산·ID는유지한다.

## 설정 적용

현재분류별초안/적용/취소/기본값복원. 소리기존음량·음소거, 화면효과reduce_visual_effects, 접근성text_scale/haptics, 미니맵기존3필드, 조작새기기설정이다. 분류이동시미적용변경버리기확인한다. 소리저장실패시메모리음량도원복한다. 전투일시정지진입context는pause로복귀하고전투음악/일시정지를유지한다. 프로필에닉네임편집을배치한다.
