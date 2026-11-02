# 조약돌 요요 정적 이미지 독립 검토

결과: 정적 이미지 `pass`. 실제 대전 재생·Android 검사는 포함하지 않는다.

- 대표 원본과 전투 본체 원본, 전투용128px 출력을 직접 열어 확인했다. 회색의 둥근 돌 원반 두 장 사이에 나무 축이 보이고, 대표 이미지에는 상아색 실 고리가 있어 요요임을 구분할 수 있다.
- 얇은 민트 무늬와 돌 재질은 두 이미지에서 동일하다. 전투 본체에서 느슨한 실 고리만 제거되어 동적 실과 겹칠 요소가 없다. 인물·텍스트·상표·별·등급 장식은 없다.
- 원본 두 장은1254×1254 RGBA이며 알파 범위0~255다. 등록용 대표는1024×1024, 전투용은128×128 RGBA다. 눈에 띄는 잘림·검은 사각 배경·외곽 누락은 없다.
- 생성 방법·권리 근거와 등록 파일 해시는 자산 manifest의 해당 기록과 맞는다. 직접 생성된 독창적 디자인으로 보이며 외부 원본을 참조했다는 증거는 없다.
- 전투용128px에서 두 돌 원반과 나무 축의 큰 형태가 유지된다. 실제28px 표시·좌우·회전 중 가독성은 게임 재생 검토가 필요하다.

## 검토 대상 SHA-256

```json
{
  "assets/accessory/pebble-yoyo/source/representative.png": "a52142006433d83152671549ef40557f25518675a4a51164c86a51c80830857a",
  "assets/accessory/pebble-yoyo/source/combat-body.png": "b2764e01785387f1e78caf3aaca8d3e588c7604c0c5f54450e6d8ddbcee6d836",
  "forest_arena/assets/common/accessory/pebble_yoyo.png": "1772edcaf3a177377d821bcba66b1907fe954f564f32320fed9da4c5833eb0a4",
  "forest_arena/assets/common/accessory/pebble_yoyo_combat.png": "2b1277d0e979513421f3c1513db3b4a4ba7ce02e2005e5f89bd5d16d7d1235bd"
}
```
