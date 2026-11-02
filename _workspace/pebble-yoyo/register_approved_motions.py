"""표준 등록기를 사용한다. 기본은 읽기 전용 계획이며 --install은 개별 사용자 승인이 필요하다.

r02 전용 일괄 등록기를 대체한다. 이번 수정은 새 요요 모션4개와 나비 idle의
몸 기준점 보정1개를 같은 검토 범위로 다룬다. 승인 전에는 runtime/manifest에 쓰지 않는다.
"""
from pathlib import Path
import sys
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools/forest_arena'))
from register_motion_candidates import main

if __name__ == '__main__':
    main()
