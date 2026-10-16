class_name UiResourcePreparer
extends Node
## Threaded loads stay alive here so menu builders never reload weak cache entries.
signal progress_changed(value: float)
var retained: Dictionary = {}
var error := ""
var generation := 0

func prepare(paths: Array[String]) -> bool:
	generation += 1
	var ticket := generation
	error = ""
	var unique: Array[String] = []
	for path: String in paths:
		if path not in unique: unique.append(path)
	for index: int in unique.size():
		var path := unique[index]
		if not retained.has(path):
			if path.is_empty() or not ResourceLoader.exists(path):
				error = "필요한 파일을 찾을 수 없습니다: " + path.get_file()
				return false
			var request := ResourceLoader.load_threaded_request(path)
			if request != OK:
				error = "파일 준비를 시작하지 못했습니다: " + path.get_file()
				return false
			while ticket == generation:
				var fraction: Array = []
				var status := ResourceLoader.load_threaded_get_status(path, fraction)
				if status == ResourceLoader.THREAD_LOAD_LOADED:
					retained[path] = ResourceLoader.load_threaded_get(path)
					break
				if status != ResourceLoader.THREAD_LOAD_IN_PROGRESS:
					error = "파일을 읽지 못했습니다: " + path.get_file()
					return false
				progress_changed.emit((index + (float(fraction[0]) if not fraction.is_empty() else 0.0)) / maxi(unique.size(), 1))
				await get_tree().process_frame
			if ticket != generation: return false
		progress_changed.emit(float(index + 1) / maxi(unique.size(), 1))
	progress_changed.emit(1.0)
	return true

func cancel() -> void:
	generation += 1

static func ui_paths(prefixes: Array[String]) -> Array[String]:
	var result: Array[String] = []
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://forest_arena/data/resource_registry.json"))
	if not document is Dictionary: return result
	for asset: Dictionary in document.get("assets", []):
		for prefix: String in prefixes:
			if String(asset.get("id", "")).begins_with(prefix):
				var path: String = ForestArenaResources.resource_path(String(asset.id))
				if not path.is_empty() and path not in result: result.append(path)
				break
	return result
