extends Node
## Systematic exploration (v1.0.1). For every area, with all doors open:
##  1. a physical flood fill (capsule sweeps against the real collision, 0.5 m grid, step-up, jump and crouch
##     rules like the player's) from the start checkpoint finds every spot the player can stand on;
##  2. every checkpoint, pickup, log, console, generator, trigger zone and exit must be reachable;
##  3. the REAL player is then walked, with real movement input, along the flood-fill route to each checkpoint
##     and exit and must arrive;
##  4. every enemy spawn must be clear of the level geometry.
##   godot --headless --fixed-fps 60 -- --driver=explore [--areas=cryo,research] [--cell=0.5]
var fails := 0
var checks := 0
var cell := 0.5
const RADIUS := 0.34
const HEIGHT := 1.8
const CROUCH_H := 1.15
var space: PhysicsDirectSpaceState3D
var stand_shape := CapsuleShape3D.new()
var crouch_shape := CapsuleShape3D.new()

func _ready() -> void:
	cell = float(Game.arg("cell", "0.5"))
	stand_shape.radius = RADIUS
	stand_shape.height = HEIGHT
	crouch_shape.radius = RADIUS
	crouch_shape.height = CROUCH_H
	await get_tree().process_frame
	var areas := Game.arg("areas", "cryo,research,security,reactor,exterior,extraction").split(",", false)
	for a in areas:
		await _area(a)
	print("EXPLORE %d checks, %d failures" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)

func ok(name: String, cond: bool, extra: String = "") -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FAIL ", name, "  ", extra)

func _key(x: int, z: int) -> int:
	return (x + 20000) * 40000 + (z + 20000)

func _floor_y(x: float, z: float, from_y: float, up: float, down: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, from_y + up, z), Vector3(x, from_y - down, z), 1)
	var r := space.intersect_ray(q)
	return r["position"].y if not r.is_empty() else NAN

## capsule (bottom at y+lift) free at this spot?
func _free(shape: CapsuleShape3D, pos: Vector3, lift: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), pos + Vector3.UP * (lift + shape.height * 0.5))
	q.collision_mask = 1
	q.margin = 0.0
	return space.intersect_shape(q, 1).is_empty()

func _sweep_ok(shape: CapsuleShape3D, a: Vector3, b: Vector3, lift: float) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), a + Vector3.UP * (lift + shape.height * 0.5))
	q.motion = b - a
	q.collision_mask = 1
	var r := space.cast_motion(q)
	return r.size() >= 2 and r[0] >= 0.999

## can the player move from a (standing on floor ya) to neighbour b? Returns the floor height or NAN.
func _step(a: Vector3, nx: float, nz: float) -> Dictionary:
	var yb := _floor_y(nx, nz, a.y, 1.0, 1.6)
	if is_nan(yb):
		return {}
	var dy := yb - a.y
	if dy > 0.7 or dy < -1.4:
		return {}
	var b := Vector3(nx, yb, nz)
	# the floor between must not rise above the lower of the two by more than a step (no climbing a wall)
	var mid := _floor_y((a.x + nx) * 0.5, (a.z + nz) * 0.5, maxf(a.y, yb), 0.9, 2.4)
	if is_nan(mid) or mid > maxf(a.y, yb) + 0.45:
		return {}
	var lift := 0.12 + maxf(0.0, dy)
	for sh in [stand_shape, crouch_shape]:
		var hop := Vector3(a.x, maxf(a.y, yb), a.z)
		var hop2 := Vector3(nx, maxf(a.y, yb), nz)
		if _free(sh, hop, 0.12 + (maxf(a.y, yb) - maxf(a.y, yb))) and _sweep_ok(sh, hop, hop2, 0.12) and _free(sh, b, 0.1):
			return {"y": yb, "crouch": sh == crouch_shape}
	return {}

## Jump over a gap in the floor along a cardinal direction (player: ~3 m running, ~4.5 m sprinting).
func _jump(a: Vector3, d: Vector2i) -> Dictionary:
	var gx0 := roundi(a.x / cell)
	var gz0 := roundi(a.z / cell)
	for n in range(2, 8):
		var gx := gx0 + d.x * n
		var gz := gz0 + d.y * n
		var yb := _floor_y(gx * cell, gz * cell, a.y, 0.7, 1.6)
		if is_nan(yb) or absf(yb - a.y) > 0.5:
			continue
		var b := Vector3(gx * cell, yb, gz * cell)
		var hop := Vector3(a.x, maxf(a.y, yb), a.z)
		if _sweep_ok(stand_shape, hop, Vector3(b.x, hop.y, b.z), 0.45) and _free(stand_shape, b, 0.1):
			return {"y": yb, "gx": gx, "gz": gz}
	return {}

func _area(id: String) -> void:
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area(id, id + "_start", true)
	var p: Player = GameMode.player
	var A: Area = GameMode.area
	p.health.dmg_mult = 0.0
	# enemies: check spawns are clear, then remove them so they do not interfere
	space = A.get_world_3d().direct_space_state
	var bad_spawns := 0
	var spawns := 0
	for e in A.find_children("*", "EnemyBase", true, false):
		spawns += 1
		var en: Node3D = e
		var ok_sp := _free(stand_shape, en.global_position + Vector3.UP * 0.0, 0.15)
		if not ok_sp:
			bad_spawns += 1
			print("  ENEMY SPAWN INSIDE GEOMETRY ", id, " ", e.get("stable_id"), " at ", en.global_position)
		ok("spawn clear " + id + " " + str(e.get("stable_id")), ok_sp)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	for n in A.find_children("*", "EnemyBase", true, false):
		n.queue_free()
	for d in A.find_children("*", "Door", true, false):
		var door: Door = d
		door.lock_flag = ""
		door.keycard = ""
		door.travel_area = ""
		door.stays_open = true
		door._open = 1.0
		door._target = 1.0
		door._apply()
	for g in A.find_children("*", "SecurityGate", true, false):
		g.open_gate()
		g.col.disabled = true
	for i in 10:
		await get_tree().physics_frame
	for t in A.find_children("*", "TriggerZone", true, false):
		if (t as TriggerZone).stable_id.begins_with("exit."):
			(t as TriggerZone).fired = true      # walking into an exit would load the next area
	for i in 4:
		await get_tree().physics_frame
	space = A.get_world_3d().direct_space_state
	# ---- flood fill from the start checkpoint
	var cps: Dictionary = A.checkpoints
	var start: Vector3 = (cps[id + "_start"] as Transform3D).origin if cps.has(id + "_start") else (cps.values()[0] as Transform3D).origin
	var sy := _floor_y(start.x, start.z, start.y + 0.3, 1.0, 3.0)
	start.y = sy if not is_nan(sy) else start.y
	var seen := {}
	var parent := {}
	var cells := {}       # key -> Vector3
	var q: Array = [start]
	var sk := _key(roundi(start.x / cell), roundi(start.z / cell))
	cells[sk] = start
	seen[sk] = true
	var head := 0
	var t0 := Time.get_ticks_msec()
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	var cap := int(Game.arg("cap", "400000"))
	while head < q.size() and q.size() < cap:
		var c: Vector3 = q[head]
		head += 1
		var ck := _key(roundi(c.x / cell), roundi(c.z / cell))
		for d in dirs:
			var gx: int = roundi(c.x / cell) + d.x
			var gz: int = roundi(c.z / cell) + d.y
			var k := _key(gx, gz)
			if seen.has(k) and not (d.x * d.y == 0 and is_nan(_floor_y(gx * cell, gz * cell, c.y, 1.0, 1.6))):
				continue
			var r := _step(c, gx * cell, gz * cell)
			if r.is_empty() and d.x * d.y == 0 and is_nan(_floor_y(gx * cell, gz * cell, c.y, 1.0, 1.6)):
				r = _jump(c, d)       # a gap in the floor: jump across it
				if not r.is_empty():
					gx = int(r["gx"])
					gz = int(r["gz"])
					k = _key(gx, gz)
					if seen.has(k):
						continue
			if r.is_empty():
				continue
			seen[k] = true
			var nb := Vector3(gx * cell, float(r["y"]), gz * cell)
			cells[k] = nb
			parent[k] = ck
			q.append(nb)
		if head % 2000 == 0:
			await get_tree().process_frame
	print("FLOOD %s: %d cells (%.0f m2) in %.1fs" % [id, q.size(), q.size() * cell * cell, (Time.get_ticks_msec() - t0) / 1000.0])
	ok("flood fill finished " + id, head >= q.size(), "capped at %d" % cap)
	# ---- targets
	var targets: Array = []
	for cp in cps.keys():
		targets.append(["checkpoint " + cp, (cps[cp] as Transform3D).origin, 0.9, true])
	for n in get_tree().get_nodes_in_group("interactable"):
		if not (n is Node3D) or not A.is_ancestor_of(n) or n is Door:
			continue
		var rng: float = n.interact_range() if n.has_method("interact_range") else 2.2
		targets.append(["%s %s" % [n.get_script().get_global_name(), str(n.get("stable_id"))], (n as Node3D).global_position, maxf(rng - 0.4, 0.8), false])
	for t in A.find_children("*", "TriggerZone", true, false):
		var tz: TriggerZone = t
		var base: Vector3 = tz.global_position - Vector3.UP * tz.size.y * 0.5
		var ex: bool = tz.stable_id.begins_with("exit.")
		targets.append(["trigger " + tz.stable_id, base, maxf(minf(tz.size.x, tz.size.z) * 0.5, 0.5), ex])
	var unreach := 0
	var routes: Array = []
	for t in targets:
		if (t[1] as Vector3).y < start.y - 1.5:
			print("  (skipped, below the floor: ", t[0], ")")
			continue
		var best_k := -1
		var best_d := INF
		var tp: Vector3 = t[1]
		for k in cells.keys():
			var c: Vector3 = cells[k]
			var dh := Vector2(c.x - tp.x, c.z - tp.z).length()
			if dh < best_d and absf(c.y - tp.y) < 2.2:
				best_d = dh
				best_k = k
		var reached: bool = best_k != -1 and best_d <= float(t[2]) + cell
		if not reached:
			unreach += 1
			var sq := PhysicsShapeQueryParameters3D.new()
			var sph := SphereShape3D.new()
			sph.radius = 0.25
			sq.shape = sph
			sq.transform = Transform3D(Basis(), tp + Vector3.UP * 0.4)
			sq.collision_mask = 1
			var hits := space.intersect_shape(sq, 3)
			var inside := not hits.is_empty()
			for h in hits:
				var cn: Node = h["collider"]
				var chain := ""
				var nn: Node = cn
				for kk in 5:
					if nn == null:
						break
					chain += str(nn.name) + " < "
					nn = nn.get_parent()
				print("     overlaps: ", chain, " at ", (cn as Node3D).global_position if cn is Node3D else "?")
			var gy := _floor_y(tp.x, tp.z, tp.y, 3.0, 6.0)
			print("  UNREACHABLE ", id, " ", t[0], " at ", tp, " nearest reachable spot ", ("%.1f m away at %s" % [best_d, str(cells[best_k])]) if best_k != -1 else "none", " | inside geometry: ", inside, " | ground y here: ", gy)
		ok("reachable " + id + " " + t[0], reached)
		if reached and t[3]:
			routes.append([t[0], best_k])
	print("AREA %s: %d targets, %d unreachable, %d enemy spawns (%d inside geometry)" % [id, targets.size(), unreach, spawns, bad_spawns])
	# ---- walk the real player along the route to each checkpoint / exit
	var walked_ok := 0
	var cur_key := sk
	for r in routes:
		if int(Game.arg("walk", "1")) == 0:
			break
		var chain: Array = []
		var k: int = r[1]
		while k != sk and parent.has(k):
			chain.append(cells[k])
			k = parent[k]
		chain.reverse()
		p.place(Transform3D(Basis(), start + Vector3.UP * 0.1))
		for i in 4:
			await get_tree().physics_frame
		var res := await _walk(p, chain)
		ok("walk route to " + r[0] + " (" + id + ")", res == "ok", res + " at " + str(p.global_position))
		if res == "ok":
			walked_ok += 1
		else:
			print("  WALK ", res, " ", id, " ", r[0], " player at ", p.global_position, " route end ", chain.back() if chain.size() > 0 else "-")
	print("WALK %s: %d/%d routes walked with real input" % [id, walked_ok, routes.size()])

## Walk the player along a list of cells. "ok" when the last one is reached, else "stuck"/"fell".
func _walk(p: Player, chain: Array) -> String:
	var i := 0
	var last := p.global_position
	var stuck_t := 0.0
	var t := 0.0
	var y0 := p.global_position.y
	var limit := chain.size() * cell / 2.5 + 10.0
	var jump_t := 0.0
	while t < limit and chain.size() > 0:
		var pos := p.global_position
		if pos.y < y0 - 12.0:
			p.touch_move = Vector2.ZERO
			return "fell"
		# aim at a cell a little ahead so corners are cut like a player would
		while i < chain.size() - 1 and Vector2(chain[i].x - pos.x, chain[i].z - pos.z).length() < 0.55 and not (i + 1 < chain.size() and Vector2(chain[i].x - chain[i + 1].x, chain[i].z - chain[i + 1].z).length() > cell * 1.8 and p.is_on_floor() and false):
			i += 1
		var gap_next: bool = i < chain.size() - 1 and Vector2(chain[i].x - chain[i + 1].x, chain[i].z - chain[i + 1].z).length() > cell * 1.8
		var look := mini(i + 2, chain.size() - 1) if not gap_next else i + 1
		var tgt: Vector3 = chain[look]
		var to := tgt - pos
		if i >= chain.size() - 1 and Vector2(to.x, to.z).length() < 0.5:
			p.touch_move = Vector2.ZERO
			return "ok"
		p.controller.yaw = rad_to_deg(atan2(-to.x, -to.z))
		p.touch_move = Vector2(0, 1)
		p.controller.sprint_toggle = gap_next
		if gap_next and Vector2(chain[i].x - pos.x, chain[i].z - pos.z).length() < 0.75 and p.is_on_floor():
			p.request_jump()
		# crouch where the route needs it (a low ceiling), jump where it climbs
		var want_crouch := not _free(stand_shape, Vector3(pos.x, pos.y, pos.z) + Vector3(to.x, 0, to.z).normalized() * 0.5, 0.1)
		if want_crouch != p.crouching:
			p.set_crouch(want_crouch)
		if tgt.y - pos.y > 0.25 and p.is_on_floor():
			p.request_jump()
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		stuck_t += dt
		if stuck_t >= 2.0:
			if Vector2(p.global_position.x - last.x, p.global_position.z - last.z).length() < 0.3:
				p.touch_move = Vector2.ZERO
				return "stuck"
			last = p.global_position
			stuck_t = 0.0
	p.touch_move = Vector2.ZERO
	var end: Vector3 = chain.back() if chain.size() > 0 else p.global_position
	return "ok" if Vector2(p.global_position.x - end.x, p.global_position.z - end.z).length() < 1.2 else "stuck"
