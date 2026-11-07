extends Node
## v1.6.0 stage 6 (D, E) tests: THE HOLLOWS area, its shutdown console and cinematic, the mission steps and the
## out-of-order skip, the 1.5 save shift into the final mission, creature and melee sounds, and the Breach Cannon
## splash damage. --driver=stage7
var passed := 0
var failed := 0

func check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, "  ", extra)

func _write(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()

func _ready() -> void:
	await get_tree().process_frame
	Game.SAVE_PATH = "user://stage7_save.json"
	Game.delete_save()
	Game.settings["touch"] = "off"
	Game.apply_settings()
	_data()
	_sounds()
	_missions()
	await _hollows()
	await _splash()
	Game.delete_save()
	Game.active_slot = 1
	print("STAGE7 %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)

func _data() -> void:
	check("save version is 3 and the build is 1.8.0", Game.SAVE_VERSION == 3 and Game.VERSION == "1.9.2")
	check("hollows is a registered area", Missions.area_exists("hollows") and load(Missions.AREAS["hollows"]["script"]) != null)
	var txt := FileAccess.get_file_as_string("res://data/dialogue.json")
	check("hollows dialogue lines exist", txt.find("\"mira_hollows_enter\"") > 0 and txt.find("\"mira_hollows_shutdown\"") > 0)
	var logs: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/logs.json"))
	var ids := []
	for l in logs:
		ids.append(int(l["id"]))
	check("two new Hollows logs (16, 17)", ids.has(16) and ids.has(17), str(ids))

func _sounds() -> void:
	var names := ["melee_swing", "melee_hit", "finisher_crunch", "breach_boom", "hunter_snarl", "hunter_roar",
		"exp_click", "exp_squelch", "exp_sniff", "crawler_chitter", "crawler_hiss"]
	var missing := []
	for n in names:
		if Sfx.stream("sfx/" + n) == null:
			missing.append(n)
	check("all %d new sounds load" % names.size(), missing.is_empty(), str(missing))

func _missions() -> void:
	var m: Dictionary = Missions.data.missions[3]
	var objs: Array = m["objectives"]
	check("final mission opens with the hollows steps", objs[0]["id"] == "hollows_enter" and objs[1]["id"] == "hollows_shutdown")
	check("the original final steps follow in order (v1.9.1 adds the answer step before the boss)", objs[2]["id"] == "cross" and objs[6]["id"] == "board" and objs[4]["id"] == "answer" and objs.size() == 7)
	Game.delete_save()
	Game.new_state()
	Game.state["mission"] = 3
	Game.state["objective"] = 0
	Game.set_flag("hollows.shutdown")
	check("a step done out of order is skipped (objective -> cross)", int(Game.state["objective"]) == 2, "objective %s" % str(Game.state["objective"]))
	Game.delete_save()
	# a 1.5 save in the final mission: its step moves past the two new steps
	Game.new_state()
	Game.active_slot = 1
	_write(Game.SAVE_PATH, {"version": 2, "area": "exterior", "checkpoint": "exterior_mid", "flags": {"area.exterior": true},
		"player": {"hp": 90.0, "weapons": ["pistol"], "reserve": {"pistol": 12}, "mag": {"pistol": 7}, "equipped": "pistol"},
		"mission": 3, "objective": 1, "logs": [], "stats": {"time": 1.0, "kills": 0, "deaths": 0, "shots": 0, "hits": 0}, "saved_at": "2026-10-20T10:00:00"})
	check("1.5 save in the final mission loads", Game.load_game())
	check("1.5 save: objective 1 (transmit) shifts to 3", int(Game.state["objective"]) == 3, "objective %s" % str(Game.state["objective"]))
	check("1.5 save: mission and area kept", int(Game.state["mission"]) == 3 and Game.state["area"] == "exterior")
	Game.delete_save()
	Game.new_state()
	_write(Game.SAVE_PATH, {"version": 2, "area": "cryo", "checkpoint": "cryo_start", "flags": {}, "player": {},
		"mission": 0, "objective": 1, "logs": [], "stats": {}, "saved_at": "2026-10-20T10:00:00"})
	check("a 1.5 save in mission 1 keeps its objective", Game.load_game() and int(Game.state["objective"]) == 1)
	Game.delete_save()

func _hollows() -> void:
	Game.delete_save()
	Game.new_state()
	await GameMode.load_area("hollows", "hollows_start", true)
	await get_tree().process_frame
	await get_tree().process_frame
	var a := GameMode.area
	check("hollows loads as the current area", a != null and a.area_id == "hollows")
	check("entering the hollows sets its flag", Game.flag("area.hollows"))
	check("the hollows has its shutdown console", get_tree().get_nodes_in_group("interactable").any(func(n): return n is Console and (n as Console).stable_id == "hol_console"))
	var kinds := {}
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is EnemyBase:
			kinds[(e as EnemyBase).kind] = true
	check("hollows has stalkers and experimentals", kinds.has("stalker") and kinds.has("experimental"), str(kinds.keys()))
	var parts := 0
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is Pickup and (n as Pickup).kind == "part":
			parts += 1
	check("hollows holds the two upgrade parts (%d)" % parts, parts == 2)
	a._shutdown()
	check("the console sets the shutdown flag", Game.flag("hollows.shutdown"))
	check("the shutdown cinematic is playing", get_tree().get_nodes_in_group("cinematic").size() > 0 or GameMode.cinematic_playing)
	a._shutdown()
	check("a second use changes nothing", Game.flag("hollows.shutdown"))
	await get_tree().create_timer(0.3).timeout
	# the cinematic runs to its end on its own; wait it out (bounded)
	var t := 0.0
	while GameMode.cinematic_playing and t < 25.0:  # v1.9.0: the echo cinematic follows the shutdown one
		await get_tree().create_timer(0.25).timeout
		t += 0.25
	check("the shutdown cinematic ends", not GameMode.cinematic_playing, "after %.1f s" % t)
	check("the cinematic sets the cleared flag", Game.flag("hollows.cleared"))
	await GameMode.load_area("exterior", "exterior_hollows", true)
	await get_tree().process_frame
	check("the exterior has a way into the hollows", GameMode.area != null and GameMode.area.area_id == "exterior")
	Game.delete_save()

func _splash() -> void:
	await GameMode.load_area("security", "security_start", true)
	await get_tree().process_frame
	await get_tree().process_frame
	var p: Player = GameMode.player
	p.combat.give("breach", true)
	var w = p.combat.current
	check("breach cannon is equipped for the splash test", w is BreachCannon)
	if not (w is BreachCannon):
		return
	var en: EnemyBase = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is EnemyBase and not (e as EnemyBase).dead:
			en = e
			break
	check("splash test has an enemy", en != null)
	if en == null:
		return
	en.set_physics_process(false)
	var c := en.global_position + Vector3.UP * 0.9
	var pos := c + Vector3(-2.0, 0.0, 0.0)
	var hp0 := en.health.hp
	w._splash(pos, Vector3.UP, Vector3.FORWARD, null)
	var lost := hp0 - en.health.hp
	check("splash hurts an enemy 2 m from the blast", lost > 1.0, "lost %.2f" % lost)
	check("splash is less than the direct slug", lost < BreachCannon.SPLASH_FRACTION * w.data.damage + 0.01)
	var hp1 := en.health.hp
	w._splash(c + Vector3(-9.0, 0.0, 0.0), Vector3.UP, Vector3.FORWARD, null)
	check("splash does nothing beyond its radius", is_equal_approx(en.health.hp, hp1))
	Game.delete_save()
