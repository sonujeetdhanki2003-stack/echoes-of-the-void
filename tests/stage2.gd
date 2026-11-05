extends Node
## v1.1.0 stage 2 tests: the hunter and the experimental organism.  --driver=stage2
var passed := 0
var failed := 0
var _exp: Experimental = null
const SPORE_OUT := 9.0

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
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["touch"] = "off"
	Game.apply_settings()
	await GameMode.load_area("cryo", "cryo_hub", true)
	await frames(10)
	_factory()
	_data()
	await _spawn_and_persistence()
	await _spores()
	print("STAGE2 %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)

func _factory() -> void:
	var h := Enemies.make("hunter")
	var e := Enemies.make("experimental")
	check("factory: hunter", h is Hunter and h.kind == "hunter")
	check("factory: experimental is a hunter variant", e is Experimental and e is Hunter and e.kind == "experimental")
	check("factory: hunter data loaded", h.data != null and h.data.id == "hunter" and h.data.max_hp == 150.0)
	check("factory: experimental data loaded", e.data != null and e.data.id == "experimental" and e.data.max_hp == 260.0)
	h.free()
	e.free()

func _data() -> void:
	var st: EnemyData = load("res://data/enemies/stalker.tres")
	var hu: EnemyData = load("res://data/enemies/hunter.tres")
	var ex: EnemyData = load("res://data/enemies/experimental.tres")
	check("balance: hunter hits harder than stalker", hu.melee_damage > st.melee_damage, "%s vs %s" % [hu.melee_damage, st.melee_damage])
	check("balance: hunter tougher than stalker", hu.max_hp > st.max_hp)
	check("balance: experimental tougher than hunter", ex.max_hp > hu.max_hp)
	check("balance: hunter run speed below stalker (relentless, not fastest)", hu.run_speed < st.run_speed)

func _spawn_and_persistence() -> void:
	var p: Player = GameMode.player
	var h: Hunter = GameMode.area.enemy("hunter", "s2_hunter", p.global_position + Vector3(9.0, 0.0, 0.0), 0.0)
	await frames(12)
	check("spawn: hunter in the world", h != null and h.is_inside_tree())
	if h == null:
		return
	h.set_state(EnemyBase.State.DORMANT)
	h.perception.last_seen_t = h.perception.now() - 11.0
	check("persistence: still tracking at 11 s unseen", not h.should_give_up())
	h.perception.last_seen_t = h.perception.now() - 13.0
	check("persistence: gives up after 12 s unseen", h.should_give_up())
	var hp_before := h.health.hp
	h.take_hit(9999.0, {"pos": h.global_position, "dir": Vector3.FORWARD, "critical": false, "source": p, "kind": "rifle", "normal": Vector3.UP})
	check("hunter: lethal hit kills it", h.dead or h.health.hp <= 0.0, "hp %s" % str(hp_before))
	var e: Experimental = GameMode.area.enemy("experimental", "s2_exp", p.global_position + Vector3(0.0, 0.0, 9.0), 0.0)
	await frames(12)
	check("spawn: experimental in the world", e != null and e.is_inside_tree())
	if e == null:
		return
	_exp = e
	e.pick_juke()
	check("juke: sideways burst speed in range", e._juke_dir.length() >= 0.59 and e._juke_dir.length() <= 1.01, str(e._juke_dir.length()))
	check("juke: sideways, not forward", absf(e._juke_dir.normalized().dot(e.global_transform.basis.x)) > 0.9)
	check("juke: timer set 1.2 to 3.0 s", e._juke_t >= 1.2 and e._juke_t <= 3.0)
	e.set_state(EnemyBase.State.DORMANT)
	# keep the test organism out of the fight: it only releases spores when told to
	e.perception.enabled = false

func _spores() -> void:
	var p: Player = GameMode.player
	var e: Experimental = _exp
	check("spores: test organism found", e != null)
	if e == null:
		return
	e.release_spores()
	check("spores: cloud released", is_instance_valid(e._cloud) and e._spore_t > 4.0, "t %s" % str(e._spore_t))
	var hp0: float = p.health.hp
	p.global_position = e._spore_pos + Vector3(0.0, 0.0, 0.5)
	await frames(60)
	var hp1: float = p.health.hp
	check("spores: standing in the cloud hurts", hp1 < hp0, "hp %s -> %s" % [str(hp0), str(hp1)])
	p.global_position = e._spore_pos + Vector3(SPORE_OUT, 0.0, 0.0)
	await frames(30)
	var hp2: float = p.health.hp
	var hp_mid := hp2
	await frames(60)
	check("spores: outside the cloud no damage", p.health.hp >= hp_mid - 0.01, "hp %s -> %s" % [str(hp_mid), str(p.health.hp)])
	var waited := 0
	while is_instance_valid(e._cloud) and waited < 600:
		await frames(10)
		waited += 10
	check("spores: cloud expires after 5 s", not is_instance_valid(e._cloud) and e._spore_t <= 0.0, "t %s" % str(e._spore_t))

