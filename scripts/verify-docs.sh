#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"

fail() {
  echo "verify-docs: FAIL: $*" >&2
  exit 1
}

for path in \
  docs/INDEX.md \
  docs/GLOSSARY.md \
  docs/product/vision.md \
  docs/product/roadmap.md \
  docs/product/world-and-story.md \
  docs/product/decisions.md \
  docs/gameplay/combat.md \
  docs/gameplay/character-combat-guide.md \
  docs/gameplay/features-and-ux.md \
  docs/contracts/attack-system-v01.json \
  docs/contracts/character-appearance-v01.json \
  docs/engineering/architecture.md \
  docs/engineering/database.md \
  docs/engineering/godot/setup.md \
  docs/engineering/godot/resource-rules.md \
  docs/engineering/godot/android-wireless-debugging.md \
  docs/content/art-and-audio.md \
  docs/ui/non-combat-ui-v01.json \
  docs/ui/penpot-setup.md \
  docs/operations/ai-development.md \
  docs/operations/harness/team-spec.md \
  docs/operations/harness/operating-index.md
do
  [ -f "$path" ] || fail "필수 파일 없음: $path"
done

top_files=$(find docs -mindepth 1 -maxdepth 1 -type f -print | sort)
expected_top_files=$(printf '%s\n' docs/GLOSSARY.md docs/INDEX.md | sort)
[ "$top_files" = "$expected_top_files" ] || fail "docs 최상위에는 INDEX.md와 GLOSSARY.md만 둘 수 있음"

for directory in product gameplay contracts engineering content ui operations
do
  [ -d "docs/$directory" ] || fail "문서 분류 폴더 없음: docs/$directory"
done

old_paths='docs/(01_product_vision\.md|02_game_design\.md|03_features_and_ux\.md|04_technical_architecture\.md|05_content_art_audio\.md|06_roadmap_and_acceptance\.md|07_ai_development_guide\.md|08_world_and_narrative\.md|DECISIONS\.md|attack-system-v01\.json|character-appearance-v01\.json|forest_arena/|harness/forest-arena/)'
if rg -n --hidden "$old_paths" AGENTS.md README.md docs .agents assets scripts tests \
  --glob '!docs/INDEX.md' \
  --glob '!scripts/verify-docs.sh'
then
  fail "활성 파일에 이전 문서 경로가 남아 있음"
fi

grep -qF '가능한 쉬운 한국어를 먼저 쓴다' AGENTS.md || fail "AGENTS 쉬운 문장 규칙 없음"
grep -qF '두 문서 이상에서 반복되는 전문 용어' docs/operations/ai-development.md || fail "AI 문서 용어 추가 규칙 없음"
grep -qF '새 문서나 파일을 추가하면' docs/operations/ai-development.md || fail "AI 문서 색인 갱신 규칙 없음"

python3 - <<'PY'
from pathlib import Path
import re
import sys

failures = []
files = [Path("README.md"), Path("AGENTS.md"), *Path("docs").rglob("*.md")]
pattern = re.compile(r"\[[^\]]*\]\(([^)]+)\)")
for source in files:
    text = source.read_text(encoding="utf-8")
    for raw_target in pattern.findall(text):
        target = raw_target.split("#", 1)[0]
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue
        resolved = (source.parent / target).resolve()
        if not resolved.exists():
            failures.append(f"{source}: 끊어진 링크 {raw_target}")

if failures:
    print("\n".join(failures), file=sys.stderr)
    sys.exit(1)
PY

echo "verify-docs: PASS"
echo "- 목적별 7개 문서 폴더와 중앙 색인 확인"
echo "- 이전 경로, 쉬운 문장 규칙과 상대 링크 확인"
