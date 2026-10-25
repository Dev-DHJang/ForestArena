# 등록 출처 메타데이터 독립 검토

독립 판정 담당은 `afterimage_final_r09 / registration-provenance-r01`이다. 마지막 설명 문서를 쓰기 전에 담당 실행이 사용량 제한으로 끝났으므로 root가 이미 확정된 독립 기록을 요약했다. root가 새 독립 판정을 만든 것은 아니다.

`qa/registration-independent-r01/provenance-check.json`은 PASS이며 A/B/F19의 실제 원화·생성 기록·프롬프트와 역할, F19 재구성 및 다른31셀 보존, 기존 원화 해시 배열 보존을 확인했다. `qa/registration-review-r02/motion-review.json`에는 담당자의 상세 관찰과 pass1이 기록돼 있고 `validate-require-pass.log`도 통과다.

r03에서 r04로 바뀐 것은 출처 기록뿐이다. 기존 source_sha256 배열은 source_sheet_sha256로 보존하고 주원화A의 단일 해시를 등록 규격에 맞췄다. 그림·SpriteFrames·비율·부착점·표시 시간·공격 시간표·제품 코드가 같음을 독립적으로 확인했다. 변경된 출처 파일에 이전 pass를 자동 복사하지 않고 새 출처를 확인한 뒤 같은 시각 근거가 같은 대상에 유효함을 기록했다. 외부 라이선스를 추가 확인했다고 주장하지 않는다.

사용자는 이후 별도 질문에 '이 자현 특수기 1종 승인'이라고 직접 답했다. 출처 검토의 PASS와 사용자 승인은 서로 다른 기록이며, 이 승인은 다른25종이나 Android 실기기 확인까지 포함하지 않는다.

표현 보충: 기존 `source_sha256` 배열은 주원화 A/B 두 개의 해시다. `creation.source_inputs`는 F19 교체 원본까지 포함한 세 개다. 독립 관찰 문구의 “3개 해시 배열”은 이 둘을 함께 가리키며, 실제 JSON과 대조 결과는 두 원화/세 전체 입력으로 구분돼 있다.
