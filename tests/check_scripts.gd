extends Node
## Loads every script in the project and reports which fail to compile (CI-style check).

func _ready() -> void:
	var bad := 0
	var files := _walk("res://scripts")
	files.append_array(_walk("res://tests"))
	for f in files:
		var s: Script = load(f)
		if s == null or not s.can_instantiate():
			bad += 1
			print("FAIL ", f)
	print("CHECKED %d scripts, %d failed" % [files.size(), bad])
	get_tree().quit(1 if bad > 0 else 0)

func _walk(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out.append_array(_walk(dir + "/" + sub))
	return out
