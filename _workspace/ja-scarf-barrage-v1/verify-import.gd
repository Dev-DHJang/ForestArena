extends SceneTree
func _initialize() -> void:
	var path := "res://assets/character/ja-hyun/animation/runtime/special_scarf_sweep_32f_barrage-v01.png"
	var raw := Image.load_from_file(path)
	raw.convert(Image.FORMAT_RGBA8)
	var fixed := raw.duplicate() as Image
	fixed.fix_alpha_edges()
	var texture := load(path) as Texture2D
	var imported := texture.get_image()
	if imported.is_compressed(): imported.decompress()
	imported.convert(Image.FORMAT_RGBA8)
	var original := raw.get_data()
	var expected := fixed.get_data()
	var actual := imported.get_data()
	var differences := 0
	var alpha_changes := 0
	var nontransparent_rgb_changes := 0
	for index: int in original.size():
		if original[index]==actual[index]:continue
		differences+=1
		if index%4==3:alpha_changes+=1
		elif original[index-index%4+3]>0:nontransparent_rgb_changes+=1
	var matches := expected==actual
	var result := {"status":"PASS" if matches else "FAIL","source_rgba_bytes":original.size(),"different_components":differences,"alpha_changes":alpha_changes,"nontransparent_rgb_changes":nontransparent_rgb_changes,"all_imported_rgba_equal_to_fix_alpha_edges":matches,"source_png_unchanged":true,"declared_import_option":"process/fix_alpha_border=true"}
	var file := FileAccess.open("res://_workspace/ja-scarf-barrage-v1/qa/import-equivalence-r01.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")+"\n")
	print("BARRAGE_IMPORT_EQUIVALENCE: "+("PASS" if matches else "FAIL"))
	quit(0 if matches else 1)
