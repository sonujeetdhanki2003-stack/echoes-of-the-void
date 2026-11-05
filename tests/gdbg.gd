extends Node
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.state["mission"] = 1
	await GameMode.load_area("security", "security_corr", true)
	var a = GameMode.area
	for c in [Vector2i(13, 1), Vector2i(14, 1), Vector2i(15, 1), Vector2i(14, 0), Vector2i(14, 2), Vector2i(12,1), Vector2i(11,1)]:
		print("CDBG cell ", c, " room ", a.B.cells.get(c))
	var con = a.find_child("comms_console*", true, false)
	for n in a.find_children("*", "", true, false):
		if str(n.name).begins_with("comms") or str(n.name).contains("console"):
			if n is Node3D:
				print("CDBG node ", n.name, " pos ", n.global_position, " fwd(-Z) ", -n.global_basis.z)
	print("CDBG con at ", a.at(14.4, 2.0), " room ", a.B.rooms.get(a.B.cells.get(Vector2i(13,1))))
	get_tree().quit()
