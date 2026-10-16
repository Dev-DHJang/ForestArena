# 타이틀 배경 제작

- 내장 image_gen으로 캐릭터 없는 밝은 판타지 숲 배경을 제작했다.
- 나무·돌 발판·햇빛·민트/금빛으로 기존 숲 분위기를 이어간다. UI 글자나 로고를 그림에 넣지 않았다.
- 원본: `assets/ui/title-v01/title-forest-source.png`. 프롬프트·출처·원본/변형 SHA-256은 같은 폴더 `manifest.json`.
- 논리 ID: `fa.background.title.forest`. high1920×1080·medium1280×720·low960×540. 기존 승인 배경은 보존한다.
- 눈으로 원본을 확인했다. 인물·동물·글자 없음, 상단 중앙 로고와 어두운 하단 문구 공간 확보. 실제 UI 가독성은 통합 화면에서 추가 확인한다.

- 기존에 없던 `IMG/bg/splash` 설계 전달 파일 `assets/ui/generated/background/bg_splash_forest.png`도 생성했다. 실제 게임은 논리 ID의 품질별 파일을 사용하며 원본·설계 전달 복사본은 APK에서 제외한다.
