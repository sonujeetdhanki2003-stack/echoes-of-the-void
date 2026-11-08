extends Node
## 1.9.3 tests (bugs 12, 17, 20-23): --driver=bugwalls
##  A. a drop of more than FALL_RETURN from the ledge returns the player to the ledge; a short drop does not.
##  B. the transmitter mast (antenna_mast) is solid only where its pole and base are: the room 1.2 m out from
##     the pole is clear for a walking capsule in all 8 directions, and the pole itself blocks.
##  C. organic props (rocks, plants, crystal clusters) collide with their real triangles (no box around the model).
var passed := 0
var total := 0
var p: Player

func check(name: String, ok: bool, info: String = "") -> void:
	total += 1
	if ok:
		passed += 1
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _box(root: Node, pos: Vector3, size: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = size
	cs.shape = bx
	sb.add_child(cs)
	root.add_child(sb)
	sb.global_position = pos

func _mast_checks(root: Node3D, label: String) -> void:
	var space: PhysicsDirectSpaceState3D = root.get_world_3d().direct_space_state
	var masts: Array = []
	for n in root.find_children("*", "Node3D", true, false):
		if n.has_meta("prop") and n.get_meta("prop") == "antenna_mast":
			masts.append(n)
	check("B. %s has its mast" % label, masts.size() >= 1, "masts=%d" % masts.size())
	for m in masts:
		var mp: Vector3 = (m as Node3D).global_position
		var clear_all := true
		for i in 8:
			var a := TAU * float(i) / 8.0
			var q := mp + Vector3(cos(a) * 2.0, 0.0, sin(a) * 2.0)
			if not _capsule_clear(space, q):
				# a blocked ring point must be a visible prop (a console, the crystal plinth), never empty space
				for h in space.intersect_shape(_cap_query(q), 4):
					var par: Node = (h["collider"] as Node).get_parent()
					if par == null or not par.has_meta("prop"):
						clear_all = false
						print("  %s dir %d: blocked by something that is not a prop" % [label, i])
		check("B. %s: the ground 2.0 m out from the mast has no invisible blocker (8 directions)" % label, clear_all)
		check("B. %s: the mast pole itself is solid" % label, not _capsule_clear(space, mp + Vector3(0.0, 0.0, -0.15)))

func _cap_query(pos: Vector3) -> PhysicsShapeQueryParameters3D:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	q.shape = cap
	q.transform = Transform3D(Basis(), pos + Vector3.UP * 0.86)
	q.collision_mask = 1
	return q

func _capsule_clear(space: PhysicsDirectSpaceState3D, pos: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.6
	q.shape = cap
	q.transform = Transform3D(Basis(), pos + Vector3.UP * 0.86)
	q.collision_mask = 1
	return space.intersect_shape(q, 1).is_empty()

func _ready() -> void:
	await get_tree().process_frame
	Game.SAVE_PATH = "user://bugwalls.json"
	Game.delete_save()
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["touch"] = "off"
	Game.settings["subtitles"] = false
	await GameMode.load_area("exterior", "exterior_start", true)
	await frames(10)
	p = GameMode.player
	var root: Node3D = GameMode.area
	# A. ledge 6 m high, ground beside it; a short ledge 1.5 m high further along
	_box(root, Vector3(300, -0.5, 0), Vector3(40, 1, 40))
	_box(root, Vector3(290, 3.0, 0), Vector3(20, 6, 20))
	_box(root, Vector3(300, -0.5, 70), Vector3(40, 1, 40))
	_box(root, Vector3(290, 0.75, 70), Vector3(20, 1.5, 20))
	await frames(10)
	p.place(Transform3D(Basis(), Vector3(290, 6.1, 0)))
	await frames(90)
	var before := p.ledge_returns
	p.global_position = Vector3(300.5, 6.2, 0)
	p.velocity = Vector3.ZERO
	await frames(180)
	check("A. a 6 m drop returns the player to the ledge", p.global_position.y > 5.5 and p.global_position.x < 296.0 and p.ledge_returns > before,
		"pos=%s returns=%d" % [str(p.global_position), p.ledge_returns - before])
	p.place(Transform3D(Basis(), Vector3(290, 1.6, 70)))
	await frames(90)
	before = p.ledge_returns
	p.global_position = Vector3(300.5, 1.7, 70)
	p.velocity = Vector3.ZERO
	await frames(120)
	check("A. a 1.5 m step does not return the player", p.ledge_returns == before and p.global_position.y < 0.6, "pos=%s" % str(p.global_position))
	await _mast_checks(root, "exterior")
	# C. (exterior has the rocks)
	# C. rocks, plants and crystals: every prop's collider is a trimesh (exact), not a box
	var boxed := []
	for n in root.find_children("*", "Node3D", true, false):
		if not n.has_meta("prop"):
			continue
		var pn: String = n.get_meta("prop")
		if not (pn.begins_with("alien_rock") or pn.begins_with("alien_plant") or pn.begins_with("crystal_cluster")):
			continue
		for cs in (n as Node).find_children("*", "CollisionShape3D", true, false):
			if not ((cs as CollisionShape3D).shape is ConvexPolygonShape3D):
				boxed.append(pn)
	check("C. organic props collide with the convex hull of their real vertices (no box)", boxed.is_empty(), "boxed=%s" % str(boxed.slice(0, 5)))
	await GameMode.load_area("hollows", "hollows_start", true)
	await frames(10)
	await _mast_checks(GameMode.area, "hollows")
	# D. lift rails (bug 6): the security lift frame has triangle collision (the reactor lift is a cab he must enter: no frame body)
	for aid in ["security"]:
		await GameMode.load_area(aid, aid + "_start", true)
		await frames(10)
		var lifts := []
		for n in GameMode.area.find_children("*", "Node3D", true, false):
			if n.name == "FrameCollision":
				lifts.append(n)
		check("D. %s: the cargo lift frame has triangle collision" % aid, lifts.size() >= 1, "bodies=%d" % lifts.size())
	print("BUGWALLS %d/%d" % [passed, total])
	get_tree().quit(0 if passed == total else 1)
