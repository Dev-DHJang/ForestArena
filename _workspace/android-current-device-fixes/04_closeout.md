# 수정 APK 실기기 검사 마무리

사용자가 갱신한 S23 주 검사·Tab S5e LAN 상대 범위에서 검사를 완료했다. S23 기능·10분9판,두 APK LAN·앱 연결 장애,실제 Wi-Fi 경기 복귀와 S23 자현의 조작·모션·UI·음악/효과음/진동을 확인했다. 독립QA는 pass다. 검사 도구와 게임수정은 develop에 실제 병합됐고 이 문서는 그 SHA와 되돌리는 방법을 기록한다.

## 검사한 APK와 보존

- APK: build/android-current-fixes/ForestArena-current-fixed-r01.apk
- SHA-256: a42857320d1a41a5e707a457d6ce71f03aba9b0e38241e4d693b04fe1f850e48
- package: com.forestarena.welllbeing; activity com.godot.game.GodotAppLauncher; Godot4.7.1
- 빌드 입력 코드: 9de51fbff130417c207ef4ef3d1e7c4e7c8d0fbf; source2101파일 export전후 변경0
- 빌드입력473MiB를 frozen-apk-source-r01 사본과JSON으로 보존하고 독립재해시2101파일 변경0을 확인했다.
- 원래 작업 폴더 기준2913파일 변경0,승인120PNG/120SpriteFrames/manifest 변경0. 별도 작업 사본만 수정했고 원래 미커밋 작업·이전APK·실패증거는 보존했다.

## 변경과 검증

일반 지상 공격의 불필요한 이동,방향 입력 중 콤보 시작·후속 적중,피격 중 행동과 접지 미끄러짐,DEAD/경기종료 상태를 수정했다. 승인시트별 고정 표시배율·발기준은 해시가 맞을 때만 적용하고 원본그림은 바꾸지 않았다. 승인 숲빛v06을 실제메뉴/HUD/고정조이스틱에 연결하고 같은인원 ID교체·제거직전 viewport callback 오류를 QA지적 뒤 수정했다. 기존승인오디오·Android VIBRATE·QA음량 저장분리와 인증된 같은참가자의 LAN 재접속대기를 포함한다.

통합 verify-integrated-r02.log 종료0/전체완료문구/host118/SCRIPT ERROR0,문서·리소스491/24품질·Android native touch10/인자8·전투/모드/오디오·LAN/API/두서버분리 통과. export-r02.log 실제fresh template생성/최종export/Android package검사 종료0,INTERNET/VIBRATE와 실행JSON 포함 확인. 일부기존 종료정리 경고는 보존한다. 중복signal과 최초template옵션 대기로 멈춘 r01의 실패/중단143도 삭제하지 않았다.

마지막 계획대조에서 외부도구 명령의 device/step/expected/observed와 commands.jsonl 요청pending→실제ACK/실패 기록을 보완했다. 비밀값은 제거하고 LAN 공유HOME의 실제기기도 표시했다. host120개와 같은APK S23context 실제seq12응답을 확인했고 독립QA도 pass다. develop통합 후120개/문서/diff검사 통과. 빌드당시2101개와 통합tree 차이는 외부도구 android_fleet.py/test_android_fleet.py 두 파일뿐이며 게임소스·승인리소스·APK는 같다.

## 실기기 증거

- 첫 새APK b49ce3fd6dfc40528deeeae426611207: 원시13pass2fail8blocked2미실행을 보존. S23기능7개(MODE하위 연습/Solo8/Team4대4결과/Story 포함)는 pass. 사용자가 검사 도중 직접조작했다고 확인한 pause/foreground손실 혼합실패는 pass로 덮어쓰지 않는다.
- S23 d6002041832f4ba6a2f37babd9907609: 설정600초/관측608.196초/9판 결과·재대전/9조합 pass,로비·입력해제·일반저장{}→{} 동일. 단일SOAK범위3pass9미실행이며 전체기능 단일시도통과로 확대하지 않는다.
- LAN03b5e3f0513048ed8dd6738433bcb885: 정상winner2/tick4959/e78e07… server+양APK일치,재대전·S23HOME·10초같은슬롯복귀·65초이탈패배 pass. 이탈winner2/tick6360/2a5e347e…는server+남은Tab범위이며 S23은메뉴/결과{}다. LAN02원시blocked는 유지하고 S23세오류+Tab정원초과 실제4PNG를 root와QA가읽어 별도쌍별 시각pass를 기록했다. fixture나가기ACKfalse는 미확인이다.
- 실제Wi-Fi339d7f5cbf1f4434b78454b54e7819c2: 양쪽동일boot/generation1/slots1·2 복귀와Tab peer상태복구,serverneutralreset,사용자“복귀 후 이동 및 공격 가능하다.” 확인으로pass. 정확한OFF초수/추가peer전이원인/Tab문구체감은미확인. S23일부ADB로그/정리저장blocked는 보존하고 별도재접속후{}동일확인을 구분한다.
- S23자현 연습0ab50ed6862f46fda3812d1ec951a6ba: 사용자가 방향+공격/회피,3단콤보,경직,몸크기,새UI/HUD,음악/효과음/진동 모두정상 답변. 독립QA가 실제화면/설치hash/일반저장{}동일/로그/입력해제도 대조했다. 사람체감을 요청수로 대체하지 않았다.

최종 final-device-composite.json은 동일새APK의 보존된 여러시도에서 이름있는12사례와 사용자수정7항목을 연결한다. 자세한조건/측정/한계는 03_qa_r01.md,05_completion_audit.md,06_fixed_device_results.md를 따른다. 성능합격수치가 없어 FPS·구간p95·PSS·온도는 측정값만 보고했다.

## 실제 원격 통합과 되돌리기

- 도구 PR89: https://github.com/Dev-DHJang/ForestArena/pull/89
  expected head44ec782b4f1a6e4f133094e3b96eb2fefae89586,develop merge `2fecc0ac00f8e5b2612eb5932804c29f05cdcaea`.
- 게임수정 PR90: https://github.com/Dev-DHJang/ForestArena/pull/90
  expected head2d0d9d6eeab004ecfe6c1b9bde07ee06a142d7aa,develop merge `d81f180f2745cc2d8c41a61e6653c62bc41e16aa`.
- 두 병합은 GitHub merged응답과origin/develop fetch로 확인했다. main승격·release/hotfix분기·강제push·원격브랜치삭제·계정/비밀정보변경은 하지 않았다.
- 최신develop d81f180…에서 codex/android-device-test-closeout 브랜치로 실제병합/마무리기록만 따로 통합한다. 마무리 기록 PR91: https://github.com/Dev-DHJang/ForestArena/pull/91. 이 문서의최종원격상태는 해당기록PR의GitHub응답과origin/develop으로 확인한다.

되돌릴 때 새 작업브랜치에서 아래순서로 수행하고 관련검사·QA·PR을 거친다. 이미설치된APK는 코드revert와 별개이며 교체APK를 만들 때 패키지/실기기검사를 다시한다. 과거APK/실패/사용자관측 증거는 남긴다.

```sh
git revert -m 1 d81f180f2745cc2d8c41a61e6653c62bc41e16aa
git revert -m 1 2fecc0ac00f8e5b2612eb5932804c29f05cdcaea
```

## 완료 범위와 미실행

이전 사용자실패를 보존한 채 새APK의 현재승인범위가 정상이라는 실제증거를 확인했다. 4실기기/30분28조합전수는 기존요청의이번범위제외를 유지한다. Tab오프라인 사람체감/모든모션16프레임 사람전수/releaseAPK 실제설치는미실행이다. Story보상·경제·개발DB·정식인터넷온라인·4인온라인은이번범위밖이다. 최초페어링/기기디버깅허용은사용자가수행했고 페어링코드·디버그키·재접속토큰은증거에기록하지않는다.
