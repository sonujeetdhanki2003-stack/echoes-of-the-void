class_name Brute
extends EnemyBase
## Heavy attacker (PRD §5.3): slow, very durable, telegraphed heavy attacks — a ground SLAM with a growing
## ring, a wide SWIPE, and a roaring CHARGE that stuns it if it hits a wall. Its glowing back crystals take
## double damage; its armoured front takes less. Difficulty comes from positioning, not a health sponge.

var _attack := ""
var _hit_done := false
var _cooldown := 0.0
var _charge_cd := 4.0
var _charge_dir := Vector3.ZERO
var _step_t := 0.0
var _breath: AudioStreamPlayer3D

func _init() -> void:
	super._init()
	kind = "brute"
	data = load("res://data/enemies/brute.tres")

func _ready() -> void:
	super._ready()
	_breath = Sfx.emitter("brute_breath", self, -11.0, 18.0)

func looping_clips() -> Array:
	return ["idle", "walk", "charge"]

func hitbox_defs() -> Array:
	return [
		{"bone": "back_crystal", "radius": 0.55, "mult": 2.2, "critical": true, "pos": Vector3(0, 2.2, 0.55), "bone_offset": Vector3.ZERO, "surface": "crystal"},
		{"bone": "head", "radius": 0.3, "mult": 1.3, "critical": false, "pos": Vector3(0, 2.4, -0.4), "surface": "flesh"},
	]

func damage_mult(info: Dictionary) -> float:
	# body (capsule) hits from the front are armoured; stunned brutes are wide open
	var m := 1.0
	if state == State.STAGGER and _attack == "stun":
		m = 1.6
	elif not info.get("critical", false):
		var dir: Vector3 = info.get("dir", Vector3.ZERO)
		var front := -global_transform.basis.z
		if dir.length() > 0.1 and front.dot(-dir) > 0.3:
			m = 0.75
	return m

func think(delta: float) -> void:
	_cooldown -= delta
	_charge_cd -= delta
	var p := player()
	match state:
		State.IDLE:
			play_anim("idle")
		State.PATROL:
			patrol(delta)
			_steps(delta, 0.9)
		State.INVESTIGATE:
			play_anim("walk")
			_steps(delta, 0.9)
			if nav_to(target_pos, data.walk_speed, delta, 1.5) or state_t > 10.0:
				set_state(State.IDLE)
		State.ALERT:
			play_anim("roar", 0.15)
			if p:
				face(p.global_position, delta, 0.8)
			if state_t > anim_length("roar", 2.0) * 0.8:
				set_state(State.CHASE)
		State.CHASE:
			if p == null:
				play_anim("idle")
				return
			var d := global_position.distance_to(p.global_position)
			if d < data.melee_range and _cooldown <= 0.0:
				_start("slam" if (randf() < 0.55 or d < 2.2) else "swipe")
				return
			if d > 8.0 and d < 22.0 and _charge_cd <= 0.0 and perception.can_see and _clear_line(p.global_position):
				_start("charge_start")
				return
			play_anim("walk", 0.2, 1.0)
			_steps(delta, 0.75)
			nav_to(p.global_position, data.walk_speed, delta, data.melee_range * 0.7)
		State.ATTACK:
			_attack_tick(delta, p)
		State.STAGGER:
			var clip := "charge_stun" if _attack == "stun" else "hit"
			play_anim(clip, 0.1)
			if state_t > anim_length(clip, 1.8 if _attack == "stun" else 0.8):
				_attack = ""
				set_state(State.CHASE)

func _steps(delta: float, interval: float) -> void:
	_step_t += delta
	if _step_t >= interval:
		_step_t = 0.0
		Sfx.play_at("brute_step", global_position, -4.0, 35.0)
		var p := player()
		if p and p.global_position.distance_to(global_position) < 12.0:
			Events.camera_shake.emit(0.08, 0.15)

func on_alert() -> void:
	set_state(State.ALERT)
	Sfx.play_at("brute_roar", global_position + Vector3.UP * 2.0, 2.0, 60.0)
	Events.camera_shake.emit(0.2, 0.8)

func _clear_line(to: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.0, to + Vector3.UP * 1.0, 1)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func _start(a: String) -> void:
	_attack = a
	_hit_done = false
	set_state(State.ATTACK)
	var p := player()
	match a:
		"slam":
			play_anim("slam", 0.12, 1.0, true)
			Fx.telegraph(global_position - global_transform.basis.z * 1.6, 4.4, 0.95)
		"swipe":
			play_anim("swipe", 0.12, 1.0, true)
			Sfx.play_at("brute_swipe", global_position + Vector3.UP * 1.5, -2.0, 30.0)
		"charge_start":
			play_anim("charge_start", 0.15, 1.0, true)
			Sfx.play_at("brute_roar", global_position + Vector3.UP * 2.0, 0.0, 60.0)
			if p:
				_charge_dir = (p.global_position - global_position)
				_charge_dir.y = 0.0
				_charge_dir = _charge_dir.normalized()

func _attack_tick(delta: float, p: Player) -> void:
	match _attack:
		"slam":
			if state_t < 0.9 and p:
				face(p.global_position, delta, 0.5)
			var hit_t := 1.0
			if not _hit_done and state_t >= hit_t:
				_hit_done = true
				var c := global_position - global_transform.basis.z * 1.6
				Sfx.play_at("brute_slam", c, 4.0, 60.0)
				Fx.burst(c + Vector3.UP * 0.2, Color(0.9, 0.7, 1.0), 1.2, 40)
				Events.camera_shake.emit(0.6, 0.5)
				Events.emit_noise(c, 20.0, self)
				if p and p.global_position.distance_to(c) < 4.4:
					deal_damage_to_player(data.melee_damage)
					var push := (p.global_position - c)
					push.y = 0.0
					p.velocity += push.normalized() * 7.0 + Vector3.UP * 4.0
			if state_t >= anim_length("slam", 2.2):
				_cooldown = data.attack_cooldown
				set_state(State.CHASE)
		"swipe":
			if state_t < 0.55 and p:
				face(p.global_position, delta, 0.9)
			if not _hit_done and state_t >= 0.62 and state_t <= 0.8 and p:
				var to := p.global_position - global_position
				to.y = 0.0
				if to.length() < 3.6 and (-global_transform.basis.z).angle_to(to.normalized()) < 1.1:
					_hit_done = true
					deal_damage_to_player(data.melee_damage * 0.75)
					p.velocity += to.normalized() * 5.0
			if state_t >= anim_length("swipe", 1.4):
				_cooldown = data.attack_cooldown * 0.8
				set_state(State.CHASE)
		"charge_start":
			if p:
				face(p.global_position, delta, 1.2)
				_charge_dir = (p.global_position - global_position)
				_charge_dir.y = 0.0
				_charge_dir = _charge_dir.normalized()
			if state_t >= 1.0:
				_attack = "charge"
				state_t = 0.0
				_hit_done = false
				play_anim("charge", 0.1)
		"charge":
			# slight homing so side-steps late still work
			if p:
				var want := (p.global_position - global_position)
				want.y = 0.0
				if want.length() > 2.0:
					_charge_dir = _charge_dir.slerp(want.normalized(), clampf(0.25 * delta, 0.0, 1.0)).normalized()
			desired_vel = _charge_dir * data.run_speed
			velocity.x = desired_vel.x
			velocity.z = desired_vel.z
			face(global_position + _charge_dir, delta, 2.0)
			_steps(delta, 0.3)
			if not _hit_done and p and p.global_position.distance_to(global_position) < 2.0:
				_hit_done = true
				deal_damage_to_player(data.melee_damage * 1.1)
				p.velocity += _charge_dir * 10.0 + Vector3.UP * 5.0
				Events.camera_shake.emit(0.7, 0.4)
				_charge_cd = 7.0
				_cooldown = 1.2
				set_state(State.CHASE)
				return
			if state_t > 0.25 and is_on_wall():
				Sfx.play_at("brute_slam", global_position + Vector3.UP, 2.0, 60.0)
				Events.camera_shake.emit(0.5, 0.4)
				_attack = "stun"
				_charge_cd = 7.0
				set_state(State.STAGGER)
				return
			if state_t > 2.6:
				_charge_cd = 6.0
				set_state(State.CHASE)

func on_stagger() -> void:
	if state == State.ATTACK and _attack in ["charge", "slam"]:
		return
	_attack = ""
	set_state(State.STAGGER)

func on_hurt(_a: float, _i: Dictionary) -> void:
	if randf() < 0.25:
		Sfx.play_at("brute_hurt", global_position + Vector3.UP * 2.0, -2.0, 40.0)

func on_death() -> void:
	play_anim("death", 0.1)
	Sfx.play_at("brute_death", global_position + Vector3.UP * 2.0, 2.0, 60.0)
	Fx.burst(global_position + Vector3.UP * 2.0, Color(1.0, 0.3, 0.8), 1.5, 50)
	Events.camera_shake.emit(0.4, 0.6)
	if _breath:
		_breath.queue_free()

func drop_chance() -> float:
	return 1.0
