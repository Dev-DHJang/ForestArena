# 표시 초기화 수정 독립 재검토 r02

2026-10-24. 담당: motion_code_review. r01의 **재등장 중 재시작/동일 캐릭터 프로필 재설정 뒤 spawn 중간 그림이 남는 문제**에 대한 root의 수정만 독립 대조했다. 프로덕션·후보·원화·manifest를 수정하지 않았다. 판정은 이 문제의 수정 **pass**이며 전체 모션 품질이나 기기 검사 판정은 아니다.

## 영향 경로

- FighterController에 인자가 없는 로컬 `presentation_reset` 신호가 추가됐다. 유효한 `configure_profile()`과 `reset_for_match()`의 기존 초기화가 끝난 뒤에만 보낸다. 잘못된 프로필로 거부될 때는 보내지 않는다.
- LocalPresentation이 준비될 때 자신의 파이터 신호에 `_reset_playback`을 한 번 연결한다. callback은 표시 시간, 직전 모션/활성화 관찰, 점프·착지·달리기·재등장 표시 예약만 초기화한다. 파이터 상태나 snapshot을 바꾸지 않는다. 다음 sync에서 그 시점의 실제 상태를 처음부터 표시한다.
- 캐릭터 ID가 달라져 자산 목록을 다시 읽을 때도 같은 초기화 함수를 사용한다. 같은 캐릭터 프로필에서는 자산을 불필요하게 다시 읽지 않고 표시 시계만 초기화한다.
- 표시 Node를 해제하면 연결과 수신자 참조가 사라지는지 실제 확인했다. 대체 표시 Node를 붙이면 다시 연결 하나가 된다. 이전 표시 Node가 파이터 신호에 붙어 남지 않았다.
- 네트워크 snapshot을 받을 때마다 초기화 신호를 보내는 방식이 아니다. 따라서 반복 수신으로 애니메이션이 매번 첫 프레임으로 돌아가는 변화는 없다. 기존 RING_OUT→IDLE 상태 관찰 및 행동 즉시 우선도 유지된다.

FighterController의 기준 HEAD 이후 diff는 신호 선언과 위 두 함수 끝의 emit뿐이다. 상태 필드, 전투 규칙·Resource, snapshot 생성/적용 함수, 소켓 전송·메시지 형식·버전은 변경하지 않았다. 해당 네트워크 경로에 diff가 없는 것도 대조했다.

## 재현과 재검사

r01의 공개 API 재현 파일을 바꾸지 않고 그대로 실행했다. 결과는 `qa/code-r02/repro-reset.log`다.

```text
before reset: spawn elapsed=0.41666666666667 frame=5
after public reset_for_match: idle elapsed=-1.0 frame=0 state=IDLE
after same-character profile reconfiguration: idle elapsed=-1.0 frame=0
```

추가한 제품 검사도 두 캐릭터 각각 실제 stock loss→respawn→0.4초 재생부터 **match reset과 profile reset을 별개로** 확인한다. 공개 configure_profile 재설정 때도 다시 중간 spawn을 만든 뒤 검사하므로 먼저 실행한 match reset 결과로 대신 통과하지 않는다.

직접 실행 결과:

| 검사 | 결과 | 증거 |
| --- | --- | --- |
| motion_lifecycle_presentation | 430개 PASS | `qa/code-r02/lifecycle.log` |
| local_fighter_presentation | PASS | `qa/code-r02/local-presentation.log` |
| two_fighter_vfx | PASS | `qa/code-r02/vfx.log` |
| r01의 실제 snapshot 적용 경계 | 21개, 오류0 | `qa/code-r02/read-network-state.log` |
| 로컬 reset 연결·해제·snapshot 불변 | 8개, 오류0 | `qa/code-r02/reset-connection.gd`와 `.log` |

연결 검사는 callback 호출 전후 전체 파이터 snapshot 불변, 잘못된 profile의 미발신, 표시 해제 뒤 weakref가 null이고 signal 연결0개인 상태, 대체 표시의 연결1개를 확인한다. 최초 QA fixture의 WeakRef 타입 추론 컴파일 오류는 명시 타입으로 고쳤고 당시 출력은 `reset-connection-initial-parse.log`로 남겼다. 최종 위8개 결과를 판정에 사용했다.

## 검토 해시와 한계

| 파일 | SHA256 |
| --- | --- |
| `scripts/fighter_controller.gd` | `63dc815dfbd5abdce3646f7386e15b25459f3b123e511a11084c3438a546d48c` |
| `scripts/local_fighter_presentation.gd` | `d7377e05868905d06264d42c965070648fccd67f1eaaeffa802cdc66d5aedfe9` |
| `tests/motion_lifecycle_presentation.gd` | `0c313e59f69b92161b78378a6876e01b4eddfbe6a794b0f4a34ca726e6c8f22d` |

이 범위에서 추가 필수 수정은 발견하지 않았다. 실제 LAN 연결·Android 생명주기·목도리 새 원화와 전체 동영상의 자연스러움을 이 검사로 통과 처리하지 않는다. 소스가 바뀐 뒤에는 이전 고정 해시의 촬영 자료와 새 자료를 구분해야 한다.
