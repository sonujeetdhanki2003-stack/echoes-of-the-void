extends Area
## A2 — RESEARCH WING (Mission 2 part 1, LOST RESEARCH). Clinical white labs gone wrong: a two-storey specimen atrium,
## Iyer's lab, Stalker patrols, the code clues (Okoye's lockdown log + Iyer's "April seventeenth"), and the
## Security Sector gate keypad (SECURITY CODE puzzle, 0417).

var gate: SecurityGate

func build() -> void:
	setup_theme("research", 202)
	# ---- layout ----
	B.room("entry", 0, 1, 1, 3, {"light_energy": 0.8})
	B.room("atrium", 1, 0, 4, 5, {"h": 2})
	B.room("lab_a", 5, 0, 3, 2)
	B.room("lab_b", 5, 3, 3, 2, {"light_energy": 0.5})
	B.room("hall", 8, 2, 3, 1, {"light_energy": 0.7})
	B.room("gatehall", 11, 1, 3, 3, {"h": 2, "light_energy": 0.8})
	B.room("beyond", 14, 2, 1, 1, {"lights": false})
	B.open(Vector2i(0, 2), "e", "open")
	B.open(Vector2i(0, 3), "e", "open")
	door("lab_a", Vector2i(4, 1), "e")
	door("lab_b", Vector2i(4, 3), "e")
	door("atrium_hall", Vector2i(4, 2), "e", {"stays_open": false})
	B.room("a_link", 5, 2, 3, 1, {"light_energy": 0.6})
	B.open(Vector2i(7, 2), "e", "open")
	door("lab_a_link", Vector2i(6, 1), "s")
	B.open(Vector2i(10, 2), "e", "open")
	B.open(Vector2i(13, 2), "e", "open")
	B.open(Vector2i(2, 4), "s", "window")
	B.open(Vector2i(6, 0), "n", "window")
	B.build()
	_props()
	_lighting()
	_story()
	checkpoint("research_start", at(0.5, 3.5), 0.0)
	checkpoint("research_atrium", at(3.0, 2.5), -90.0, Vector3(4, 3, 4))
	checkpoint("research_gate", at(11.6, 2.5), -90.0, Vector3(3, 3, 4))
	exit_zone("to_security", at(14.6, 2.5), Vector3(2.0, 3.0, 3.5), "security", "security_start", "puzzle.security_code")

func _props() -> void:
	# atrium: rows of specimen tubes, some shattered, lab benches, a crystal bloom where the worst breach was
	var tubes := [[2.0, 1.0, false], [3.0, 1.0, true], [4.0, 1.0, false], [2.0, 4.0, true], [3.0, 4.0, false], [4.0, 4.0, true]]
	for t in tubes:
		prop("containment_tube_broken" if t[2] else "containment_tube", at(t[0], t[1]), 0.0)
	prop("lab_table_clutter", at(2.4, 2.5), 90.0)
	prop("lab_table", at(3.6, 2.5), 90.0)
	prop("lab_equipment", at(3.6, 3.2), 0.0)
	prop("crystal_cluster_a", at(4.2, 2.3), 40.0)
	prop("crystal_cluster_c", at(4.5, 2.9), 10.0)
	prop("corpse_prone", at(1.6, 3.0), 120.0, true)
	prop("server_rack", at(1.15, 0.6), 90.0)
	prop("server_rack", at(1.15, 1.0), 90.0)
	prop("console_large", at(1.4, 4.6), 180.0)
	prop("debris_pile", at(2.8, 3.4), 0.0, true, 0.6)
	cover_point(at(2.4, 2.0))
	cover_point(at(3.6, 3.6))
	# lab A: Iyer's office
	prop("desk", at(6.0, 0.4), 0.0)
	prop("monitor", at(6.0, 0.4) + Vector3(0, 0.8, 0), 0.0, false)
	prop("chair", at(6.0, 0.8), 160.0)
	prop("lab_equipment", at(7.6, 0.5), -90.0)
	prop("containment_tube", at(7.5, 1.5), 0.0)
	prop("crystal_cluster_c", at(7.5, 1.5) + Vector3(0, 0.0, 0), 0.0, true, 0.6)
	prop("locker", at(5.2, 1.6), 90.0)
	# lab B: specimen storage
	for x in [5.6, 6.6, 7.6]:
		prop("containment_tube_broken" if x > 6.0 else "containment_tube", at(x, 4.6), 180.0)
	prop("lab_table_clutter", at(6.5, 3.6), 0.0)
	prop("crate_large", at(7.4, 3.4), 20.0)
	prop("corpse_sitting", at(5.4, 3.3), 90.0, true)
	# link corridor / hall
	prop("crate_small", at(6.1, 2.2), 10.0)
	prop("pipe_straight", at(9.5, 2.1) + Vector3(0, 3.3, 0), 90.0, false)
	prop("barrel", at(10.6, 2.8), 0.0)
	# gate hall: guard post
	prop("desk", at(12.0, 1.4), 90.0)
	prop("terminal", at(12.0, 1.9), 90.0)
	prop("chair", at(11.6, 1.6), -90.0)
	prop("turret_broken", at(13.4, 1.4), -90.0)
	prop("crate_large", at(12.0, 3.6), 0.0)
	prop("crate_small", at(13.3, 3.7), 30.0)
	cover_point(at(12.0, 3.2))
	gate = SecurityGate.new()
	add_child(gate)
	gate.global_position = at(14.0, 2.5)
	gate.rotation.y = -PI * 0.5
	var kp := Keypad.new()
	kp.stable_id = "security_keypad"
	add_child(kp)
	kp.global_position = at(13.85, 1.8)
	kp.rotation.y = -PI * 0.5
	label3d("SECURITY SECTOR", at(13.95, 2.5) + Vector3(0, 5.6, 0), -90.0, 96, Color(1.0, 0.75, 0.3))
	label3d("LOCKDOWN — OVERRIDE REQUIRED", at(13.95, 2.5) + Vector3(0, 5.15, 0), -90.0, 48, Color(1.0, 0.3, 0.25))
	# pickups
	pickup("ammo_pistol", "res_a1", at(2.4, 2.4) + Vector3(0, 0.95, 0), 12)
	pickup("ammo_pistol", "res_a2", at(7.2, 3.6) + Vector3(0, 0.95, 0), 12)
	pickup("ammo_pistol", "res_a3", at(12.0, 1.0) + Vector3(0, 0.8, 0), 18)
	pickup("medkit", "res_m1", at(6.0, 1.2))
	pickup("medkit", "res_m2", at(9.2, 2.8))
	var st := AmmoStation.new()
	add_child(st)
	st.global_position = at(11.15, 3.0)
	st.rotation.y = PI * 0.5
	# logs: 4 atrium console, 5 + 6 Iyer's office, 7 the guard desk
	log_at(4, at(1.6, 4.4) + Vector3(0, 0.95, 0))
	log_at(5, at(6.0, 0.5) + Vector3(0, 0.82, 0.2))
	log_at(6, at(7.2, 1.0))
	log_at(7, at(12.2, 1.4) + Vector3(0, 0.82, 0))

func _lighting() -> void:
	room_lights("entry", 2, 0.8)
	room_lights("atrium", 2, 0.75, true, 0.15)
	room_lights("lab_a", 2, 0.9)
	room_lights("lab_b", 2, 0.5, true, 0.5)
	room_lights("a_link", 2, 0.6)
	room_lights("hall", 2, 0.6, true, 0.3)
	room_lights("gatehall", 2, 0.7)
	# atrium: shafts from the upper gantry, a sick violet glow from the crystal bloom
	spot(at(3.0, 2.5) + Vector3(0, 7.6, 0), at(3.0, 2.5), Color(0.9, 0.95, 1.0), 5.0, 12.0, 50.0, true)
	omni(at(4.3, 2.5) + Vector3(0, 1.0, 0), Color(0.65, 0.3, 1.0), 2.4, 7.0)
	omni(at(7.5, 1.5) + Vector3(0, 1.4, 0), Color(0.6, 0.3, 1.0), 1.2, 4.0)
	# gate: amber warning beacons
	for z in [1.2, 3.8]:
		omni(at(13.6, z) + Vector3(0, 4.6, 0), Color(1.0, 0.55, 0.15), 1.8, 8.0, false, 0.5)

func _story() -> void:
	trigger("res_enter", at(0.5, 2.5), Vector3(4, 3, 4), func(_p): beat("research", "mira_research", 1.0))
	trigger("res_gate_seen", at(11.8, 2.5), Vector3(4, 3, 10), func(_p):
		Game.set_flag("seen.security_gate")
		Events.message.emit("Find the security override code", 3.0))
	Events.flag_set.connect(func(f):
		if f == "puzzle.security_code":
			Sfx.say("mira_code_ok", true)
			GameMode.save_checkpoint("research_gate"))
	# Stalkers: two prowl the atrium, one waits in lab B, two come for the player at the gate hall
	enemy("stalker", "res_s1", at(3.0, 1.8), 0.0, {"patrol": [at(2.0, 2.5), at(4.4, 2.0), at(4.4, 3.8), at(2.0, 3.6)]})
	enemy("stalker", "res_s2", at(2.0, 3.8), 90.0, {"patrol": [at(1.5, 3.8), at(4.5, 4.4)]})
	enemy("stalker", "res_s3", at(7.0, 3.5), -90.0)
	var g1 := enemy("stalker", "res_s4", at(12.5, 3.5), -90.0, {"dormant": true})
	var g2 := enemy("stalker", "res_s5", at(13.0, 1.6), -90.0, {"dormant": true})
	# capture instance ids, not the nodes: either stalker may be dead and freed before the player gets here
	var amb_ids := [g1.get_instance_id() if g1 else 0, g2.get_instance_id() if g2 else 0]
	trigger("res_gate_ambush", at(10.0, 2.5), Vector3(4, 3, 4), func(_p):
		for eid in amb_ids:
			var e = instance_from_id(eid) if eid != 0 and is_instance_id_valid(eid) else null
			if e:
				Fx.burst(e.global_position + Vector3.UP, Color(0.7, 0.75, 0.8), 0.6, 20)
				e.awaken(true)
		Sfx.play_at("vent_burst", at(12.8, 2.5) + Vector3.UP * 3.0, 2.0, 40.0))

func on_enter(fresh: bool) -> void:
	super.on_enter(fresh)
	tension = true
