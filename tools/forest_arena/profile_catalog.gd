extends SceneTree

func _initialize() -> void:
	var catalog := LocalPlayCatalog.new()
	var result := {"characters": [], "accessories": []}
	for item: Dictionary in catalog.products:
		result["characters" if item.kind == "character" else "accessories"].append(item.id)
	var path := "res://server/api/src/profile_catalog.json"
	if "--write" in OS.get_cmdline_user_args():
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(result, "  ") + "\n")
		file.close()
		quit(0)
	else:
		var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		var ok: bool = saved == result
		if not ok: push_error("프로필 서버 카탈로그가 게임과 다릅니다. profile_catalog.gd -- --write로 재생성하세요.")
		print("PROFILE_CATALOG: " + ("PASS" if ok else "FAIL"))
		quit(0 if ok else 1)
