extends Node
## v1.1.0 screenshot pass for the release gallery (not a pass/fail test): --driver=s1shots --out=<dir>
func _ready() -> void:
	var out := Game.arg("out", "/tmp")
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["touch"] = "off"
	get_window().size = Vector2i(1600, 900)
	Game.apply_settings()
	await GameMode.load_area("cryo", "cryo_hub", true)
	var ui = GameMode.ui
	for cfg in [["medium", false], ["large", true]]:
		Game.settings["subtitle_size"] = cfg[0]
		Game.settings["subtitle_bg"] = cfg[1]
		Events.subtitle.emit("MIRA", "This is the Orpheus relay. If anyone can hear this, the signal is still going out.", 30.0)
		for i in 6:
			await get_tree().process_frame
		_save(out + "/subtitles-%s-%s.png" % [cfg[0], "bg" if cfg[1] else "nobg"])
	Events.subtitle.emit("", "", 0.0)
	Game.settings["subtitle_size"] = "medium"
	Game.settings["subtitle_bg"] = false
	for i in 2:
		await get_tree().process_frame
	ui.open_settings("settings")
	for i in 8:
		await get_tree().process_frame
	_save(out + "/settings-page.png")
	get_tree().quit(0)

func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path)
