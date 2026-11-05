extends Node
## v1.7.0 bug-hunt suite (stage F): routes and edge cases the feature suites do not walk. --driver=stage9
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
	Game.SAVE_PATH = "user://stage9_save.json"
	Game.delete_save()
	Game.settings["touch"] = "off"
	Game.apply_settings()
	await _route()
	await _melee_edges()
	_rebind()
	await _save_in_hollows()
	Game.delete_save()
	print("STAGE9 %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)

func _route() -> void:
	# exterior -> hollows through the valley entrance zone, and back through the hollows exit zone
	Game.new_state()
	await GameMode.load_area("exterior", "exterior_hollows", true)
	await get_tree().process_frame
	await get_tree().process_frame
	var p: Player = GameMode.player
	check("exterior: start at the hollows checkpoint", GameMode.area.area_id == "exterior" and p != null)
	p.global_position = Vector3(-9.0, p.global_position.y + 0.2, -41.0)
	var t := 0.0
	while GameMode.area != null and GameMode.area.area_id != "hollows" and t < 6.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	check("the valley entrance zone takes the player into the hollows", GameMode.area != null and GameMode.area.area_id == "hollows", "in %s after %.1f s" % [GameMode.area.area_id if GameMode.area else "none", t])
	await get_tree().process_frame
	p = GameMode.player
	if GameMode.area == null or GameMode.area.area_id != "hollows" or p == null:
		return
	# the hollows exit zone sits at the entrance: stepping onto it returns to the exterior
	p.global_position = Vector3(0.0, p.global_position.y + 0.2, 4.0)
	t = 0.0
	while GameMode.area != null and GameMode.area.area_id != "exterior" and t < 6.0:
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	check("the hollows exit zone returns to the exterior", GameMode.area != null and GameMode.area.area_id == "exterior", "after %.1f s" % t)
	Game.delete_save()

func _melee_edges() -> void:
	await GameMode.load_area("security", "security_start", true)
	await get_tree().process_frame
	await get_tree().process_frame
	var p: Player = GameMode.player
	p.melee_cd = 0.0
	p.locked = true
	check("melee does nothing while the player is locked (cinematic, puzzle)", not p.try_melee())
	p.locked = false
	p.melee_cd = 0.0
	p.dead = true
	check("melee does nothing while dead", not p.try_melee())
	p.dead = false
	p.melee_cd = 0.0
	var ok := true
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is EnemyBase and (e as EnemyBase).dead:
			ok = ok and Melee.target_in_arc(p) != e
	check("a dead enemy is never a melee target", ok)
	var en: EnemyBase = null
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is EnemyBase and not (e as EnemyBase).dead:
			en = e
			break
	if en != null:
		en.set_physics_process(false)
		en.health.hp = 1.0
		en.global_position = p.global_position + p.forward() * 1.0 + Vector3(0, 0.05, 0)
		p.melee_cd = 0.0
		var r := Melee.swing(p)
		check("a low-health enemy dies to one melee hit", en.dead, "r=%s" % r)
		check("a dead enemy is not staggered", not en.is_staggered())
	p.melee_cd = 0.0
	p.melee_cd = 0.0
	var miss := Melee.swing(p)
	check("melee with no target reports a miss", miss == "")

func _rebind() -> void:
	var before := Game.binding_of("melee")
	Game.set_binding("melee", KEY_B)
	check("melee can be rebound to B", Game.binding_of("melee") == KEY_B)
	Game.set_binding("melee", KEY_G)
	check("melee rebinds back to G", Game.binding_of("melee") == KEY_G or before == KEY_G)
	Game.reset_bindings()
	check("reset puts melee back on G", Game.binding_of("melee") == KEY_G)

func _save_in_hollows() -> void:
	Game.new_state()
	await GameMode.load_area("hollows", "hollows_start", true)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.set_flag("hollows.shutdown")
	check("save inside the hollows writes", Game.save_game())
	Game.new_state()
	check("the save loads back", Game.load_game())
	check("the saved area is the hollows", Game.state["area"] == "hollows")
	check("the shutdown flag survives the save", Game.flag("hollows.shutdown"))
	Game.delete_save()
