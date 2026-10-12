# 실제 기기 소리·진동 수정

실패 APK 6b855d25…에서 두 기기 모두 배경음악을 듣지 못했고 타격음 적용이 불완전하며 진동이 없다고 사용자가 보고했다. 원본 feature 브랜치의 CombatAudio는 이전 절차식 짧은 tone 코드이며 승인된 음악 Autoload와 자산 연결이 없다. 최신 origin/develop에는 ForestArenaAudio, 47개 승인 음원과 이벤트 연결이 이미 통합되어 있다. 새 APK는 최신 개발 기반과 현재 승인 캐릭터·숲빛 UI를 함께 사용한다. 기존 실패 APK를 다른 버전의 음악 검사 통과로 덮어쓰지 않는다.

새 음원이나 승인 자산을 만들지 않았다. 음악은 Music, 버튼은 UI, 공격·적중은 Combat 버스와 기존 이벤트·우선순위·동시 재생 예산을 유지한다. 실제 상태가 바뀔 때 소리 연결을 사용하며 오디오가 피해·승패를 결정하지 않는다. 기존 오디오 검사에서 같은 입력의 음소거 전후 전투 해시가 같음을 확인한다.

실패 APK의 aapt permissions는 INTERNET만 있고 VIBRATE가 없다. Android Debug·Demo preset에 permissions/vibrate=true를 넣었고 패키지 검사는 VIBRATE를 요구한다. UI 역할은 MISS/IMMUNE에서는 진동 요청을 만들지 않고 유효 HIT/BLOCK 등에서만 기존 피드백을 호출한다. 새 APK의 실제 권한·출력과 사용자 체감 재검사는 아직 남아 있다.

오디오 설정도 debug QA 실행별 user://qa/<run>/audio.cfg에 분리한다. 일반 실행·release·잘못된 ID·중복 ID는 기존 경로를 사용한다. Android 네이티브 QA 인자의 debug 전용 제한과 Godot debug 확인을 함께 유지한다. 기존 플레이 설정을 테스트가 덮어쓰지 않는다.

ANDROID_AUDIO_STORE 자동 검사에서 정상 분리·일반 경로·release 비활성·경로 이동 문자열 및 중복 ID 거부를 확인했다. 기존 AUDIO_APP_FLOW와 PHASE6_AUDIO_CONTRACT는 독립 QA에서 통과했다. 이 결과를 두 기기의 실제 청취·진동 체감 통과로 확대하지 않는다.
