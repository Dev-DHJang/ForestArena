# 자현·나비 전투 개편 마무리 상태

## 현재 결과

전투·제품·저장·LAN코드를구현했고전체verify r04·문서·리소스·실제LAN/DB검사가통과했다. 실사용모션36개독립QA도pass이며기록완전성검사를통과했다. 새모션은후보와검토자료를만들었으며사용자승인전이라게임자산에등록하지않았다. 새전투/모션/실기기개발전체가완료됐다고표시하지않는다.

- 작업브랜치: `codex/two-fighter-combat-v2`, 시작origin/develop95e1fe4.
- 구현/공용인터페이스:01_contract.md,02_combat.md,02_ui_product.md,02_motion_tools.md.
- 독립검사:03_qa_combat_r01.md,03_qa_product_r01.md와모션QA기록.
- 통합검사:03_integration.md 및qa폴더의원시로그/DB실조회/실제화면·영상.
- 사용자검토:review/approval.html(새5개),review/index.html(실사용36개),review/live-special/index.html(실제특수3경기).
- PR/커밋정보는생성뒤아래에확정한다. 승인전draft를유지하며아직develop병합하지않는다.

## 승인 대상

1. 자현약4전방발차기:attack_light_combo_04/r01n02.
2. 자현공중강목도리내려치기:attack_air_heavy/r01n02.
3. 자현좌·우·위목도리특수:special_scarf_sweep/r01n02.
4. 나비약2오른손위할퀴기:attack_light_up/r02n02.
5. 나비공중강올려치기:attack_air_heavy/r04n02.

실제파일과해시는candidate-catalog.json/scope.json과정식motion-review.json에고정한다. 새그림은기존승인idle과정체성·안무를대조하되표정/머리폭에조금차이가있을수있어최종사용자결정이필요하다.

## 미확인·다음 절차

- 위5개모션별사용자명시승인→원본보존/자산등록→동일버전전체검사→기존범위PR검토/병합.
- 최신물리Android의엄지접근성·가독성·멀티터치·중단/복귀·성능·LAN두기기는미실행. 기기연결뒤이름을붙인수동재검사로별도기록한다.
- APK배포·스토어등록은이번범위밖이다.

## 롤백

이번PR의전투Resource·새선택정책·UI·LAN서버/클라이언트를한묶음으로되돌린다. 보유/전적/프리셋원본과DB볼륨은삭제하지않는다. LAN protocol2와3을섞지않고동일버전서버/클라이언트로복귀한다.
