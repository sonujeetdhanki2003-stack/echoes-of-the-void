extends Node
## Diagnostic probe (1.9.2): prints the world AABB and colliders of named props in one area.
##   godot ... -- --driver=probe2 --area=cryo --names=lab_table_clutter,desk
func _ready() -> void:
	await get_tree().process_frame
	var area_id := Game.arg("area", "cryo")
	var names := Game.arg("names", "").split(",", false)
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area(area_id, area_id + "_start", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	for n in GameMode.area.find_children("*", "Node3D", true, false):
		var nm: String = n.get_meta("prop") if n.has_meta("prop") else str(n.name)
		if not (nm in names):
			continue
		var aabb := AABB()
		var first := true
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			if m.mesh == null:
				continue
			var g := m.global_transform * m.mesh.get_aabb()
			aabb = g if first else aabb.merge(g)
			first = false
		var cols := n.find_children("*", "CollisionShape3D", true, false)
		var cinfo := []
		for c in cols:
			var cs := c as CollisionShape3D
			cinfo.append("%s@%s" % [cs.shape.get_class() if cs.shape else "none", str(cs.global_position)])
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var mm := mi as MeshInstance3D
			print("  MESH %s local=%s aabb=%s" % [mm.name, str(mm.position), str(mm.get_aabb())])
		print("PROBE %s pos=%s aabb_min=%s aabb_max=%s colliders=%s" % [nm, str(n.global_position), str(aabb.position), str(aabb.end), str(cinfo)])
	get_tree().quit(0)
