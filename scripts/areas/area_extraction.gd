extends Area
## A6 — EXTRACTION ZONE (Mission 4 part 2). The launch pad on a plateau beside a chasm, emergency-red lights,
## the shuttle. Send the warning -> THE HERALD rises -> three-phase boss fight -> ENDING cinematic and credits.

var terrain: Terrain
var herald: Herald
var shuttle: Node3D
var spire_light: OmniLight3D
const PAD := Vector3(0, 0, 0)
const HERALD_POS := Vector3(27.5, -0.5, -2.0)

func build() -> void:
	setup_theme("extraction", 606)
	nav.navigation_mesh.cell_size = 0.5
	nav.navigation_mesh.cell_height = 0.25
	nav.navigation_mesh.agent_max_climb = 0.5
	nav.navigation_mesh.filter_baking_aabb = AABB(Vector3(-40, -10, -40), Vector3(64, 30, 100))
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, 0.5)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, 0.25)
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	# the storm: the same NYX-7 sky, burning red (emergency palette), heavy cloud
	sm.set_shader_parameter("zenith", Vector3(0.02, 0.006, 0.01))
	sm.set_shader_parameter("horizon", Vector3(0.22, 0.05, 0.05))
	sm.set_shader_parameter("glow_col", Vector3(0.9, 0.18, 0.08))
	sm.set_shader_parameter("cloud_col", Vector3(0.12, 0.03, 0.035))
	sm.set_shader_parameter("aurora_col", Vector3(0.6, 0.1, 0.25))
	sm.set_shader_parameter("clouds", 1.0)
	sm.set_shader_parameter("stars", 0.4)
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.fog_sky_affect = 0.18
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_energy = 0.6
	make_sun(Vector3(-12, -120, 0), Color(0.75, 0.62, 0.9), 0.75, true)
	terrain = Terrain.new(606)
	terrain.origin = Vector3(0, 0, 20)
	terrain.size = 180.0
	terrain.amp = 5.0
	terrain.path = PackedVector3Array([Vector3(0, 0, 70), Vector3(0, 0, 30), Vector3(0, 0, 0)])
	terrain.path_width = 30.0
	terrain.flats = [[PAD, 26.0, 0.0], [Vector3(46, 0, -2), 20.0, -40.0], [Vector3(42, 0, 24), 16.0, -40.0], [Vector3(42, 0, -26), 16.0, -40.0]]
	terrain.build(self, Terrain.ground_material())
	_pad()
	_story()
	checkpoint("extraction_start", Vector3(0, 0.3, 54), 0.0)
	checkpoint("extraction_pad", Vector3(-6, 0.5, 10), 0.0)
	checkpoint("extraction_boss", Vector3(-8, 0.5, 6), -90.0)

func _pad() -> void:
	var pad := prop("landing_pad", PAD, 0.0)
	shuttle = Props.instance("shuttle")
	add_child(shuttle)
	shuttle.global_position = PAD + Vector3(-6, 0.4, -6)
	shuttle.rotation.y = deg_to_rad(20.0)
	var sc := Props.make("shuttle", true)
	add_child(sc)
	sc.global_transform = shuttle.global_transform
	sc.get_child(0).visible = false
	# chasm rim: an invisible wall the player can't cross (the Herald's side)
	var rim := StaticBody3D.new()
	rim.collision_layer = 64      # blocks the player only; shots and the beam pass over the chasm
	add_child(rim)
	B.box_collider(Vector3(20.5, 3.0, 0), Vector3(1.0, 10.0, 90.0), rim)
	for z in range(-30, 34, 8):
		prop("alien_rock_d", Vector3(21.0, terrain.height_at(21.0, z) - 0.4, z), z * 17.0, true, 1.2)
	# cover on the pad for the beam
	var cover := [[Vector3(6, 0.4, 4), "cargo_containers", 90.0], [Vector3(-2, 0.4, 9), "crate_large", 15.0], [Vector3(9, 0.4, -8), "crate_large", -10.0],
		[Vector3(-10, 0.4, 2), "crate_large", 0.0], [Vector3(2, 0.4, -2), "cargo_containers", 0.0], [Vector3(12, 0.4, 10), "crate_large", 30.0]]
	for c in cover:
		prop(c[1], c[0], c[2])
		cover_point(c[0] + Vector3(-1.6, 0, 0))
	prop("antenna_mast", PAD + Vector3(-14, 0.4, -14), 0.0)
	var cc := Props.instance("comms_console")
	add_child(cc)
	cc.global_position = PAD + Vector3(-12, 0.4, 12)
	cc.rotation.y = deg_to_rad(45.0)
	# emergency lights at the pad corners
	for c in [Vector3(-15, 1.4, -15), Vector3(15, 1.4, -15), Vector3(-15, 1.4, 15), Vector3(15, 1.4, 15)]:
		omni(c, Color(1.0, 0.18, 0.1), 3.0, 16.0, false, 0.15)
	spot(PAD + Vector3(-6, 14, 6), PAD + Vector3(-6, 0, -6), Color(1.0, 0.85, 0.7), 4.0, 30.0, 40.0, true)
	var spire := Props.instance("the_spire")
	add_child(spire)
	spire.global_position = Vector3(-60, -10, -380)
	spire.scale = Vector3.ONE * 2.2
	spire_light = omni(Vector3(-60, 80, -360), Color(0.6, 0.3, 1.0), 10.0, 220.0)
	# resupply around the arena (no softlock in the boss fight)
	for p in [[Vector3(-14, 0.4, 6), 90.0], [Vector3(-4, 0.4, -14), 0.0], [Vector3(10, 0.4, 14), 180.0]]:
		var st := AmmoStation.new()
		st.give_medkit = true
		st.recharge = 25.0
		add_child(st)
		st.global_position = p[0]
		st.rotation.y = deg_to_rad(p[1])
	pickup("ammo_rifle", "exz_r1", Vector3(-2, 0.1, 40), 48)
	pickup("medkit", "exz_m1", Vector3(3, 0.1, 34))
	log_at(15, Vector3(-11, 0.42, 10.5))
	prop("crystal_figure", Vector3(-13.5, 0.4, 9.0), 120.0)

func _story() -> void:
	trigger("exz_arrive", Vector3(0, 0, 24), Vector3(30, 6, 6), func(_p):
		beat("pad", "mira_pad", 0.5)
		GameMode.save_checkpoint("extraction_pad"))
	enemy("stalker", "exz_s1", Vector3(8, terrain.height_at(8, 30), 30), 180.0)
	enemy("sentinel", "exz_t1", Vector3(-12, 0.5, -4), 180.0)
	console("pad_comms", PAD + Vector3(-12, 0.4, 12), 45.0, "Send the warning", func(_p): _transmit(),
		{"model": "", "focus": Vector3(0, 1.2, 0.6)})
	herald = Herald.new()
	add_child(herald)
	herald.global_position = HERALD_POS
	herald.rotation.y = PI * 0.5
	herald.vents = [Vector3(14, 0.4, -14), Vector3(14, 0.4, 14), Vector3(-14, 0.4, -10), Vector3(16, 0.4, 0)]
	herald.defeated.connect(_on_herald_dead)
	herald.phase_changed.connect(_on_phase)
	if Game.flag("transmission.sent") and not Game.flag("boss.dead"):
		call_deferred("_climax")
	elif Game.flag("boss.dead"):
		call_deferred("_after_boss")

func _on_phase(ph: int) -> void:
	if ph == 1:
		Sfx.say("mira_nodes", true)
	elif ph == 3:
		Sfx.say("mira_phase3", true)

func _transmit() -> void:
	var p: Player = GameMode.player
	Sfx.play("comms_static", -6.0)
	var dur := Sfx.say("kabir_transmission", true)
	Events.message.emit("Transmitting…", maxf(dur, 6.0))
	await get_tree().create_timer(maxf(dur, 6.0) + 0.4, false).timeout
	Game.set_flag("transmission.sent")
	GameMode.save_checkpoint("extraction_boss", false)
	_climax()

func _climax() -> void:
	var c := Cinematic.new()
	add_child(c)
	var hp := HERALD_POS
	c.shot(PAD + Vector3(-10, 2.0, 16), PAD + Vector3(6, 2, -2), PAD + Vector3(-12, 1.6, 18), PAD + Vector3(10, 4, -2), 3.0, 50.0)
	c.shot(PAD + Vector3(18, 0.9, 12), hp + Vector3(0, 4, 0), PAD + Vector3(17, 0.8, 13.5), hp + Vector3(0, 12, 0), 7.0, 45.0, 55.0)
	c.shot(PAD + Vector3(14, 1.0, 6), hp + Vector3(0, 11, 0), PAD + Vector3(12, 0.8, 8), hp + Vector3(0, 10, 0), 4.0, 38.0, 34.0)
	c.at(0.3, func():
		Events.camera_shake.emit(0.5, 3.0)
		Sfx.say("mira_herald", true))
	c.at(2.6, func(): herald.rise(), true)
	c.at(10.4, func(): Sfx.play_at("herald_roar", herald.global_position + Vector3.UP * 10.0, 8.0, 300.0))
	c.at(13.9, func(): pass, true)
	await c.play()
	GameMode.boss_fight = true
	herald.start_fight()

func _on_herald_dead() -> void:
	GameMode.boss_fight = false
	Game.set_flag("boss.dead")
	await get_tree().create_timer(4.0, false).timeout
	Sfx.say("mira_victory", true)
	GameMode.save_checkpoint("extraction_boss", false)
	_after_boss()

func _after_boss() -> void:
	if herald:
		herald.visible = Game.flag("boss.dead") == false
	var b := console("shuttle_ramp", shuttle.global_position + shuttle.global_basis * Vector3(0, 0.0, 7.6), rad_to_deg(shuttle.rotation.y) + 180.0, "Board the shuttle", func(_p): _ending(), {"model": "", "focus": Vector3(0, 1.2, 0)})
	b.range_m = 4.0

func _ending() -> void:
	var p: Player = GameMode.player
	var c := Cinematic.new()
	add_child(c)
	var sp := shuttle.global_position
	c.shot(sp + Vector3(-18, 3, 22), sp + Vector3(0, 2, 0), sp + Vector3(-20, 4, 24), sp + Vector3(0, 6, 0), 6.0, 45.0)
	c.shot(sp + Vector3(30, 2, 40), sp + Vector3(0, 10, 0), sp + Vector3(30, 2, 40), sp + Vector3(0, 60, -20), 9.0, 50.0, 45.0)
	c.shot(Vector3(0, 6, 60), Vector3(-60, 40, -380), Vector3(0, 6, 58), Vector3(-60, 30, -380), 8.0, 40.0, 36.0)
	c.shot(Vector3(0, 6, 58), Vector3(0, 200, -200), Vector3(0, 6, 58), Vector3(0, 400, -100), 12.0, 50.0, 40.0)
	c.at(0.1, func():
		Sfx.set_music_mode("ending")
		if p:
			p.visible = false)
	c.at(5.8, func():
		Sfx.play("shuttle_launch", 6.0)
		Events.camera_shake.emit(0.7, 4.0)
		# engines light up, dust blows off the pad
		var ramp := shuttle.find_child("Ramp", true, false) as Node3D
		if ramp:
			# the ramp is exported open (139 deg about its hinge); identity = closed against the hull
			create_tween().tween_property(ramp, "quaternion", Quaternion.IDENTITY, 1.4).set_trans(Tween.TRANS_SINE)
		# OSV-2 PERSEPHONE: two main engines in the tail (local +Z), belly lift thruster under the centre
		for x in [-3.0, 3.0]:
			Fx.thruster(shuttle, Vector3(x, 4.3, 7.0), Vector3(0, -0.25, 1.0), 1.3)
		Fx.thruster(shuttle, Vector3(0, 1.2, 0.0), Vector3.DOWN, 0.8)
		var eng := _shuttle_mats("EmitEngine")
		for m in eng:
			create_tween().tween_property(m, "emission_energy_multiplier", 14.0, 1.5)
		for i in 6:
			var a := TAU * float(i) / 6.0
			Fx.burst(sp + Vector3(cos(a) * 5.0, 0.4, sin(a) * 5.0), Color(0.5, 0.42, 0.4), 2.2, 30)
		var nose := -shuttle.global_basis.z
		nose.y = 0.0
		nose = nose.normalized()
		var tw := create_tween()
		tw.tween_property(shuttle, "global_position", sp + Vector3(0, 6, 0), 2.5).set_ease(Tween.EASE_IN)
		tw.tween_property(shuttle, "global_position", sp + Vector3(0, 220, 0) + nose * 160.0, 7.0).set_ease(Tween.EASE_IN))
	c.at(15.5, func():
		create_tween().tween_property(spire_light, "light_energy", 0.0, 5.0)
		Sfx.say("kabir_transmission", true))
	c.at(23.5, func(): Sfx.say("mira_goodbye"))
	c.at(34.0, func():
		Game.set_flag("game.complete")
		Game.state["stats"]["complete"] = true, true)
	await c.play()
	await GameMode.ui.fade_to(1.0, 2.0)
	Sfx.stop_voice()
	Sfx.play("comms_static", -8.0)
	await get_tree().create_timer(2.0, false).timeout
	Sfx.say("kabir_echo", true)
	await get_tree().create_timer(6.0, false).timeout
	GameMode.save_checkpoint("extraction_boss", false)
	GameMode.ui.show_end_credits()

## Unique copies of the shuttle's materials whose name starts with `prefix` (so the launch can brighten the engines).
func _shuttle_mats(prefix: String) -> Array:
	var out: Array = []
	for mi in shuttle.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var mat := m.get_active_material(i)
			if mat is StandardMaterial3D and mat.resource_name.begins_with(prefix):
				var d: StandardMaterial3D = mat.duplicate()
				d.emission_enabled = true
				m.set_surface_override_material(i, d)
				out.append(d)
	return out

func _process(delta: float) -> void:
	super._process(delta)
	if spire_light and not Game.flag("game.complete"):
		spire_light.light_energy = 9.0 + sin(_t * 1.2) * 3.0

func on_enter(fresh: bool) -> void:
	super.on_enter(fresh)
	tension = true
