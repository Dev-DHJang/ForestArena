#!/bin/sh
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$ROOT"
fail() { echo "verify-harness: FAIL: $*" >&2; exit 1; }
check_file() { [ -f "$1" ] || fail "missing file: $1"; }

for path in AGENTS.md README.md project.godot export_presets.cfg docs/01_product_vision.md docs/02_game_design.md docs/03_features_and_ux.md docs/04_technical_architecture.md docs/05_content_art_audio.md docs/06_roadmap_and_acceptance.md docs/07_ai_development_guide.md docs/DECISIONS.md docs/character-appearance-v01.json docs/ui/non-combat-ui-v01.json docs/ui/combat-ui-v01.json docs/ui/penpot-setup.md tests/ui_design_contract.gd tests/combat_ui_design_contract.gd assets/ui/.gdignore assets/ui/asset-requirements.csv assets/ui/combat-asset-requirements.csv .codex/config.toml.example scripts/start-penpot-mcp.sh docs/harness/forest-arena/team-spec.md docs/harness/forest-arena/operating-index.md
do
  check_file "$path"
done

team_skills=$(awk -F'|' '/^\|/ && $3 ~ /^[[:space:]]*forest-arena-/ {gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}' docs/harness/forest-arena/team-spec.md)
[ -n "$team_skills" ] || fail "team spec has no skill roster"
duplicates=$(printf '%s\n' "$team_skills" | sort | uniq -d)
[ -z "$duplicates" ] || fail "duplicate team skill: $duplicates"

for skill_id in $team_skills
do
  skill=".agents/skills/$skill_id/SKILL.md"
  check_file "$skill"
  [ "$(sed -n '1p' "$skill")" = "---" ] || fail "frontmatter start: $skill"
  [ "$(sed -n '4p' "$skill")" = "---" ] || fail "frontmatter end: $skill"
  [ "$(sed -n 's/^name: //p' "$skill")" = "$skill_id" ] || fail "skill name: $skill"
  grep -Eq '^description: .*[가-힣]' "$skill" || fail "Korean description: $skill"
  for heading in '## 사용 시점' '## 필수 입력' '## 작업 흐름' '## 산출물과 검증'
  do
    grep -qF "$heading" "$skill" || fail "section $heading: $skill"
  done
done

expected=$(printf '%s\n' "$team_skills" | sort)
actual=$(find .agents/skills -mindepth 2 -maxdepth 2 -name SKILL.md -type f | sed 's#.agents/skills/##; s#/SKILL.md##' | sort)
[ "$expected" = "$actual" ] || fail "team roster and skill directories differ"

for removed in "forest-arena-godot"'-ui' "forest-arena-character"'-motion' "forest-arena-version"'-control'
do
  [ ! -e ".agents/skills/$removed/SKILL.md" ] || fail "removed skill remains: $removed"
done
if rg -n 'forest-arena-(godot-ui|character-motion|version-control)' AGENTS.md README.md docs/harness docs/forest_arena docs/ui .agents; then fail "removed skill ID in active guidance"; fi
if rg -n '[1]7개 역할|[1]5개 역할|현재 Phase 0' AGENTS.md README.md docs/01_product_vision.md docs/02_game_design.md docs/03_features_and_ux.md docs/07_ai_development_guide.md docs/harness docs/ui .agents; then fail "stale active role count or Phase state"; fi

grep -qF 'ForestArenaResources' .agents/skills/forest-arena-ui/SKILL.md || fail "UI resource consumption missing"
grep -qF 'docs/forest_arena/GODOT_SETUP.md' .agents/skills/forest-arena-ui/SKILL.md || fail "UI setup missing"
grep -qF '모션별 사용자 명시 승인' .agents/skills/forest-arena-2d-animation/SKILL.md || fail "motion approval missing"
grep -qF 'develop` 병합' .agents/skills/forest-arena-orchestrator/SKILL.md || fail "merge ownership missing"
grep -qF '00_request.md' docs/harness/forest-arena/team-spec.md || fail "request evidence missing"
grep -qF '04_closeout.md' docs/harness/forest-arena/team-spec.md || fail "closeout evidence missing"
if grep -qF '02_version'"-control.md" docs/harness/forest-arena/team-spec.md docs/07_ai_development_guide.md; then fail "obsolete evidence remains"; fi

for path in docs/forest_arena/GODOT_SETUP.md docs/forest_arena/RESOURCE_RULES.md forest_arena/scripts/forest_arena_resource_manager.gd forest_arena/data/resource_registry.json forest_arena/data/quality_profiles.json tools/forest_arena/verify_godot_resources.py harness/forest_arena_godot/codex_apply_contract.json
do
  check_file "$path"
done
grep -qF 'ForestArenaResources="*res://forest_arena/scripts/forest_arena_resource_manager.gd"' project.godot || fail "Autoload missing"
python3 tools/forest_arena/verify_godot_resources.py --project-root . || fail "resource registry verification"

grep -qF '사용자의 명시적 승인 전에는 `assets/character/` 또는 그 manifest에 쓰지 않는다' .agents/skills/forest-arena-character-design/SKILL.md || fail "character approval gate missing"
for consumer in character-design image-design 2d-animation
do
  grep -qF 'docs/character-appearance-v01.json' ".agents/skills/forest-arena-$consumer/SKILL.md" || fail "appearance consumer: $consumer"
done
grep -qF '사용자 시안 승인만으로는 계약 변경 승인이 되지 않는다' docs/harness/forest-arena/team-spec.md || fail "appearance contract gate missing"

for path in .agents/skills/forest-arena-ui/references/penpot-workflow.md .agents/skills/forest-arena-ui/templates/penpot-master-prompt.md .agents/skills/forest-arena-image-design/templates/ui-image-batch-prompt.md
do
  check_file "$path"
done
grep -qF 'Penpot 비전투 UI 설계' docs/harness/forest-arena/team-spec.md || fail "Penpot route missing"
grep -qF 'references/penpot-workflow.md' .agents/skills/forest-arena-ui/SKILL.md || fail "UI Penpot reference missing"
grep -qF 'http://localhost:4401/mcp' .codex/config.toml.example || fail "Penpot URL drift"
grep -qF 'npx -y @penpot/mcp@stable' scripts/start-penpot-mcp.sh || fail "Penpot command drift"

grep -q 'Phase 7 이전 온라인 구현 요청' docs/harness/forest-arena/team-spec.md || fail "online gate missing"
grep -q 'accepted 네트워크 ADR 전에는 사용하지 않는다' .agents/skills/forest-arena-multiplayer/SKILL.md || fail "multiplayer gate missing"
grep -q '온라인 계약은 Phase 7과 accepted 네트워크 ADR 전 확정하지 않는다' .agents/skills/forest-arena-contracts/SKILL.md || fail "contracts gate missing"

legacy='ForestTales|forest-tales|com\\.foresttales|ForestTales-debug'
if grep -REn "$legacy" .agents/skills docs/harness docs/ui; then fail "legacy brand in active guidance"; fi
grep -qF 'config/name="Forest Arena"' project.godot || fail "Godot name drift"
grep -qF 'export_path="build/android/ForestArena-debug.apk"' export_presets.cfg || fail "APK path drift"
grep -qF 'package/unique_name="com.forestarena.welllbeing"' export_presets.cfg || fail "package ID drift"
grep -qF 'package/name="Forest Arena"' export_presets.cfg || fail "package label drift"

echo "verify-harness: PASS"
echo "- $(printf '%s\n' "$team_skills" | wc -l | tr -d ' ') active roles from team spec"
echo "- Korean skill structure, merged ownership, dynamic roster, resource, approval and online gates"
