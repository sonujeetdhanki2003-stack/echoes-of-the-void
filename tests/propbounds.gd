extends Node
## Diagnostic (1.9.3): prints the model bounds of props and per-mesh AABBs (--driver=propbounds --names=a,b)
func _ready() -> void:
	await get_tree().process_frame
	var names := Game.arg("names", "antenna_mast,alien_rock_d,alien_plant_a,alien_plant_b,alien_plant_c,alien_rock_a,alien_rock_b,alien_rock_c,crystal_cluster_a,crystal_cluster_b,crystal_cluster_c").split(",", false)
	for n in names:
		var inst := Props.instance(n)
		add_child(inst)
		var b := Props.bounds(inst)
		print("PB %s size=(%.2f,%.2f,%.2f) pos=(%.2f,%.2f,%.2f)" % [n, b.size.x, b.size.y, b.size.z, b.position.x, b.position.y, b.position.z])
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null: continue
			var a := m.mesh.get_aabb()
			print("   mesh %s verts=%d aabb=(%.2f,%.2f,%.2f)@(%.2f,%.2f,%.2f) xf=%s" % [m.name, m.mesh.get_faces().size() / 3, a.size.x, a.size.y, a.size.z, a.position.x, a.position.y, a.position.z, str(m.transform.origin)])
		inst.queue_free()
	get_tree().quit(0)
