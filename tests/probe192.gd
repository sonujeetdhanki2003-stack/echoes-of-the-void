extends Node
## Diagnostic (1.9.2 bugs 12/20/17): colliders with no visible mesh overlapping their box, per area.
func _ready() -> void:
	var ids := ["cryo", "security", "reactor", "research", "hollows", "extraction", "exterior"]
	for id in ids:
		await _area(id)
	get_tree().quit(0)

func _area(id: String) -> void:
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area(id, id + "_start", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var root: Node = GameMode.area
	var meshes := []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh != null and m3.is_visible_in_tree():
			meshes.append(m3)
	var n_inv := 0
	for cs in root.find_children("*", "CollisionShape3D", true, false):
		var c := cs as CollisionShape3D
		if c.shape == null or c.disabled:
			continue
		var body := c.get_parent()
		if not (body is StaticBody3D or body is AnimatableBody3D):
			continue
		var sz := Vector3.ZERO
		if c.shape is BoxShape3D:
			sz = (c.shape as BoxShape3D).size
		elif c.shape is CylinderShape3D:
			sz = Vector3(2.0 * (c.shape as CylinderShape3D).radius, (c.shape as CylinderShape3D).height, 2.0 * (c.shape as CylinderShape3D).radius)
		elif c.shape is SphereShape3D:
			sz = Vector3.ONE * 2.0 * (c.shape as SphereShape3D).radius
		else:
			sz = Vector3(-1, -1, -1)
		var wpos := c.global_position
		var box := AABB(wpos - sz * 0.5 * c.global_transform.basis.get_scale(), sz * c.global_transform.basis.get_scale())
		var covered := false
		for m in meshes:
			var ma: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			if ma.grow(0.3).intersects(box):
				covered = true
				break
		if not covered:
			n_inv += 1
			print("INVIS %s body=%s shape=%s pos=(%.2f,%.2f,%.2f) size=(%.2f,%.2f,%.2f)" % [id, body.name, c.shape.get_class(), wpos.x, wpos.y, wpos.z, sz.x, sz.y, sz.z])
	print("AREA %s invisible=%d meshes=%d" % [id, n_inv, meshes.size()])
