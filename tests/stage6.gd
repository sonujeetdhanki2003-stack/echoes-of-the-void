extends Node
## v1.6.0 stage 6 (stage B) tests: melee strike input and reach, stagger, finishing moves, flanking, herald telegraph
## cues, touch button. --driver=stage6
var passed := 0
var failed := 0

func check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, "  ", extra)

func _ready() -> void:
	await get_tree().process_frame
	Game.SAVE_PATH = "user://stage6_save.json"
	Game.delete_save()
	Game.settings["touch"] = "off"
	Game.apply_settings()
	_keys_check()
	await GameMode.load_area("security", "security_start", true)
	await get_tree().process_frame
	await get_tree().process_frame
	await _melee()
	await _flank()
	_telegraph()
	Game.delete_save()
	print("STAGE6 %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)

func _keys_check() -> void:
	check("melee action is bound by default (G)", Game.DEFAULT_KEYS.has("melee") and Game.DEFAULT_KEYS["melee"].has(KEY_G))
	check("melee action exists in the input map", InputMap.has_action("melee"))
	var ev := InputEventKey.new()
	ev.keycode = KEY_G
	ev.physical_keycode = KEY_G
	ev.pressed = true
	check("G triggers melee", InputMap.event_is_action(ev, "melee"))
	check("lamp still on F", InputMap.event_is_action(_key(KEY_F), "lamp"))
	check("melee is rebindable", Game.REBINDABLE.any(func(p): return p[0] == "melee"))
	check("melee is on the pad (dpad right)", InputMap.action_has_event("melee", _pad()))
	check("melee tuning sane", Melee.RANGE > 1.5 and Melee.RANGE < 3.0 and Melee.COOLDOWN > 0.2 and Melee.FINISH_MULT >= 10.0)

func _key(k: int) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.physical_keycode = k
	ev.pressed = true
	return ev

func _pad() -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = JOY_BUTTON_DPAD_RIGHT
	return e

func _enemies() -> Array:
	var out: Array = []
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is EnemyBase and not (e as EnemyBase).dead:
			out.append(e)
	return out

func _place_in_front(p: Player, en: EnemyBase, dist: float, side: float = 0.0) -> void:
	var f := p.forward()
	f.y = 0.0
	f = f.normalized()
	var r := Vector3(-f.z, 0.0, f.x)
	en.global_position = p.global_position + f * dist + r * side + Vector3(0, 0.05, 0)
	en.velocity = Vector3.ZERO
	en.set_physics_process(false)

func _melee() -> void:
	var p: Player = GameMode.player
	var en: EnemyBase = null
	for e in _enemies():
		en = e
		break
	check("security has an enemy to test on", en != null)
	if en == null:
		return
	p.melee_cd = 0.0
	_place_in_front(p, en, 1.2)
	var hp0 := en.health.hp
	check("enemy in front, in reach", Melee.target_in_arc(p) == en)
	var r1 := Melee.swing(p)
	check("first swing hits and staggers", r1 == "stagger" and en.health.hp < hp0 and en.is_staggered(), "r=%s hp %.1f->%.1f" % [r1, hp0, en.health.hp])
	p.melee_cd = 0.0
	var r2 := Melee.swing(p)
	check("second swing on a staggered enemy is a finishing move", r2 == "finish" and en.dead, "r=%s dead=%s" % [r2, en.dead])
	await get_tree().process_frame
	# out of reach / behind
	var en2: EnemyBase = null
	for e in _enemies():
		if e != en:
			en2 = e
			break
	if en2 != null:
		_place_in_front(p, en2, 6.0)
		check("enemy 6 m away is out of reach", Melee.target_in_arc(p) == null)
		_place_in_front(p, en2, 1.0)
		en2.global_position += -p.forward() * 2.0
		check("enemy behind the player is out of the arc", Melee.target_in_arc(p) == null)
	p.melee_cd = 0.0
	p.try_melee()
	check("try_melee starts the cooldown", p.melee_cd > 0.1, "cd %.2f" % p.melee_cd)
	check("cooldown blocks a second swing at once", not p.try_melee())
	p.melee_cd = 0.0
	# staggered window ends
	check("staggered is false for a fresh enemy", en2 == null or not en2.is_staggered())

func _flank() -> void:
	var p: Player = GameMode.player
	var group: Array = []
	for e in _enemies():
		if (e as EnemyBase).kind in EnemyBase.FLANK_KINDS:
			group.append(e)
	check("security has two flank-capable enemies", group.size() >= 2, "found %d" % group.size())
	if group.size() < 2:
		return
	var pp := p.global_position
	var angs: Array = []
	for i in 2:
		var en: EnemyBase = group[i]
		en.set_physics_process(false)
		en.alerted = true
		en.state = EnemyBase.State.CHASE
		var a := TAU * float(i) / 2.0
		en.global_position = pp + Vector3(cos(a), 0.0, sin(a)) * 8.0
	await get_tree().process_frame
	var goals: Array = []
	for i in 2:
		goals.append((group[i] as EnemyBase).flank_goal(pp))
	var dist_ok := true
	for g in goals:
		var d := Vector2(g.x - pp.x, g.z - pp.z).length()
		dist_ok = dist_ok and d > 1.0 and d < 3.0
	check("flankers take ring positions near the player", dist_ok)
	var sep := Vector2(goals[0].x - goals[1].x, goals[0].z - goals[1].z).length()
	check("two flankers take different positions", sep > 1.0, "sep %.2f" % sep)
	for en in group:
		(en as EnemyBase).alerted = false
		(en as EnemyBase).state = EnemyBase.State.IDLE
	var solo: EnemyBase = group[0]
	check("a non-alerted enemy goes straight at the player", solo.flank_goal(pp).is_equal_approx(pp))

func _telegraph() -> void:
	var consts: Dictionary = load("res://scripts/ai/herald.gd").get_script_constant_map()
	check("herald slam has a wind-up cue", str(consts.get("CUE_SLAM", "")).begins_with("SLAM"))
	check("herald sweep has a wind-up cue", str(consts.get("CUE_SWEEP", "")).begins_with("SWEEP"))
