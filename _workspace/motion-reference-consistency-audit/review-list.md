# 모션 외형 차이 검토 목록

2026-10-29 등록본을 승인 대표 v01과 비교했다. **재작업은 아직 적용하지 않았다.**

전체 **122모션 / 2,000프레임**을 직접 비교했다. 검토 목록에 든 **87개 모션**에는 공통 색감 후보의 영향 범위도 포함된다. 독립된 관찰은 **30건**이며, 개별 중대 결함 개수와 같지 않다.

| 캐릭터 | 확인 모션 | 목록에 든 모션 | 원화 프레임 |
| --- | ---: | ---: | ---: |
| 자현 | 32 | 19 | 536 |
| 묘령 | 31 | 31 | 496 |
| 나비 | 29 | 7 | 488 |
| 유란 | 30 | 30 | 480 |

먼저 볼 차이는 자현 `attack_heavy_charge`의 투명하게 빠진 몸통·하의다. 크기·비율 후보는 대기 전후와 다시 대조하고, 공통 색감 후보는 목표 색조 선택부터 하는 편이 좋다.

[전체 비교·정상/느린 재생](index.html) · [CSV](review-list.csv) · [전체 122개 판정 JSON](motion-review.json) · [독립 관찰](qa-myo-yu.json)

## 읽는 방법

- **차이 확인**은 눈에 보이는 차이를 뜻하며 재작업 승인이 아니다. **추가 비교 후보**는 작은 차이 또는 포즈·원근·해상도 영향이 남는 항목이다.
- 프레임은 1부터 센다. 보드 상단은 승인4각도를 고정1/8로 표시하며 목표 게임 크기를 새로 정하지 않는다. RAW는 원화, DISPLAY는 실제 관측 배율·몸 기준점 적용이다. `*`는 타임라인에서 미선택된 원화로, 표시 위치는 추정이다.
- 영상은 실제 표시 변환과 목도리·손톱 효과 코드를 고정 검사 화면에서 재생한다. 60Hz 기록의2틱마다30FPS이며 앞뒤 대기 각0.5초, 좌우 반전과 원래 크기를 포함한다. 실제 경기·Android 결과나 모든 행위 표현의 통과 판정은 아니다.
- CSV/JSON 시간은 각 타임라인 변형에서 최초~최종 노출 구간이다. 반복·건너뛴 구간이 포함될 수 있다. 영상에서는 앞에0.5초가 더해지며 모든 변형을 순서대로 이어 붙인다.
- 웅크림·회전·원근·가려짐·귀/꼬리/천의 자연 움직임과 표정은 별도로 구분했다. 작은 눈·장식처럼 확정하지 못한 세부는 동일하다고 보증하지 않는다.

## 공통 색감 후보

묘령31개, 유란30개의 색감은 각각 한 건의 공통 관찰이다. 아래 개별 목록에도 영향 범위를 표시했으며 CSV에는 모션별 행이 있다. 색조·명암의 목표를 먼저 검토하고, 전 모션 재제작을 자동 결정하지 않는다.

- **묘령 31모션**: 전 프레임에서 의상의 분홍과 머리카락/피부의 붉은 명암이 승인 대표보다 더 진하고 포화돼 보인다. 대표의 옅은 흰색·분홍 재질보다 붉은 경계와 하이라이트 대비가 강하다. 동일 회색 배경의 고정1/8 기준과 RAW/DISPLAY를 직접 비교했다.
- **유란 30모션**: 대표보다 갈색·피부 음영이 약간 붉고 대비가 강해 보이는 공통 색감 후보다. 저해상도·안티앨리어싱 영향과 분리 확정하지 못했으며 뚜렷한 모델·표시 크기 위반으로 판정하지 않는다.

**묘령 영향 모션 전체**: [`idle`](boards/myo-ryung--idle.jpg), [`run`](boards/myo-ryung--run.jpg), [`jump`](boards/myo-ryung--jump.jpg), [`attack_light_combo_01`](boards/myo-ryung--attack_light_combo_01.jpg), [`attack_light_combo_02`](boards/myo-ryung--attack_light_combo_02.jpg), [`attack_light_combo_03`](boards/myo-ryung--attack_light_combo_03.jpg), [`attack_light_combo_04`](boards/myo-ryung--attack_light_combo_04.jpg), [`evade`](boards/myo-ryung--evade.jpg), [`guard`](boards/myo-ryung--guard.jpg), [`hitstun`](boards/myo-ryung--hitstun.jpg), [`launch`](boards/myo-ryung--launch.jpg), [`attack_heavy_charge`](boards/myo-ryung--attack_heavy_charge.jpg), [`death`](boards/myo-ryung--death.jpg), [`knock_down`](boards/myo-ryung--knock_down.jpg), [`ring_out`](boards/myo-ryung--ring_out.jpg), [`spawn`](boards/myo-ryung--spawn.jpg), [`wake_up`](boards/myo-ryung--wake_up.jpg), [`attack_air_heavy`](boards/myo-ryung--attack_air_heavy.jpg), [`attack_air_light`](boards/myo-ryung--attack_air_light.jpg), [`attack_dash_heavy`](boards/myo-ryung--attack_dash_heavy.jpg), [`attack_dash_light`](boards/myo-ryung--attack_dash_light.jpg), [`attack_heavy_down`](boards/myo-ryung--attack_heavy_down.jpg), [`attack_heavy_side`](boards/myo-ryung--attack_heavy_side.jpg), [`attack_heavy_up`](boards/myo-ryung--attack_heavy_up.jpg), [`attack_light_down`](boards/myo-ryung--attack_light_down.jpg), [`attack_light_up`](boards/myo-ryung--attack_light_up.jpg), [`special_down`](boards/myo-ryung--special_down.jpg), [`special_neutral`](boards/myo-ryung--special_neutral.jpg), [`special_side`](boards/myo-ryung--special_side.jpg), [`special_up`](boards/myo-ryung--special_up.jpg), [`ultimate`](boards/myo-ryung--ultimate.jpg)

**유란 영향 모션 전체**: [`idle`](boards/yu-ran--idle.jpg), [`run`](boards/yu-ran--run.jpg), [`jump`](boards/yu-ran--jump.jpg), [`attack_light_combo_01`](boards/yu-ran--attack_light_combo_01.jpg), [`attack_light_combo_02`](boards/yu-ran--attack_light_combo_02.jpg), [`attack_light_combo_03`](boards/yu-ran--attack_light_combo_03.jpg), [`evade`](boards/yu-ran--evade.jpg), [`guard`](boards/yu-ran--guard.jpg), [`hitstun`](boards/yu-ran--hitstun.jpg), [`launch`](boards/yu-ran--launch.jpg), [`attack_heavy_charge`](boards/yu-ran--attack_heavy_charge.jpg), [`death`](boards/yu-ran--death.jpg), [`knock_down`](boards/yu-ran--knock_down.jpg), [`ring_out`](boards/yu-ran--ring_out.jpg), [`spawn`](boards/yu-ran--spawn.jpg), [`wake_up`](boards/yu-ran--wake_up.jpg), [`attack_air_heavy`](boards/yu-ran--attack_air_heavy.jpg), [`attack_air_light`](boards/yu-ran--attack_air_light.jpg), [`attack_dash_heavy`](boards/yu-ran--attack_dash_heavy.jpg), [`attack_dash_light`](boards/yu-ran--attack_dash_light.jpg), [`attack_heavy_down`](boards/yu-ran--attack_heavy_down.jpg), [`attack_heavy_side`](boards/yu-ran--attack_heavy_side.jpg), [`attack_heavy_up`](boards/yu-ran--attack_heavy_up.jpg), [`attack_light_down`](boards/yu-ran--attack_light_down.jpg), [`attack_light_up`](boards/yu-ran--attack_light_up.jpg), [`special_down`](boards/yu-ran--special_down.jpg), [`special_neutral`](boards/yu-ran--special_neutral.jpg), [`special_side`](boards/yu-ran--special_side.jpg), [`special_up`](boards/yu-ran--special_up.jpg), [`ultimate`](boards/yu-ran--ultimate.jpg)

## 모션별 개별 후보

| 캐릭터·모션 | 차이 / 정도 / 확신 | 문제 프레임 | 관찰·다음 검토 | 근거 |
| --- | --- | --- | --- | --- |
| 자현 `attack_heavy_charge` | 외형·장착물 / 큼 / 차이 확인 | F1~16 | 승인 기준의 검은 안쪽 상의·검은 반바지와 다리의 넓은 영역이 투명하게 빠져 배경이 관통한다. 신발과 윤곽 일부만 남아 대기와 다른 외형으로 보인다. 실제 효과 렌더에서도 동일하다. 원화/알파 복구 재작업 우선; 배율만으로 해결되지 않음 | [고정 비교](comparisons/ja-hyun--attack_heavy_charge--1.jpg) · [전체 프레임](boards/ja-hyun--attack_heavy_charge.jpg) · [재생](playback/ja-hyun--attack_heavy_charge.mp4) |
| 나비 `jump` | 표시 크기 / 중간 / 차이 확인 | F1,F17,F22,F23,F24 | 착지 말미 F23→F24에서 머리·얼굴과 머리카락 덩어리가 커지는 그림 전환이 보인다. F24는 대기 그림과 가깝고 F1~23의 머리 모델과 차이가 있다. 착지 웅크림 자체는 문제로 세지 않는다. 원화·공통 배율 검토: 착지 마지막을 동일 머리 모델로 연결 | [고정 비교](comparisons/nabi--jump--1.jpg) · [전체 프레임](boards/nabi--jump.jpg) · [재생](playback/nabi--jump.mp4) |
| 나비 `launch` | 몸 비율 / 중간 / 차이 확인 | F1~10 | F2~9는 대기·F1·F10 이후에 비해 작은 얼굴/머리에 길어진 몸통·다리가 붙은 체형으로 보인다. 뒤로 젖힌 각도와 무릎 펴짐을 감안해도 모델 차이를 검토할 가치가 크다. 원화 재작업 검토: 같은 머리 크기에서 몸통·다리 길이를 대조 | [고정 비교](comparisons/nabi--launch--1.jpg) · [전체 프레임](boards/nabi--launch.jpg) · [재생](playback/nabi--launch.mp4) |
| 자현 `launch` | 표시 크기 / 중간 / 추가 비교 후보 | F12~16 | 뒤로 젖힌 반응 뒤 끝 프레임에서 얼굴·머리가 좁고 작아지는 다른 그림군으로 전환된다. F12→F14 및 대기 전후를 비교할 필요가 있다. 회전만으로 설명되는 부분은 분리해야 한다. 추가 대조: 반응→공중 전환의 머리 기준점을 찍고 원화/표시 중 원인 결정 | [고정 비교](comparisons/ja-hyun--launch--1.jpg) · [전체 프레임](boards/ja-hyun--launch.jpg) · [재생](playback/ja-hyun--launch.mp4) |
| 자현 `attack_dash_heavy` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F13,F14,F15,F16 | 회복 끝의 머리·상체·신발이 대기보다 작게 보인다. 돌진 중의 단축 원근과 분리해 확인할 후보다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--attack_dash_heavy--1.jpg) · [전체 프레임](boards/ja-hyun--attack_dash_heavy.jpg) · [재생](playback/ja-hyun--attack_dash_heavy.mp4) |
| 자현 `attack_dash_light` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F8,F13,F14,F15,F16 | 마지막 회복 자세에서도 대기보다 머리·상체·신발이 작고 가늘게 보인다. 전진 기울기는 별도다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--attack_dash_light--1.jpg) · [전체 프레임](boards/ja-hyun--attack_dash_light.jpg) · [재생](playback/ja-hyun--attack_dash_light.mp4) |
| 자현 `attack_heavy_down` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F13,F14,F15,F16 | 시작·마지막 회복에서 머리·어깨 폭이 대기보다 작고 팔다리가 가늘게 보인다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--attack_heavy_down--1.jpg) · [전체 프레임](boards/ja-hyun--attack_heavy_down.jpg) · [재생](playback/ja-hyun--attack_heavy_down.mp4) |
| 자현 `attack_heavy_side` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F12,F13,F14,F15,F16 | 지상 시작·회복에서 머리 본체와 어깨·신발이 대기보다 작게 보인다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--attack_heavy_side--1.jpg) · [전체 프레임](boards/ja-hyun--attack_heavy_side.jpg) · [재생](playback/ja-hyun--attack_heavy_side.mp4) |
| 자현 `attack_heavy_up` | 표시 크기 / 작음 / 추가 비교 후보 | F12~16 | 회복의 머리·어깨·신발이 대기보다 작게 보인다. 위로 뻗는 팔의 길이는 정상 포즈 변화로 구분한다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--attack_heavy_up--1.jpg) · [전체 프레임](boards/ja-hyun--attack_heavy_up.jpg) · [재생](playback/ja-hyun--attack_heavy_up.mp4) |
| 자현 `attack_light_combo_03` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F2,F14,F15,F16 | 시작·회복의 비슷한 지상 자세에서 대기/약공격1·2보다 머리와 어깨 폭이 작게 보인다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--attack_light_combo_03--1.jpg) · [전체 프레임](boards/ja-hyun--attack_light_combo_03.jpg) · [재생](playback/ja-hyun--attack_light_combo_03.mp4) |
| 자현 `attack_light_combo_04` | 몸 비율 / 작음 / 추가 비교 후보 | F2,F3,F5,F10,F11,F12 | 들어 올린 무릎·킥 중 대기보다 머리는 비슷한데 몸통과 지지 다리가 가늘고 길게 보인다. 몸을 펴는 자세 효과가 포함돼 확정하지 않는다. 추가 대조: 중립 몸 모델을 겹쳐 팔다리 길이부터 확인 | [고정 비교](comparisons/ja-hyun--attack_light_combo_04--1.jpg) · [전체 프레임](boards/ja-hyun--attack_light_combo_04.jpg) · [재생](playback/ja-hyun--attack_light_combo_04.mp4) |
| 자현 `attack_light_down` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F12,F13,F14,F15,F16 | 몸을 일으킨 시작·회복 자세의 얼굴·머리 크기가 대기보다 작게 보인다. 낮은 킥 자세의 높이는 판정 근거가 아니다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--attack_light_down--1.jpg) · [전체 프레임](boards/ja-hyun--attack_light_down.jpg) · [재생](playback/ja-hyun--attack_light_down.mp4) |
| 자현 `attack_light_up` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F13,F14,F15,F16 | 시작·회복에서 대기보다 머리와 어깨가 작게 보인다. 팔을 들어 늘어나는 외곽 높이는 제외했다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--attack_light_up--1.jpg) · [전체 프레임](boards/ja-hyun--attack_light_up.jpg) · [재생](playback/ja-hyun--attack_light_up.mp4) |
| 자현 `evade` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F13,F14,F15,F16 | 서 있는 회복 자세의 머리와 신발이 대기보다 약간 작게 보인다. 낮게 피하는 자세는 정상 변화다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--evade--1.jpg) · [전체 프레임](boards/ja-hyun--evade.jpg) · [재생](playback/ja-hyun--evade.mp4) |
| 자현 `jump` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F3,F17,F22,F24 | 착지 후반에도 대기보다 얼굴·머리와 신발이 작게 보인다. 공중에서 무릎을 접어 낮아진 외곽 자체는 차이에서 제외했다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--jump--1.jpg) · [전체 프레임](boards/ja-hyun--jump.jpg) · [재생](playback/ja-hyun--jump.mp4) |
| 자현 `run` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F2,F7,F13,F16 | 앞으로 기울인 자세를 감안해도 대기와 비교해 머리 본체와 신발이 함께 작게 보인다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--run--1.jpg) · [전체 프레임](boards/ja-hyun--run.jpg) · [재생](playback/ja-hyun--run.mp4) |
| 자현 `special_down` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F13,F14,F15,F16 | 서 있는 회복에서 머리 본체와 상체 폭이 대기보다 작게 보인다. 목도리의 회전 궤적은 모델 크기에서 제외했다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--special_down--1.jpg) · [전체 프레임](boards/ja-hyun--special_down.jpg) · [재생](playback/ja-hyun--special_down.mp4) |
| 자현 `special_scarf_sweep` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F2,F3,F29,F30,F31,F32 | 실제 표시 배율 보정 뒤에도 시작·회복의 머리와 몸통이 대기보다 작게 보인다. 큰 목도리 잔상을 캐릭터 크기로 세지 않았다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--special_scarf_sweep--1.jpg) · [전체 프레임](boards/ja-hyun--special_scarf_sweep.jpg) · [재생](playback/ja-hyun--special_scarf_sweep.mp4) |
| 자현 `special_side` | 표시 크기 / 작음 / 추가 비교 후보 | F13~16 | 돌진이 끝나 일어선 프레임의 머리·어깨·신발이 대기보다 작고 가늘게 보인다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--special_side--1.jpg) · [전체 프레임](boards/ja-hyun--special_side.jpg) · [재생](playback/ja-hyun--special_side.mp4) |
| 자현 `special_up` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F13,F14,F15,F16 | 머리·얼굴과 몸통 폭이 대기보다 작게 보인다. 공중 자세가 계속돼 지상 회복과 직접 대응하기 어려우므로 단정하지 않는다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--special_up--1.jpg) · [전체 프레임](boards/ja-hyun--special_up.jpg) · [재생](playback/ja-hyun--special_up.mp4) |
| 자현 `ultimate` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F2,F14,F15,F16 | 목도리 외곽을 제외한 시작·회복의 머리·상체가 대기보다 작게 보인다. 표시 보정 검토: 동일 카메라의 대기 전후와 머리 본체를 비교해 공통 모델 배율을 먼저 확정; 부족하면 원화 재작업 | [고정 비교](comparisons/ja-hyun--ultimate--1.jpg) · [전체 프레임](boards/ja-hyun--ultimate.jpg) · [재생](playback/ja-hyun--ultimate.mp4) |
| 묘령 `attack_heavy_up` | 몸 비율 / 작음 / 추가 비교 후보 | F8~9 | 상향으로 완전히 편 다리가 작은 몸통에 비해 길게 읽힌다. 대표의 중립/기본 자세와 각도가 달라 실제 모델 길이 차이인지 킥의 원근/변형인지 확정할 수 없어 재검토 후보로만 남긴다. 추가 대조: 대표 모델의 팔다리 길이와 포즈 원근을 겹쳐 비교하고 재작업 여부 선택 | [고정 비교](comparisons/myo-ryung--attack_heavy_up--2.jpg) · [전체 프레임](boards/myo-ryung--attack_heavy_up.jpg) · [재생](playback/myo-ryung--attack_heavy_up.mp4) |
| 묘령 `special_up` | 몸 비율 / 작음 / 추가 비교 후보 | F7~9 | 위로 길게 편 다리가 작은 몸통 대비 길어 보이는 후보다. 기준 이미지와 각도가 달라 모델 길이 변화인지 동작의 원근/변형인지 확정하지 않았다. 추가 대조: 대표 모델의 팔다리 길이와 포즈 원근을 겹쳐 비교하고 재작업 여부 선택 | [고정 비교](comparisons/myo-ryung--special_up--2.jpg) · [전체 프레임](boards/myo-ryung--special_up.jpg) · [재생](playback/myo-ryung--special_up.mp4) |
| 나비 `attack_air_heavy` | 외형·장착물 / 작음 / 추가 비교 후보 | F5~8 | 위로 든 손의 보라색 장착 날이 대표/다른 공격의 긴 금속 날보다 짧은 손톱처럼 읽히는 세부 후보다. 128px 해상도·손 방향·원근·가림의 영향과 확정 분리하지 못했다. 실제 효과에는 긴 보라 잔상이 있으며, 효과 부재로 판정한 항목이 아니다. 원화 세부 검토: 잔상 유지 여부와 별도로 실제 장착 보호대 길이 기준 결정 | [고정 비교](comparisons/nabi--attack_air_heavy--1.jpg) · [전체 프레임](boards/nabi--attack_air_heavy.jpg) · [재생](playback/nabi--attack_air_heavy.mp4) |
| 나비 `attack_heavy_up` | 외형·장착물 / 작음 / 추가 비교 후보 | F8~10 | 위로 든 손의 보라색 장착 날이 대표/다른 공격의 긴 금속 날보다 짧은 손톱처럼 읽히는 세부 후보다. 128px 해상도·손 방향·원근·가림의 영향과 확정 분리하지 못했다. 실제 효과에는 긴 보라 잔상이 있으며, 효과 부재로 판정한 항목이 아니다. 원화 세부 검토: 잔상 유지 여부와 별도로 실제 장착 보호대 길이 기준 결정 | [고정 비교](comparisons/nabi--attack_heavy_up--1.jpg) · [전체 프레임](boards/nabi--attack_heavy_up.jpg) · [재생](playback/nabi--attack_heavy_up.mp4) |
| 나비 `attack_light_up` | 외형·장착물 / 작음 / 추가 비교 후보 | F6~9 | 위로 든 손의 보라색 장착 날이 대표/다른 공격의 긴 금속 날보다 짧은 손톱처럼 읽히는 세부 후보다. 128px 해상도·손 방향·원근·가림의 영향과 확정 분리하지 못했다. 실제 효과에는 긴 보라 잔상이 있으며, 효과 부재로 판정한 항목이 아니다. 원화 세부 검토: 잔상 유지 여부와 별도로 실제 장착 보호대 길이 기준 결정 | [고정 비교](comparisons/nabi--attack_light_up--1.jpg) · [전체 프레임](boards/nabi--attack_light_up.jpg) · [재생](playback/nabi--attack_light_up.mp4) |
| 나비 `ring_out` | 몸 비율 / 작음 / 추가 비교 후보 | F1~6 | 대기보다 작은 얼굴과 긴 드러난 다리로 보이는 초반 반응이 있다. 장외 회전·다리 펴짐에 의한 원근일 수 있어 확정하지 않는다. 추가 대조: launch와 함께 공중 반응 모델 비교 | [고정 비교](comparisons/nabi--ring_out--1.jpg) · [전체 프레임](boards/nabi--ring_out.jpg) · [재생](playback/nabi--ring_out.mp4) |
| 나비 `run` | 표시 크기 / 작음 / 추가 비교 후보 | F1,F5,F9,F13,F16 | 달리기에서 대기보다 머리 본체가 약간 작고 얼굴이 좁게 보인다. 머리카락이 뒤로 흐르는 외곽 변화와 전진 원근은 제외하고 추가 비교할 후보다. 표시 보정 검토: 대기↔달리기 머리 중심·높이 비교 | [고정 비교](comparisons/nabi--run--1.jpg) · [전체 프레임](boards/nabi--run.jpg) · [재생](playback/nabi--run.mp4) |

## 목록에 들지 않은 모션

이번 전체 프레임 비교에서 뚜렷한 차이를 관찰하지 못했다는 뜻이다. 보이지 않는 세부나 다른 카메라·실기기 환경까지 통과했다는 뜻은 아니다.

- **자현**: `idle`, `attack_light_combo_01`, `attack_light_combo_02`, `attack_air_light`, `death`, `guard`, `hitstun`, `knock_down`, `ring_out`, `spawn`, `wake_up`, `attack_air_heavy`, `special_neutral`
- **나비**: `idle`, `attack_light_combo_01`, `attack_light_combo_02`, `attack_air_light`, `attack_dash_heavy`, `attack_dash_light`, `attack_heavy_charge`, `attack_heavy_down`, `attack_heavy_side`, `attack_light_down`, `death`, `evade`, `guard`, `hitstun`, `knock_down`, `spawn`, `special_down`, `special_neutral`, `special_side`, `special_up`, `ultimate`, `wake_up`

## 등록·재생 확인 메모

나비18개의 과거 `unapproved-workspace-only` 상태 필드는 현재 런타임 소비와 별도로 기록했다. PR112 승인 기록의 PNG 해시와 일치하므로 해당 문자열만으로 미승인 모션이라 판정하지 않았다. 원래 상태 필드는 변경하지 않았다.

유란 `attack_light_combo_03`은 active 단계 그림 수가 표시 틱 수보다 많다는 기존 타임라인 경고가 있다. 이번 외형 검토는 원화16장 전체를 포함하며, 건너뛴 그림은 `*`와 JSON에 기록했다. 타이밍 재작업은 이 목록의 외형 차이와 별도다.

검증과 재현 방법은 [작업 종료 기록](04_closeout.md)에 남긴다.
