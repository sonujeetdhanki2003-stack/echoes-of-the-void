extends Node
## Diagnostic 1.9.5 (bug 8): every emissive mesh and multimesh instance within 2.5 m of the fallen beam (16, 1.3, 6).
##   godot --headless --fixed-fps 60 -- --driver=bug8probe
const C := Vector3(16.0, 1.3, 6.0)
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("cryo", "cryo_start", true)
	for i in 10:
		await get_tree().physics_frame
	var root := get_tree().root
	for mmi in root.find_children("*", "MultiMeshInstance3D", true, false):
		var m := mmi as MultiMeshInstance3D
		if m.multimesh == null or m.multimesh.mesh == null:
			continue
		var mname := ""
		var mesh := m.multimesh.mesh
		var mats := []
		for s in mesh.get_surface_count():
			var mt := mesh.surface_get_material(s)
			mats.append(mt.resource_name if mt else "none")
		var seen := 0
		for i in m.multimesh.instance_count:
			var g := m.global_transform * m.multimesh.get_instance_transform(i)
			if g.origin.distance_to(C) < 2.5:
				seen += 1
				print("MMHIT %s[%d] mesh=%s mats=%s at (%.2f, %.2f, %.2f) scale=(%.2f,%.2f,%.2f)" % [m.name, i, mesh.resource_name, str(mats), g.origin.x, g.origin.y, g.origin.z, g.basis.get_scale().x, g.basis.get_scale().y, g.basis.get_scale().z])
		if seen > 0:
			print("MMNODE %s count=%d hits=%d parent=%s" % [m.name, m.multimesh.instance_count, seen, m.get_parent().name])
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m2 := mi as MeshInstance3D
		if m2.global_position.distance_to(C) > 2.5 or m2.mesh == null:
			continue
		var mts := []
		for s2 in m2.mesh.get_surface_count():
			var mt2 := m2.get_active_material(s2)
			mts.append(mt2.resource_name if mt2 else "none")
		print("MESHNEAR %s parent=%s at (%.2f, %.2f, %.2f) aabb=%s mats=%s" % [m2.name, m2.get_parent().name, m2.global_position.x, m2.global_position.y, m2.global_position.z, str(m2.get_aabb().size), str(mts)])
	get_tree().quit(0)
