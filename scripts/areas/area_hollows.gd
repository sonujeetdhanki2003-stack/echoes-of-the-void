extends Area
## v1.6.0 (stage D) — THE HOLLOWS, a sunken crystal basin west of the canyon path (Mission 4, THE SIGNAL). The
## Spire's relay sends a steady tone from the basin's heart. A narrow valley winds down into the basin: stalker
## packs and an organism guard the crystal floor, and crawlers chitter in the cracks. At the end, a transmitter
## mast on a crystal plinth can be shut down from its console (cinematic). Optional for the final route, but the
## mission objective and the story beats expect it (see ASSUMPTIONS.md).

var terrain: Terrain
var mast_light: OmniLight3D
var _chitter_t := 3.0
const PATH_H := [Vector3(0, 0, 0), Vector3(6, 0, -24), Vector3(-10, 0, -44), Vector3(-16, 0, -66), Vector3(2, 0, -84), Vector3(14, 0, -100)]

func build() -> void:
	setup_theme("exterior", 818)
	nav.navigation_mesh.cell_size = 0.5
	nav.navigation_mesh.cell_height = 0.25
	nav.navigation_mesh.agent_max_climb = 0.5
	nav.navigation_mesh.filter_baking_aabb = AABB(Vector3(-60, -20, -130), Vector3(120, 60, 150))
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, 0.5)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, 0.25)
	_sky()
	terrain = Terrain.new(818)
	terrain.origin = Vector3(0, 0, -50)
	terrain.size = 160.0
	terrain.path = PackedVector3Array(PATH_H)
	terrain.path_width = 13.0
	terrain.flats = [[Vector3(14, 0, -100), 14.0, 0.0], [Vector3(0, 0, 0), 9.0, 0.0]]
	terrain.build(self, Terrain.ground_material())
	_set_pieces()
	_story()
	checkpoint("hollows_start", Vector3(0, 0.3, -2.0), 0.0)
	checkpoint("hollows_basin", _g(12, -94), 180.0, Vector3(12, 4, 6))
	exit_zone("to_exterior", _g(0, 4), Vector3(8, 6, 4), "exterior", "exterior_hollows")   # behind the arrival point, so arriving never starts inside it

func _g(x: float, z: float, lift: float = 0.0) -> Vector3:
	return Vector3(x, terrain.height_at(x, z) + lift, z)

func _sky() -> void:
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sm
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.sky = sky
	env.fog_sky_affect = 0.3
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.5
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	make_sun(Vector3(-30, -120, 0), Color(0.6, 0.55, 1.0), 0.55, true)

func _set_pieces() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 818
	var kinds := ["crystal_cluster_a", "crystal_cluster_b", "crystal_cluster_c", "alien_plant_a", "alien_plant_b"]
	for i in 70:
		var t := rng.randf()
		var seg := int(t * (PATH_H.size() - 1))
		var c: Vector3 = PATH_H[seg].lerp(PATH_H[seg + 1], t * (PATH_H.size() - 1) - seg)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var p := c + Vector3(side * rng.randf_range(5.0, 26.0), 0, rng.randf_range(-4, 4))
		if p.distance_to(Vector3(14, 0, -100)) < 12.0 or p.distance_to(Vector3(0, 0, 0)) < 8.0:
			continue
		var k: String = kinds[rng.randi() % kinds.size()]
		prop(k, _g(p.x, p.z, -0.2), rng.randf() * 360.0, true, rng.randf_range(0.9, 1.7))
	for i in 20:
		var t := rng.randf()
		var seg := int(t * (PATH_H.size() - 1))
		var c: Vector3 = PATH_H[seg].lerp(PATH_H[seg + 1], t * (PATH_H.size() - 1) - seg)
		var p := c + Vector3((1.0 if rng.randf() < 0.5 else -1.0) * rng.randf_range(12.0, 30.0), 0, rng.randf_range(-6, 6))
		prop(["alien_rock_a", "alien_rock_b", "alien_rock_c", "alien_rock_d"][rng.randi() % 4], _g(p.x, p.z, -1.0), rng.randf() * 360.0, true, rng.randf_range(1.2, 2.6))
	# basin: a crystal plinth around the transmitter, lit from below
	var basin := Vector3(14, 0, -100)
	prop("crystal_cluster_c", _g(basin.x, basin.z), 0.0, true, 2.4)
	prop("antenna_mast", _g(basin.x + 1.5, basin.z - 1.0), 20.0, true)
	mast_light = omni(_g(basin.x, basin.z, 6.0), Color(0.7, 0.35, 1.0), 4.0, 26.0)
	for i in 6:
		var a := TAU * float(i) / 6.0
		omni(_g(basin.x + cos(a) * 9.0, basin.z + sin(a) * 9.0, 1.2), Color(0.55, 0.3, 1.0), 1.6, 10.0)
	# valley crystals glow along the route
	for i in 6:
		var c: Vector3 = PATH_H[1 + i % (PATH_H.size() - 2)]
		omni(_g(c.x + (9.0 if i % 2 == 0 else -9.0), c.z, 1.5), Color(0.5, 0.3, 1.0), 1.8, 11.0)
	# cover on the route
	for p in [Vector3(4, 0, -40), Vector3(-12, 0, -58), Vector3(4, 0, -78)]:
		prop("alien_rock_d", _g(p.x, p.z, -0.4), rng.randf() * 360.0, true, 1.0)
		cover_point(_g(p.x, p.z + 3.0))
	# pickups
	pickup("ammo_pistol", "hol_a1", _g(-3, -14, 0.1), 24)
	pickup("medkit", "hol_m1", _g(-14, -50, 0.1))
	pickup("ammo_rifle", "hol_r1", _g(10, -70, 0.1), 48)
	pickup("medkit", "hol_m2", _g(12, -94, 0.1))
	pickup("part", "hol_p1", _g(-8, -36, 0.3))     # v1.6.0: two more upgrade parts (16 in all)
	pickup("part", "hol_p2", _g(8, -82, 0.3))
	log_at(16, _g(-16, -66))
	log_at(17, _g(12, -103))

func _story() -> void:
	trigger("hol_enter", Vector3(0, 0, -6), Vector3(12, 4, 6), func(_p): beat("hollows.enter", "mira_hollows_enter", 1.0))
	enemy("stalker", "hol_s1", _g(-6, -32), 0.0, {"patrol": [_g(-6, -32), _g(4, -40)]})
	enemy("stalker", "hol_s2", _g(-12, -54), 0.0)
	enemy("experimental", "hol_x1", _g(-16, -68), 90.0)
	enemy("experimental", "hol_x2", _g(6, -88), -90.0)
	enemy("stalker", "hol_s3", _g(6, -62), 0.0)
	enemy("sentinel", "hol_t1", _g(18, -90), 180.0)
	console("hol_console", _g(15.5, -98.5), 200.0, "Shut down the signal transmitter", _shutdown)

func _shutdown() -> void:
	if Game.flag("hollows.shutdown"):
		return
	Game.set_flag("hollows.shutdown")
	Sfx.play("power_on", -2.0)
	_shutdown_cinematic()

func _shutdown_cinematic() -> void:
	GameMode.player.locked = true
	var c := Cinematic.new()
	c.hide_player = false
	add_child(c)
	var m := _g(14, -100, 3.0)
	c.shot(m + Vector3(-3.0, 1.5, 6.0), m + Vector3(0, 2.0, 0), m + Vector3(-2.0, 2.5, 8.5), m + Vector3(0, 3.0, 0), 4.0, 50.0, 46.0)
	c.shot(m + Vector3(6.0, 2.0, 2.0), m + Vector3(0, 2.5, 0), m + Vector3(3.5, 3.5, -2.0), m + Vector3(0, 3.5, 0), 3.5, 46.0, 52.0)
	c.at(0.3, func(): Sfx.play_at("breaker_trip", m, -2.0, 80.0))
	c.at(0.8, func():
		if mast_light:
			mast_light.light_energy = 0.4)
	c.at(1.4, func():
		if GameMode.ui:
			GameMode.ui.toast("Signal lost. Transmitter offline.", 3.0))
	c.say(2.2, "mira_hollows_shutdown")
	c.at(5.5, func(): Game.set_flag("hollows.cleared"))
	c.finished.connect(_after_shutdown)
	c.play()

## v1.9.0 (stage G): the signal answers back once the transmitter is down. A slow pull up into the sky with two subtitled lines from Mira.
func _after_shutdown() -> void:
	GameMode.player.locked = false
	_echo_cinematic()

func _echo_cinematic() -> void:
	GameMode.player.locked = true
	var c := Cinematic.new()
	c.hide_player = false
	add_child(c)
	var m := _g(14, -100, 3.0)
	c.shot(m + Vector3(0, 1.2, 3.0), m + Vector3(0, 2.0, 0), m + Vector3(0, 6.0, 9.0), m + Vector3(0, 14.0, -10.0), 8.0, 50.0, 62.0)
	c.say(0.6, "mira_hollows_echo_1")
	c.say(6.2, "mira_hollows_echo_2")
	c.at(9.0, func(): Game.set_flag("hollows.echo"))
	c.finished.connect(func(): GameMode.player.locked = false)
	c.play()

func _process(delta: float) -> void:
	super._process(delta)
	if mast_light and not Game.flag("hollows.shutdown"):
		mast_light.light_energy = 3.5 + 1.5 * absf(sin(_t * 1.7))
	elif mast_light:
		mast_light.light_energy = 0.4
	# crawlers chitter in the cracks along the valley: sound only, no creature to see
	_chitter_t -= delta
	if _chitter_t <= 0.0:
		_chitter_t = randf_range(5.0, 9.0)
		var spot: Vector3 = (PATH_H[randi() % PATH_H.size()] as Vector3) + Vector3(randf_range(-12, 12), 0, randf_range(-6, 6))
		Sfx.play_at("crawler_chitter" if randf() < 0.7 else "crawler_hiss", _g(spot.x, spot.z, 0.5), -10.0, 26.0)

func on_enter(fresh: bool) -> void:
	super.on_enter(fresh)
	tension = false
	Game.set_flag("area.hollows")
	if Game.flag("hollows.shutdown"):
		mast_light.light_energy = 0.4
