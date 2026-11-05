extends Node
## Collision test (Sonujeet: "the player must never pass through solid objects"). For every area and every
## checkpoint, the player sprints in 12 directions for 2.5 s using the real movement code. Every physics frame
## the path from the previous position to the new one is ray-checked at knee and chest height against the world
## and enemies: a hit means the player went through something (tunnelling). A shrunken copy of the player's
## capsule must also never overlap world geometry. Then a Stalker and a Brute are placed in the player's path:
## the player must stop at them, not walk through.
##   godot --headless --fixed-fps 60 -- --driver=collide [--areas=cryo,research]
var fails := 0
var checks := 0

func _ready() -> void:
	await get_tree().process_frame
	var areas := Game.arg("areas", "cryo,research,security,reactor,exterior,extraction").split(",", false)
	for a in areas:
		await _area(a)
	print("COLLIDE %d checks, %d failures" % [checks, fails])
	get_tree().quit(0 if fails == 0 else 1)

func _area(id: String) -> void:
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area(id, id + "_start", true)
	var p: Player = GameMode.player
	p.health.dmg_mult = 0.0
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	for n in GameMode.area.find_children("*", "EnemyBase", true, false):
		n.queue_free()
	await get_tree().physics_frame
	var cps: Dictionary = GameMode.area.checkpoints
	var tun := 0
	var ovl := 0
	for cp in cps.keys():
		for d in 12:
			var xf: Transform3D = cps[cp]
			p.place(Transform3D(Basis(), xf.origin + Vector3.UP * 0.1))
			p.velocity = Vector3.ZERO
			p.controller.yaw = d * 30.0
			p.controller.sprint_toggle = true
			for i in 4:
				await get_tree().physics_frame
			var prev := p.global_position
			for f in 150:
				p.touch_move = Vector2(0, 1)
				p.controller.sprint_toggle = true
				await get_tree().physics_frame
				var cur := p.global_position
				checks += 1
				if _ray(p, prev, cur):
					tun += 1
					if tun <= 5:
						print("  TUNNEL %s %s dir=%d %s -> %s" % [id, cp, d, prev, cur])
				if _overlap(p):
					ovl += 1
					if ovl <= 5:
						print("  OVERLAP %s %s dir=%d at %s" % [id, cp, d, cur])
				prev = cur
			p.touch_move = Vector2.ZERO
	print("AREA %s: %d checkpoints x 12 runs, tunnels=%d overlaps=%d" % [id, cps.size(), tun, ovl])
	fails += tun + ovl
	# enemies block the player
	for kind in ["stalker", "brute"]:
		var xf: Transform3D = cps.values()[0]
		p.place(Transform3D(Basis(), xf.origin + Vector3.UP * 0.1))
		p.velocity = Vector3.ZERO
		p.controller.yaw = rad_to_deg(xf.basis.get_euler().y)
		await get_tree().physics_frame
		var fwd := -p.controller.yaw_basis().z
		var e = GameMode.area.enemy(kind, "col_" + kind, p.global_position + fwd * 3.0, 0.0, {})
		if e == null:
			continue
		await get_tree().physics_frame
		e.set_physics_process(false)
		e.perception.enabled = false
		for f in 4:
			await get_tree().physics_frame
		var start := p.global_position
		var closest := 99.0
		for f in 120:
			p.touch_move = Vector2(0, 1)
			await get_tree().physics_frame
			var dd := Vector2(p.global_position.x - e.global_position.x, p.global_position.z - e.global_position.z).length()
			closest = minf(closest, dd)
		p.touch_move = Vector2.ZERO
		var min_ok: float = e.data.radius + Player.RADIUS - 0.08
		checks += 1
		var travelled := Vector2(p.global_position.x - start.x, p.global_position.z - start.z).length()
		var blocked := closest >= min_ok
		print("ENEMY %s %s: closest %.2f (min %.2f) travelled %.2f -> %s" % [id, kind, closest, min_ok, travelled, "OK" if blocked else "PASSED THROUGH"])
		if not blocked:
			fails += 1
		e.queue_free()
		await get_tree().physics_frame

func _ray(p: Player, a: Vector3, b: Vector3) -> bool:
	if a.distance_to(b) < 0.001:
		return false
	var ss := p.get_world_3d().direct_space_state
	for h in [0.45, 1.25]:
		var q := PhysicsRayQueryParameters3D.create(a + Vector3.UP * h, b + Vector3.UP * h, 1 | 4)
		q.exclude = [p.get_rid()]
		q.hit_back_faces = false
		var r := ss.intersect_ray(q)
		if not r.is_empty():
			return true
	return false

func _overlap(p: Player) -> bool:
	var ss := p.get_world_3d().direct_space_state
	var cap := CapsuleShape3D.new()
	cap.radius = Player.RADIUS - 0.08
	cap.height = p.capsule.height - 0.3
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = cap
	q.transform = Transform3D(Basis(), p.global_position + Vector3.UP * (p.capsule.height * 0.5 + 0.05))
	q.collision_mask = 1
	q.exclude = [p.get_rid()]
	return not ss.intersect_shape(q, 1).is_empty()
