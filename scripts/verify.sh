#!/bin/sh
set -eu

python3 tools/forest_arena/test_recover_codex_session.py

python3 tools/forest_arena/verify_forest_ledge_art.py
python3 tools/forest_arena/verify_job_id_independence.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/phase0_smoke.gd
godot --headless --path . --script res://tests/phase1_combat_contract.gd
godot --headless --path . --script res://tests/phase1_combat_behavior.gd
godot --headless --path . --script res://tests/phase1_match_rules.gd
godot --headless --path . --script res://tests/phase1_determinism.gd
godot --headless --path . --script res://tests/combat_feel_stage_v2.gd
godot --headless --path . --script res://tests/phase1_input_ui.gd
godot --headless --path . --script res://tests/phase2_loadout_contract.gd
godot --headless --path . --script res://tests/phase2_runtime_wiring.gd
godot --headless --path . --script res://tests/phase3_style_comparison.gd
godot --headless --path . --script res://tests/phase3_style_playtest_entry.gd
godot --headless --path . --script res://tests/phase4_accessory_validation.gd
godot --headless --path . --script res://tests/phase5_job_inheritance.gd
godot --headless --path . --script res://tests/phase6_local_mode_contract.gd
godot --headless --path . --script res://tests/phase6_multifighter_match.gd
godot --headless --path . --script res://tests/phase6_audio_contract.gd
godot --headless --path . --script res://tests/combat_overhaul_contract.gd
godot --headless --path . --script res://tests/character_data_contract.gd
godot --headless --path . --script res://tests/character_appearance_contract.gd
godot --headless --path . --script res://tests/character_motion_contract.gd
godot --headless --path . --script res://tests/character_attack_motion_contract.gd
godot --headless --path . --script res://tests/combat_concept_contract.gd
godot --headless --path . --script res://tests/ui_design_contract.gd
godot --headless --path . --script res://tests/battle_minimap.gd
godot --headless --path . --script res://tests/battle_minimap_app_flow.gd
godot --headless --path . --script res://tests/local_player_store.gd
godot --headless --path . --script res://tools/forest_arena/profile_catalog.gd
godot --headless --path . --script res://tests/local_ai_behavior.gd
godot --headless --path . --script res://tests/local_ai_soak.gd
godot --headless --path . --script res://tests/local_fighter_presentation.gd
godot --headless --path . --script res://tests/local_ai_app_flow.gd
godot --headless --path . --script res://tests/local_accessory_play.gd
godot --headless --path . --script res://tests/local_touch_controls.gd
godot --headless --path . --script res://tests/lan_contract.gd
./scripts/verify-lan-runtime.sh
./scripts/verify-online-server.sh
./scripts/verify-harness.sh

echo "Forest Arena verification passed."
