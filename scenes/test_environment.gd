extends Node3D
## TestEnvironment (Doc 03 Task 001): a bare floor, sun, sky and camera with the player, for trying movement,
## camera and animation away from the levels.  Run: godot --path . res://scenes/test_environment.tscn
func _ready() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(60, 1, 60)
	cs.shape = bs
	cs.position = Vector3(0, -0.5, 0)
	floor_body.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.42, 0.44, 0.47)
	mat.uv1_scale = Vector3(30, 30, 1)
	pm.material = mat
	mi.mesh = pm
	floor_body.add_child(mi)
	add_child(floor_body)
	# a few blocks to walk around, jump on and test camera collision against
	for i in 6:
		var b := StaticBody3D.new()
		var c2 := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(2, 0.5 + i * 0.5, 2)
		c2.shape = s
		c2.position.y = s.size.y * 0.5
		b.add_child(c2)
		var m2 := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s.size
		m2.mesh = bm
		m2.position.y = s.size.y * 0.5
		b.add_child(m2)
		b.position = Vector3(-10 + i * 4, 0, -8)
		add_child(b)
	_box(Vector3(14, 1.6, 4), Vector3(0.6, 0.4, 3.0), Color(0.9, 0.6, 0.1))       # crouch bar: underside at 1.4 m
	_box(Vector3(-24, 2.0, 4), Vector3(0.4, 4.0, 8.0), Color(0.5, 0.52, 0.55))     # camera-collision wall
	_systems()
	var player := Player.new()
	add_child(player)
	player.place(Transform3D(Basis(), Vector3(0, 0.2, 4)))
	GameMode.player = player
	GameMode.in_game = true
	print("TESTENV ready: floor, sun, sky, %d blocks, player at %s" % [6, player.global_position])
	if Game.arg("quit_after") != "":
		await get_tree().create_timer(float(Game.arg("quit_after"))).timeout
		print("TESTENV ok player_on_floor=", player.is_on_floor(), " camera=", player.controller.cam != null)
		get_tree().quit()


func _box(pos: Vector3, size: Vector3, c: Color) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	cs.shape = s
	b.add_child(cs)
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	bm.material = mat
	m.mesh = bm
	b.add_child(m)
	add_child(b)
	b.position = pos
	return b

## Story PRD Ph1 "a shared test scene containing one player, terminal, door, pickup and enemy": a terminal that
## powers a door, a medkit, and a dormant Stalker, built with the same classes the areas use.
var terminal: Console
var door: Door
var medkit: Pickup
var stalker: EnemyBase
func _systems() -> void:
	terminal = Console.new()
	terminal.stable_id = "test_terminal"
	terminal.prompt = "Restore door power"
	terminal.model_name = "terminal"
	terminal.action = func(_p): Game.set_flag("test.power")
	add_child(terminal)
	terminal.position = Vector3(6, 0, 12)
	door = Door.new()
	door.stable_id = "test_door"
	door.lock_flag = "test.power"
	door.locked_text = "No power"
	add_child(door)
	door.position = Vector3(10, 0, 12)
	medkit = Pickup.new()
	medkit.kind = "medkit"
	medkit.stable_id = "test_medkit"
	add_child(medkit)
	medkit.position = Vector3(8, 0.1, 8)
	stalker = Enemies.make("stalker")
	stalker.stable_id = "test_stalker"
	stalker.spawn_opts = {"dormant": true}
	add_child(stalker)
	stalker.position = Vector3(18, 0.3, 14)
