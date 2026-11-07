extends Node
## Walk-reach audit (1.9.2): flood-fill walkable ground from each area's start (capsule cast_motion,
## 0.5 m cells, 0.45 m steps). Reports (a) colliders that stop the walk with standable ground beyond,
## with a visible-mesh check, and (b) POCKETS: ground reached by a drop from the main route that has no
## walk back up (a player who falls in there is stuck). Run:
##   godot --headless --fixed-fps 60 -- --driver=walkgrid --areas=hollows,extraction
const CELL := 0.5
const RAD := 0.3
const HGT := 1.6
const MAXC := 90000
const POCKET_MAX := 6000
var area_ids := []
var space: PhysicsDirectSpaceState3D
var shape: CapsuleShape3D
var DIRS := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

func _ready() -> void:
	area_ids = ["cryo", "security", "reactor", "research", "hollows", "extraction", "exterior"]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--areas="):
			area_ids = a.substr(8).split(",")
	shape = CapsuleShape3D.new()
	shape.radius = RAD
	shape.height = HGT
	for id in area_ids:
		await _area(id)
	print("WALKGRID DONE")
	get_tree().quit(0)

func _floor(x: float, z: float, y0: float, depth: float = 2.5) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, y0 + 2.5, z), Vector3(x, y0 - depth, z), 1)
	var h: Dictionary = space.intersect_ray(q)
	if h.is_empty():
		return NAN
	return (h["position"] as Vector3).y

func _clear(x: float, y: float, z: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), Vector3(x, y + 0.06 + HGT * 0.5, z))
	q.collision_mask = 1
	return space.intersect_shape(q, 1).is_empty()

# a walk that may also go down (falls) to ground up to 30 m below, for pocket search
func _step_drop(c: Vector2i, y1: float, n: Vector2i) -> float:
	var s := _step(c, y1, n, {})
	if not is_nan(s):
		return s
	var fd := _floor(n.x * CELL, n.y * CELL, y1, 30.0)
	if not is_nan(fd) and fd < y1 - 0.45 and _clear(n.x * CELL, fd, n.y * CELL):
		return fd
	return NAN

# returns the floor height at the neighbour if the capsule can walk there from (c, y1), else NAN
func _step(c: Vector2i, y1: float, n: Vector2i, blockers: Dictionary) -> float:
	var x1 := c.x * CELL
	var z1 := c.y * CELL
	var x2 := n.x * CELL
	var z2 := n.y * CELL
	var y2 := _floor(x2, z2, y1)
	if is_nan(y2) or absf(y2 - y1) > 0.45:
		if not is_nan(y2):
			blockers["SLOPE"] = blockers.get("SLOPE", 0) + 1
		return NAN
	if not _clear(x2, y2, z2):
		return NAN
	for lift in [0.05, 0.4]:
		var qm := PhysicsShapeQueryParameters3D.new()
		qm.shape = shape
		qm.transform = Transform3D(Basis(), Vector3(x1, y1 + lift + HGT * 0.5, z1))
		qm.motion = Vector3(x2 - x1, 0, z2 - z1)
		qm.collision_mask = 1
		var r := space.cast_motion(qm)
		if r.size() == 2 and r[0] >= 0.999:
			return y2
		if lift == 0.05 and r.size() == 2:
			var hit := PhysicsShapeQueryParameters3D.new()
			hit.shape = shape
			var f: float = r[1] + 0.05
			hit.transform = Transform3D(Basis(), Vector3(x1 + (x2 - x1) * f, y1 + 0.05 + HGT * 0.5, z1 + (z2 - z1) * f))
			hit.collision_mask = 1
			for h in space.intersect_shape(hit, 4):
				var col: Object = h["collider"]
				if col is Node3D:
					var key := str((col as Node3D).get_path())
					blockers[key] = blockers.get(key, 0) + 1
	return NAN

func _area(id: String) -> void:
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area(id, id + "_start", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var root: Node = GameMode.area
	space = root.get_world_3d().direct_space_state
	var vis: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m3 := mi as MeshInstance3D
		if m3.mesh != null and m3.is_visible_in_tree():
			vis.append(m3.global_transform * m3.get_aabb().get_center())
	for mm in root.find_children("*", "MultiMeshInstance3D", true, false):
		var mmi := mm as MultiMeshInstance3D
		if mmi.multimesh == null or not mmi.is_visible_in_tree():
			continue
		for i in mmi.multimesh.instance_count:
			vis.append(mmi.global_transform * mmi.multimesh.get_instance_transform(i).origin)
	var start: Vector3 = (GameMode.area as Area).checkpoint_xform(id + "_start").origin
	var sy := _floor(start.x, start.z, start.y)
	if is_nan(sy):
		print("WALKGRID %s no floor at start" % id)
		return
	var reach := {}
	var q: Array = [Vector2i(roundi(start.x / CELL), roundi(start.z / CELL))]
	reach[q[0]] = sy
	var blocked := {}
	var drops := []
	var head := 0
	while head < q.size() and reach.size() < MAXC:
		var c: Vector2i = q[head]
		head += 1
		var y1: float = reach[c]
		for d in DIRS:
			var n: Vector2i = c + d
			if reach.has(n):
				continue
			var y2 := _step(c, y1, n, blocked)
			if not is_nan(y2):
				reach[n] = y2
				q.append(n)
			else:
				var fd := _floor(n.x * CELL, n.y * CELL, y1, 30.0)
				if not is_nan(fd) and fd < y1 - 0.45 and _clear(n.x * CELL, fd, n.y * CELL):
					drops.append([c, n])
	# pockets: each drop landing that cannot walk back to the main reach
	var checked := {}
	var pockets := 0
	var trapped := 0
	for dp in drops:
		var land: Vector2i = dp[1]
		if reach.has(land) or checked.has(land):
			continue
		var ly := _floor(land.x * CELL, land.y * CELL, reach.get(dp[0], sy) - 1.0, 30.0)
		var pq: Array = [land]
		var seen := {land: ly}
		var ph := 0
		var back := false
		while ph < pq.size() and seen.size() < POCKET_MAX and not back:
			var c2: Vector2i = pq[ph]
			ph += 1
			for d in DIRS:
				var n2: Vector2i = c2 + d
				if seen.has(n2):
					continue
				if reach.has(n2):
					back = true
					break
				var y3 := _step_drop(c2, seen[c2], n2)
				if not is_nan(y3):
					seen[n2] = y3
					pq.append(n2)
		for k in seen.keys():
			checked[k] = true
		pockets += 1
		if not back:
			trapped += 1
			var cx := 0.0
			var cz := 0.0
			for k in seen.keys():
				cx += k.x * CELL
				cz += k.y * CELL
			var nn := maxf(1.0, float(seen.size()))
			print("TRAPPED %s pocket cells=%d centre=(%.1f,%.1f,%.1f) drop_from=(%.1f,%.1f) drop_to_floor=%.2f" % [id, seen.size(), cx / nn, ly, cz / nn, dp[0].x * CELL, dp[0].y * CELL, ly])
	# blocked walls with no visible mesh within 1 m
	var rows := []
	for k in blocked.keys():
		var kk := str(k)
		if not kk.begins_with("/") or "Terrain" in kk:
			continue
		var node := root.get_node_or_null(NodePath(kk))
		if node == null or not (node is Node3D):
			continue
		var cen := (node as Node3D).global_position
		var seen2 := false
		for p in vis:
			if (p as Vector3).distance_to(cen) < 1.0:
				seen2 = true
				break
		if not seen2:
			var pm := "-"
			if node.get_parent() and node.get_parent().has_meta("prop"):
				pm = str(node.get_parent().get_meta("prop"))
			rows.append("INVISBLOCK %s %s prop=%s pos=(%.2f,%.2f,%.2f) hits=%d" % [id, kk.get_file(), pm, cen.x, cen.y, cen.z, blocked[k]])
	for r in rows:
		print(r)
	print("SLOPE_EDGES %s %d" % [id, blocked.get("SLOPE", 0)])
	print("WALKGRID %s reach=%d drops=%d pockets=%d trapped=%d invisible_blockers=%d" % [id, reach.size(), drops.size(), pockets, trapped, rows.size()])
