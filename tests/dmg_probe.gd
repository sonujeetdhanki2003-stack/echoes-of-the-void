extends Node
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.state["mission"] = 1
	await GameMode.load_area(Game.arg("area", "research"), Game.arg("area", "research") + "_start", true)
	for w in GameMode.area.B.wall_edges:
		if w["piece"] == "kit_wall_damaged":
			print("DMG pos ", w["pos"], " in ", w["in"], " along ", w["along"], " room ", w["room"])
	get_tree().quit()
