# 비교 자료 제작과 검토 방법

## 고정 입력

- 기준 커밋 `4221f6cc6bee607aa6f7d2f30d1d0b2230126def`의 manifest 전체 `animation-runtime`: 122모션/2,000프레임.
- 승인 대표 v01 PNG16장과 외형 계약. 세트4개 `--require-approved` 구조 검사 통과.
- `source-snapshot.json`: PNG/TRES/계약/표시 보정/실제 표시 코드·공격 데이터·효과 코드·목도리 텍스처 해시.
- 나비 과거 상태 필드18개는 현재 승인 기록 PNG 해시와 대조했다. `approval-status-note.json` 참고. 필드나 자산을 고치지 않았다.

## 자료

1. `motion_consistency_timeline.gd`는 기존 `motion_review_timeline.gd`를 상속해 실제 `LocalFighterPresentation.sync_visual()` 뒤 배율·위치·몸 기준점 결과와 효과 입력을 추가로 관측한다. 전투 snapshot이 바뀌면 기존 검사에서 실패한다. 후보 모션을 주입하지 않는다.
2. `audit_motion_consistency.py`는 16/24/32 선언과 128셀·최대16열을 읽어 전체 프레임을 보드로 만든다. 원화와 실제 관측 배율 적용을 구분한다. 전체 외곽에 맞춰 모션별/프레임별 크기를 다시 맞추지 않는다. 승인 참조는 고정1/8 비교용이며 새 게임 크기 계약이 아니다.
3. 별도 고정 검사 장면에서 `render_motion_consistency.gd`가 관측 변환과 실제 `fighter_attack_effects.gd`를 재생했다. Apple M4 OpenGL compatibility의 실렌더다. 정상·좌우 반전 각2배 확대와 원래 크기를 함께 캡처했다. 60Hz의2틱마다30FPS, 앞뒤 대기 각0.5초. 합계8,797 캡처. 실제 경기/전체 앱/Android 검사는 아니다.
4. `package_motion_consistency.py`가 MP4122개, 표본 보드·원본 크기 PNG, 정상1×/느리게0.25× 선택 뷰어를 만들었다. `media-validation.json`은 ffprobe로 모든 영상의 전체 디코드 프레임 수/FPS/길이/크기를 확인한 기록이다. 저속은 뷰어에서 재생률만 바꾸므로 원화나 시간 자료를 바꾸지 않는다.
5. 사람 관찰은 `review-ja-nabi.json`, `qa-myo-yu.json`에 남겼다. 122개 모든 원화 프레임과 승인4각도를 직접 비교했고 실제 표시·효과·반전·작은 표시 표본도 확인했다. 정상/저속 재생 가능 자료 제공을 전체 행동 표현의 지각 평가 통과나 Android 통과로 확대하지 않는다.
6. `build_report.py`는 직접 관찰을 판정 없이 묶어 Markdown/CSV/JSON/뷰어 필터를 만든다. 공통 색감2건의 영향 모션61개를 개별 중대 결함61건으로 집계하지 않는다. 추가 비교 후보는 재작업 지시가 아니다.

## 해석 한계

- 보드 `*` 프레임은 해당 관측 타임라인에서 선택되지 않은 원화다. 실제 배율은 유지하되 표시 위치는 첫 관측 위치 또는 명시된 몸 기준점으로 추정했다. 별도로 원화 전체는 직접 검사했다.
- 타임라인은 공격 데이터 시간과 고정 상태/합성 점프 단계의 재생 시험이다. 자연스러운 전체 매치 입력·카메라 이동을 재현하는 검사가 아니다.
- 첫~마지막 프레임 시간은 반복/중간 공백을 포함할 수 있는 범위다. CSV보다 JSON의 프레임별 시간과 원본 타임라인이 자세하다.
- 실렌더 영상은 좌우 비교 영역 사이를 큰 목도리 효과가 넘을 수 있다. 이를 추가 꼬리/장착물 수의 원화 결함으로 세지 않는다.
- 귀·꼬리·리본 외곽, 웅크림, 회전, 원근·가림·표정을 모델 크기/개수 변화로 자동 판정하지 않았다. 작은 눈/장식의 세부는 해상도상 확정하지 않았다.
- 실렌더 표본과 전체 순서 보드의 외형 비교를 실시했다. 모든 재생률에 대한 행위 표현 정식 승인이나 모든 타이밍/장면의 완전한 시각 통과 기록은 아니다.

## 재현

루트에서 아래 순서로 실행한다. 이미 사람이 검토한 폴더에는 prepare를 덮어쓰지 못한다. 재생성은 새 작업 폴더에서 한다. 실렌더는 화면이 있는 Godot 실행 환경이 필요하다.

```sh
godot --headless --path . --script res://tools/forest_arena/motion_consistency_timeline.gd -- --output <새폴더절대경로>/timeline.json
python3 tools/forest_arena/audit_motion_consistency.py --timeline <새폴더>/timeline.json --output <새폴더>
godot --path . --rendering-method gl_compatibility --audio-driver Dummy --script res://tools/forest_arena/render_motion_consistency.gd -- --timeline <새폴더절대경로>/timeline.json --output <캡처절대경로>
python3 tools/forest_arena/package_motion_consistency.py --captures <캡처폴더> --output <새폴더>
```

현재 검토 기록의 무결성 검사는 다음과 같다.

```sh
python3 tools/forest_arena/audit_motion_consistency.py --validate --output _workspace/motion-reference-consistency-audit
python3 tools/forest_arena/test_motion_consistency.py
```
