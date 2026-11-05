extends Node
## Player mechanics test (Doc 03 Ph2/Ph3 acceptance, Godot PRD Ph2/Ph4): drives the REAL input path (InputMap actions,
## the touch stick) in the shared TestEnvironment and measures walk/run/sprint speeds, jump height, crouching under a
## 1.4 m bar, camera collision against a wall, facing, animation states, weapon switching, reload bookkeeping, medkits,
## and the scene's terminal -> door, pickup and dormant enemy.
##   godot --headless --fixed-fps 60 -- --driver=move_test
var passed := 0
var total := 0
var p: Player
var env: Node3D
var ammo_events := 0

func check(name: String, ok: bool, info: String = "") -> void:
	total += 1
	if ok:
		passed += 1
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func secs(s: float) -> void:
	await frames(int(s * 60.0))

func press(action: String, on: bool = true) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = on
	e.strength = 1.0 if on else 0.0
	Input.parse_input_event(e)

func tap(action: String) -> void:
	press(action, true)
	await frames(2)
	press(action, false)
	await frames(2)

func release_all() -> void:
	for a in ["move_forward", "move_back", "move_left", "move_right", "sprint"]:
		Input.action_release(a)
	p.touch_move = Vector2.ZERO

func place(pos: Vector3, yaw_deg: float) -> void:
	release_all()
	p.place(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), pos))
	p.velocity = Vector3.ZERO
	p.controller.yaw = yaw_deg
	p.controller.snap_to(deg_to_rad(yaw_deg))
	await frames(20)

func hspeed_over(s: float) -> float:
	var a := p.global_position
	await secs(s)
	var b := p.global_position
	return Vector2(b.x - a.x, b.z - a.z).length() / s

func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	env = load("res://scenes/test_environment.tscn").instantiate()
	GameMode.world_root.add_child(env)
	await frames(10)
	p = GameMode.player
	Events.ammo_changed.connect(func(_m, _r): ammo_events += 1)
	# --- scene contents
	check("test scene has player, terminal, door, pickup, enemy", p != null and env.terminal != null and env.door != null and env.medkit != null and env.stalker != null)
	check("dormant enemy stays dormant", env.stalker.state == EnemyBase.State.DORMANT, "state %d" % env.stalker.state)
	check("door starts locked", env.door.is_locked())
	env.terminal.interact(p)
	await frames(5)
	check("terminal powers the door", Game.flag("test.power") and not env.door.is_locked())
	var mk0 := p.inventory.medkits
	await place(env.medkit.global_position + Vector3(0, 0.1, 0), 0.0)
	await secs(0.5)
	check("medkit pickup", p.inventory.medkits == mk0 + 1, "medkits %d" % p.inventory.medkits)
	# --- speeds (open floor, facing -Z)
	await place(Vector3(-16, 0.2, 24), 0.0)
	p.touch_move = Vector2(0, Player.WALK / Player.RUN)      # half-tilted stick
	await secs(1.0)
	var walk := await hspeed_over(0.5)
	p.touch_move = Vector2.ZERO
	check("walk speed", absf(walk - Player.WALK) < Player.WALK * 0.15, "%.2f m/s, want %.1f" % [walk, Player.WALK])
	var anim_idle_ok := false
	await place(Vector3(-16, 0.2, 24), 0.0)
	anim_idle_ok = str(p.anim.tree.get("parameters/state/current_state")) == "unarmed" and float(p.anim.tree.get("parameters/loco_u/blend_position")) < 0.3
	Input.action_press("move_forward")
	await secs(1.0)
	var run := await hspeed_over(0.5)
	var anim_run_ok := float(p.anim.tree.get("parameters/loco_u/blend_position")) > 3.0
	check("run speed", absf(run - Player.RUN) < Player.RUN * 0.15, "%.2f m/s, want %.1f" % [run, Player.RUN])
	Input.action_press("sprint")
	await secs(1.0)
	var spr := await hspeed_over(0.5)
	check("sprint speed", absf(spr - Player.SPRINT) < Player.SPRINT * 0.15, "%.2f m/s, want %.1f" % [spr, Player.SPRINT])
	check("animation follows speed (idle -> run)", anim_idle_ok and anim_run_ok)
	release_all()
	await secs(1.0)
	check("stops when input is released", Vector2(p.velocity.x, p.velocity.z).length() < 0.2)
	# --- jump
	var y0 := p.global_position.y
	var peak := y0
	await tap("jump")
	var t := 0.0
	var left_floor := false
	while t < 1.6:
		await frames(1)
		t += 1.0 / 60.0
		peak = maxf(peak, p.global_position.y)
		left_floor = left_floor or not p.is_on_floor()
	check("jump height", left_floor and peak - y0 > 0.8, "peak %.2f m" % (peak - y0))
	check("lands back on the floor", p.is_on_floor() and absf(p.global_position.y - y0) < 0.1)
	# --- crouch under the 1.4 m bar (bar at x = 14)
	await place(Vector3(11.5, 0.2, 4), -90.0)
	Input.action_press("move_forward")
	await secs(1.8)
	var blocked_x := p.global_position.x
	check("standing player is blocked by the 1.4 m bar", blocked_x < 13.8, "x %.2f" % blocked_x)
	release_all()
	await tap("crouch")
	await frames(10)
	var cap_h := 0.0
	for c in p.find_children("*", "CollisionShape3D", false, false):
		if (c as CollisionShape3D).shape is CapsuleShape3D:
			cap_h = ((c as CollisionShape3D).shape as CapsuleShape3D).height
	check("crouch lowers the capsule", p.crouching and absf(cap_h - Player.CROUCH_H) < 0.05, "capsule %.2f" % cap_h)
	Input.action_press("move_forward")
	await secs(2.5)
	check("crouched player passes under the bar", p.global_position.x > 14.8, "x %.2f" % p.global_position.x)
	release_all()
	await tap("crouch")
	await frames(10)
	check("stands up again", not p.crouching)
	# --- camera collision: back to a wall, camera behind
	await place(Vector3(-23.3, 0.2, 4), -90.0)
	await secs(0.6)
	var cam := p.controller.cam
	var piv := p.controller.arm.global_position
	var q := PhysicsRayQueryParameters3D.create(piv, cam.global_position, 1)
	q.exclude = [p.get_rid()]
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	check("camera stays on the player's side of the wall", hit.is_empty() and cam.global_position.x > -23.8,
		"cam x %.2f, arm %.2f of %.2f" % [cam.global_position.x, p.controller.arm.get_hit_length(), PlayerController.ARM_LEN])
	check("spring arm shortens against the wall", p.controller.arm.get_hit_length() < PlayerController.ARM_LEN - 0.5)
	# --- facing: move right relative to the camera -> the body turns to face +X
	await place(Vector3(-16, 0.2, 24), 0.0)
	Input.action_press("move_right")
	await secs(0.7)
	var yaw_err := absf(rad_to_deg(angle_difference(p.rotation.y, deg_to_rad(-90.0))))
	check("character faces the movement direction", yaw_err < 25.0, "error %.0f deg" % yaw_err)
	release_all()
	await secs(0.5)
	# --- weapons via input
	p.combat.give("pistol")
	p.combat.give("rifle")
	await secs(0.6)
	await tap("weapon_1")
	await secs(0.5)
	var w1 := p.combat.current_id()
	await tap("weapon_2")
	await secs(0.5)
	check("weapon keys switch weapons", w1 == "pistol" and p.combat.current_id() == "rifle", "%s -> %s" % [w1, p.combat.current_id()])
	check("armed animation state", str(p.anim.tree.get("parameters/state/current_state")) == "armed")
	# --- reload bookkeeping
	var w: WeaponBase = p.combat.current
	w.mag = 10
	p.inventory.reserve["rifle"] = 100
	ammo_events = 0
	await tap("reload")
	await secs(w.data.reload_time + 0.4)
	check("reload fills the magazine from reserve", w.mag == w.data.mag_size and int(p.inventory.reserve["rifle"]) == 100 - (w.data.mag_size - 10) and ammo_events > 0,
		"mag %d/%d reserve %d events %d" % [w.mag, w.data.mag_size, p.inventory.reserve["rifle"], ammo_events])
	# --- medkit via input
	p.health.dmg_mult = 1.0
	p.health.take_damage(40.0, {"kind": "test"})
	var hp0 := p.health.hp
	var mk := p.inventory.medkits
	await tap("medkit")
	await secs(1.2)
	check("medkit heals and is used up", p.health.hp > hp0 + 30.0 and p.inventory.medkits == mk - 1, "hp %.0f -> %.0f, medkits %d -> %d" % [hp0, p.health.hp, mk, p.inventory.medkits])
	# --- Doc 03 named scenes load and are the real classes
	var pl = load("res://scenes/player/Player.tscn").instantiate()
	var rf = load("res://scenes/weapons/pulse_rifle.tscn").instantiate()
	var ep = load("res://scenes/weapons/energy_pistol.tscn").instantiate()
	var lv = load("res://scenes/levels/cryo_chamber.tscn").instantiate()
	check("named scenes instantiate (Player, weapons, levels, MainMenu)", pl is Player and rf.data.id == "rifle" and ep.data.id == "pistol"
		and rf.get_node_or_null("Model") != null and lv.area_id == "cryo" and load("res://scenes/MainMenu.tscn").can_instantiate())
	for n in [pl, rf, ep, lv]:
		n.free()
	print("MOVETEST %d/%d passed" % [passed, total])
	get_tree().quit(0 if passed == total else 1)
