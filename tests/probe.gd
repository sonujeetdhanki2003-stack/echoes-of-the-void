extends Node
## Debug probe: load an area at a checkpoint and print the player's position over time.
func _ready() -> void:
	Game.new_state()
	await GameMode.load_area(Game.arg("area", "cryo"), Game.arg("cp", Game.arg("area", "cryo") + "_start"), true)
	var p := GameMode.player
	if Game.arg("pos") != "":
		var s := Game.arg("pos").split(",")
		p.place(Transform3D(Basis(), Vector3(float(s[0]), float(s[1]), float(s[2]))))
	for i in 12:
		await get_tree().create_timer(0.25).timeout
		print("PROBE t=", i, " pos=", p.global_position, " floor=", p.is_on_floor())
	var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 50, p.global_position + Vector3.DOWN * 200, 1)
	print("PROBE ray: ", p.get_world_3d().direct_space_state.intersect_ray(q))
	var line := ""
	for z in range(-60, 110, 10):
		line = "z=%4d " % z
		for x in range(-80, 90, 10):
			var q2 := PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -100, z), 1)
			var h := p.get_world_3d().direct_space_state.intersect_ray(q2)
			line += ("#" if h and h["collider"].name == "TerrainBody" else ("o" if h else ".")) 
		print("GRID ", line)
	get_tree().quit()
