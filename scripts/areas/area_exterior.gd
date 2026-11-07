extends Area
## A5 — ALIEN EXTERIOR (Mission 4 part 1, FINAL EXTRACTION). The surface of NYX-7 at dusk: two moons, a violet
## sky, crystal fields and the Spire on the horizon. A canyon path from the station's surface lift to the launch
## pad, with Stalker packs in the crystals and Sentinels on the ridges.

var terrain: Terrain
var spire_light: OmniLight3D
var beacon: OmniLight3D
const PATH := [Vector3(0, 0, 0), Vector3(4, 0, -30), Vector3(-14, 0, -62), Vector3(-6, 0, -96), Vector3(18, 0, -122), Vector3(22, 0, -158), Vector3(20, 0, -180)]

func build() -> void:
	setup_theme("exterior", 505)
	nav.navigation_mesh.cell_size = 0.5
	nav.navigation_mesh.cell_height = 0.25
	nav.navigation_mesh.agent_max_climb = 0.5
	nav.navigation_mesh.filter_baking_aabb = AABB(Vector3(-60, -20, -200), Vector3(120, 60, 230))
	NavigationServer3D.map_set_cell_size(get_world_3d().navigation_map, 0.5)
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map, 0.25)
	_sky()
	terrain = Terrain.new(77)
	terrain.origin = Vector3(0, 0, -90)
	terrain.size = 260.0
	terrain.path = PackedVector3Array(PATH)
	terrain.path_width = 16.0
	terrain.flats = [[Vector3(0, 0, 6), 12.0, 0.0], [Vector3(20, 0, -180), 16.0, 0.0]]
	terrain.build(self, Terrain.ground_material())
	_set_pieces()
	_story()
	checkpoint("exterior_start", Vector3(0, 0.3, -2.0), 0.0)
	checkpoint("exterior_mid", _g(-10, -80), 180.0, Vector3(12, 4, 6))
	exit_zone("to_extraction", _g(20, -178), Vector3(16, 6, 4), "extraction", "extraction_start")
	# v1.6.0 (stage D): the valley west of the canyon path leads down into THE HOLLOWS (the signal's source)
	checkpoint("exterior_hollows", _g(-9, -35), 0.0, Vector3(8, 4, 6))
	exit_zone("to_hollows", _g(-9, -41), Vector3(4, 5, 4), "hollows", "hollows_start")
	omni(_g(-9, -44, 1.0), Color(0.6, 0.3, 1.0), 3.0, 14.0)

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
	env.fog_sky_affect = 0.18
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.6
	env.ambient_light_energy = 0.7
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	make_sun(Vector3(-14, -150, 0), Color(0.72, 0.68, 1.0), 0.85, true)

func _set_pieces() -> void:
	# where the surface lift comes up: a habitat module and antenna, the station half-buried behind
	prop("habitat_module", Vector3(0, 0, 14), 180.0)
	prop("antenna_mast", Vector3(-9, 0, 8), 0.0)
	prop("cargo_containers", Vector3(8, 0, 4), 70.0)
	prop("satellite_dish", Vector3(-24, terrain.height_at(-24, 18), 18), 30.0)
	# the Spire, far beyond the canyon
	var spire := Props.instance("the_spire")
	add_child(spire)
	spire.global_position = Vector3(-70, -10, -430)
	spire.scale = Vector3.ONE * 2.2
	spire_light = omni(Vector3(-70, 80, -410), Color(0.6, 0.3, 1.0), 10.0, 220.0)
	# crystal fields and rocks along the canyon
	var rng := RandomNumberGenerator.new()
	rng.seed = 505
	var kinds := ["crystal_cluster_a", "crystal_cluster_b", "crystal_cluster_c", "alien_plant_a", "alien_plant_b", "alien_plant_c"]
	for i in 90:
		var t := rng.randf()
		var seg := int(t * (PATH.size() - 1))
		var f := t * (PATH.size() - 1) - seg
		var c: Vector3 = PATH[seg].lerp(PATH[seg + 1], f)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var off := Vector3(side * rng.randf_range(4.0, 22.0), 0, rng.randf_range(-4, 4))
		var p := c + off
		if p.distance_to(Vector3(0, 0, 4)) < 14.0 or p.distance_to(Vector3(20, 0, -180)) < 18.0:
			continue
		var k: String = kinds[rng.randi() % kinds.size()]
		var big := k.begins_with("crystal") and rng.randf() < 0.3
		prop(k, _g(p.x, p.z, -0.2), rng.randf() * 360.0, true, rng.randf_range(0.8, 1.6) * (1.6 if big else 1.0))
	for i in 34:
		var t := rng.randf()
		var seg := int(t * (PATH.size() - 1))
		var c: Vector3 = PATH[seg].lerp(PATH[seg + 1], t * (PATH.size() - 1) - seg)
		var side := 1.0 if rng.randf() < 0.5 else -1.0
		var p := c + Vector3(side * rng.randf_range(16.0, 40.0), 0, rng.randf_range(-8, 8))
		var k: String = ["alien_rock_a", "alien_rock_b", "alien_rock_c", "alien_rock_d"][rng.randi() % 4]
		prop(k, _g(p.x, p.z, -1.0), rng.randf() * 360.0, true, rng.randf_range(1.0, 2.4))   # 1.9.2: every rock is solid (bug 11)
	# crystal glow
	for i in 10:
		var c: Vector3 = PATH[1 + i % (PATH.size() - 2)]
		omni(_g(c.x + (12.0 if i % 2 == 0 else -12.0), c.z + 6.0, 1.5), Color(0.6, 0.3, 1.0), 2.0, 12.0)
	# cover rocks on the path for the fights
	for p in [Vector3(2, 0, -40), Vector3(-10, 0, -66), Vector3(-2, 0, -100), Vector3(14, 0, -128), Vector3(24, 0, -150)]:
		prop("alien_rock_d", _g(p.x, p.z, -0.4), rng.randf() * 360.0, true, 1.0)
		cover_point(_g(p.x, p.z + 3.0))
	# the pad beacon guides the player
	beacon = omni(_g(20, -186, 8.0), Color(1.0, 0.3, 0.2), 6.0, 40.0, false)
	var bm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	bm.mesh = sm
	bm.material_override = Fx.glow_mat(Color(1.0, 0.3, 0.2), 8.0)
	add_child(bm)
	bm.global_position = _g(20, -186, 8.0)
	# pickups
	pickup("ammo_rifle", "ext_r1", _g(6, -34, 0.1), 48)
	pickup("medkit", "ext_m1", _g(-9.0, -72.5, 0.1))   # v1.0.1: was buried inside a rock at (-12, -70)
	pickup("ammo_pistol", "ext_a1", _g(-4, -104, 0.1), 24)
	pickup("ammo_rifle", "ext_r2", _g(16, -134, 0.1), 48)
	pickup("medkit", "ext_m2", _g(22, -160, 0.1))
	pickup("part", "ext_p1", _g(-14, -50, 0.3))   # v1.5.0 upgrade parts (exterior: 2 more; 14 in all)
	pickup("part", "ext_p2", _g(12, -92, 0.3))
	log_at(13, Vector3(5.0, 0.0, 2.2))   # v1.0.1: was inside the cargo containers
	log_at(14, _g(-15, -88))
	prop("corpse_prone", _g(-14, -87), 40.0, true)

func _story() -> void:
	trigger("ext_enter", Vector3(0, 0, -6), Vector3(14, 4, 6), func(_p): beat("surface", "mira_surface", 1.5))
	enemy("stalker", "ext_s1", _g(-4, -50), 0.0, {"patrol": [_g(-4, -50), _g(10, -40)]})
	enemy("stalker", "ext_s2", _g(-14, -58), 0.0)
	enemy("experimental", "ext_x1", _g(-9, -63), 180.0)   # v1.1.0 stage 2: unpredictable organism
	enemy("sentinel", "ext_t1", _g(-20, -96), 90.0)
	enemy("stalker", "ext_s3", _g(4, -110), 0.0, {"patrol": [_g(4, -110), _g(-6, -98)]})
	enemy("stalker", "ext_s4", _g(10, -116), 0.0)
	enemy("sentinel", "ext_t2", _g(28, -140), -90.0)
	enemy("brute", "ext_b1", _g(18, -152), 180.0)

func _process(delta: float) -> void:
	super._process(delta)
	if spire_light:
		spire_light.light_energy = 9.0 + sin(_t * 0.9) * 2.5
	if beacon:
		beacon.light_energy = 3.0 + 3.0 * absf(sin(_t * 2.5))

func on_enter(fresh: bool) -> void:
	super.on_enter(fresh)
	tension = false
