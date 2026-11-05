# 누락 자산 추림 완료

2026-11-05. 승인된21종 MENU09 UI의 누락 합집합29개를 이미지7·영상22로 분류했다. 개별 슬롯·현재 표시명·비율·현재 사용 여부·후보 경로·다음 확인은asset-backlog.csv/json과02_assets.md에 기록했다.

이미지는 신기6종과 실버3 문양1종이다. 현재 승인 UI의 표시명인 철갑옷·복싱 글러브·균형 신기·도약 장갑·집중 신기·활공 신기를 사용하고 옛 내부 ID의 뜻으로 외형이나 기능을 발명하지 않았다.6종은 현재 경기 비활성이다.

기존 rank_silver.png와 fa.rank.rank.silver 등록을 찾았으나 기존 CSV에는 rank-approval-required가 남아 있고 새실버3 슬롯과도다르다. 신규제작확정으로단정하지않고재사용검토후보1종으로분류했다. 이파일의존재로Penpot누락슬롯을교체하거나자산승인완료로바꾸지않았다.

영상은4캐릭터각5개로20종,철갑옷·조약돌요요소개2종이다. assets·forest_arena/assets에서MP4/WebM/MOV/M4V/GIF완성영상은없지만4캐릭터각5기술대응모션이미지와자현·나비요요사용모션파일은존재한다. 따라서완성영상공급누락과신규모션제작필요를구분했다. 최종모션연결·촬영범위·길이/인코딩과비활성콘텐츠소개는제작전확인대상이다. 개별모션승인·실제재생검증을새로수행한것은아니다.

29개중복제거·기존합집합일치·7/22분류·후보경로실재·CSV일치·문서링크를검사했다. 자산생성·이미지교체·Penpot수정·런타임등록·실제게임개발은없다. UI210단계나같은게임검사는반복하지않았다.

전용폴더 /Users/jdh/.codex/worktrees/menu-sketch-ui/ForestArena,브랜치codex/menu09-missing-assets,시작develop3b9a40c39515fd089ae3803adf8b83440c191e8c. 변경은_workspace/menu-sketch-ui/의목록·전달링크뿐이다. 실제PR·병합·되돌리기증적은아래에남긴다. Git통합커밋을revert하면목록변경을되돌릴수있으며기존누락29원본과승인UI는그대로다.

## 실제 통합 기록

- 목록·근거·검증 커밋은 `e81d0bdcabd35bfd21dc6be7996230f0a0b690c1`이다.
- [PR #141](https://github.com/Dev-DHJang/ForestArena/pull/141)을 develop에 병합했다. 실제 병합 커밋은 `0c75d88d878c99a1407d5887a719ab10486a6c34`다. 예상 head와 실제 head가 일치한 상태에서 통합했다.
- 되돌리기는 `git revert -m 1 0c75d88d878c99a1407d5887a719ab10486a6c34`로 목록·전달 링크 변경만 대상으로 한다. 자산·게임·Penpot 변경은 없다.
- 이 통합 증적만 codex/menu09-missing-assets-closeout에서 추가한다. 같은 UI·게임 검사는 반복하지 않는다.
