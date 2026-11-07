extends Node
## Diagnostic screenshots at fixed camera spots (1.9.2): --driver=bugshot --out=<dir>
## SHOTS: [area, camera pos, look-at, file]
const SHOTS := [
	["hollows", Vector3(4.0, 1.6, -31.0), Vector3(4.0, 0.5, -40.0), "rock_d_from_south"],
	["hollows", Vector3(-12.0, 1.6, -40.0), Vector3(4.0, 0.5, -40.0), "rock_d_from_west"],
	["hollows", Vector3(-17.0, 1.6, -54.0), Vector3(-20.3, 0.7, -58.9), "crystal_b"],
	["hollows", Vector3(-6.0, 1.6, -88.0), Vector3(-2.3, 1.3, -93.4), "crystal_a"],
]
func _ready() -> void:
	var out := Game.arg("out", "/tmp")
	await get_tree().process_frame
	Game.SAVE_PATH = "user://bugshot.json"
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
