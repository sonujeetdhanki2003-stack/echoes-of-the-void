extends Node
## 1.9.4 scene audit (bugs 8, 10): kit pieces and lights in a box around a point. --driver=scene194
## usage: pass --box=x0,x1,y0,y1,z0,z1 after "--" (defaults: the decontamination corridor)
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("cryo", "cryo_hub", true)
	await get_tree().physics_frame
	var area = GameMode.area
	var b = area.B
	var box := [16.0, 24.0, -4.0, 6.0, 3.0, 9.0]
	for s in OS.get_cmdline_user_args():
		if s.begins_with("--box="):
			var parts := s.substr(6).split(",")
			for i in 6: box[i] = float(parts[i])
	print("PLACED ", b.placed.size())
	for e in b.placed:
		var o: Vector3 = (e[1] as Transform3D).origin
		if _in(o, box):
			print("KIT ", e[0], " ", str(o), " yaw=", "%.1f" % rad_to_deg((e[1] as Transform3D).basis.get_euler().y))
	_scan(area, box)
	get_tree().quit(0)

func _in(o: Vector3, box: Array) -> bool:
	return o.x >= box[0] and o.x <= box[1] and o.y >= box[2] and o.y <= box[3] and o.z >= box[4] and o.z <= box[5]

func _scan(n: Node, box: Array) -> void:
	for c in n.get_children():
		if c is Light3D and _in(c.global_position, box):
			print("LIGHT ", c.get_path(), " ", str(c.global_position), " e=%.2f" % c.light_energy, " vis=", c.visible)
		elif c is Decal and _in(c.global_position, box):
			print("DECAL ", c.get_path(), " ", str(c.global_position), " size=", str(c.size), " name=", c.name, " emis=%.2f" % c.emission_energy, " tex=", str(c.texture_emission != null))
		elif c is Node3D and c.name != "Geometry" and not (c is MultiMeshInstance3D):
			if c is MeshInstance3D and _in(c.global_position, box):
				print("MESH ", c.get_path(), " ", str(c.global_position), " vis=", c.is_visible_in_tree())
			elif c is MeshInstance3D:
				pass
		_scan(c, box)
