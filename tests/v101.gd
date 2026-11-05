extends Node
## v1.0.1 regression tests: one check per bug fixed in the 1.0.1 bug hunt.  --driver=v101
var passed := 0
var failed := 0

func check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, "  ", extra)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	Game.settings["subtitles"] = true
	await get_tree().process_frame
	var only := Game.arg("only", "")
	if only == "" or only == "saves":
		await _saves()
		await _manual_save_position()
	if only == "" or only == "fall":
		await _fall_recovery()
	if only == "" or only == "ui":
		await _ui_fixes()
	if only == "" or only == "web":
		await _web()
	if only == "" or only == "camera":
		await _camera()
	print("V101 %d/%d passed" % [passed, passed + failed])
	for f in [Game.SAVE_PATH, Game.SAVE_PATH + ".bak", Game.SETTINGS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	get_tree().quit(0 if failed == 0 else 1)

func _write(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()

# ---- BUG: "Continue" was offered for a save that load_game() rejects (too-new version / wrong area)
func _saves() -> void:
	Game.delete_save()
	check("no save -> no Continue", not Game.has_save())
	Game.new_state()
	_write(Game.SAVE_PATH, {"version": 99, "area": "cryo", "checkpoint": "cryo_start", "flags": {}, "player": {}, "mission": 0, "objective": 0})
	check("too-new save does not offer Continue", not Game.has_save(), "has_save=%s" % Game.has_save())
	check("too-new save: save_info empty", Game.save_info() == "")
	_write(Game.SAVE_PATH, {"version": 1, "area": "nowhere", "checkpoint": "x", "flags": {}, "player": {}, "mission": 0, "objective": 0})
	check("save for a missing area does not offer Continue", not Game.has_save())
	# a good .bak behind a bad main file still counts
	Game.new_state()
	Game.state["area"] = "research"
	Game.state["checkpoint"] = "research_atrium"
	Game.state["mission"] = 1
	check("good save writes", Game.save_game())
	check("good save offered", Game.has_save())
	_write(Game.SAVE_PATH + ".bak", Game.state)
	var f := FileAccess.open(Game.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ not json")
	f.close()
	check("corrupt main + good .bak still continues", Game.has_save() and Game.load_game() and Game.state["area"] == "research")
	check("save_info reads the .bak", Game.save_info() != "")
	Game.delete_save()

# ---- BUG: continuing from a manual save overwrote it with a checkpoint save (position lost)
func _manual_save_position() -> void:
	Game.delete_save()
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("cryo", "cryo_hub", true)
	var p: Player = GameMode.player
	p.place(Transform3D(Basis(Vector3.UP, 1.0), Vector3(31.0, 0.1, 9.0)))
	await frames(40)
	check("manual save is allowed in the hub", GameMode.can_manual_save() == "", GameMode.can_manual_save())
	check("manual save succeeds", GameMode.manual_save())
	var txt1 := FileAccess.get_file_as_string(Game.SAVE_PATH)
	var d1: Dictionary = JSON.parse_string(txt1)
	check("save file holds the manual position", d1.get("pos") is Array and absf(float(d1["pos"][0]) - 31.0) < 0.2)
	# quit to menu and continue
	GameMode.to_menu()
	await frames(5)
	var ok: bool = await GameMode.continue_game()
	await frames(30)
	check("continue loads", ok and GameMode.in_game)
	var q: Player = GameMode.player
	check("player is where the manual save was taken", q != null and q.global_position.distance_to(Vector3(31.0, 0.0, 9.0)) < 0.6, str(q.global_position if q else "-"))
	var d2: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Game.SAVE_PATH))
	check("continuing does not overwrite the manual save", d2.get("pos") is Array and absf(float(d2["pos"][0]) - 31.0) < 0.2, str(d2.get("pos")))
	GameMode.to_menu()
	await frames(5)
	ok = await GameMode.continue_game()
	await frames(30)
	check("second continue still at the manual position", ok and GameMode.player.global_position.distance_to(Vector3(31.0, 0.0, 9.0)) < 0.6)
	Game.delete_save()

# ---- BUG: no out-of-world recovery for the player or for enemies
func _fall_recovery() -> void:
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("research", "research_atrium", true)
	var p: Player = GameMode.player
	await frames(40)
	var floor_y := p.global_position.y
	var got := [false]
	p.recovered_from_fall.connect(func(): got[0] = true)
	var hp0 := p.health.hp
	p.global_position = Vector3(p.global_position.x, floor_y - 120.0, p.global_position.z)
	p.velocity = Vector3(0, -30, 0)
	await frames(4)
	check("player recovered from a fall out of the world", got[0] and p.global_position.y > floor_y - 1.0, "y=%s" % p.global_position.y)
	check("recovery costs no health", absf(p.health.hp - hp0) < 0.01)
	await frames(30)
	check("player stays on the floor after recovery", p.is_on_floor() and absf(p.global_position.y - floor_y) < 0.5)
	# far below with no safe spot recorded yet (fresh teleport): absolute floor of the world
	p.global_position = Vector3(p.global_position.x, -400.0, p.global_position.z)
	await frames(3)
	check("fall below -300 m also recovers", p.global_position.y > -50.0)
	# enemies
	var en: EnemyBase = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is EnemyBase and not e.dead and e.visible and e.process_mode != Node.PROCESS_MODE_DISABLED:
			en = e
			break
	if en:
		await frames(40)
		var home := en.global_position
		en.global_position = home + Vector3(0, -90, 0)
		await frames(3)
		print("  enemy dbg home=", en._home, " set=", en._home_set, " floor_t=", en._floor_t, " pm=", en.process_mode, " class=", en.get_script().get_global_name(), " dead=", en.dead, " physics=", en.is_physics_processing())
		check("enemy that left the world is put back at its post", en.global_position.distance_to(home) < 1.0, str(en.global_position))
	else:
		check("an enemy exists to test", false)

# ---- BUGS: toast hidden by the previous toast's fade; SKIP button state stuck after a cinematic
func _ui_fixes() -> void:
	var ui = GameMode.ui
	ui.toast("first", 0.05)
	await get_tree().create_timer(0.12, true, false, true).timeout    # the fade of "first" is now running
	ui.toast("second", 2.0)
	await get_tree().create_timer(0.6, true, false, true).timeout
	check("a toast shown during the previous fade stays visible", ui.toast_lbl.text == "second" and ui.toast_lbl.modulate.a > 0.95, "alpha=%.2f" % ui.toast_lbl.modulate.a)
	ui._skip_touch = true
	ui._skip_hold = 0.5
	ui._on_cinematic(true)
	await get_tree().process_frame
	ui._skip_touch = true     # finger still on the (about to be freed) button
	ui._on_cinematic(false)
	check("skip-button state is cleared when the cinematic ends", not ui._skip_touch and ui._skip_hold == 0.0)
	await get_tree().process_frame
	check("SKIP button removed after the cinematic", ui.get_node_or_null("SkipButton") == null)

# ---- the camera must stay inside the level and never inside a wall (v1.0.1 camera sweep)
func _camera() -> void:
	var bad := 0
	var n := 0
	for id in ["cryo", "research", "security", "reactor", "exterior", "extraction"]:
		Game.new_state()
		Game.state["flags"]["cine.wake"] = true
		await GameMode.load_area(id, id + "_start", true)
		var p: Player = GameMode.player
		p.health.dmg_mult = 0.0
		for e in get_tree().get_nodes_in_group("enemy"):
			e.queue_free()
		var space := p.get_world_3d().direct_space_state
		var cps: Dictionary = GameMode.area.checkpoints
		var area_bad := 0
		for cp in cps.keys():
			var origin: Vector3 = (cps[cp] as Transform3D).origin
			for d in 12:
				var yaw := d * 30.0
				# stand 0.45 m from the nearest wall in the direction the camera looks away from (the arm points back
				# at the wall): the worst case for the spring arm
				var dir := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))     # camera sits behind the player: +dir
				var q := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * 1.2, origin + Vector3.UP * 1.2 + dir * 8.0, 1)
				var hit := space.intersect_ray(q)
				var pos := origin
				if not hit.is_empty():
					pos = hit["position"] - dir * 0.45
					pos.y = origin.y
				p.place(Transform3D(Basis(), pos + Vector3.UP * 0.1))
				p.velocity = Vector3.ZERO
				p.controller.yaw = yaw + 180.0
				for pitch in [-8.0, 45.0, -60.0]:
					p.controller.pitch = pitch
					await frames(4)
					var cam := p.controller.cam.global_position
					var head := p.global_position + Vector3.UP * 1.5
					n += 1
					var sq := PhysicsShapeQueryParameters3D.new()
					var sph := SphereShape3D.new()
					sph.radius = 0.12
					sq.shape = sph
					sq.transform = Transform3D(Basis(), cam)
					sq.collision_mask = 1
					var inside := not space.intersect_shape(sq, 1).is_empty()
					var seg := PhysicsRayQueryParameters3D.create(head, cam, 1)
					var blocked := not space.intersect_ray(seg).is_empty()
					if inside or blocked:
						bad += 1
						area_bad += 1
						if area_bad <= 3:
							print("  CAMERA ", id, " ", cp, " yaw ", yaw, " pitch ", pitch, " cam ", cam, " inside=", inside, " blocked=", blocked)
		print("CAMERA area ", id, " bad=", area_bad)
	check("camera never inside geometry or behind a wall (%d samples)" % n, bad == 0, "%d bad" % bad)

func _web() -> void:
	print("--- web quality / performance guard")
	Game.is_web = true
	Game.is_mobile = false
	# the "web" profile: sun shadow + grime + ambient tuned, no forward-only features
	Game.settings["quality"] = "web"
	var pr := Game.quality_profile()
	check("web profile has no forward-only effects", not pr["sdfgi"] and not pr["ssao"] and not pr["vol_fog"] and pr["shadows"] and pr["glow"])
	check("web profile keeps the sun shadow at 2048", pr["shadow_size"] == 2048)
	# v1.0.0 web player with 'low' saved moves to 'web' once and keeps a later explicit choice
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "quality", "low")
	cfg.save(Game.SETTINGS_PATH)
	Game.settings["web_default"] = false
	Game.settings["quality"] = "high"
	Game.load_settings()
	check("saved 'low' from v1.0.0 migrates to 'web' on the web build", Game.settings["quality"] == "web" and Game.settings["web_default"] == true, str(Game.settings["quality"]))
	Game.settings["quality"] = "low"
	Game.save_settings()
	Game.settings["quality"] = "high"
	Game.load_settings()
	check("a later explicit 'low' is kept", Game.settings["quality"] == "low")
	# guard: needs a game running
	Game.new_state()
	await GameMode.load_area("cryo", "cryo_start", true)
	await frames(10)
	Game.settings["quality"] = "web"
	Game.perf_dropped = false
	Game._perf_warm = 3.0
	for i in 2000:
		Game.perf_sample(1.0 / 60.0)
	check("a steady 60 fps keeps the web look", Game.settings["quality"] == "web" and not Game.perf_dropped)
	for i in 80:
		Game.perf_sample(1.0)   # a tab-switch hitch is ignored
	check("single long hitches are ignored", Game.settings["quality"] == "web")
	for i in 400:
		Game.perf_sample(0.1)    # 10 fps
	check("a slow browser drops to Low once and tells the player", Game.settings["quality"] == "low" and Game.perf_dropped)
	Game.is_web = false
	Game.settings["quality"] = "high"
	for f in [Game.SAVE_PATH, Game.SAVE_PATH + ".bak", Game.SETTINGS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
