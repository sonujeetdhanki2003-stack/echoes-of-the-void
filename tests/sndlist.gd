extends Node
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.state["mission"] = 1
	await GameMode.load_area(Game.arg("area", "security"), Game.arg("cp", "security_corr"), true)
	await get_tree().create_timer(1.5).timeout
	for n in get_tree().root.find_children("*", "", true, false):
		if (n is AudioStreamPlayer or n is AudioStreamPlayer3D) and n.playing:
			var d := -1.0
			if n is AudioStreamPlayer3D and GameMode.player:
				d = n.global_position.distance_to(GameMode.player.global_position)
			print("PLAYING ", n.get_path(), " ", n.stream.resource_path.get_file() if n.stream else "", " bus=", n.bus, " vol=", n.volume_db, " dist=", d)
	get_tree().quit()
