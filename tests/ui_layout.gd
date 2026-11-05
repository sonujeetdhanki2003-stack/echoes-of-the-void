extends Node
## Touch HUD layout check at phone sizes: subtitles vs touch controls.  --driver=ui_layout
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["touch"] = "on"
	Game.apply_settings()
	await GameMode.load_area("cryo", "cryo_hub", true)
	var ui = GameMode.ui
	var bad := 0
	for sz in [Vector2i(1600, 720), Vector2i(2400, 1080), Vector2i(1280, 720), Vector2i(1920, 1080)]:
		get_window().size = sz
		Game.apply_settings()
		await get_tree().process_frame
		ui.hud_visible(true)
		ui.relayout_hud()
		Events.subtitle.emit("TEST", "This is the Orpheus relay. If anyone can hear this, the signal is still going out. Whatever happened down there, we're coming. Hold on, we are almost in range.", 3.0)
		for i in 4:
			await get_tree().process_frame
		var vr: Rect2 = ui.get_viewport().get_visible_rect()
		var sr: Rect2 = ui.sub_box.get_global_rect()
		print("SIZE ", sz, " visible ", vr.size, " scale ", get_window().content_scale_factor, " sub ", sr)
		for b in ui.touch.find_children("*", "Control", true, false):
			var bc: Control = b
			if bc.visible and bc.size.x > 20.0 and bc.size.x < 500.0 and bc.name.begins_with("Touch"):
				var hit: bool = bc.get_global_rect().intersects(sr)
				print("   ", bc.name, " ", bc.get_global_rect(), " HIT" if hit else "")
				if hit:
					bad += 1
	print("UILAYOUT overlaps=", bad)
	get_tree().quit()
