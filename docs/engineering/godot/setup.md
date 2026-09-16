# Forest Arena / Godot 4 설정

Godot 고유 이름이 낯설면 [용어 가이드](../../GLOSSARY.md#godot와-데이터-용어)를 참고한다.

설치 스크립트는 현재 프로젝트에 `res://forest_arena/`를 복사하고, 게임 시작 때 자동으로 준비되는 공용 객체(Autoload)로 `ForestArenaResources`를 등록한다.

품질 설정은 `high`, `medium`, `low`다. 전체 화면 배경·일러스트·효과 22개만 품질별로 나뉘며 UI·버튼·아이콘·캐릭터·장신구는 공통 고품질 자산이다.

경로가 아니라 논리 ID를 사용한다.

```gdscript
ForestArenaResources.set_quality("medium")
$TextureRect.texture = ForestArenaResources.load_texture("fa.background.bg.lobby.forest.town")
```

현재 시험용 전투도 같은 자산 찾기 규칙을 사용한다. 배경은 `fa.background.combat.training.arena`, 터치 조작은 `fa.ui.combat.*`, 전투 정보와 재시작 버튼은 기존 `fa.ui.panel.*`·`fa.ui.button.*` ID로 파일을 찾는다. 임시 이미지는 논리 ID를 유지한 채 승인된 최종 자산으로 교체한다.

카탈로그는 기존 `assets/character/`, `assets/ui/generated/`의 승인·소유권 경계를 바꾸지 않는다.
