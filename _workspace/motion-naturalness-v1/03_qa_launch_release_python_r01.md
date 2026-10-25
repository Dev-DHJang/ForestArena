# 날림 표시 연결 Python 등록 경로 독립 검사 r01

담당: `qa /root/afterimage_final_r09`, 2026-10-26. **pass — 선택 표시 값의 검증·등록 보존과 승인 차단 범위**. 제품 코드·시안·catalog·원화·실제 manifest는 수정하지 않았다. 검사 중의 설치와 인공 승인 기록은 자동 삭제되는 임시 시험 프로젝트에만 존재하며 실제 사용자 승인으로 사용하지 않는다.

## 검토 범위와 판단

`tools/forest_arena/motion_layout.py`, `register_motion_candidates.py`, `test_motion_action_review.py`의 현재 diff와 실제 호출 경로를 읽었다. 기존 `load_selection`과 독립 QA 기록 확인 뒤 `layout(source)`가 실행되며, 새 표시 값은 기존 `DISPLAY_FIELDS`를 통해 후보 원본 값 그대로 복사된다. 변경된 도구와 연결된 검사·계약의 해시는 `qa/launch-release-python-independent-r01/sources.json`에 고정했다.

- `launch_release_frame_range`와 `launch_release_ticks`는 함께 있어야 한다. launch에만 허용하고, 범위는 `0 <= begin < end <= frame_count`, 시간은 정수값1~12 및 그림 수 이상으로 제한한다. Godot JSON의 정수값 float도 허용하지만 bool·문자열·소수·NaN·무한대·범위 밖의 거대 수는 거부한다. 검사 중 원본 row를 바꾸지 않는다.
- 기존 `landing_down_frame_range`, `state_duration_ticks`, `state_hold_frame`은 각각 유효 구간·양의 정수값·선언 프레임 안의 정수값으로 검사한다. 새 쌍과 기존 세 필드가 계획의 manifest JSON 및 임시 승인 설치 뒤에도 같은 값으로 남는다. 필드 없는 기존 layout 기본값은 유지한다.
- `plan_registration`은 파일과 백업을 만들지 않고 재실행 결과가 같다. 설치는 사용자 결정 기록을 먼저 확인한다. 새 필드가 있는 경우에도 승인 누락·명시 거부는 target/backup 생성 전에 실패한다. 계획·승인 뒤 표시 시간만 바꾼 경우도 현재 QA/계획과 달라져 쓰기 전에 거부한다.
- 등록 목록의 그림 SHA·SpriteFrames·현재 QA·정확한 계획 해시와 모션별 승인을 묶는 기존 조건을 제거하거나 우회하는 변경은 없다. 이번 검사는 파일 데이터 경로의 완전성을 확인하며 그림 품질이나 사용자 승인을 자동 판정하지 않는다.

## 독립 실행 결과

| 검사 | 결과 | 증거 |
| --- | --- | --- |
| 기존 `test_motion_action_review.py` 전체 | 87개 PASS | `qa/launch-release-python-independent-r01/unittest-existing.log` |
| 새 독립 경계·등록 검사 | 7개 PASS | 같은 폴더 `check_independent.py`, `check.log` |
| 위 추가 검사 안의 숫자·구간 사례 | 2,656개 통과 | 16/24/32 프레임의 모든 합법 구간(최대12장)·정수/실수 JSON 및 잘못된 값 |

실행 명령:

```sh
python3 -m unittest discover -s tools/forest_arena -p test_motion_action_review.py
python3 _workspace/motion-naturalness-v1/qa/launch-release-python-independent-r01/check_independent.py
```

추가 검사는 전체 합법 구간과 시작·끝·시간을 JSON 저장·재로딩한 뒤 입력 불변을 검사한다. 임시 프로젝트에서는 정수값 float인 새 쌍과 기존 상태 필드가 계획·설치에서 보존되는지, 모든 파일 byte snapshot이 읽기 전용 계획과 승인 거부 전후에 같은지 검사했다. 기존 제작 검사만 다시 실행한 결과와 독립 추가 검사를 구분해 기록했다. 실제 art·manifest로 설치를 실행하지 않았다.

수정 요청 사항은 발견하지 않았다. 새 표시 연결의 게임 내 화질·자연스러움·실제 LAN 왕복·모션별 사용자 승인·실제 Android 기기는 이 코드 검사 밖이다. `result.json`은 이 좁은 범위를 담으며 다른 모션이나 제품 전체의 통과를 뜻하지 않는다.
