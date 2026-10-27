#!/bin/sh
set -eu
godot --headless --path . --script res://tests/local_fighter_presentation.gd
godot --headless --path . --script res://tests/motion_lifecycle_presentation.gd
godot --headless --path . --script res://tests/hit_reaction_presentation.gd
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
