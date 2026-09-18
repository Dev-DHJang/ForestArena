#!/bin/sh
set -eu

godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/phase0_smoke.gd
godot --headless --path . --script res://tests/phase1_combat_contract.gd
godot --headless --path . --script res://tests/phase1_combat_behavior.gd
godot --headless --path . --script res://tests/phase1_match_rules.gd
godot --headless --path . --script res://tests/phase1_determinism.gd
godot --headless --path . --script res://tests/phase1_input_ui.gd
godot --headless --path . --script res://tests/phase2_loadout_contract.gd
godot --headless --path . --script res://tests/phase2_runtime_wiring.gd
godot --headless --path . --script res://tests/phase3_style_comparison.gd
godot --headless --path . --script res://tests/phase3_style_playtest_entry.gd
godot --headless --path . --script res://tests/combat_overhaul_contract.gd
godot --headless --path . --script res://tests/character_data_contract.gd
godot --headless --path . --script res://tests/character_appearance_contract.gd
godot --headless --path . --script res://tests/character_motion_contract.gd
godot --headless --path . --script res://tests/character_attack_motion_contract.gd
godot --headless --path . --script res://tests/combat_concept_contract.gd
godot --headless --path . --script res://tests/ui_design_contract.gd
./scripts/verify-harness.sh

echo "Forest Arena verification passed."
