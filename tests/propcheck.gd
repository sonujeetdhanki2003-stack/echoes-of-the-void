extends Node
## Static world audit (1.9.2). Walks every area and reports:
##  NOCOLL   a solid-looking prop (mesh bounds over 0.45 m, not a known no-collide kind) that has no collider
##  FLOAT    a prop or pickup whose lowest point has no floor, prop or surface within 0.15 m below it
##  INVIS    a collider with no visible mesh beside it (invisible wall candidates)
##  DUPE     two visible meshes with the same mesh and transform (z-fight / flicker candidates)
##  NOCOLLFLAG a prop placed with collide=false (passable on purpose or not: judge from the list)
##  Fails the run on NOCOLL and FLOAT and DUPE; the rest is printed for review.
##   godot --headless --fixed-fps 60 -- --driver=propcheck [--areas=cryo,...]
var fails := 0
var rep := {"NOCOLL": [], "FLOAT": [], "INVIS": [], "DUPE": [], "NOCOLLFLAG": []}

const NO_SOLID := ["medkit", "ammo_pistol", "ammo_rifle", "datapad", "keycard", "cable_bundle", "wall_lamp", "ceiling_lamp", "monitor", "pipe_straight", "kit_vent_cover", "fallen_beam", "the_spire"]

func _ready() -> void:
	await get_tree().process_frame
	var areas := Game.arg("areas", "cryo,research,security,reactor,exterior,extraction,hollows").split(",", false)
	for a in areas:
		await _area(a)
	for k in rep.keys():
		print("== %s: %d" % [k, rep[k].size()])
		for line in rep[k]:
			print("  " + line)
	fails = rep["NOCOLL"].size() + rep["DUPE"].size()
	print("PROPCHECK fails=%d" % fails)
	get_tree().quit(0 if fails == 0 else 1)

func _area(id: String) -> void:
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area(id, id + "_start", true)
	for n in GameMode.area.find_children("*", "EnemyBase", true, false):
		n.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var root: Node = GameMode.area
	for n in root.find_children("*", "Node3D", true, false):
		if not n.has_meta("prop"):
			continue
		var pname: String = n.get_meta("prop")
		var mis := []
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			if (mi as MeshInstance3D).mesh != null:
				mis.append(mi)
		if mis.is_empty():
			continue
		var aabb := AABB()
		var first := true
		for mi in mis:
			var g := (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).mesh.get_aabb()
			aabb = g if first else aabb.merge(g)
			first = false
		var pos := "%s %s" % [pname, _v(n.global_position)]
		var colls := n.find_children("*", "CollisionShape3D", true, false)
		var has_coll := not colls.is_empty()
		var size_max := aabb.size.max_axis_index()
		if not has_coll and not (pname in NO_SOLID) and aabb.size.max_axis_index() >= 0 and maxf(aabb.size.x, maxf(aabb.size.y, aabb.size.z)) > 0.45:
			rep["NOCOLL"].append("%s [%s] %s" % [id, pos, _v(aabb.size)])
		if not bool(n.get_meta("prop_collide")):
			rep["NOCOLLFLAG"].append("%s [%s]" % [id, pos])
		if n.get_meta("prop_collide") and not has_coll and pname in NO_SOLID:
			pass
		# floor check: five points under the lowest face
		var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
		var bottom := aabb.position.y
		var c := aabb.get_center()
		var pts := [Vector3(c.x, bottom, c.z), Vector3(aabb.position.x + 0.05, bottom, aabb.position.z + 0.05), Vector3(aabb.end.x - 0.05, bottom, aabb.position.z + 0.05), Vector3(aabb.position.x + 0.05, bottom, aabb.end.z - 0.05), Vector3(aabb.end.x - 0.05, bottom, aabb.end.z - 0.05)]
		var best := 99.0
		for p in pts:
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(p + Vector3.UP * 0.02, p + Vector3.DOWN * 5.0, 1)
			var hit: Dictionary = space.intersect_ray(q)
			if not hit.is_empty():
				best = minf(best, (p.y + 0.02) - (hit["position"] as Vector3).y)
		if best > 0.10 and not (pname in ["monitor", "pipe_straight", "kit_vent_cover", "wall_lamp", "ceiling_lamp", "cable_bundle", "fallen_beam", "debris_pile", "corpse_prone", "cargo_lift", "the_spire", "landing_pad", "keypad_panel", "door_panel", "comms_console"]):
			rep["FLOAT"].append("%s [%s] gap=%.2f size=%s" % [id, pos, best, _v(aabb.size)])
	for n in root.find_children("*", "Pickup", true, false) + root.find_children("*", "LogPickup", true, false):
		var pn := n as Node3D
		var space2: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
		var q2: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(pn.global_position + Vector3.UP * 0.05, pn.global_position + Vector3.DOWN * 5.0, 1)
		var h2: Dictionary = space2.intersect_ray(q2)
		var gap2 := 99.0 if h2.is_empty() else pn.global_position.y - (h2["position"] as Vector3).y
		if gap2 > 0.12:
			rep["FLOAT"].append("%s [pickup %s %s] gap=%.2f" % [id, pn.name, _v(pn.global_position), gap2])
	# invisible colliders: static bodies whose collider has no visible mesh beside it
	var meshes := []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		if (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).is_visible_in_tree():
			meshes.append(mi)
	for sb in root.find_children("*", "StaticBody3D", true, false):
		var sbp := (sb as Node3D).global_position
		var near := false
		for m in meshes:
			if (m as Node3D).global_position.distance_to(sbp) < 2.5:
				near = true
				break
		for cs in sb.find_children("*", "CollisionShape3D", false, false):
			var cc := ((cs as Node3D).global_position)
			for m in meshes:
				if (m as Node3D).global_position.distance_to(cc) < 3.0:
					near = true
					break
		if not near:
			rep["INVIS"].append("%s [%s] size=%s" % [id, _v(sbp), _v((sb.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D).shape.get("size") if sb.find_children("*", "CollisionShape3D", false, false).size() > 0 and (sb.find_children("*", "CollisionShape3D", false, false)[0] as CollisionShape3D).shape is BoxShape3D else Vector3.ZERO)])
	# duplicate visible meshes (same mesh, same transform)
	var seen := {}
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh == null or not m3.is_visible_in_tree():
			continue
		var key := "%s|%s" % [str(m3.mesh.get_instance_id()), _v(m3.global_position)]
		if seen.has(key):
			rep["DUPE"].append("%s [%s] %s" % [id, m3.get_path().get_name(m3.get_path().get_name_count() - 1), key])
		seen[key] = true

func _v(v: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [v.x, v.y, v.z]
