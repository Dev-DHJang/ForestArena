# 전투 구현 기록 — 묶음 G

- LoadoutBuilder는 캐릭터 기본값 뒤 부모 직업·현재 직업·장신구를 차례로 적용한다.
- MatchController는 의미 이벤트만 발행하고 ArenaVisual은 화면 번쩍임처럼 표현만 소비한다. 프레임·애니메이션은 적중 시간이나 승패를 바꾸지 않는다.
- Hurtbox, Hitbox, Pushbox를 구분한다. GrabBox·투사체 영역은 실제 기능이 추가될 때 같은 경계로 확장한다.
- Android debug APK export와 패키지 계약 검증은 통과했으며, 연결된 에뮬레이터가 없어 런타임 터치·중단/복귀 검사는 미확인이다.
