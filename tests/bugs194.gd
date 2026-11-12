extends Node
## 1.9.4 tests: --driver=bugs194
##  1. the start-area gap (decontamination corridor) is a walkable bridge: the player walks across it with
##     the move input and never drops below the floor.
var passed := 0
var failed := 0

func check(name: String, ok: bool, info: String = "") -> void:
	if ok:
		passed += 1
	else:
		failed += 1
	print(("PASS " if ok else "FAIL ") + name + ("  (" + info + ")" if info != "" else ""))

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	await get_tree().process_frame
	Game.SAVE_PATH = "user://bugs194.json"
	Game.delete_save()
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("cryo", "cryo_hub", true)
	await frames(30)
	await _bridge()
	await _float_lights()
	await _lift_rails()
	await _multitouch()
	await _touch_size()
	await _cam_probe()
	await _audit_nocoll()
	print("BUGS194 %d/%d passed" % [passed, passed + failed])
	for f in [Game.SAVE_PATH, Game.SAVE_PATH + ".bak", Game.SETTINGS_PATH]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(f))
	get_tree().quit(0 if failed == 0 else 1)

func _bridge() -> void:
	# 1.9.4 bug 1: walk from the ledge (x 17.6) east across the 1.8 m gap at x 19..20.8 with the stick, no jump
	var p: Player = GameMode.player
	p.place(Transform3D(Basis(Vector3.UP, deg_to_rad(90.0)), Vector3(17.6, 0.1, 6.0)))
	p.controller.snap_to(p.rotation.y)
	await frames(20)
	var start_x := p.global_position.x
	var lowest := 99.0
	p.touch_move = Vector2(0.0, -1.0)
	var t := 0.0
	while t < 4.0 and p.global_position.x < 23.5:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		lowest = minf(lowest, p.global_position.y)
	p.touch_move = Vector2.ZERO
	await frames(5)
	var end_x := p.global_position.x
	check("1. walking east from the ledge reaches the far side of the gap", end_x > 21.5, "x %.2f -> %.2f in %.1f s" % [start_x, end_x, t])
	check("1. the player never drops into the trench on the way across", lowest > -0.5, "lowest y %.2f" % lowest)

## audit (1.9.4 bugs 13, 16, 19): every prop in every area that has no collision body at all
func _audit_nocoll() -> void:
	var areas := ["cryo", "research", "security", "reactor", "exterior", "extraction", "hollows"]
	for a in areas:
		await GameMode.load_area(a, "", true)
		await frames(10)
		var root: Node = GameMode.area if "area" in GameMode else null
		var n_props := 0
		var n_nocoll := 0
		for n in get_tree().root.find_children("*", "Node3D", true, false):
			if not n.has_meta("prop"):
				continue
			n_props += 1
			var bodies := (n as Node3D).find_children("*", "CollisionObject3D", true, false)
			if bodies.is_empty():
				n_nocoll += 1
				var gp: Vector3 = (n as Node3D).global_position
				print("NOCOLL %s %s at (%.2f, %.2f, %.2f) collide_flag=%s" % [a, n.get_meta("prop"), gp.x, gp.y, gp.z, str(n.get_meta("prop_collide", true))])
		print("AUDIT %s props=%d without_collider=%d" % [a, n_props, n_nocoll])

func _dump_lift() -> void:
	var inst := Props.instance("cargo_lift")
	add_child(inst)
	inst.global_position = Vector3.ZERO
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var ab := m.get_aabb()
		var gp := m.global_transform * ab.get_center()
		print("LIFTPART %s centre=(%.2f, %.2f, %.2f) size=(%.2f, %.2f, %.2f)" % [m.get_path(), gp.x, gp.y, gp.z, ab.size.x, ab.size.y, ab.size.z])
	inst.queue_free()
	await frames(2)

## 1.9.4 bug 6: the reactor lift's cage is solid outside the door gap and open in the gap
func _lift_rails() -> void:
	await GameMode.load_area("reactor", "", true)
	await frames(10)
	var lift: Node3D = null
	for n in get_tree().root.find_children("cargo_lift", "Node3D", true, false):
		lift = n as Node3D
	if lift == null:
		check("6. the reactor lift is in the reactor area", false)
		return
	var space: PhysicsDirectSpaceState3D = lift.get_world_3d().direct_space_state
	var c := lift.global_position
	var rail_hit := true
	for z in [-3.2, 3.2]:
		var q := PhysicsRayQueryParameters3D.create(c + Vector3(-3.6, 1.0, z), c + Vector3(-1.5, 1.0, z))
		q.collision_mask = 1
		rail_hit = rail_hit and not space.intersect_ray(q).is_empty()
	check("6. the reactor lift rails are solid outside the door gap (z = +-3.2 blocks)", rail_hit)
	var gap_open := true
	for z in [-1.2, -0.4, 0.4, 1.2]:
		for h in [0.5, 1.5]:
			var q2 := PhysicsRayQueryParameters3D.create(c + Vector3(-3.6, h, z), c + Vector3(-1.5, h, z))
			q2.collision_mask = 1
			gap_open = gap_open and space.intersect_ray(q2).is_empty()
	check("6. the reactor lift entrance gap (z -1.2..1.2) is open for a walking player", gap_open)

## bug 8: a light strip with no surface within 0.4 m in any of six directions is floating
func _float_lights() -> void:
	await GameMode.load_area("cryo", "cryo_start", true)
	await frames(10)
	var space: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state
	var dirs := [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]
	var n := 0
	var floating := 0
	for m in get_tree().root.find_children("EmitLight*", "MeshInstance3D", true, false):
		n += 1
		var mi := m as MeshInstance3D
		var gp: Vector3 = mi.global_position
		var hits := 0
		for d in dirs:
			var q := PhysicsRayQueryParameters3D.create(gp, gp + d * 0.4)
			q.collision_mask = 1
			if not space.intersect_ray(q).is_empty():
				hits += 1
		if hits == 0:
			floating += 1
			print("FLOATLIGHT cryo %s at (%.2f, %.2f, %.2f) size=%s" % [mi.name, gp.x, gp.y, gp.z, str(mi.get_aabb().size)])
	var names := {}
	for m2 in get_tree().root.find_children("*", "Node3D", true, false):
		var nm := str(m2.name)
		if nm.containsn("light") or nm.containsn("lamp") or nm.containsn("emit") or nm.containsn("broken"):
			var gp2: Vector3 = (m2 as Node3D).global_position
			print("LIGHTNAME %s (%s) at (%.2f, %.2f, %.2f) parent=%s" % [nm, m2.get_class(), gp2.x, gp2.y, gp2.z, m2.get_parent().name])
	print("FLOATAUDIT cryo emit_lights=%d floating=%d" % [n, floating])

## bugs 3 and 15 (touch): a held move stick, a FIRE tap and a USE tap at the same time all register
func _raw(p: Vector2) -> Vector2:
	return p * ratio

var ratio := Vector2.ONE

func _tdown(idx: int, p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.pressed = true
	e.position = _raw(p)
	Input.parse_input_event(e)
	await frames(2)

func _tup(idx: int, p: Vector2) -> void:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.pressed = false
	e.position = _raw(p)
	Input.parse_input_event(e)
	await frames(2)

func _tdrag(idx: int, p: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = _raw(p)
	e.relative = _raw(rel)
	Input.parse_input_event(e)
	await frames(2)

func _btn(t, id: String) -> Button:
	for e in t.buttons:
		if e[1] == id:
			return e[0]
	return null

func _multitouch() -> void:
	Game.settings["touch"] = "on"
	Game.apply_settings()
	get_window().size = Vector2i(2400, 1080)
	Game.apply_settings()
	await frames(4)
	ratio = Vector2(get_window().size) / get_viewport().get_visible_rect().size
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("cryo", "cryo_hub", true)
	await frames(30)
	var p: Player = GameMode.player
	var t = GameMode.ui.touch
	p.combat.give("pistol")
	await frames(10)
	var fire := _btn(t, "fire")
	var use := _btn(t, "interact")
	await _tdown(0, Vector2(250, 520))
	await _tdrag(0, Vector2(370, 520), Vector2(120, 0))
	await frames(5)
	check("3/15 the move stick is held", p.touch_move.x > 0.5, str(p.touch_move))
	var fc: Vector2 = fire.get_global_rect().get_center()
	await _tdown(1, fc)
	await frames(5)
	check("3/15 FIRE tap registers while the stick is held", p.combat.touch_fire, "touch_fire=%s" % str(p.combat.touch_fire))
	var uc: Vector2 = use.get_global_rect().get_center()
	await _tdown(2, uc)
	await frames(3)
	check("3/15 USE tap registers while the stick and FIRE are held", Input.is_action_pressed("interact"))
	check("3/15 the stick still moves the player with FIRE and USE held", p.touch_move.x > 0.5, str(p.touch_move))
	await _tup(2, uc)
	await _tup(1, fc)
	await _tup(0, Vector2(370, 520))
	await frames(5)
	check("3/15 all fingers up releases the stick and FIRE", p.touch_move.length() < 0.01 and not p.combat.touch_fire)

## 1.9.4 bugs 3 and 15: every touch button is at least 1.0 cm square on a 6.7 inch 2400x1080 phone (1 cm is about
## 116 units at the touch UI scale of 1.35), and a tap at its centre lands on that button and no other.
func _touch_size() -> void:
	var t = GameMode.ui.touch
	var min_units := 116.0
	var n := 0
	var worst := 9999.0
	var worst_name := ""
	var ok_hit := true
	for i in t.buttons.size():
		var bt: Button = t.buttons[i][0]
		if not bt.visible:
			continue
		n += 1
		var side := minf(bt.size.x, bt.size.y)
		if side < worst:
			worst = side
			worst_name = bt.text
		var c := bt.get_global_rect().get_center()
		if t._button_at(c) != i:
			ok_hit = false
			print("  miss: centre of %s hits index %d" % [bt.text, t._button_at(c)])
	check("3/15 every touch button is at least 1.0 cm (116 units) square (%d shown)" % n, n > 0 and worst >= min_units, "smallest %s %.0f units" % [worst_name, worst])
	check("3/15 a tap at the centre of each touch button lands on that button", ok_hit and n > 0)

func _cam_probe() -> void:
	await GameMode.load_area("cryo", "cryo_hub", true)
	await frames(20)
	var space: PhysicsDirectSpaceState3D = get_tree().root.get_world_3d().direct_space_state
	var cam := Vector3(29.20116, 4.272456, 7.36832)
	var sq := PhysicsShapeQueryParameters3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 0.12
	sq.shape = sph
	sq.transform = Transform3D(Basis(), cam)
	sq.collision_mask = 1
	for h in space.intersect_shape(sq, 8):
		var co := h["collider"] as Node
		var par := co.get_parent()
		print("CAMHIT collider=%s parent=%s prop=%s" % [co.name, par.name if par else "-", str(par.get_meta("prop", "")) if par else ""])
	print("CAMHITS done")
