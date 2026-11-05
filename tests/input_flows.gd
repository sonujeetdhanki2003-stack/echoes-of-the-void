extends Node
## Touch input + pause / back / game-over / restart / quit loops through real input events.  --driver=input_flows
var passed := 0
var failed := 0
var ratio := Vector2.ONE

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
	await get_tree().process_frame

func _raw(p: Vector2) -> Vector2:
	return p * ratio

func tdown(idx: int, p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.pressed = true
	e.position = _raw(p)
	Input.parse_input_event(e)
	await frames(2)

func tup(idx: int, p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.pressed = false
	e.position = _raw(p)
	Input.parse_input_event(e)
	await frames(2)

func tdrag(idx: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = _raw(p)
	e.relative = _raw(rel)
	Input.parse_input_event(e)
	await frames(2)

func btn(id: String) -> Button:
	for e in GameMode.ui.touch.buttons:
		if e[1] == id:
			return e[0]
	return null

func center(b: Button) -> Vector2:
	return b.get_global_rect().get_center()

func _ready() -> void:
	await get_tree().process_frame
	Game.settings["touch"] = "on"
	Game.apply_settings()
	get_window().size = Vector2i(2400, 1080)
	Game.apply_settings()
	await frames(4)
	ratio = Vector2(get_window().size) / get_viewport().get_visible_rect().size
	await _touch()
	await _flows()
	print("INPUTFLOWS %d/%d passed" % [passed, passed + failed])
	for f in [Game.SAVE_PATH, Game.SAVE_PATH + ".bak", Game.SETTINGS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	get_tree().quit(0 if failed == 0 else 1)

func _touch() -> void:
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("cryo", "cryo_hub", true)
	await frames(30)
	var ui = GameMode.ui
	var p: Player = GameMode.player
	var t = ui.touch
	check("touch controls visible in game", t.visible)
	p.combat.give("pistol")
	await frames(10)
	# stick
	var yaw0: float = p.controller.yaw
	var pos0 := p.global_position
	await tdown(0, Vector2(250, 520))
	await tdrag(0, Vector2(370, 520), Vector2(120, 0))
	check("stick drag right -> touch_move", p.touch_move.x > 0.7 and absf(p.touch_move.y) < 0.2, str(p.touch_move))
	await frames(30)
	check("player walks while the stick is held", p.global_position.distance_to(pos0) > 0.8, str(p.global_position.distance_to(pos0)))
	await tup(0, Vector2(370, 520))
	check("stick release stops the player's input", p.touch_move.length() < 0.01 and t.stick_idx == -1)
	# stick up = forward
	await tdown(0, Vector2(250, 520))
	await tdrag(0, Vector2(250, 400), Vector2(0, -120))
	check("stick up -> forward", p.touch_move.y > 0.7, str(p.touch_move))
	await tup(0, Vector2(250, 400))
	# look drag on the right half
	yaw0 = p.controller.yaw
	await tdown(1, Vector2(1200, 300))
	await tdrag(1, Vector2(1300, 300), Vector2(100, 0))
	check("look drag turns the camera", absf(p.controller.yaw - yaw0) > 3.0, "yaw %s -> %s" % [yaw0, p.controller.yaw])
	await tup(1, Vector2(1300, 300))
	check("look finger released", t.look_idx == -1)
	# a touch in the dead strip at the top-left does nothing
	await tdown(2, Vector2(100, 100))
	check("touch in the top-left corner is ignored", t.stick_idx == -1 and t.look_idx == -1)
	await tup(2, Vector2(100, 100))
	# jump button: a tap makes the player jump
	var jb := btn("jump")
	p.global_position = pos0
	p.velocity = Vector3.ZERO
	await frames(20)
	var left_floor := false
	await tdown(3, center(jb))
	for i in 8:
		await get_tree().physics_frame
		if not p.is_on_floor():
			left_floor = true
	await tup(3, center(jb))
	check("tap JUMP jumps", left_floor)
	await frames(60)
	# FIRE: hold/release
	var fb := btn("fire")
	check("FIRE button is shown with a weapon", fb.visible)
	await tdown(4, center(fb))
	check("hold FIRE -> touch_fire", p.combat.touch_fire)
	# multi-touch: stick + look + fire together
	await tdown(0, Vector2(250, 520))
	await tdrag(0, Vector2(250, 420), Vector2(0, -100))
	await tdown(1, Vector2(1000, 300))
	await tdrag(1, Vector2(1060, 300), Vector2(60, 0))
	check("stick, look and FIRE work together", p.touch_move.y > 0.5 and p.combat.touch_fire and t.look_idx == 1)
	await tup(0, Vector2(250, 420))
	check("releasing the stick leaves FIRE and look running", p.combat.touch_fire and t.look_idx == 1 and p.touch_move.length() < 0.01)
	await tup(4, center(fb))
	check("releasing FIRE stops firing", not p.combat.touch_fire)
	await tup(1, Vector2(1060, 300))
	# toggles
	var ab := btn("aim")
	await tdown(5, center(ab))
	await tup(5, center(ab))
	check("tap AIM toggles aim on", p.controller.aim_toggle)
	await tdown(5, center(ab))
	await tup(5, center(ab))
	check("tap AIM again toggles it off", not p.controller.aim_toggle)
	# USE: stand at the bay panel console and tap USE
	p.place(Transform3D(Basis(), Vector3(27.5, 0.1, 5.9)))
	p.controller.yaw = 0.0
	await frames(30)
	Game.state["flags"].erase("power.bay_panel")
	var ub := btn("interact")
	await tdown(6, center(ub))
	await tup(6, center(ub))
	await frames(5)
	check("tap USE at the panel uses it", Game.flag("power.bay_panel") or p.interaction.focus == null, "focus=%s" % str(p.interaction.focus))
	# pause button
	var pb := btn("pause")
	await tdown(7, Vector2(250, 520))
	check("finger on the stick when pausing", t.stick_idx == 7)
	await tdown(8, center(pb))
	await tup(8, center(pb))
	check("tap II pauses", ui.current == "pause" and get_tree().paused)
	check("pausing releases every touch", t.stick_idx == -1 and t.look_idx == -1 and p.touch_move.length() < 0.01)
	ui.back_pressed()
	await frames(3)
	check("back button resumes from pause", ui.current == "" and not get_tree().paused)
	await tup(7, Vector2(250, 520))

func _flows() -> void:
	var ui = GameMode.ui
	# ---- Android back button everywhere
	ui.back_pressed()
	await frames(3)
	check("back during play opens the pause menu", ui.current == "pause" and get_tree().paused)
	ui.open_settings("settings_pause")
	await frames(3)
	ui.back_pressed()
	await frames(3)
	check("back in settings returns to pause", ui.current == "pause")
	ui.open_howto(true)
	await frames(3)
	ui.back_pressed()
	await frames(3)
	check("back in How to play returns to pause", ui.current == "pause")
	ui.open_journal(true)
	await frames(3)
	ui.back_pressed()
	await frames(3)
	check("back in the journal returns to pause", ui.current == "pause")
	ui.back_pressed()
	await frames(3)
	check("back in pause resumes", ui.current == "" and not get_tree().paused)
	# the OS back request goes to the same place
	GameMode._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(3)
	check("OS back request pauses", ui.current == "pause")
	GameMode._notification(NOTIFICATION_WM_GO_BACK_REQUEST)
	await frames(3)
	# ---- game over -> retry loop x3
	for round in 3:
		var p: Player = GameMode.player
		p.health.take_damage(99999.0, {"kind": "test"})
		await get_tree().create_timer(3.0, true, false, true).timeout
		check("death screen shows (round %d)" % round, ui.current == "death", ui.current)
		ui.back_pressed()
		check("back on the death screen does nothing", ui.current == "death")
		GameMode.restart_checkpoint()
		await get_tree().create_timer(2.5, true, false, true).timeout
		check("retry reloads and the player is alive (round %d)" % round, GameMode.in_game and GameMode.player != null and not GameMode.player.dead and GameMode.player.health.hp > 0.0 and ui.current == "")
	# ---- main menu -> continue -> main menu -> new game, no leaks
	var areas_before := GameMode.world_root.get_child_count()
	for round in 3:
		GameMode.to_menu()
		await frames(5)
		check("to_menu shows the menu (round %d)" % round, ui.current == "menu" and not GameMode.in_game and GameMode.area == null)
		check("no looping sounds survive the menu", Sfx._loops.is_empty() or _all_stopped())
		ui.back_pressed()
		check("back on the main menu does nothing", ui.current == "menu")
		var ok: bool = await GameMode.continue_game()
		await get_tree().create_timer(2.0, true, false, true).timeout
		check("continue works after quitting (round %d)" % round, ok and GameMode.in_game and GameMode.player != null)
	await frames(10)
	# only one world area + the menu backdrop at most
	var n_areas := 0
	for c in GameMode.world_root.get_children():
		if c is Area:
			n_areas += 1
	check("exactly one area is loaded after the loops", n_areas == 1, "%d" % n_areas)
	# quitting to the menu while a load is running must not wedge the game
	for delay in [2, 30, 60, 90, 120]:
		GameMode.to_menu()
		await frames(3)
		GameMode.new_game()
		await frames(delay)
		GameMode.to_menu()
		await get_tree().create_timer(2.5, true, false, true).timeout
		var orphans := 0
		for c in GameMode.world_root.get_children():
			if c is Area:
				orphans += 1
		check("quit to menu %d frames into a load leaves no area behind" % delay, orphans == 0 and not GameMode.in_game and not GameMode.loading, "areas=%d in_game=%s loading=%s" % [orphans, GameMode.in_game, GameMode.loading])
	check("menu stays usable after quitting mid-load", ui.current == "menu" and not GameMode.loading, "current=%s loading=%s" % [ui.current, GameMode.loading])
	await GameMode.new_game()
	await get_tree().create_timer(1.0, true, false, true).timeout
	check("a new load works after a cancelled one", GameMode.in_game and GameMode.player != null and not GameMode.loading)
	# the cancelled load must not leave a second area behind
	var n2 := 0
	for c in GameMode.world_root.get_children():
		if c is Area:
			n2 += 1
	check("no orphan area from the cancelled load", n2 == 1, "%d areas" % n2)

func _all_stopped() -> bool:
	for k in Sfx._loops.keys():
		var pl = Sfx._loops[k]
		if is_instance_valid(pl) and pl.playing:
			return false
	return true
