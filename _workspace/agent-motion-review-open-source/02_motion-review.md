# 전체 모션 행위 검토 결과

- 대상: 현재 원본 작업 폴더의 승인 캐릭터120종·1,920프레임. 원본 파일 해시는 `01_source_snapshot.json`에 고정했다.
- 방법: 캐릭터별 전체 프레임 비교판, 실제 표현 코드의60Hz 기록, 정상·0.25배·좌우 반전·절반 표시를 확인했다. 비반복2초 유지·반복 모션2완전주기와 점프 속도는 합성 검토 조건으로 실제 경기 수명·물리 기기 검증과 구분한다.
- 결과: pass92·fix22·redo6. 이는 현 자산의 결과이며 수정 시안의 승인이나 게임 적용 완료를 뜻하지 않는다.
- 재생: `review/index.html`; 기존 프레임 재생 수정 시안13종: `drafts/sequence-proposals.html`.

| 캐릭터/모션 | 결과 | 문제 |
| --- | --- | --- |
| ja-hyun/attack_heavy_charge | redo | 준비 유지와 방향별 해제 공격이 같은 visual_state_id를 사용한다. 현재 공용 시트만으로 위·아래·옆 타격과 힘모으기를 모두 정확히 표현하지 못한다. |
| ja-hyun/jump | fix | 하강 중 바닥 착지 자세를 유지한다. |
| myo-ryung/attack_heavy_charge | redo | 준비 유지와 방향별 해제 공격이 같은 visual_state_id를 사용한다. 현재 공용 시트만으로 위·아래·옆 타격과 힘모으기를 모두 정확히 표현하지 못한다. |
| myo-ryung/attack_light_combo_01 | fix | 뻗은 앞손은 준비2–5에 있고 적중6·7·9·10에는 손을 회수하거나 대기하여 판정과 손 타격 표현이 어긋난다. |
| myo-ryung/guard | fix | 방어 후반에 앞팔을 내려 일반 대기로 돌아오며 실제 정지16에서 얼굴·몸 앞을 막지 않는다. |
| myo-ryung/jump | fix | 바닥에 양발을 딛고 무릎을 압축한 착지 자세13이 runtime descent 단계에서 약183ms 동안 표시된다. |
| myo-ryung/run | fix | 달리기 루프 마지막4장이 양발을 바닥에 두고 선 대기 자세여서 runtime 매 반복에 약333ms의 멈춤 구간이 생긴다. |
| myo-ryung/special_neutral | fix | 세 차례의 킥 중 첫 타3은 준비, 마지막 타11은 회복에 놓이고 적중6–10은 한 차례 킥만 완성해 연속 킥과 실제 적중 구간이 어긋난다. |
| myo-ryung/ultimate | fix | 포획 띄우기→연속 킥→하강 마무리의 구분이 약하며 하강 마무리 후보11–13이 runtime 회복에 놓인다. |
| nabi/attack_heavy_charge | redo | 준비 유지와 방향별 해제 공격이 같은 visual_state_id를 사용한다. 현재 공용 시트만으로 위·아래·옆 타격과 힘모으기를 모두 정확히 표현하지 못한다. |
| nabi/guard | fix | 방어가 계속되는 상태인데 후반에 손을 내리고 마지막 대기 자세를 고정한다. |
| nabi/hitstun | fix | 맞은 직후 약150ms 동안 정상 대기와 유사하여 최소10tick 경직의 대부분에서 피격이 읽히지 않는다. |
| nabi/jump | fix | 하강 구간이 두 발을 디딘 지상 쪼그림 프레임을 약 183ms 표시한다. |
| nabi/run | fix | 두 차례 뻗기에서 동일한 앞발이 선행하여 반대발 전진과 지지발 교대가 식별되지 않는다. |
| nabi/special_down | redo | 원문은 후퇴 뒤 전진 가드 레이크인데 그림에는 후퇴 체중 이동이 분명하지 않고 구현 데이터도 중립 호환이어서 기준 차이가 있다. |
| nabi/ultimate | fix | 계약의 교차 발톱 연타 뒤 큰 날리기가 한 번의 도약 찌르기와 나란한 양팔 뻗기로 표현되어 순서를 식별하기 어렵다. |
| yu-ran/attack_heavy_charge | redo | 준비 유지와 방향별 해제 공격이 같은 visual_state_id를 사용한다. 현재 공용 시트만으로 위·아래·옆 타격과 힘모으기를 모두 정확히 표현하지 못한다. |
| yu-ran/attack_heavy_up | fix | 위 강공격의 주된 동작이 무릎 상승이며 계약의 꼬리 띄우기가 보이지 않는다. |
| yu-ran/attack_light_combo_02 | fix | 계약은 짧은 꼬리 옆 견제이나 활성 자세는 손을 뻗고 꼬리가 뒤에 머문다. |
| yu-ran/attack_light_combo_03 | fix | 마지막 활성12가 꼬리를 거둔 낮은 회복 자세라 넓은 꼬리 쓸기의 적중 단계와 어긋난다. |
| yu-ran/attack_light_down | fix | 낮은 손 공격이며 계약의 low tail check가 보이지 않는다. |
| yu-ran/attack_light_up | fix | 위로 올린 부위가 앞손이고 꼬리가 뒤에 고정되어 rising tail check와 다르다. |
| yu-ran/jump | fix | 하강 끝13이 두 발을 벌려 몸을 받는 착지 준비/압축으로 보여 공중 하강과 착지가 구분되지 않는다. |
| yu-ran/run | fix | 양쪽 반주기의 긴 보폭에서 같은 앞발·뒷발 배치가 반복되어 좌우 지지발 교대가 명확하지 않다. |
| yu-ran/special_down | fix | 활성 끝9~10에 낮은 꼬리 쓸기 대신 꼬리 회수와 손 모으기가 나온다. |
| yu-ran/special_side | redo | docs/contracts/attack-system-v01.json은 mist-path tail rush를 요구하지만 현재 moveset의 special_side에는 자기 이동이 없고 combat.md는 중립 호환 기술로 명시한다. 그림만 바꿔 돌진이라고 통과시킬 수 없다. |
| yu-ran/special_up | fix | 상승 주먹/무릎 자세가 반복되어 spiral tail vault의 꼬리 나선 도약이 읽히지 않는다. |
| yu-ran/ultimate | fix | 준비 뒤 단일 수평 꼬리 쓸기로 보여 ringed-tail vortex→forward finish의 두 단계가 구별되지 않는다. |
