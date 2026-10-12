extends SceneTree
func _initialize() -> void:
 var script=load('res://scripts/audio_director.gd')
 var failures: Array[String]=[]
 var tests=[
  [PackedStringArray(['--qa-run=manual_123']),true,'user://qa/manual_123/audio.cfg'],
  [PackedStringArray(['--qa-run=manual_123']),false,'user://forest_arena_audio.cfg'],
  [PackedStringArray([]),true,'user://forest_arena_audio.cfg'],
  [PackedStringArray(['--qa-run=../bad']),true,'user://forest_arena_audio.cfg'],
  [PackedStringArray(['--qa-run=one','--qa-run=two']),true,'user://forest_arena_audio.cfg']]
 for case: Array in tests:
  if script.debug_settings_path(case[0],case[1])!=case[2]: failures.append('audio QA storage guard failed')
 for failure: String in failures: push_error(failure)
 print('ANDROID_AUDIO_STORE: '+('PASS' if failures.is_empty() else 'FAIL'))
 quit(0 if failures.is_empty() else 1)
