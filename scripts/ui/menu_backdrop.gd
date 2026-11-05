extends Node3D
## Main-menu backdrop: the Spire on the horizon of NYX-7 under its two moons, crystal fields catching the
## light, with a slow drifting camera. Built from the exterior props (or stand-ins) so it costs little.

var cam: Camera3D
var t := 0.0
var spire_light: OmniLight3D

func _ready() -> void:
	var theme := Themes.get_theme("exterior")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/sky.gdshader")
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.08
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.fog_enabled = true
	env.fog_light_color = Color(0.25, 0.2, 0.4)
	env.fog_density = 0.012
	env.fog_sky_affect = 0.3
	env.volumetric_fog_enabled = not Game.is_mobile and not Game.is_web
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.5, 0.45, 0.7)
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-12, -150, 0)
	sun.light_color = Color(0.75, 0.7, 1.0)
	sun.light_energy = 0.9
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(600, 600)
	pm.subdivide_depth = 1
	ground.mesh = pm
	ground.material_override = (theme["materials"] as Dictionary).get("Ground", Themes.pbr("ground_alien", Color(0.5, 0.45, 0.55), 0.25))
	add_child(ground)
	var spire := Props.instance("the_spire")
	add_child(spire)
	spire.position = Vector3(0, -2, -150)
	spire.scale = Vector3.ONE * 1.6
	spire_light = OmniLight3D.new()
	spire_light.light_color = Color(0.6, 0.3, 1.0)
	spire_light.light_energy = 6.0
	spire_light.omni_range = 120.0
	spire_light.position = Vector3(0, 40, -140)
	add_child(spire_light)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for i in 26:
		var names := ["crystal_cluster_a", "crystal_cluster_b", "crystal_cluster_c", "alien_rock_a", "alien_rock_b", "alien_rock_d", "alien_plant_a"]
		var n := Props.instance(names[rng.randi() % names.size()])
		add_child(n)
		n.position = Vector3(rng.randf_range(-70, 70), 0, rng.randf_range(-110, -12))
		n.rotation.y = rng.randf() * TAU
		var s := rng.randf_range(0.8, 2.2)
		n.scale = Vector3.ONE * s
	var hab := Props.instance("habitat_module")
	add_child(hab)
	hab.position = Vector3(26, 0, -40)
	hab.rotation.y = 0.6
	var mast := Props.instance("antenna_mast")
	add_child(mast)
	mast.position = Vector3(18, 0, -30)
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.far = 900.0
	add_child(cam)
	cam.make_current()

func _process(delta: float) -> void:
	t += delta
	cam.position = Vector3(sin(t * 0.03) * 10.0 + 6.0, 4.0 + sin(t * 0.05) * 0.6, 22.0)
	cam.look_at(Vector3(-4.0, 18.0, -140.0), Vector3.UP)
	spire_light.light_energy = 5.0 + sin(t * 0.8) * 1.5
