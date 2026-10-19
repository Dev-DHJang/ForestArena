# 외부 도구 조사와 반영

- 문제: 승인 PNG120종의 비교판과 재생 검토 양식을 만들고, 해시·프레임 자료를 반복 검사해야 한다.
- 비교: Godot에서 실제 프레임 선택을 수집하고 이미지는 기존 Python/Pillow 도구를 재사용하는 방법, 모든 비교판까지 Godot로 새로 구현하는 방법, 추가 영상 라이브러리를 도입하는 방법을 비교했다.
- 선택: 실제 게임 타이밍은 Godot, 이미지 파일 읽기·비교판은 기존 Pillow를 재사용했다. 기존 normalize_myo_ryung_approved.py·normalize_nabi_approved.py도 PIL을 사용한다. 추가 영상 라이브러리나 Android 런타임 플러그인은 도입하지 않았다.
- 확인일: 2026-10-19.
- 원본: [Pillow 저장소](https://github.com/python-pillow/Pillow), [검증 버전13.0.0](https://pypi.org/project/pillow/13.0.0/), [해당 버전 LICENSE](https://github.com/python-pillow/Pillow/blob/13.0.0/LICENSE), [공식 설치 문서](https://pillow.readthedocs.io/en/stable/installation/index.html). PyPI의 해당 버전 표시는 MIT-CMU와 Python>=3.10이다. 이것을 프로젝트 전체의 라이선스라고 해석하지 않는다. 라이브러리를 별도 묶어 배포할 때는 원본 이용 조건과 표시 문구를 함께 확인한다.
- 환경: 기존 Python의 Pillow12.1.0에서도 기본 동작은 확인했지만, 공식 알려진 문제 목록에서13.0.0으로 수정된 항목을 확인해 별도 가상 환경에서13.0.0을 시험했고25개 테스트가 통과했다. 기존 Python 설치는 바꾸지 않는다. 정확한 개발 도구 버전은 requirements-motion-review.txt에 고정한다. Android 게임에는 Python/Pillow를 포함하지 않는다.
- 시험: 임시 폴더 PNG/SpriteFrames fixture로 자료 생성, 프레임 순서·시간 보존, 자료 변경·누락·근거 없는 통과 거부25개 테스트. 현재 원본 자산120종과 통합 작업 폴더 자산120종에서 각각 실제 Godot 자료 생성에 성공했다.
- 되돌리기: 이번 비교판 도구·관련 테스트·개발 전용 requirements를 함께 제거한다. 기존 전투·PNG·manifest·기존 Pillow 설치는 변경하지 않았다.
- 실제 Android에서 새 라이브러리를 시험한 결과는 없다. 개발용 파일 처리만 검증했으므로 기기 호환 통과라고 기록하지 않는다.

- 알려진 문제 확인: [공식 공지](https://github.com/python-pillow/Pillow/security/advisories/GHSA-xgh8-jp6q-p5x8)는12.3.0 이하의 형식 판별 지연과13.0.0 수정을 명시한다. PNG만 읽는 비교판 도구는 허용 형식을 PNG로 제한하고, 새 개발 환경은13.0.0으로 고정한다.
