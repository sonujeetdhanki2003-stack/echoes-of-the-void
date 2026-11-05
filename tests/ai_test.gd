extends Node
## AI behaviour test (Doc 03 Phase 6): Stalker patrols -> chases -> loses the player -> investigates -> back to
## patrol; Sentinel guards and repositions under pressure; Brute charges. Headless, fixed 60 fps.
##   godot --headless --fixed-fps 60 -- --driver=ai_test
var passed := 0
var total := 0

func check(name: String, ok: bool, info: String = "") -> void:
	total += 1
	if ok:
		passed += 1
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))

func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.state["mission"] = 1
	await GameMode.load_area("research", "research_atrium", true)
	var p: Player = GameMode.player
	p.health.dmg_mult = 0.0
	var s1 = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e.stable_id == "res_s1":
			s1 = e
		elif e.stable_id != "":
			e.queue_free()
	# --- Stalker
	var park := p.global_position + Vector3(0, 60, 0)
	p.place(Transform3D(Basis(), park))       # out of sight while we watch the patrol
	p.set_physics_process(false)
	# the checkpoint is in the stalker's view: start it calm, on its route
	s1.alerted = false
	s1.perception.awareness = 0.0
	GameMode.hunter(s1, false)
	s1.set_state(EnemyBase.State.PATROL)
	var start: Vector3 = s1.global_position
	var walked := 0.0
	var prev: Vector3 = start
	for i in 360:
		await get_tree().physics_frame
		walked += s1.global_position.distance_to(prev)
		prev = s1.global_position
	check("stalker patrols", s1.state in [EnemyBase.State.PATROL, EnemyBase.State.IDLE, EnemyBase.State.INVESTIGATE] and walked > 2.0, "state %d, walked %.1f m in 6 s" % [s1.state, walked])
	p.set_physics_process(true)
	p.place(Transform3D(Basis(), s1.global_position + Vector3(4, 0.2, 0)))
	await _secs(0.2)
	s1.alert()
	var seen_chase := await _until(func(): return s1.state in [EnemyBase.State.CHASE, EnemyBase.State.ATTACK], 4.0)
	check("stalker detects and chases", seen_chase, "state %d" % s1.state)
	p.place(Transform3D(Basis(), park))
	p.set_physics_process(false)
	var inv := await _until(func(): return s1.state == EnemyBase.State.INVESTIGATE, 25.0)
	print("  dbg see=", s1.perception.can_see, " since=", s1.perception.seconds_since_seen(), " d=", s1.global_position.distance_to(p.global_position))
	check("stalker loses the player and investigates", inv, "state %d" % s1.state)
	var back := await _until(func(): return s1.state == EnemyBase.State.PATROL, 20.0)
	check("stalker returns to patrol", back, "state %d" % s1.state)
	s1.queue_free()
	p.set_physics_process(true)
	# --- Sentinel
	var ppos: Vector3 = A().at(3.0, 2.5)
	p.place(Transform3D(Basis(), ppos + Vector3(0, 0.2, 0)))
	await _secs(0.3)
	var sn = A().enemy("sentinel", "ai_sent", ppos + Vector3(0, 0.3, 9.0), 180.0, {})
	await _secs(0.5)
	sn.alert()
	var spos: Vector3 = sn.global_position
	var reps := 0
	var t := 0.0
	var last_state: int = sn.state
	var fired := false
	while t < 14.0:
		await get_tree().physics_frame
		t += 1.0 / 60.0
		if sn.state != last_state and sn.state == EnemyBase.State.REPOSITION:
			reps += 1
		last_state = sn.state
		if sn.get("_charge_t") != null and float(sn.get("_charge_t")) > 0.0:
			fired = true
		# pressure: walk the player around the sentinel
		if int(t * 60.0) % 180 == 0:
			p.place(Transform3D(Basis(), sn.global_position + Vector3(randf_range(-3, 3), 0.2, randf_range(-3, 3))))
	check("sentinel engages at range (charges a burst)", fired)
	check("sentinel repositions", reps >= 1 or sn.global_position.distance_to(spos) > 2.0, "repositions %d, moved %.1f m" % [reps, sn.global_position.distance_to(spos)])
	sn.queue_free()
	# --- stuck recovery: a crate dropped across a patrol route after the navmesh was baked
	p.place(Transform3D(Basis(), ppos + Vector3(0, 60, 0)))
	p.set_physics_process(false)
	var wall := StaticBody3D.new()
	wall.collision_layer = 1
	var wcs := CollisionShape3D.new()
	var wbx := BoxShape3D.new()
	wbx.size = Vector3(5.0, 2.0, 0.6)
	wcs.shape = wbx
	wall.add_child(wcs)
	A().add_child(wall)
	wall.global_position = ppos + Vector3(0, 1.0, 3.0)
	var sk = A().enemy("stalker", "ai_stuck", ppos + Vector3(0, 0.3, 0), 0.0, {"patrol": [ppos + Vector3(0, 0, 0.2), ppos + Vector3(0, 0, 6.5)]})
	await _secs(0.3)
	sk.alerted = false
	sk.perception.awareness = 0.0
	sk.set_state(EnemyBase.State.PATROL)
	sk._patrol_i = 1
	EnemyBase.debug_ai = true
	var recovered := await _until(func(): return sk.stuck_events >= 1 and sk._patrol_i != 1, 8.0)
	check("stuck enemy recovers (skips the blocked patrol point)", recovered, "stuck events %d, patrol index %d" % [sk.stuck_events, sk._patrol_i])
	await _secs(0.1)
	var lbl: Label3D = sk.get("_dbg")
	check("AI debug overlay shows state", lbl != null and lbl.visible and lbl.text.contains("STALKER") and lbl.text.contains("STUCK"), lbl.text.replace("\n", " | ") if lbl else "no label")
	EnemyBase.debug_ai = false
	sk.queue_free()
	wall.queue_free()
	p.set_physics_process(true)
	# --- Brute (open ground: the exterior canyon)
	Game.state["mission"] = 3
	await GameMode.load_area("exterior", "exterior_start", true)
	for e in get_tree().get_nodes_in_group("enemy"):
		e.queue_free()
	p = GameMode.player
	p.health.dmg_mult = 0.0
	await _secs(0.5)
	var fwd := -p.global_transform.basis.z
	var bpos: Vector3 = p.global_position + fwd * 13.0
	bpos.y = A().terrain.height_at(bpos.x, bpos.z) + 0.3
	var br = A().enemy("brute", "ai_brute", bpos, rad_to_deg(p.rotation.y) + 180.0, {})
	await _secs(0.5)
	br.alert()
	var charged := await _until(func(): return br.get("_attack") in ["charge_start", "charge"], 15.0)
	check("brute charges", charged, "state %d attack %s dist %.1f sees %s" % [br.state, br.get("_attack"), br.global_position.distance_to(p.global_position), br.perception.can_see])
	print("AITEST %d/%d passed" % [passed, total])
	get_tree().quit()

func A():
	return GameMode.area

func _secs(s: float) -> void:
	var t := 0.0
	while t < s:
		await get_tree().physics_frame
		t += 1.0 / 60.0

func _until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += 1.0 / 60.0
	return cond.call()
