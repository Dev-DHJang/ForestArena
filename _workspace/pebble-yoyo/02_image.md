# 이미지 제작

내장 image_gen으로 원본 대표 이미지와 동일 외형의 전투 본체 파생본을 제작했다. 대표는 조약돌 회색 원반2개·나무 축·상아색 실·작은 민트 문양이며 전투 본체는 돌출 실을 제거했다. 제3자 참고 이미지·상표·작가 스타일을 사용하지 않았다.

원본: `assets/accessory/pebble-yoyo/source/`. 생성 원본은 보존하고 .gdignore로 중복 가져오기를 막는다. runtime 이미지는 전체 균일 축소·투명 캔버스 배치만 적용했다. 대표1024×1024와 전투128×128은 `forest_arena/assets/common/accessory/` 아래이며 논리 ID2개를 사용한다. manifest에 원본·파생 파일의 해시와 생성·권리 근거를 남겼다. 정적 이미지 독립 QA는 `03_qa_image_r01.md`다.

생성 요청: `stylized-concept`, Forest Arena original pebble yo-yo; smooth gray river-pebble twin discs, warm wooden axle, narrow mint inlay, short ivory loop, hand-painted clean nonpixel fantasy mobile art, isolated transparent square, no hands/characters/text/rarity. 전투 편집은 `precise-object-edit`; 같은 요요 외형을 유지하고 느슨한 실·손가락 고리만 제거, 축 안에 감긴 실은 유지한다.

캐릭터 모션 최종 프롬프트는 `motion-prompts.json`에 원문을 보존한다. 승인된 각 캐릭터 reference/v01의 combat.png·side.png를 실제 생성 입력에 직접 첨부했고 candidate.json에 첨부 해시와 참조 버전을 남겼다. 대표 세트 검사2개가 통과했다. r01의 잘림·가로 출력은 미채택으로 보존하고 r02는16개 전신과 여백을 확인했다.
