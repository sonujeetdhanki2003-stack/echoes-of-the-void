class_name ScatterShotgun
extends WeaponBase
## v1.1.0 stage 3: Scatter Shotgun. Close-range burst: data.pellets pellets per trigger, each a separate trace
## inside the cone, each doing data.damage. It shares the energy cells with the pistol (ammo_type "pistol").

func auto_fire_allowed() -> bool:
	return false

## the pellet directions for one trigger pull: pellet 0 is the aim line, the rest are spread in the cone
static func pellet_dirs(dir: Vector3, pellets: int, cone_deg: float) -> Array:
	var out: Array = [dir]
	var side := dir.cross(Vector3.UP)
	if side.length() < 0.001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := side.cross(dir).normalized()
	for i in range(1, pellets):
		var a := TAU * float(i) / float(maxi(pellets - 1, 1)) + 0.4
		var r := tan(deg_to_rad(cone_deg)) * (0.55 + 0.45 * float((i * 7) % 5) / 4.0)
		out.append((dir + (side * cos(a) + up * sin(a)) * r).normalized())
	return out

func fire() -> bool:
	if not can_fire():
		return false
	_cooldown = 1.0 / data.fire_rate
	mag -= 1
	var ray: Array = owner_player.controller.aim_ray()
	var origin: Vector3 = ray[0]
	var aim: Vector3 = ray[1]
	aim = _aim_assist(origin, aim)
	var cone := current_spread()
	var first_end := Vector3.ZERO
	var first := true
	for d in pellet_dirs(aim, data.pellets, cone):
		var dir: Vector3 = d
		var hit := _trace(origin, dir)
		var end: Vector3 = hit["position"] if hit else origin + dir * data.range
		if first:
			first_end = end
			first = false
		if hit:
			_apply_hit(hit, dir)
	var mp := muzzle_pos()
	Fx.muzzle_flash(mp, aim, data.tracer_color, true)
	Fx.tracer(mp, first_end, data.tracer_color, 0.03)
	var kick := data.recoil_pitch * (0.55 if owner_player.aiming else 1.0)
	owner_player.controller.add_recoil(kick, randf_range(-data.recoil_yaw, data.recoil_yaw))
	owner_player.controller.shake(0.3, 0.14)
	Sfx.play(data.sfx_fire, 2.0, randf_range(0.85, 0.92))
	Events.emit_noise(owner_player.global_position, data.noise_radius, owner_player)
	Game.state["stats"]["shots"] += 1
	fired.emit()
	return true
