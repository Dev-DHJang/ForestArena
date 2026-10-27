#!/bin/sh
set -eu

python3 tools/forest_arena/test_personality_concepts.py
python3 tools/forest_arena/test_personality_normalization.py
python3 tools/forest_arena/test_personality_registration.py
python3 tools/forest_arena/install_personality_concepts.py

python3 tools/forest_arena/test_recover_codex_session.py
python3 tools/forest_arena/test_motion_action_review.py
python3 tools/forest_arena/test_android_fleet.py
python3 tools/forest_arena/test_android_touch.py
python3 tools/forest_arena/test_prepare_android_qa.py

python3 tools/forest_arena/verify_forest_ledge_art.py
python3 tools/forest_arena/verify_job_id_independence.py
godot --headless --path . --editor --quit
godot --headless --path . --script res://tests/phase0_smoke.gd
godot --headless --path . --script res://tests/phase1_combat_contract.gd
godot --headless --path . --script res://tests/phase1_combat_behavior.gd
godot --headless --path . --script res://tests/phase1_match_rules.gd
godot --headless --path . --script res://tests/phase1_determinism.gd
godot --headless --path . --script res://tests/combat_feel_stage_v2.gd
godot --headless --path . --script res://tests/match_playtest_combat.gd
godot --headless --path . --script res://tests/two_fighter_combat_v2.gd
godot --headless --path . --script res://tests/two_fighter_combat_boundaries.gd
godot --headless --path . --script res://tests/two_fighter_product.gd
godot --headless --path . --script res://tests/two_fighter_presentation.gd
godot --headless --path . --script res://tests/two_fighter_vfx.gd
godot --headless --path . --script res://tests/scarf_path_continuity.gd
godot --headless --path . --script res://tests/nabi_claw_presentation.gd
godot --headless --path . --script res://tests/variable_motion_presentation.gd
godot --headless --path . --script res://tests/two_fighter_ai.gd
godot --headless --path . --script res://tests/android_device_combat_regression.gd
godot --headless --path . --script res://tests/phase1_input_ui.gd
godot --headless --path . --script res://tests/phase2_loadout_contract.gd
godot --headless --path . --script res://tests/phase2_runtime_wiring.gd
godot --headless --path . --script res://tests/phase3_style_comparison.gd
godot --headless --path . --script res://tests/phase3_style_playtest_entry.gd
godot --headless --path . --script res://tests/phase4_accessory_validation.gd
godot --headless --path . --script res://tests/accessory_policy.gd
godot --headless --path . --script res://tests/phase5_job_inheritance.gd
godot --headless --path . --script res://tests/phase6_local_mode_contract.gd
godot --headless --path . --script res://tests/phase6_multifighter_match.gd
./scripts/verify-audio.sh
godot --headless --path . --script res://tests/android_audio_store.gd
godot --headless --path . --script res://tests/combat_overhaul_contract.gd
godot --headless --path . --script res://tests/character_data_contract.gd
godot --headless --path . --script res://tests/character_appearance_contract.gd
godot --headless --path . --script res://tests/character_personality_concept_contract.gd
godot --headless --path . --script res://tests/character_motion_contract.gd
godot --headless --path . --script res://tests/character_attack_motion_contract.gd
godot --headless --path . --script res://tests/combat_concept_contract.gd
godot --headless --path . --script res://tests/ui_design_contract.gd
godot --headless --path . --script res://tests/battle_minimap.gd
godot --headless --path . --script res://tests/battle_minimap_app_flow.gd
godot --headless --path . --script res://tests/local_player_store.gd
godot --headless --path . --script res://tests/menu_state_store.gd
godot --headless --path . --script res://tests/menu_feature_store_unit.gd
godot --headless --path . --script res://tests/menu_service_client_unit.gd
godot --headless --path . --script res://tests/menu_touch_controls.gd
godot --headless --path . --script res://tests/premium_menu_touch_scroll.gd
godot --headless --path . --script res://tests/premium_menu_runtime.gd
godot --headless --path . --script res://tests/demo_guest_client.gd
godot --headless --path . --script res://tools/forest_arena/profile_catalog.gd
godot --headless --path . --script res://tests/local_ai_behavior.gd
godot --headless --path . --script res://tests/local_ai_soak.gd
godot --headless --path . --script res://tests/local_fighter_presentation.gd
godot --headless --path . --script res://tests/motion_lifecycle_presentation.gd
godot --headless --path . --script res://tests/hit_reaction_presentation.gd
godot --headless --path . --script res://tests/special_hit_presentation.gd
godot --headless --path . --script res://tests/launch_release_presentation.gd
godot --headless --path . --script res://tests/title_loading_flow.gd
godot --headless --path . --script res://tests/local_ai_app_flow.gd
godot --headless --path . --script res://tests/forestlight_runtime.gd
godot --headless --path . --script res://tests/local_accessory_play.gd
godot --headless --path . --script res://tests/local_touch_controls.gd
godot --headless --path . --script res://tests/forestlight_touch_input.gd
godot --headless --path . --script res://tests/match_playtest_ui.gd
godot --headless --path . --script res://tests/android_qa_session.gd
godot --headless --path . --script res://tests/menu_unified_callback.gd
godot --headless --path . --script res://tests/lan_result_outbox.gd
godot --headless --path . --script res://tests/lan_contract.gd
godot --headless --path . --script res://tests/lan_resume_pending.gd
./scripts/verify-lan-runtime.sh
./scripts/verify-android-qa-lan.sh
./scripts/verify-online-server.sh
./scripts/verify-harness.sh

echo "Forest Arena verification passed."
