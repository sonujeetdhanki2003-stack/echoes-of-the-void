extends Node
## Diagnostic 1.9.4 (bug 8 / 4 / 14): fixed camera spots in the start area. --driver=bugshot194 --out=<dir>
const SHOTS := [
	["cryo", Vector3(17.0, 1.6, 6.0), Vector3(22.0, 3.5, 6.0), "decon_light_22"],
	["cryo", Vector3(14.0, 1.6, 6.0), Vector3(14.0, 3.5, 6.0), "decon_light_14"],
	["cryo", Vector3(9.0, 1.6, 6.0), Vector3(22.0, 3.0, 6.0), "decon_from_bay"],
	["cryo", Vector3(3.6, 1.6, 6.0), Vector3(11.0, 3.4, 6.0), "start_look_hall"],
]
func _ready() -> void:
	var out := Game.arg("out", "/tmp")
	await get_tree().process_frame
	Game.SAVE_PATH = "user://bugshot194.json"
	Game.delete_save()
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["touch"] = "off"
	Game.settings["subtitles"] = false
	get_window().size = Vector2i(1280, 720)
	Game.apply_settings()
	var cur := ""
	for s in SHOTS:
		if s[0] != cur:
			cur = s[0]
			await GameMode.load_area(cur, cur + "_start", true)
			for i in 10:
				await get_tree().process_frame
		var cam := Camera3D.new()
		GameMode.area.add_child(cam)
		cam.global_position = s[1]
		cam.look_at(s[2], Vector3.UP)
		cam.fov = 70.0
		cam.make_current()
		for i in 6:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("%s/%s.png" % [out, s[3]])
		print("SAVED ", s[3])
		cam.queue_free()
	Game.delete_save()
	get_tree().quit(0)
