class_name Stalker
extends EnemyBase
## Fast melee hunter (PRD §5.3): patrol -> detect (screech) -> chase (zig-zag) -> close distance ->
## telegraphed lunge / swipe -> hop back -> repeat. Headshots hurt.

var _attack := ""
var _attack_hit := false
var _cooldown := 0.0
var _zig := 0.0
var _lunge_dir := Vector3.ZERO
var _chitter := 0.0

func _init() -> void:
	super._init()
	kind = "stalker"
	data = load("res://data/enemies/stalker.tres")

func eye_height() -> float:
	return 0.9

func aim_target() -> Vector3:
	return global_position + Vector3.UP * 0.75 - global_transform.basis.z * 0.5

func hitbox_defs() -> Array:
	return [
		{"bone": "head", "radius": 0.28, "mult": 2.0, "critical": true, "pos": Vector3(0, 0.85, -1.0), "surface": "crystal"},
		{"bone": "spine", "box": Vector3(0.7, 0.6, 1.6), "mult": 1.0, "pos": Vector3(0, 0.7, -0.1)},
	]

func think(delta: float) -> void:
	_cooldown -= delta
	_chitter -= delta
	if _chitter <= 0.0 and not alerted:
		_chitter = randf_range(5.0, 11.0)
		Sfx.play_at("stalker_chitter", global_position + Vector3.UP, -10.0, 22.0)
	match state:
		State.IDLE:
			play_anim("idle")
		State.PATROL:
			patrol(delta)
		State.INVESTIGATE:
			play_anim("walk", -1.0, data.walk_speed * 1.6 / 2.0)
			if nav_to(target_pos, data.walk_speed * 1.6, delta) or state_t > 8.0:
				set_state(State.PATROL if _patrol.size() > 0 else State.IDLE)
		State.ALERT:
			var p := player()
			if p:
				face(p.global_position, delta, 1.5)
			play_anim("screech", 0.12)
			if state_t >= anim_length("screech", 1.1) * 0.9:
				set_state(State.CHASE)
		State.CHASE:
			_chase(delta)
		State.ATTACK:
			_attack_tick(delta)
		State.REPOSITION:
			# hop back after an attack
			play_anim("leap_back", 0.1)
			var back := global_transform.basis.z
			desired_vel = back * (5.0 if state_t < 0.35 else 0.0)
			if state_t > 0.6:
				set_state(State.CHASE)
		State.STAGGER:
			play_anim("hit", 0.08)
			if state_t > anim_length("hit", 0.35) + 0.05:
				set_state(State.CHASE)

func on_alert() -> void:
	set_state(State.ALERT)
	Sfx.play_at("stalker_screech", global_position + Vector3.UP, 0.0, 45.0)

func _chase(delta: float) -> void:
	var p := player()
	if p == null:
		play_anim("idle")
		return
	var d := global_position.distance_to(p.global_position)
	var see := perception.can_see
	if d < 2.2 and _cooldown <= 0.0 and see:
		_start_attack("swipe")
		return
	if d < 5.0 and d > 2.2 and _cooldown <= 0.0 and see and facing_error(p.global_position) < 0.6:
		_start_attack("lunge")
		return
	# zig-zag on the approach so it's harder to track
	_zig += delta * 3.2
	var goal := p.global_position
	if d > 7.0 and see:
		var side := global_transform.basis.x * sin(_zig) * 2.5
		goal += side
	play_anim("run", 0.15, data.run_speed / 9.0)
	nav_to(goal, data.run_speed, delta, 1.6)
	if perception.seconds_since_seen() > 10.0 and d > 20.0:
		# lost the player: prowl to the last known position
		target_pos = perception.last_seen
		alerted = false
		GameMode.hunter(self, false)
		set_state(State.INVESTIGATE)

func _start_attack(a: String) -> void:
	_attack = a
	_attack_hit = false
	set_state(State.ATTACK)
	play_anim(a, 0.08, 1.0, true)
	var p := player()
	if p:
		_lunge_dir = (p.global_position - global_position)
		_lunge_dir.y = 0.0
		_lunge_dir = _lunge_dir.normalized()
	Sfx.play_at("stalker_attack", global_position + Vector3.UP, -2.0, 30.0)

func _attack_tick(delta: float) -> void:
	var p := player()
	var windup := 0.35 if _attack == "lunge" else 0.32
	var total := anim_length(_attack, 1.0 if _attack == "lunge" else 0.8)
	if state_t < windup:
		# telegraph: crouch and track the player
		if p:
			face(p.global_position, delta, 1.2)
			_lunge_dir = (p.global_position - global_position)
			_lunge_dir.y = 0.0
			_lunge_dir = _lunge_dir.normalized()
		desired_vel = Vector3.ZERO
	elif _attack == "lunge" and state_t < windup + 0.32:
		desired_vel = _lunge_dir * 11.0
		velocity = desired_vel
	else:
		desired_vel = Vector3.ZERO
	var hit_from := windup + 0.05
	var hit_to := windup + (0.4 if _attack == "lunge" else 0.18)
	if not _attack_hit and state_t >= hit_from and state_t <= hit_to and p:
		var reach := 1.9 if _attack == "lunge" else 2.3
		var to := p.global_position - global_position
		to.y = 0.0
		var front := -global_transform.basis.z
		if to.length() < reach and front.angle_to(to.normalized()) < 1.2:
			_attack_hit = true
			deal_damage_to_player(data.melee_damage * (1.15 if _attack == "lunge" else 0.9))
	if state_t >= total:
		_cooldown = data.attack_cooldown + randf_range(0.0, 0.6)
		set_state(State.REPOSITION if _attack == "lunge" else State.CHASE)

func on_stagger() -> void:
	if state != State.ATTACK or state_t < 0.35:
		set_state(State.STAGGER)

func on_hurt(_a: float, _i: Dictionary) -> void:
	if not dead and randf() < 0.4:
		Sfx.play_at("stalker_hurt", global_position + Vector3.UP, -4.0, 30.0)

func on_death() -> void:
	play_anim("death", 0.1)
	Sfx.play_at("stalker_death", global_position + Vector3.UP, 0.0, 40.0)
	Fx.burst(global_position + Vector3.UP * 0.7, Color(0.6, 0.3, 1.0), 0.8, 30)
