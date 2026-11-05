extends Node
## Records one cinematic through the movie writer:  --driver=cinerec --cine=wake|signal|reveal|climax|ending
func _ready() -> void:
	await get_tree().process_frame
	Game.settings["subtitles"] = not Game.has_arg("clean")   # --clean: no subtitles / skip hint (trailer footage)
	var which := Game.arg("cine", "wake")
	Game.new_state()
	var len := 16.0
	match which:
		"wake":
			Game.state["mission"] = 0
			await GameMode.load_area("cryo", "cryo_start", true)
			len = 15.0
		"signal":
			Game.state["flags"]["cine.wake"] = true
			Game.state["mission"] = 1
			Game.state["flags"]["enc.brute"] = true
			await GameMode.load_area("security", "security_corr", true)
			_clear()
			GameMode.area._dead_signal()
			len = 23.0
		"reveal":
			Game.state["flags"]["cine.wake"] = true
			Game.state["mission"] = 2
			await GameMode.load_area("reactor", "reactor_start", true)
			_clear()
			GameMode.area._reveal()
			len = 17.0
		"climax":
			Game.state["flags"]["cine.wake"] = true
			Game.state["mission"] = 3
			await GameMode.load_area("extraction", "extraction_pad", true)
			_clear()
			GameMode.area._climax()
			len = 15.0
		"endstate":     # memory check: the ending's area state without the cinematic
			Game.state["flags"]["cine.wake"] = true
			Game.state["flags"]["transmission.sent"] = true
			Game.state["flags"]["boss.dead"] = true
			Game.state["mission"] = 3
			await GameMode.load_area("extraction", "extraction_pad", true)
			_clear()
			len = 8.0
		"ending":
			Game.state["flags"]["cine.wake"] = true
			Game.state["flags"]["transmission.sent"] = true
			Game.state["flags"]["boss.dead"] = true
			Game.state["mission"] = 3
			await GameMode.load_area("extraction", "extraction_pad", true)
			_clear()
			GameMode.area._ending()
			len = 36.0
	await get_tree().create_timer(len).timeout
	print("CINEREC done ", which)
	get_tree().quit()

func _process(_d: float) -> void:
	if Game.has_arg("clean") and GameMode.ui and GameMode.ui.get("skip_lbl"):
		GameMode.ui.skip_lbl.visible = false
		var sb = GameMode.ui.get_node_or_null("SkipButton")
		if sb:
			sb.visible = false

func _clear() -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
