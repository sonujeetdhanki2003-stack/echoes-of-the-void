class_name WeaponBase
extends Node3D
## PRD BP_EOT_WeaponBase: shared hitscan weapon behaviour. Pulse Rifle and Energy Pistol derive from it.

signal fired
signal reloaded

var data: WeaponData
var owner_player: Player
var mag := 0
var _cooldown := 0.0
var spread := 0.0
var reloading := false
var _reload_t := 0.0
var model: Node3D
var muzzle: Node3D
var mag_node: Node3D
var _session := 0

func setup(d: WeaponData, p: Player) -> void:
	data = d
	owner_player = p
	name = d.id
	mag = d.mag_size
	_build_model()

func _build_model() -> void:
	if data.model != "" and ResourceLoader.exists(data.model):
		var ps: PackedScene = load(data.model)
		model = ps.instantiate()
		add_child(model)
		muzzle = model.find_child("Muzzle", true, false)
		mag_node = model.find_child("Mag", true, false)
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	else:
		model = _placeholder()
		add_child(model)
	if muzzle == null:
		muzzle = Node3D.new()
		muzzle.name = "Muzzle"
		muzzle.position = Vector3(0, 0.05, -0.8 if data.id == "rifle" else -0.25)
		add_child(muzzle)

func _placeholder() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var l := 0.8 if data.id == "rifle" else 0.26
	bm.size = Vector3(0.07, 0.12, l)
	body.mesh = bm
	body.position = Vector3(0, 0.04, -l * 0.4)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.18, 0.19, 0.21)
	m.metallic = 0.7
	m.roughness = 0.35
	body.material_override = m
	n.add_child(body)
	var strip := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.075, 0.02, l * 0.6)
	strip.mesh = sm
	strip.position = Vector3(0, 0.1, -l * 0.45)
	strip.material_override = Fx.glow_mat(data.tracer_color, 2.0)
	n.add_child(strip)
	return n

func muzzle_pos() -> Vector3:
	return muzzle.global_position

func can_fire() -> bool:
	return not reloading and _cooldown <= 0.0 and mag > 0

func _process(delta: float) -> void:
	_cooldown -= delta
	var rec := data.spread_recover * (1.6 if owner_player.aiming else 1.0)
	spread = maxf(0.0, spread - rec * delta)
	if reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			_finish_reload()

func current_spread() -> float:
	var base := data.spread_aim if owner_player.aiming else data.spread_hip
	if owner_player.crouching:
		base *= 0.7
	var mv := Vector2(owner_player.velocity.x, owner_player.velocity.z).length()
	base += clampf(mv / 6.0, 0.0, 1.0) * (0.4 if owner_player.aiming else 1.2)
	if not owner_player.is_on_floor():
		base += 2.0
	return minf(base + spread, data.spread_max + base)

## One trigger pull: returns true if a shot went out.
func fire() -> bool:
	if not can_fire():
		return false
	_cooldown = 1.0 / data.fire_rate
	mag -= 1
	var ray: Array = owner_player.controller.aim_ray()
	var origin: Vector3 = ray[0]
	var dir: Vector3 = ray[1]
	dir = _apply_spread(dir, current_spread())
	dir = _aim_assist(origin, dir)
	spread = minf(spread + data.spread_per_shot, data.spread_max)
	var hit := _trace(origin, dir)
	var end: Vector3 = hit["position"] if hit else origin + dir * data.range
	# the barrel can be blocked by a wall right in front of the player: re-trace from the muzzle
	var mp := muzzle_pos()
	if hit:
		var q2 := PhysicsRayQueryParameters3D.create(mp, end + dir * 0.05, 1)
		q2.exclude = [owner_player.get_rid()]
		var h2 := owner_player.get_world_3d().direct_space_state.intersect_ray(q2)
		if h2 and h2["position"].distance_to(end) > 0.3 and mp.distance_to(h2["position"]) < mp.distance_to(end) - 0.3:
			hit = h2
			end = h2["position"]
	Fx.muzzle_flash(mp, dir, data.tracer_color, data.id == "rifle")
	Fx.tracer(mp, end, data.tracer_color, 0.02 if data.id == "rifle" else 0.028)
	if hit:
		_apply_hit(hit, dir)
	var kick := data.recoil_pitch * (0.55 if owner_player.aiming else 1.0)
	owner_player.controller.add_recoil(kick, randf_range(-data.recoil_yaw, data.recoil_yaw))
	owner_player.controller.shake(0.12 if data.id == "rifle" else 0.16, 0.08)
	Sfx.play(data.sfx_fire, 0.0, randf_range(0.97, 1.03))
	Events.emit_noise(owner_player.global_position, data.noise_radius, owner_player)
	Game.state["stats"]["shots"] += 1
	fired.emit()
	return true

func _apply_spread(dir: Vector3, deg: float) -> Vector3:
	if deg <= 0.001:
		return dir
	var r := deg_to_rad(deg) * sqrt(randf())
	var a := randf() * TAU
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	var x := dir.cross(up).normalized()
	var y := x.cross(dir).normalized()
	return (dir + (x * cos(a) + y * sin(a)) * tan(r)).normalized()

## Gentle magnetism for touch and gamepad players: nudge toward an enemy within a few degrees.
func _aim_assist(origin: Vector3, dir: Vector3) -> Vector3:
	if not Game.settings["aim_assist"]:
		return dir
	var strength := 0.0
	if Game.touch_enabled():
		strength = 1.0
	elif Input.get_connected_joypads().size() > 0 and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		strength = 0.7
	if strength <= 0.0:
		return dir
	var best := dir
	var best_ang := deg_to_rad(4.5 * strength)
	for e in owner_player.get_tree().get_nodes_in_group("enemy"):
		if not e.has_method("aim_target") or e.get("dead"):
			continue
		var tp: Vector3 = e.aim_target()
		var to := tp - origin
		if to.length() > data.range:
			continue
		var ang := dir.angle_to(to.normalized())
		if ang < best_ang:
			best_ang = ang
			best = dir.slerp(to.normalized(), 0.6)
	return best

func _trace(origin: Vector3, dir: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * data.range, 1 | 4 | 8)
	q.collide_with_areas = true
	q.exclude = [owner_player.get_rid()]
	return owner_player.get_world_3d().direct_space_state.intersect_ray(q)

func _apply_hit(hit: Dictionary, dir: Vector3) -> void:
	var col: Object = hit["collider"]
	var target: Node = null
	var mult := 1.0
	var surface := "metal"
	var critical := false
	if col is Node:
		var n := col as Node
		if n.has_meta("hit_owner"):
			target = n.get_meta("hit_owner")
			mult = float(n.get_meta("mult", 1.0))
			critical = bool(n.get_meta("critical", mult > 1.4))
			surface = str(n.get_meta("surface", "flesh"))
		elif n.has_method("take_hit"):
			target = n
			surface = str(n.get_meta("surface", "flesh"))
		else:
			surface = str(n.get_meta("surface", "metal"))
	var dmg := data.damage * mult
	if critical:
		dmg = data.damage * maxf(mult, data.crit_mult)
	Fx.impact(hit["position"], hit["normal"], surface, 1.0 if data.id == "rifle" else 1.2)
	if target and is_instance_valid(target) and target.has_method("take_hit"):
		var killed: bool = target.take_hit(dmg, {"pos": hit["position"], "dir": dir, "critical": critical, "source": owner_player, "kind": data.id, "normal": hit["normal"]})
		Game.state["stats"]["hits"] += 1
		Events.hit_confirmed.emit(critical, killed)
		Sfx.play("impact_" + ("crystal" if critical else "flesh"), -8.0)
	else:
		Sfx.play_at("impact_metal", hit["position"], -10.0, 30.0)
	if col is RigidBody3D:
		(col as RigidBody3D).apply_impulse(dir * data.impulse, hit["position"] - (col as RigidBody3D).global_position)

# ---------------------------------------------------------------- reload
func needs_reload() -> bool:
	return mag < data.mag_size

func start_reload(reserve: int) -> bool:
	if reloading or mag >= data.mag_size or reserve <= 0:
		return false
	reloading = true
	_reload_t = data.reload_time
	_session += 1
	Sfx.play(data.sfx_reload, -4.0)
	return true

func _finish_reload() -> void:
	reloading = false
	var need := data.mag_size - mag
	var got := owner_player.inventory.take_ammo(data.ammo_type, need)
	mag += got
	reloaded.emit()

func cancel_reload() -> void:
	reloading = false
	_session += 1

func reload_progress() -> float:
	return 1.0 - clampf(_reload_t / data.reload_time, 0.0, 1.0) if reloading else 0.0
