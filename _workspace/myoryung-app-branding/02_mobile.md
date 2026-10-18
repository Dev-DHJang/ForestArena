# Android 앱 브랜딩 적용

프로젝트 앱 아이콘은새1024PNG, Android일반아이콘은192PNG, 적응형전경과배경은각각별도432PNG에연결했다. 프로젝트부트화면의show_image=false, minimum_display_time=0을명시했다. 기존게임시작장면과로비는유지한다.

앱아이콘은운영체제및Godot부트시점에Autoload보다먼저읽는설정자산이다. 기존app_icon.svg와같이ProjectSettings와Androidexport가직접참조하며런타임리소스카탈로그ID를추가하지않는다. 기존SVG는복구용으로그대로보존했다. 공개API·스키마·저장경로·게임규칙변경은없다.

Android12이상의운영체제시작화면은엔진부트로고와다르다. Godot가내보낸drawable/splash_icon.webp가새묘령전경인지확인하고Godot로고로되돌아가지않는지검사한다. 생성되는android/build테마는직접수정하지않는다.

현재ADB와무선서비스검색에기기가없다. APK빌드·패키지검사는실기기설치·시작영상검사를대신하지않는다. 연결되면홈아이콘과완전종료후3회실행, 재실행과홈이동후복귀를영상·로그로기록한다.

APK의 `project.binary`를 별도 폴더로 추출하고 Godot MainLoop에서 실제 설정을 읽었다. `show_image=false`, 지연0, 기존 `local_ai_app.tscn` 시작 장면과 새1024아이콘 경로가 확인됐다. Android의 `splash_icon.webp`도 새 묘령이며 하단 branding 이미지는 알파0의 완전 투명 파일이다. `branding-checks.json`에 실제 패키지 비교 결과를 남겼다.

WebP 변환에서 전경의 알파0–31인 가장자리 RGB는 일부 바뀌었다. 알파와 불투명한 얼굴 픽셀은 같고, 알파를 반영한 평균 채널 차이는255단계 중약0.0078이다. 따라서 픽셀 전체가 완전히 같다고 기록하지 않는다. 눈·입·귀와 작은 아이콘의 실질적 시각 결함은 독립 검토로 확인한다.
