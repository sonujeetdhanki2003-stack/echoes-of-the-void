extends Node
## Diagnostic 1.9.5 (bug 8): world bounds of the EmitLight surface of fallen_beam, and whether geometry sits behind it.
##   godot --headless --fixed-fps 60 -- --driver=bug8probe_b
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("cryo", "cryo_start", true)
	for i in 10:
		await get_tree().physics_frame
	var space := get_tree().root.get_world_3d().direct_space_state
	for mi in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.get_parent() == null or not str(m.get_parent().name).begins_with("fallen_beam"):
			continue
		for s in m.mesh.get_surface_count():
			var mt := m.get_active_material(s)
			var nm := mt.resource_name if mt else ""
			var arrs := m.mesh.surface_get_arrays(s)
			var verts: PackedVector3Array = arrs[Mesh.ARRAY_VERTEX]
			var lo := Vector3(1e9, 1e9, 1e9)
			var hi := Vector3(-1e9, -1e9, -1e9)
			for v in verts:
				var g := m.global_transform * v
				lo = lo.min(g)
				hi = hi.max(g)
			print("BEAMSURF %s[%d] %s verts=%d world_lo=(%.2f, %.2f, %.2f) world_hi=(%.2f, %.2f, %.2f)" % [m.name, s, nm, verts.size(), lo.x, lo.y, lo.z, hi.x, hi.y, hi.z])
			if nm == "EmitLight":
				var c := (lo + hi) * 0.5
				var q := PhysicsRayQueryParameters3D.create(c, c + Vector3.DOWN * 3.0)
				q.collision_mask = 1
				var r := space.intersect_ray(q)
				print("BEAMLIGHT centre=(%.2f, %.2f, %.2f) below_hit=%s" % [c.x, c.y, c.z, str(r.get("position", "none"))])
	get_tree().quit(0)
