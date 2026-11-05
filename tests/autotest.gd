extends Node
## Automated playthrough: plays ECHOES OF THE VOID from a new game to the credits, area by area, using the real
## systems (doors, pickups, logs, weapons firing at real enemies, puzzles through their UI, cinematics, saves,
## area travel, the boss). Movement is by teleport; everything else goes through the game's own code paths.
##   godot --headless -- --autotest            (exit code 0 = all checks passed)

var passed := 0
var failed := 0
var fails: Array = []
var t0 := 0
var shots_fired_kills := 0
var forced_kills := 0
# evidence gathered while the run plays (Post-PRD audit): every log pickup seen, each checkpoint's save, stable ids
var log_ids := {}
var cp_snaps := {}          # checkpoint id -> {"text": save json, "mission": int, "objective": String, "area": String}
var _last_save := ""
var _scan_n := 0
var id_areas := {}          # stable id -> {area: true}
var dup_in_area: Array = []
var collecting := true

func _ready() -> void:
	t0 = Time.get_ticks_msec()
	Engine.time_scale = float(Game.arg("speed", "2.0"))
	Game.settings["subtitles"] = true
	await get_tree().process_frame
	await _run()
	var secs := (Time.get_ticks_msec() - t0) / 1000.0
	print("AUTOTEST %d/%d passed in %.1fs (weapon kills %d, forced kills %d)" % [passed, passed + failed, secs, shots_fired_kills, forced_kills])
	for f in fails:
		print("  FAILED: ", f)
	for f in [Game.SAVE_PATH, Game.SAVE_PATH + ".bak", Game.SETTINGS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	get_tree().quit(0 if failed == 0 else 1)

func _physics_process(_d: float) -> void:
	_scan_n += 1
	if not collecting:
		return
	# a new checkpoint save on disk -> keep it (what a player would load from that checkpoint)
	if FileAccess.file_exists(Game.SAVE_PATH):
		var txt := FileAccess.get_file_as_string(Game.SAVE_PATH)
		if txt != _last_save:
			_last_save = txt
			var j: Variant = JSON.parse_string(txt)
			if j is Dictionary and Game._valid(j) and j.get("pos") == null and str(j.get("checkpoint", "")) != "":
				cp_snaps[str(j["checkpoint"])] = {"text": txt, "mission": int(j.get("mission", -1)), "area": str(j["area"]),
					"objective": Missions.objective_text()}
	if _scan_n % 30 != 0 or A() == null or GameMode.loading:
		return
	var here := {}
	for n in get_tree().get_nodes_in_group("interactable") + get_tree().get_nodes_in_group("enemy"):
		if n is LogPickup:
			log_ids[int(n.log_id)] = true
		var sid := str(n.get("stable_id"))
		if sid == "":
			continue
		if here.has(sid) and not sid in dup_in_area:
			dup_in_area.append("%s in %s" % [sid, A().area_id])
		here[sid] = true
		if not id_areas.has(sid):
			id_areas[sid] = {}
		id_areas[sid][A().area_id] = true

func check(name: String, ok: bool) -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		fails.append(name)
		print("FAIL ", name, "  (area=", Game.state.get("area"), " mission=", Game.state.get("mission"), " obj=", Missions.objective_text(), ")")

func wait(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func until(cond: Callable, timeout: float) -> bool:
	var t := 0.0
	while t < timeout:
		if cond.call():
			return true
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	return cond.call()

func P() -> Player:
	return GameMode.player

func A() -> Area:
	return GameMode.area

func god() -> void:
	if P():
		P().health.dmg_mult = 0.0

func tp(pos: Vector3, yaw_deg: float = 0.0) -> void:
	var p := P()
	p.place(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos + Vector3.UP * 0.1))
	p.velocity = Vector3.ZERO
	await frames(3)

func skip_cinematics() -> void:
	for i in 6:
		var c := get_tree().get_first_node_in_group("cinematic")
		if c and c.has_method("skip"):
			c.skip()
		await frames(2)

func find(cls_name: String, id: String = "") -> Node:
	for n in A().find_children("*", "", true, false):
		if n.get_script() and (n.get_script() as Script).get_global_name() == cls_name:
			if id == "" or n.get("stable_id") == id:
				return n
	return null

func use(n: Node) -> void:
	var p := P()
	if n is Node3D:
		var fp: Vector3 = n.focus_point() if n.has_method("focus_point") else (n as Node3D).global_position
		var to := fp - p.global_position
		to.y = 0.0
		var stand := fp - to.normalized() * 1.2 if to.length() > 0.1 else fp + Vector3(1.2, 0, 0)
		stand.y = (n as Node3D).global_position.y
		await tp(stand, rad_to_deg(atan2(-(fp - stand).x, -(fp - stand).z)))
	if n.has_method("can_interact") and not n.can_interact(p):
		return
	n.interact(p)
	await frames(2)

func load_area_wait(area_id: String) -> bool:
	return await until(func(): return A() != null and A().area_id == area_id and GameMode.in_game and not GameMode.loading, 30.0)

## Fight an enemy with the player's weapon: aim the camera at it and hold the trigger. Forces the kill if the
## shots can't finish it in time (geometry in the way) and counts which happened.
func fight(e: Node, max_secs: float = 8.0) -> void:
	if e == null or not is_instance_valid(e) or e.get("dead"):
		return
	var p := P()
	var t := 0.0
	var tgt: Vector3 = e.aim_target()
	var near := tgt + (p.global_position - tgt).normalized() * 6.0
	near.y = e.global_position.y
	await tp(near, rad_to_deg(atan2(-(tgt - near).x, -(tgt - near).z)))
	while t < max_secs and is_instance_valid(e) and not e.get("dead"):
		tgt = e.aim_target()
		var from: Vector3 = p.controller.cam.global_position
		var d := (tgt - from).normalized()
		p.controller.yaw = rad_to_deg(atan2(-d.x, -d.z))
		p.controller.pitch = clampf(rad_to_deg(asin(d.y)), -60.0, 60.0)
		p.controller.aim_toggle = true
		p.combat.touch_fire = true
		var w = p.combat.current
		if w and w.mag == 0 and not w.reloading:
			p.combat.reload()
		if p.inventory.reserve.get(w.data.ammo_type, 0) < 10 if w else false:
			p.inventory.add_ammo(w.data.ammo_type, 60)
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
	p.combat.touch_fire = false
	p.controller.aim_toggle = false
	if is_instance_valid(e) and not e.get("dead"):
		forced_kills += 1
		e.health.take_damage(99999.0, {"kind": "test"})
	else:
		shots_fired_kills += 1
	await frames(3)

func clear_enemies(max_each: float = 6.0) -> void:
	for e in get_tree().get_nodes_in_group("enemy"):
		if is_instance_valid(e) and not e.get("dead") and e.visible and e.process_mode != Node.PROCESS_MODE_DISABLED:
			await fight(e, max_each)

# ================================================================= the run
func _run() -> void:
	await _menu_and_settings()
	await _cryo()
	await _research()
	await _security()
	await _reactor()
	await _exterior()
	await _extraction()
	await _save_load()
	await _post_prd()
	collecting = false
	await _ids()
	await _checkpoints()

func _menu_and_settings() -> void:
	var ui = GameMode.ui
	ui.show_menu()
	await frames(5)
	check("menu opens", ui.current == "menu")
	ui.open_settings("settings_menu")
	await frames(2)
	check("settings opens", ui.current == "settings_menu")
	# every preset applies live: the particle scale GameMode pushes to Fx follows the profile, and the presets differ
	var profs := {}
	var applied := true
	for q in ["low", "medium", "high", "ultra", "mobile"]:
		Game.settings["quality"] = q
		Game.apply_settings()
		await frames(1)
		profs[q] = Game.quality_profile()
		applied = applied and is_equal_approx(Fx.particle_scale, float(profs[q]["particles"]))
	Game.settings["quality"] = "high"
	Game.apply_settings()
	check("quality presets apply", applied and profs["low"]["lights_shadow"] == false and profs["mobile"]["lights_shadow"] == false
		and int(profs["ultra"]["shadow_size"]) > int(profs["low"]["shadow_size"]) and float(profs["ultra"]["far"]) > float(profs["mobile"]["far"]))
	# every setting persists (Post-PRD Phase 9 / Doc 3 Phase 10): change, save, wipe, load
	var keep: Dictionary = Game.settings.duplicate(true)
	var want := {"quality": "low", "music": 0.3, "sfx": 0.4, "sensitivity": 1.7, "subtitles": false, "cam_distance": 1.3,
		"invert_y": true, "show_fps": true, "difficulty": "hard", "ui_size": "large", "fov": 80.0}
	Game.settings.merge(want, true)
	Game.save_settings()
	for k in want.keys():
		Game.settings[k] = keep[k]
	Game.load_settings()
	var restored := true
	for k in want.keys():
		if str(Game.settings[k]) != str(want[k]):
			restored = false
			print("  setting not restored: ", k, " = ", Game.settings[k])
	check("all settings persist across a restart", restored)
	Game.apply_settings()
	await frames(2)
	var sfx_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))
	check("audio settings drive the mix buses", absf(sfx_db - linear_to_db(0.4)) < 0.2)
	check("FPS readout follows its setting", await until(func(): return GameMode.ui.fps_lbl.visible, 1.0))
	for k in want.keys():
		Game.settings[k] = keep[k]
	Game.apply_settings()
	# subtitles grow upward from a fixed bottom edge: a 3-line line clears the letterbox and the touch buttons
	var uix = GameMode.ui
	var long_line := "This is the Orpheus relay. If anyone can hear this, the signal is still going out. Whatever happened down there, we're coming. Hold on, we are almost in range."
	Events.cinematic_state.emit(true)
	Events.subtitle.emit("TEST", long_line, 3.0)
	await frames(4)
	var vrect: Rect2 = uix.get_viewport().get_visible_rect()
	var srect: Rect2 = uix.sub_box.get_global_rect()
	check("long subtitle stays above the cinematic letterbox", srect.end.y <= vrect.size.y - 130.0 + 1.0 and srect.size.y > 60.0 and srect.position.x >= 0.0 and srect.end.x <= vrect.size.x)
	Events.cinematic_state.emit(false)
	var keep_touch = Game.settings.get("touch", "auto")
	Game.settings["touch"] = "on"
	Game.apply_settings()
	uix.hud_visible(true)
	uix.relayout_hud()
	await frames(2)
	Events.subtitle.emit("TEST", long_line, 3.0)
	await frames(4)
	srect = uix.sub_box.get_global_rect()
	var clash := ""
	for b in uix.touch.find_children("*", "Control", true, false):
		var bc: Control = b
		if bc.name.begins_with("Touch_") and bc.size.x > 20.0 and bc.get_global_rect().intersects(srect):
			clash += bc.name + " "
	if clash != "":
		print("  subtitle overlaps touch controls: ", clash, " sub=", srect)
	check("touch: subtitles clear the buttons and sticks", clash == "" and srect.end.y <= vrect.size.y)
	Game.settings["touch"] = keep_touch
	Game.apply_settings()
	uix.relayout_hud()
	Game.save_settings()
	# key rebinding persists (Post-PRD Phase 9)
	ui.open_bindings("settings_menu")
	await frames(2)
	check("key bindings page opens", ui.current == "bindings")
	Game.set_binding("jump", KEY_G)
	var has_g := false
	for e in InputMap.action_get_events("jump"):
		if e is InputEventKey and e.physical_keycode == KEY_G:
			has_g = true
	var c := ConfigFile.new()
	c.load(Game.SETTINGS_PATH)
	var saved: Dictionary = c.get_value("settings", "bindings", {})
	check("rebinding applies and is saved", has_g and int(saved.get("jump", 0)) == KEY_G)
	check("keyboard hints follow the rebinding", Game.key_name("jump") == "G" and GameMode.ui.howto_text("KEYBOARD").contains("G jump")
		and Game.keys_line().contains("G jump"))
	Game.set_binding("jump", KEY_E)
	check("rebinding to a used key swaps", Game.binding_of("interact") == KEY_G and Game.binding_of("jump") == KEY_E)
	Game.reset_bindings()
	check("bindings reset to defaults", Game.binding_of("jump") == KEY_SPACE and Game.binding_of("interact") == KEY_E)
	ui.show_menu()
	await frames(2)

func _cryo() -> void:
	await GameMode.new_game()
	check("cryo loads", await load_area_wait("cryo"))
	god()
	await frames(10)
	check("opening cinematic plays", GameMode.cinematic_playing)
	await skip_cinematics()
	check("cinematic skip returns control", not GameMode.cinematic_playing and not P().locked)
	await frames(6)
	var arm_len: float = P().controller.arm.get_hit_length()
	check("after the wake-up the camera is clear of the pod (arm %.2f m)" % arm_len, arm_len > 2.2)
	# a quality preset reaches the live area: Low turns off every omni/spot shadow and coarsens mesh LOD
	Game.settings["quality"] = "low"
	Game.apply_settings()
	await frames(2)
	var no_shadows := A()._lights.all(func(pair): return not is_instance_valid(pair[0]) or not (pair[0] as Light3D).shadow_enabled)
	var lod_low := get_viewport().mesh_lod_threshold
	Game.settings["quality"] = "high"
	Game.apply_settings()
	await frames(2)
	var some_shadows := A()._lights.any(func(pair): return is_instance_valid(pair[0]) and (pair[0] as Light3D).shadow_enabled)
	check("quality preset applies to the live area", no_shadows and some_shadows and lod_low > get_viewport().mesh_lod_threshold)
	check("mission 1 active", Game.state["mission"] == 0 and Missions.objective_text().begins_with("Get out"))
	# tutorial walk: crouch beam + jump gap triggers
	await tp(Vector3(14.0, 0.0, 6.0), -90.0)
	await tp(Vector3(17.8, 0.0, 6.0), -90.0)
	await tp(Vector3(19.9, -2.5, 6.0), -90.0)
	await frames(10)
	check("falling in the gap resets the player", P().global_position.x < 19.0 and P().global_position.y > -0.5)
	await tp(Vector3(24.0, 0.0, 6.0), -90.0)
	var door: Door = find("Door", "cryo_bay")
	check("bay door starts locked", door and door.is_locked())
	await use(find("Console", "bay_panel"))
	await tp(Vector3(26.5, 0.0, 6.0), -90.0)
	check("bay door opens after the panel", await until(func(): return Game.flag("door.cryo_bay"), 5.0))
	check("objective advances to weapon", await until(func(): return Missions.objective_text().contains("weapon"), 2.0))
	await tp(Vector3(31.0, 0.0, 6.0), 180.0)
	check("aux door locked without weapon", find("Door", "aux").is_locked())
	# medbay: log, medkit, pistol
	await use(find("LogPickup", "log.1"))
	check("log 1 collected", 1 in Game.state["logs"])
	await tp(Vector3(42.6, 0.95, 6.9))
	check("medkit auto-pickup", await until(func(): return P().inventory.medkits >= 1, 2.0))
	await use(find("Pickup", "pistol"))
	check("pistol picked up", P().combat.weapons.has("pistol") and Game.flag("got.pistol"))
	check("save after arming", Game.has_save())
	# the vent stalker
	await tp(Vector3(33.0, 0.0, 10.0), 0.0)
	var st: EnemyBase = A().vent_stalker
	check("vent stalker awakens", await until(func(): return st and st.visible and st.alerted, 6.0))
	await wait(1.0)
	await fight(st, 10.0)
	check("first encounter done", await until(func(): return Game.flag("enc.cryo_first"), 4.0))
	# generators: a wrong order trips the breaker, then the right one
	await tp(Vector3(32.0, 0.0, 14.5), 180.0)
	check("aux door unlocked once armed", not find("Door", "aux").is_locked())
	var pz: GeneratorPuzzle = A().gen_puzzle
	await use(pz.gens["A"])
	await wait(2.0)
	check("wrong generator order resets", pz.progress.size() == 0 and not pz.gens["A"].running)
	for g in ["B", "C", "A"]:
		await use(pz.gens[g])
		await wait(0.3)
	check("generator puzzle solved", await until(func(): return Game.flag("puzzle.generators"), 4.0))
	check("bulkhead unlocked", not A().bulkhead.is_locked())
	await tp(Vector3(32.0, 0.0, -6.4), 180.0)
	check("research wing loads", await load_area_wait("research"))
	check("mission 2 starts", Game.state["mission"] == 1)

func _research() -> void:
	god()
	await frames(5)
	await clear_enemies()
	await use(find("LogPickup", "log.5"))
	await use(find("LogPickup", "log.7"))
	check("code clue logs collected", 5 in Game.state["logs"] and 7 in Game.state["logs"])
	await tp(A().at(11.8, 2.5), -90.0)
	await wait(1.0)
	check("gate reached", Game.flag("seen.security_gate"))
	await clear_enemies()
	var kp: Keypad = find("Keypad", "security_keypad")
	await use(kp)
	var ui = GameMode.ui
	check("keypad overlay opens", ui.current == "keypad")
	ui.keypad_type("1234")
	await wait(1.0)
	check("wrong code rejected", not Game.flag("puzzle.security_code"))
	ui.keypad_type("0417")
	check("code 0417 accepted", await until(func(): return Game.flag("puzzle.security_code"), 3.0))
	await wait(1.5)
	ui._close_to_game()
	await wait(3.5)
	await tp(A().at(14.6, 2.5), -90.0)
	check("security sector loads", await load_area_wait("security"))

func _security() -> void:
	god()
	await frames(5)
	await use(find("Pickup", "rifle"))
	check("rifle picked up", Game.flag("got.rifle") and P().combat.weapons.has("rifle"))
	P().combat.equip("rifle")
	await wait(0.8)
	await clear_enemies(8.0)
	check("brute defeated", await until(func(): return Game.flag("enc.brute"), 4.0))
	await tp(A().at(12.5, 2.5), -90.0)
	await wait(0.6)
	check("comms door unlocked", not find("Door", "comms").is_locked())
	await use(find("Console", "comms_console"))
	await frames(10)
	await skip_cinematics()
	check("comms restored", await until(func(): return Game.flag("comms.restored"), 4.0))
	check("mission 3 starts", Game.state["mission"] == 2)
	await use(find("Console", "lift_controls"))
	check("reactor loads", await load_area_wait("reactor"))

func _reactor() -> void:
	god()
	await frames(5)
	await clear_enemies()
	# environmental hazard: stand in a steam vent through one full cycle -> it hurts (and only when active)
	var hz: HazardZone = A().hazards[0]
	await tp(hz.global_position, 0.0)
	P().health.dmg_mult = 1.0
	var hp0: float = P().health.hp
	await wait(hz.idle_secs + hz.warn_secs + hz.active_secs + 0.3)
	check("reactor hazard damages the player (%d ticks, %.0f HP)" % [hz.hits, hp0 - P().health.hp], hz.hits > 0 and P().health.hp < hp0 and not P().dead)
	god()
	P().health.heal(100.0)
	await tp(A().at(8.6, 2.0), -90.0)
	check("iyer lab found", await until(func(): return Game.flag("seen.iyer_lab"), 2.0))
	var cc: ConduitConsole = find("ConduitConsole", "conduits")
	await use(cc)
	var ui = GameMode.ui
	check("conduit board opens", ui.current == "conduits")
	check("conduit board starts unsolved", not cc.board.is_solved())
	# solve it through the board view, tile by tile (rotate each tile until it matches the known route)
	var view = ui._conduit_canvas
	for i in cc.board.rot.size():
		var guard := 0
		while cc.board.rot[i] != cc.board.solution[i] and guard < 4 and not cc.board.is_solved():
			view.rotate_tile(i % cc.board.w, i / cc.board.w)
			guard += 1
	check("conduit puzzle solved", await until(func(): return Game.flag("puzzle.conduits"), 3.0))
	await wait(2.0)
	if ui.current == "conduits":
		ui._close_to_game()
	await until(func(): return GameMode.cinematic_playing, 10.0)
	await skip_cinematics()
	check("survival starts", await until(func(): return A().surviving, 5.0))
	await wait(3.0)
	check("survival waves spawn", get_tree().get_nodes_in_group("enemy").filter(func(e): return not e.dead).size() > 0)
	A().survive_left = 1.0
	check("survival completes", await until(func(): return Game.flag("enc.reactor_survive"), 4.0))
	await clear_enemies(4.0)
	await use(find("Console", "lift_out_controls"))
	await tp(A().at(9.0, 5.0), -90.0)
	if not await until(func(): return A().area_id == "exterior", 2.0):
		await use(find("Console", "lift_out_controls"))
	check("exterior loads", await load_area_wait("exterior"))
	check("mission 4 starts", Game.state["mission"] == 3)

func _exterior() -> void:
	god()
	await frames(5)
	await use(find("LogPickup", "log.13"))
	check("log 13 collected", 13 in Game.state["logs"])
	await clear_enemies(5.0)
	var cp: Vector3 = A()._g(20, -178, 0.3)
	await tp(cp, 180.0)
	check("extraction loads", await load_area_wait("extraction"))

func _extraction() -> void:
	god()
	await frames(5)
	await clear_enemies(5.0)
	await use(find("Console", "pad_comms"))
	check("transmission sent", await until(func(): return Game.flag("transmission.sent"), 40.0))
	await until(func(): return GameMode.cinematic_playing, 5.0)
	await skip_cinematics()
	var h: Herald = A().herald
	check("herald fight starts", await until(func(): return h.phase == 1 and GameMode.boss_fight, 15.0))
	# shoot the shoulder nodes with the rifle for a few seconds (real hit-scan against the node hitboxes)
	P().inventory.add_ammo("rifle", 192)
	await tp(Vector3(13, 0.5, -3), -90.0)
	var hits_before: int = Game.state["stats"]["hits"]
	for id in ["node_l", "node_r"]:
		var a: Area3D = h.nodes[id]["area"]
		var t := 0.0
		while t < 4.0 and h.nodes[id]["alive"]:
			var from: Vector3 = P().controller.cam.global_position
			var d := (a.global_position - from).normalized()
			P().controller.yaw = rad_to_deg(atan2(-d.x, -d.z))
			P().controller.pitch = clampf(rad_to_deg(asin(d.y)), -60.0, 60.0)
			P().controller.aim_toggle = true
			P().combat.touch_fire = true
			if P().combat.current.mag == 0:
				P().combat.reload()
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		P().combat.touch_fire = false
		var r: Array = P().controller.aim_ray()
		var q := PhysicsRayQueryParameters3D.create(r[0], r[0] + r[1] * 140.0, 1 | 4 | 8)
		q.collide_with_areas = true
		q.exclude = [P().get_rid()]
		var hit := P().get_world_3d().direct_space_state.intersect_ray(q)
		print("DEBUG node ", id, " aim hit: ", hit.get("collider"), " at ", hit.get("position"), " node at ", a.global_position, " weapon ", P().combat.current_id(), " mag ", P().combat.current.mag if P().combat.current else -1)
		if h.nodes[id]["alive"]:
			h.node_hit(id, 99999.0)
		await wait(2.0)
	check("rifle shots hit the herald nodes", int(Game.state["stats"]["hits"]) > hits_before)
	check("herald phase 2", await until(func(): return h.phase == 2, 8.0))
	await wait(4.0)
	h._phase2_t = 40.0
	check("herald phase 3", await until(func(): return h.phase == 3, 15.0))
	await wait(3.0)
	h.node_hit("node_c", 99999.0)
	check("herald defeated", await until(func(): return Game.flag("boss.dead"), 12.0))
	var ramp := await _wait_node("Console", "shuttle_ramp", 12.0)
	check("shuttle ramp appears", ramp != null)
	if ramp:
		await use(ramp)
		await wait(1.0)
		check("ending cinematic", GameMode.cinematic_playing)
		await skip_cinematics()
	check("game complete", await until(func(): return Game.flag("game.complete"), 5.0))
	check("end credits roll", await until(func(): return GameMode.ui.current == "end_credits", 30.0))
	var all_ids := {}
	for l in GameData.logs():
		all_ids[int(l["id"])] = true
	var missing := []
	for k in all_ids.keys():
		if not log_ids.has(k):
			missing.append(k)
	if not missing.is_empty():
		print("  logs never placed in any area: ", missing)
	check("all logs findable (%d placed of %d)" % [log_ids.size(), all_ids.size()], missing.is_empty() and all_ids.size() > 0)
	# the ending happens once and completion persists in the save
	var again := find("Console", "shuttle_ramp")
	if again and P() and again.can_interact(P()):
		again.interact(P())
	await frames(5)
	check("ending trigger is one-shot", again != null and P() != null and not again.can_interact(P()) and not GameMode.cinematic_playing)
	check("completion persists in the save", Game.load_game() and Game.flag("game.complete"))

func _wait_node(cls_name: String, id: String, timeout: float) -> Node:
	var t := 0.0
	while t < timeout:
		var n := find(cls_name, id)
		if n:
			return n
		await wait(0.25)
		t += 0.25
	return null

func _save_load() -> void:
	check("save file valid", Game.load_game() and Game.state["area"] == "extraction")
	check("stats recorded", float(Game.state["stats"]["time"]) > 0.0 and int(Game.state["stats"]["kills"]) > 5)
	# continue from the save goes back to the extraction pad with the boss already dead
	GameMode.to_menu()
	await frames(5)
	var ok: bool = await GameMode.continue_game()
	check("continue loads the save", ok and await load_area_wait("extraction"))


## Post-PRD compliance checks: inventory screen, restart checkpoint, death -> respawn, save validation.
func _post_prd() -> void:
	var ui = GameMode.ui
	await frames(10)
	ui.open_journal(false)
	await frames(2)
	check("inventory & logs screen opens", ui.current == "journal")
	ui._close_to_game()
	await frames(2)
	var cp_t: Transform3D = GameMode.area.checkpoints.get(str(Game.state["checkpoint"]), Transform3D())
	await tp(cp_t.origin + Vector3(6, 0, 6), 0.0)
	await GameMode.restart_checkpoint()
	await load_area_wait("extraction")
	await frames(10)
	check("restart checkpoint returns to the checkpoint", P() and P().global_position.distance_to(cp_t.origin) < 2.5)
	# death -> death screen -> respawn at the checkpoint
	P().health.dmg_mult = 1.0
	P().health.take_damage(9999.0, {"kind": "test"})
	check("player dies", await until(func(): return ui.current == "death", 6.0))
	var deaths: int = int(Game.state["stats"]["deaths"])
	ui._clear_host()
	ui.current = ""
	await GameMode.restart_checkpoint()
	await load_area_wait("extraction")
	await frames(10)
	check("respawn at checkpoint with full health", P() and not P().dead and P().health.hp >= P().health.max_hp - 0.5 and deaths >= 1)
	# save data: versioned, validated, falls back to the backup when the main file is corrupt
	var raw := FileAccess.get_file_as_string(Game.SAVE_PATH)
	var j: Variant = JSON.parse_string(raw)
	check("save carries a version", j is Dictionary and int(j.get("version", 0)) == Game.SAVE_VERSION)
	GameMode.manual_save()
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{corrupt")
	f.close()
	check("corrupt save falls back to the backup", Game.load_game())
	var f2 := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f2.store_string(JSON.stringify({"area": "nowhere", "checkpoint": "x", "flags": {}, "player": {}}))
	f2.close()
	check("invalid save data is rejected", not Game._valid(JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_PATH))))
	god()


## Story PRD Ph1: stable ids are unique (inside an area and across areas).
func _ids() -> void:
	var cross: Array = []
	for sid in id_areas.keys():
		if (id_areas[sid] as Dictionary).size() > 1:
			cross.append("%s in %s" % [sid, ", ".join((id_areas[sid] as Dictionary).keys())])
	if not dup_in_area.is_empty() or not cross.is_empty():
		print("  duplicate ids: ", dup_in_area, " ", cross)
	check("no duplicate stable ids (%d ids)" % id_areas.size(), dup_in_area.is_empty() and cross.is_empty() and id_areas.size() > 20)

## Story PRD §11 / Godot PRD Ph6: load the save made at EVERY checkpoint of the run; the player must stand on the
## floor, alive, in the same mission with the same objective (mission gates stay consistent).
func _checkpoints() -> void:
	print("checkpoints saved during the run: ", cp_snaps.keys())
	check("checkpoint saves recorded (%d)" % cp_snaps.size(), cp_snaps.size() >= 12)
	for cp in cp_snaps.keys():
		var s: Dictionary = cp_snaps[cp]
		var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
		f.store_string(s["text"])
		f.close()
		GameMode.to_menu()
		await frames(5)
		var ok: bool = await GameMode.continue_game()
		ok = ok and await load_area_wait(s["area"])
		god()
		await skip_cinematics()
		var floor_ok := await until(func(): return P() != null and P().is_on_floor(), 3.0)
		await wait(0.5)
		var same: bool = int(Game.state["mission"]) == int(s["mission"]) and Missions.objective_text() == s["objective"]
		if not same:
			print("  cp ", cp, ": mission ", Game.state["mission"], " vs ", s["mission"], " | '", Missions.objective_text(), "' vs '", s["objective"], "'")
		check("load checkpoint %s" % cp, ok and floor_ok and P() and not P().dead and same)
