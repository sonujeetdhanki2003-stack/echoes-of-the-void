extends Node
## v1.7.0 stage C tests: the new weapon models (scatter shotgun, precision rifle, Breach Cannon) load as phone-sized
## GLB scenes with a muzzle, and the weapons use them in the game. Optional screenshots with --shots=<dir>. --driver=stage8
var passed := 0
var failed := 0

func check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, "  ", extra)

func _ready() -> void:
	await get_tree().process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			SHOTS = a.substr(8)
	Game.SAVE_PATH = "user://stage8_save.json"
	Game.delete_save()
	Game.settings["touch"] = "off"
	Game.apply_settings()
	var files := {"shotgun": "res://assets/models/shotgun.glb", "precision_rifle": "res://assets/models/precision_rifle.glb",
		"breach_cannon": "res://assets/models/breach_cannon.glb"}
	for k in files.keys():
		var path: String = files[k]
		check("%s.glb is in the project" % k, ResourceLoader.exists(path))
		var sz := FileAccess.get_file_as_bytes(path).size()
		check("%s.glb is phone-sized (%d bytes)" % [k, sz], sz > 1000 and sz < 150000)
		var ps: PackedScene = load(path)
		var inst := ps.instantiate()
		check("%s has a Muzzle node" % k, inst.find_child("Muzzle", true, false) != null)
		check("%s has geometry" % k, inst.find_children("*", "MeshInstance3D", true, false).size() >= 8)
		inst.free()
	var ids := {"shotgun": "shotgun", "precision": "precision", "breach": "breach"}
	await GameMode.load_area("security", "security_start", true)
	await get_tree().process_frame
	var p: Player = GameMode.player
	for id in ids.keys():
		p.combat.give(id, true)
		var w = p.combat.current
		var has_model := w != null and w.model != null and w.model.find_child("Muzzle", true, false) != null
		check("%s is held with its own model" % id, has_model)
		if has_model:
			check("%s muzzle comes from the model" % id, w.muzzle == w.model.find_child("Muzzle", true, false))
		if SHOTS != "":
			await get_tree().create_timer(0.6).timeout
			var img := get_viewport().get_texture().get_image()
			img.save_png(SHOTS + "/" + id + ".png")
	Game.delete_save()
	print("STAGE8 %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)

var SHOTS := ""
