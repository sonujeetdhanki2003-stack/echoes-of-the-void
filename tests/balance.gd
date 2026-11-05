extends Node
## Balance probe: a bot with phone-like aim error (gaussian jitter) fights live enemies on NORMAL in the open
## Research atrium. It stands its ground, aims at the body centre, fires, reloads. Reports time-to-kill, damage
## taken and ammo used per scenario (the player is kept alive so the whole fight is measured).
##   godot --headless --fixed-fps 60 -- --driver=balance [--jitter=2.5] [--diff=normal]
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 1234
	await get_tree().process_frame
	Game.settings["difficulty"] = Game.arg("diff", "normal")
	var scen := [["stalker"], ["stalker", "stalker", "stalker"], ["sentinel"], ["sentinel", "sentinel"], ["brute"], ["brute", "stalker", "stalker"]]
	if Game.arg("only") != "":
		scen = [Game.arg("only").split("+")]
	for s in scen:
		for weapon in ["rifle", "pistol"]:
			if weapon == "pistol" and s.size() > 1:
				continue
			await _trial(s, weapon)
	get_tree().quit()

func _trial(kinds: Array, weapon: String) -> void:
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.state["mission"] = 1
	await GameMode.load_area(Game.arg("area", "exterior"), Game.arg("cp", "exterior_start"), true)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	await get_tree().physics_frame
	var p: Player = GameMode.player
	p.combat.give(weapon)
	p.inventory.add_ammo(weapon, 999)
	var hp0 := p.health.hp
	var acc := {"taken": 0.0, "heals": 0}
	p.health.damaged.connect(func(a, _i): acc["taken"] += a)
	var fwd := -p.global_transform.basis.z
	var right := p.global_transform.basis.x
	var es: Array = []
	var i := 0
	for k in kinds:
		var pos: Vector3 = p.global_position + fwd * (float(Game.arg("dist", "12")) + i * 1.5) + right * (i - 1) * 2.5
		if GameMode.area.get("terrain"):
			pos.y = GameMode.area.terrain.height_at(pos.x, pos.z) + 0.3
		var e = GameMode.area.enemy(k, "bal_%d" % i, pos, 180.0 + rad_to_deg(p.rotation.y), {"alerted": true})
		es.append(e)
		i += 1
	await get_tree().create_timer(0.5).timeout
	var t := 0.0
	var shots := 0
	var mag0: int = p.combat.current.mag
	var jit := float(Game.arg("jitter", "2.5"))
	while t < 60.0:
		var alive: Array = es.filter(func(e): return is_instance_valid(e) and not e.dead)
		if alive.is_empty():
			break
		alive.sort_custom(func(a, b): return a.global_position.distance_to(p.global_position) < b.global_position.distance_to(p.global_position))
		var tgt: Vector3 = alive[0].global_position + Vector3.UP * alive[0].data.height * 0.55
		var from: Vector3 = p.controller.cam.global_position
		var d := (tgt - from).normalized()
		p.controller.yaw = rad_to_deg(atan2(-d.x, -d.z)) + rng.randfn(0.0, jit)
		p.controller.pitch = clampf(rad_to_deg(asin(d.y)) + rng.randfn(0.0, jit), -60.0, 60.0)
		p.controller.aim_toggle = true
		if int(t * 60.0) % 300 == 10:
			var q := PhysicsRayQueryParameters3D.create(from, from + d * 60.0, 1 | 4 | 8)
			q.collide_with_areas = true
			q.exclude = [p.get_rid()]
			var h := p.get_world_3d().direct_space_state.intersect_ray(q)
			print("  ray t=%.1f -> %s %s  tgt %s  enemy-dist %.1f" % [t, h.get("collider"), h.get("position"), tgt, alive[0].global_position.distance_to(p.global_position)])
		var w = p.combat.current
		var before: int = w.mag
		p.combat.touch_fire = (weapon == "rifle") or (int(t * 60.0) % 18 < 2)
		if w.mag == 0 and not w.reloading:
			p.combat.reload()
		if p.health.hp < 30.0:
			p.health.heal(100.0)
			acc["heals"] += 1
		await get_tree().physics_frame
		if w.mag < before:
			shots += before - w.mag
		t += get_physics_process_delta_time()
	p.combat.touch_fire = false
	for e in es:
		if is_instance_valid(e):
			print("  ", e.data.id if e.data else "?", " hp ", e.health.hp, "/", e.health.max_hp, " state ", e.state, " pos d=", e.global_position.distance_to(p.global_position))
	var kills := es.filter(func(e): return not is_instance_valid(e) or e.dead).size()
	print("BALANCE %-24s %-6s kills %d/%d  time %5.1fs  dmg taken %5.0f (would-die x%d)  shots %d" % [",".join(kinds), weapon, kills, kinds.size(), t, acc["taken"], acc["heals"], shots])
