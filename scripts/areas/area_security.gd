extends Area
## A3 — SECURITY SECTOR (Mission 2 part 2, LOST RESEARCH). Dark industrial: a cover-filled courtyard held by
## Sentinels, the armory (Pulse Rifle), the vehicle bay Brute, and the comms room where the DEAD SIGNAL
## cinematic plays. The cargo lift down to the Reactor Core leaves from the vehicle bay.

var brute: EnemyBase
var lift_platform: Node3D

func build() -> void:
	setup_theme("security", 303)
	B.room("entry", 0, 1, 2, 2, {"light_energy": 0.7})
	B.room("yard", 2, 0, 4, 4, {"h": 2, "light_energy": 0.6})
	B.room("armory", 2, 4, 2, 2, {"light_energy": 0.9})
	B.room("corr", 6, 1, 3, 1, {"light_energy": 0.5})
	B.room("bay", 9, 0, 4, 4, {"h": 2, "light_energy": 0.55, "floor": "solid"})
	B.room("comms", 13, 1, 2, 2, {"light_energy": 0.7})
	B.room("lift", 10, 4, 2, 2, {"h": 2, "light_energy": 0.6})
	B.open(Vector2i(1, 1), "e", "open")
	B.open(Vector2i(1, 2), "e", "open")
	door("armory", Vector2i(2, 3), "s")
	door("yard_corr", Vector2i(5, 1), "e")
	B.open(Vector2i(8, 1), "e", "open")
	door("comms", Vector2i(12, 2), "e", {"lock": "enc.brute", "text": "Door jammed — clear the vehicle bay"})
	B.open(Vector2i(10, 3), "s", "open")
	B.open(Vector2i(11, 3), "s", "open")
	B.open(Vector2i(14, 1), "e", "window")
	B.build()
	_props()
	_lighting()
	_story()
	checkpoint("security_start", at(0.6, 2.0), -90.0)
	checkpoint("security_armory", at(3.0, 5.0), 0.0)
	checkpoint("security_corr", at(6.6, 1.5), -90.0, Vector3(3, 3, 3))
	checkpoint("security_comms", at(13.6, 2.0), -90.0)
	checkpoint("security_lift", at(11.0, 4.6), 180.0)

func _props() -> void:
	# entry
	prop("crate_large", at(0.5, 1.4), 0.0)
	prop("turret_broken", at(1.6, 1.2), -90.0)
	# yard: an obstacle course of cover for Sentinel fights
	var cover := [[3.0, 1.0, "crate_large"], [4.6, 1.4, "cargo_containers"], [3.2, 2.8, "crate_large"], [5.0, 3.0, "crate_large"],
		[4.0, 2.0, "barrel"], [2.6, 2.0, "crate_small"], [5.4, 0.6, "crate_small"], [4.2, 3.6, "debris_pile"]]
	for c in cover:
		prop(c[2], at(c[0], c[1]), randf_range(-20, 20) if c[2] != "cargo_containers" else 90.0)
		cover_point(at(c[0], c[1]) + Vector3(0.0, 0.0, 1.2))
		cover_point(at(c[0], c[1]) + Vector3(0.0, 0.0, -1.2))
	prop("fallen_beam", at(3.5, 3.5) + Vector3(0, 0.0, 0), 30.0)
	prop("kit_pillar", at(4.0, 2.0) + Vector3(-2, 0, -2), 0.0)
	prop("kit_pillar", at(4.0, 2.0) + Vector3(2, 0, 2), 0.0)
	prop("corpse_prone", at(2.8, 1.6), 200.0, true)
	# armory
	for z in [4.3, 4.9, 5.5]:
		prop("locker", at(2.15, z), 90.0)
	prop("server_rack", at(3.85, 5.6), -90.0)
	prop("desk", at(3.0, 4.4), 0.0)
	# corridor
	prop("pipe_straight", at(7.5, 1.1) + Vector3(0, 3.3, 0), 90.0, false)
	prop("barrel", at(7.0, 1.8), 0.0)
	# vehicle bay
	prop("cargo_containers", at(10.0, 0.6), 0.0)
	prop("cargo_containers", at(12.2, 1.6), 90.0)
	prop("crate_large", at(10.4, 2.6), 15.0)
	prop("crate_large", at(11.8, 3.3), -10.0)
	prop("barrel", at(9.4, 3.4), 0.0)
	prop("barrel", at(9.7, 3.6), 0.0)
	prop("debris_pile", at(11.0, 2.0), 0.0, true, 0.8)
	prop("corpse_sitting", at(12.6, 0.4), 180.0, true)
	# comms
	prop("comms_console", at(14.4, 2.0), -90.0)
	prop("server_rack", at(13.2, 1.15), 0.0)
	prop("server_rack", at(13.8, 1.15), 0.0)
	prop("chair", at(14.0, 2.3), 90.0)
	# lift
	var lift := Props.instance("cargo_lift")
	add_child(lift)
	lift.global_position = at(11.0, 5.0)
	lift_platform = Props.part(lift, "Platform")
	if lift_platform:
		Props.add_slab(lift_platform, Vector3(6.1, 0.3, 6.1), Vector3(0, -0.15, 0), true)   # 1.9.2 bug 6: solid floor of the lift, rides it
	label3d("CARGO LIFT — REACTOR LEVEL", at(11.0, 5.95) + Vector3(0, 4.5, 0), 180.0, 72, Color(1.0, 0.75, 0.3))
	# pickups
	pickup("weapon_rifle", "rifle", at(3.0, 4.5) + Vector3(0, 0.8, 0))
	pickup("weapon_shotgun", "sec_shotgun", at(2.4, 5.0) + Vector3(0, 0.8, 0))   # v1.1.0 stage 3
	pickup("weapon_precision", "sec_precision", at(1.2, 2.6) + Vector3(0, 0.8, 0))   # v1.1.0 stage 3
	pickup("ammo_rifle", "sec_r1", at(3.6, 5.2), 32)
	pickup("ammo_pistol", "sec_a1", at(0.6, 2.6), 18)
	pickup("medkit", "sec_m1", at(2.5, 5.6))
	pickup("ammo_rifle", "sec_r2", at(7.6, 1.6), 32)
	pickup("medkit", "sec_m2", at(9.6, 1.0))
	pickup("ammo_rifle", "sec_r3", at(12.0, 3.6), 32)
	# v1.5.0: upgrade parts (14 in all across the game) and the Upgrade Bench
	pickup("part", "sec_p1", at(6.0, 2.4) + Vector3(0, 0.3, 0))
	pickup("part", "sec_p2", at(13.0, 2.0) + Vector3(0, 0.3, 0))
	pickup("part", "sec_p3", at(8.0, 2.0) + Vector3(0, 0.3, 0))
	pickup("part", "sec_p4", at(3.0, 6.0) + Vector3(0, 0.3, 0))
	var bench := UpgradeBench.new()
	add_child(bench)
	bench.global_position = at(11.0, 3.0)
	bench.rotation.y = -PI * 0.5
	var st := AmmoStation.new()
	add_child(st)
	st.global_position = at(3.85, 4.6)
	st.rotation.y = -PI * 0.5
	var st2 := AmmoStation.new()
	st2.give_medkit = true
	add_child(st2)
	st2.global_position = at(8.6, 1.15)
	st2.rotation.y = 0.0
	log_at(8, at(3.0, 4.4) + Vector3(0, 0.82, 0.25))
	log_at(9, at(13.4, 2.6))

func _lighting() -> void:
	room_lights("entry", 2, 0.6)
	room_lights("yard", 2, 0.45, true, 0.2)
	room_lights("armory", 2, 0.9)
	room_lights("corr", 2, 0.5, true, 0.5)
	room_lights("bay", 2, 0.4)
	room_lights("comms", 2, 0.6)
	room_lights("lift", 2, 0.5)
	# red/amber work lights
	for p in [at(2.4, 0.4), at(5.6, 3.6), at(9.4, 0.4), at(12.6, 3.6)]:
		spot(p + Vector3(0, 7.2, 0), p + Vector3(0, 0, 0) + (at(4, 2) - p) * 0.3, Color(1.0, 0.45, 0.2), 4.0, 14.0, 45.0, p.x < 12.0)
	omni(at(11.0, 5.0) + Vector3(0, 6.0, 0), Color(1.0, 0.6, 0.2), 2.0, 10.0, false, 0.4)
	omni(at(14.2, 2.0) + Vector3(0, 1.5, 0), Color(0.3, 0.9, 0.6), 1.0, 5.0)

func _story() -> void:
	trigger("sec_sentinels", at(2.2, 2.0), Vector3(3, 3, 8), func(_p): beat("sentinel", "mira_sentinel", 0.5))
	# yard Sentinels hold the far side; a Stalker flanks
	enemy("sentinel", "sec_t1", at(5.2, 0.8), 90.0)
	enemy("sentinel", "sec_t2", at(5.3, 3.4), 90.0, {"patrol": [at(5.3, 3.4), at(4.4, 2.6)]})
	enemy("stalker", "sec_s1", at(4.6, 3.7), 90.0)
	enemy("hunter", "sec_h1", at(6.4, 4.6), 90.0)   # v1.1.0 stage 2: persistent pursuer
	trigger("sec_armory_hint", at(3.0, 3.4), Vector3(4, 3, 2), func(_p):
		if not Game.flag("got.rifle"):
			beat("armory", "mira_armory"))
	Events.flag_set.connect(func(f):
		if f == "got.rifle":
			GameMode.save_checkpoint("security_armory")
			Events.message.emit("1 / 2 or Q-wheel to switch weapons" if not Game.touch_enabled() else "SWAP switches weapons", 3.0))
	# corridor: a Sentinel squad pushes from the bay once you have the rifle
	enemy("sentinel", "sec_t3", at(9.8, 1.5), 90.0)
	# vehicle bay Brute
	if not Game.flag("enc.brute"):
		brute = enemy("brute", "sec_brute", at(11.4, 2.4), 90.0)
		if brute:
			brute.health.died.connect(func(_i):
				Game.set_flag("enc.brute")
				await get_tree().create_timer(2.0, false).timeout
				Sfx.say("mira_comms")
				GameMode.save_checkpoint("security_corr"))
	trigger("sec_brute_warn", at(8.2, 1.5), Vector3(3, 3, 4), func(_p):
		if not Game.flag("enc.brute"):
			beat("brute", "mira_brute"))
	enemy("stalker", "sec_s2", at(12.5, 3.5), 180.0, {"dormant": true})
	# comms console -> DEAD SIGNAL cinematic
	console("comms_console", at(14.3, 2.0), -90.0, "Restore communications", func(_p): _dead_signal(),
		{"model": "", "focus": Vector3(0, 1.2, 0.4), "requires": "enc.brute", "requires_text": "No power"})
	# cargo lift controls
	console("lift_controls", at(10.2, 4.3), 90.0, "Descend to the Reactor Core", func(_p): _descend(),
		{"model": "terminal", "requires": "comms.restored", "requires_text": "Lift locked — restore comms first", "one_shot": false})

func _dead_signal() -> void:
	var c := Cinematic.new()
	c.hide_player = false
	add_child(c)
	var con := at(14.4, 2.0) + Vector3(0, 1.2, 0)
	var floor_c := at(14.4, 2.0)
	var pl := floor_c + Vector3(-1.05, 0, 0)
	var p: Player = GameMode.player
	if p:
		# Kabir at the console, facing it (+X), so the shots can hold on him while the signal plays
		p.global_position = pl + Vector3(0, 0.05, 0)
		p.rotation.y = deg_to_rad(-90.0)
		if p.controller:
			p.controller.yaw = -90.0
		p.velocity = Vector3.ZERO
	c.shot(pl + Vector3(-2.9, 1.9, 2.5), con + Vector3(0, -0.1, 0), pl + Vector3(-2.2, 1.75, 1.9), con, 6.0, 50.0, 44.0)
	c.shot(pl + Vector3(0.6, 1.72, 1.15), pl + Vector3(0, 1.58, 0), pl + Vector3(0.5, 1.7, 0.85), pl + Vector3(0.05, 1.62, 0), 6.0, 38.0, 32.0)
	c.shot(Vector3(53.0, 3.4, 4.6), con + Vector3(0, -0.4, 0), Vector3(53.5, 3.0, 5.1), con + Vector3(0, -0.3, 0), 9.0, 55.0, 48.0)
	# the console screens throb with the signal
	var sig := OmniLight3D.new()
	sig.light_color = Color(0.35, 0.85, 1.0)
	sig.omni_range = 5.0
	sig.shadow_enabled = false
	add_child(sig)
	sig.global_position = con + Vector3(-0.6, 0.3, 0)
	var tw := create_tween().set_loops(10)
	tw.tween_property(sig, "light_energy", 3.0, 0.35)
	tw.tween_property(sig, "light_energy", 0.6, 0.75)
	get_tree().create_timer(22.0, false).timeout.connect(sig.queue_free)
	c.at(0.3, func(): Sfx.play("comms_static", -4.0))
	c.at(1.5, func(): Sfx.say("echo_signal", true))
	c.say(10.5, "mira_signal")
	c.at(20.8, func():
		Game.set_flag("comms.restored")
		Sfx.sting("sting_reveal", -4.0), true)
	await c.play()
	GameMode.save_checkpoint("security_comms")
	await get_tree().create_timer(1.0, false).timeout
	Sfx.say("mira_reactor")

func _descend() -> void:
	var p: Player = GameMode.player
	if p == null:
		return
	p.locked = true
	Sfx.play("lift_start", 0.0)
	Events.camera_shake.emit(0.3, 2.5)
	var lp := Sfx.emitter("lift_loop", self, -2.0, 30.0)
	if lift_platform:
		create_tween().tween_property(lift_platform, "position:y", lift_platform.position.y - 1.5, 2.5)
	await get_tree().create_timer(2.2, false).timeout
	if lp:
		lp.queue_free()
	p.locked = false
	GameMode.travel("reactor", "reactor_start")

func on_enter(fresh: bool) -> void:
	super.on_enter(fresh)
	tension = true
