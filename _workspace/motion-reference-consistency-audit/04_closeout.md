# 모션 외형 차이 목록 종료 기록

## 결과

2026-10-29 등록된 네 캐릭터 **122모션/2,000프레임**의 전체 원화와 승인 대표 v01을 직접 비교했다. **차이 확인3모션 / 추가 비교84모션 / 차이 미관찰35모션**으로 나눴다. 검토 목록에 든87모션에는 묘령31·유란30의 공통 색감 후보 영향 범위가 포함된다. 같은 관찰을 묶으면30건이다. 이는 중대 결함30건이나 재작업87개 확정이라는 뜻이 아니다.

- 차이가 분명한 항목: 자현 `attack_heavy_charge`의 몸통·하체 투명 누락, 나비 `jump` 마지막 그림의 머리 크기 전환, 나비 `launch` 일부 프레임의 작은 머리·긴 몸 모델.
- 자현의 작은 크기 차이, 나비 장착 날의 짧은 세부 인상, 묘령의 편 다리와 공통 색감 등은 원근·가림·해상도 영향이 남는 추가 비교 후보다.
- 사용자가 목록을 검토한 뒤 재작업 범위를 선택한다. 이번 작업에서는 PNG·SpriteFrames·manifest·전투·표시 설정을 수정하지 않았다.

## 산출물

- [사용자 검토 목록](review-list.md), [CSV](review-list.csv), [전체 122개 판정·해시 JSON](motion-review.json).
- [프레임·정상/느린 재생 뷰어](index.html), `boards/` 전체 원화122개, `playback/` MP4122개, `runtime-boards/` 실효과 표본 및 원래 비율 상세 자료.
- `comparisons/`: 대표→현재 대기→문제 그림을 같은2배로 표시한30개 카드. `evidence/`의 공격 효과 확대 자료, `overview/` 캐릭터별 요약.
- [생산자 관찰](review-ja-nabi.json), [묘령·유란 독립 관찰](qa-myo-yu.json), [독립 QA](03_qa_r01.md).
- [제작·재현과 해석 한계](02_2d_animation.md), [완료 요건 대조](completion-audit.json), [입력 해시](source-snapshot.json), [캡처 재생 순서](capture-provenance.json).

122모션의 정상/좌우 반전·원래 크기 영상은 실제 표시 변환과 효과 코드를 고정 검사 화면에서 재생한 자료다. 실제 전체 매치나 Android 실기기 검사가 아니다. 전체 프레임과 표시·효과 표본을 직접 확인했으며, 122개 MP4 모두를 사람이 끝까지 시청한 정식 행위 표현 승인으로 주장하지 않는다. 작은 세부가 가려진 프레임과 타임라인에서 미선택된 원화는 불확실성/추정 표시로 남겼다.

## 검증

- 승인 대표4세트 `combat_reference.py validate --require-approved`: 통과.
- 실제 표시 타임라인:122모션 통과. 유란 `attack_light_combo_03`의 기존 active 그림/틱 경고1건은 원화 전수 비교 및 미선택 표시와 분리했다.
- 새 회귀7개:16/24/32의 마지막 그림을 실제 보드에 포함, 고정 배율, 발/몸 기준점, 반전, 잘못된 배율, 누락/변경 입력 실패를 검증했다.
- `audit_motion_consistency.py --validate`:122모션/2,000프레임·입력/증거 해시 대조 통과. 시각 판정을 자동 증명하는 검사가 아니다.
- [영상 검사](media-validation.json):122개 전체 디코드8,797프레임,30FPS,1280×512와 길이 일치.
- 뷰어122개 고유 항목, 로컬 미디어/Markdown 링크, JavaScript 구문, Python 구문 검사 통과. 브라우저 UI 자동화는 Work 설정에서 사용할 수 없어 브라우저에서 화면 조작 통과를 주장하지 않는다.
- `./scripts/verify.sh --full`: 최종 **92/92 단계(가져오기1+91검사) 통과,526.98초**. 결과 원본 `build/verification/20261029-222203-6f483468/result.json`; [보존본](verification-full-result.json). 새7회귀 포함. 검사 당시 HEAD는 기준 커밋이고 작업 폴더의 변경·새 도구를 포함해 실행했다.
- [독립 QA 최종 pass](03_qa_r01.md). 목록의 근거·범위·확신 구분에 대한 통과이며, 모션 외형 전체 통과/재작업 승인과 구분한다.

## Git·원격 통합

- 기준: `origin/develop`의 `4221f6cc6bee607aa6f7d2f30d1d0b2230126def`.
- 작업 폴더: `/Users/jdh/.codex/worktrees/combat-character-references/ForestArena` 재사용.
- 브랜치: `codex/motion-reference-consistency-audit`.
- 기존 참조 작업 브랜치의 종료 감사 커밋은 이전 브랜치에 보존했다. 다른 작업 폴더 파일을 덮어 복사하지 않았다.
- 원격 PR·병합 식별자는 실제 반영 뒤 아래에 추가한다. 롤백은 해당 PR의 감사 도구·문서·검토 자료만 되돌리며 원래 모션 자산은 건드리지 않는다.
