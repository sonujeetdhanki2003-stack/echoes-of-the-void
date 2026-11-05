class_name Sentinel
extends EnemyBase
## Ranged attacker (PRD §5.3): detect -> seek a firing position (line of sight to the player at a preferred
## range, near cover, not shared with another Sentinel) -> charged 3-bolt bursts -> reposition when flanked,
## hurt, or blind. Its glowing chest core is the critical spot.

static var claimed := {}    # position key -> sentinel id

var fire_pos := Vector3.ZERO
var _has_pos := false
var _bursts := 0
var _shots_left := 0
var _shot_t := 0.0
var _cooldown := 0.0
var _hurt_since_move := 0.0
var _blind_t := 0.0
var _charge_light: OmniLight3D
var _claim_key := ""
var _at_cover := false

func _init() -> void:
	super._init()
	kind = "sentinel"
	data = load("res://data/enemies/sentinel.tres")

func _ready() -> void:
	super._ready()
	_charge_light = OmniLight3D.new()
	_charge_light.light_color = Color(1.0, 0.3, 0.9)
	_charge_light.light_energy = 0.0
	_charge_light.omni_range = 4.0
	add_child(_charge_light)
	_charge_light.position = Vector3(0.35, 1.35, -0.6)
	_hum = Sfx.emitter("sentinel_hum", self, -19.0, 13.0)

func hitbox_defs() -> Array:
	return [
		{"bone": "head", "radius": 0.2, "mult": 1.6, "critical": true, "pos": Vector3(0, 1.72, 0), "surface": "crystal"},
		{"bone": "core", "radius": 0.18, "mult": 2.2, "critical": true, "pos": Vector3(0, 1.32, -0.18), "surface": "crystal"},
	]

func muzzle_pos() -> Vector3:
	if skel and skel.find_bone("muzzle") != -1:
		return skel.global_transform * skel.get_bone_global_pose(skel.find_bone("muzzle")).origin
	return global_transform * Vector3(0.35, 1.35, -0.75)

func think(delta: float) -> void:
	_cooldown -= delta
	var p := player()
	match state:
		State.IDLE:
			play_anim("idle")
		State.PATROL:
			patrol(delta)
		State.INVESTIGATE:
			play_anim("walk")
			if nav_to(target_pos, data.walk_speed, delta) or state_t > 10.0:
				set_state(State.PATROL if _patrol.size() > 0 else State.IDLE)
		State.ALERT:
			play_anim("alert", 0.12)
			if p:
				face(p.global_position, delta)
			if state_t > anim_length("alert", 1.0):
				_pick_position()
		State.REPOSITION:
			if not _has_pos:
				_pick_position()
			play_anim("run", 0.15)
			if p and global_position.distance_to(fire_pos) < 6.0:
				face(p.global_position, delta)
			if nav_to(fire_pos, data.run_speed, delta, 0.8) or state_t > 7.0:
				set_state(State.ATTACK)
				_bursts = 0
				_hurt_since_move = 0.0
		State.ATTACK:
			_attack_tick(delta)
		State.STAGGER:
			play_anim("hit", 0.08)
			_charge_light.light_energy = 0.0
			_shots_left = 0
			if state_t > anim_length("hit", 0.4) + 0.1:
				set_state(State.ATTACK)

func on_alert() -> void:
	set_state(State.ALERT)
	Sfx.play_at("sentinel_alert", global_position + Vector3.UP * 1.5, -2.0, 40.0)

## Choose a firing position: sample a ring around the player plus authored cover points; score for line of
## sight, preferred range, cover, travel cost and spacing from other Sentinels.
func _pick_position() -> void:
	var p := player()
	if p == null:
		set_state(State.IDLE)
		return
	_release_claim()
	var cands: Array = []
	for c in get_tree().get_nodes_in_group("cover"):
		if c is Node3D and (c as Node3D).global_position.distance_to(p.global_position) < 26.0:
			cands.append([(c as Node3D).global_position, true])
	for i in 12:
		var ang := TAU * i / 12.0
		for r in [data.preferred_range * 0.75, data.preferred_range, data.preferred_range * 1.35]:
			cands.append([p.global_position + Vector3(cos(ang), 0, sin(ang)) * r, false])
	var map := get_world_3d().navigation_map
	var best := global_position
	var best_score := -INF
	for cd in cands:
		var pos: Vector3 = NavigationServer3D.map_get_closest_point(map, cd[0])
		if pos.distance_to(cd[0]) > 2.0:
			continue
		var dp := pos.distance_to(p.global_position)
		if dp < 6.0:
			continue
		var score := 0.0
		var eye_pt := pos + Vector3.UP * 1.5
		if perception.has_los_to(eye_pt):
			score += 10.0
		else:
			score -= 6.0
		score -= absf(dp - data.preferred_range) * 0.5
		score -= pos.distance_to(global_position) * 0.12
		if cd[1]:
			score += 3.0
		if claimed.has(_key(pos)):
			score -= 12.0
		for e in get_tree().get_nodes_in_group("enemy"):
			if e != self and e is Sentinel and (e as Sentinel)._has_pos and (e as Sentinel).fire_pos.distance_to(pos) < 4.0:
				score -= 8.0
		if score > best_score:
			best_score = score
			best = pos
			_at_cover = cd[1]
	fire_pos = best
	_has_pos = true
	_claim_key = _key(best)
	claimed[_claim_key] = get_instance_id()
	set_state(State.REPOSITION)

func _key(v: Vector3) -> String:
	return "%d_%d" % [int(round(v.x / 2.0)), int(round(v.z / 2.0))]

func _release_claim() -> void:
	if _claim_key != "" and claimed.get(_claim_key, -1) == get_instance_id():
		claimed.erase(_claim_key)
	_claim_key = ""

func _attack_tick(delta: float) -> void:
	var p := player()
	if p == null:
		play_anim("idle")
		return
	face(p.global_position, delta, 1.3)
	var d := global_position.distance_to(p.global_position)
	var see := perception.can_see
	_blind_t = 0.0 if see else _blind_t + delta
	# reposition triggers: flanked/too close, blind, hurt, or after a couple of bursts
	if _shots_left == 0 and (d < 5.5 or _blind_t > 1.6 or _hurt_since_move > 35.0 or _bursts >= 2):
		if d < 1.9 and _cooldown <= 0.0:
			# shove the player away
			play_anim("fire", 0.08, 1.0, true)
			deal_damage_to_player(data.melee_damage, "melee")
			_cooldown = 1.0
		_has_pos = false
		set_state(State.REPOSITION)
		return
	if _shots_left > 0:
		_shot_t -= delta
		play_anim("aim", 0.1)
		if _shot_t <= 0.0:
			_fire_bolt(p)
			_shots_left -= 1
			_shot_t = 0.2
			if _shots_left == 0:
				_bursts += 1
				_cooldown = randf_range(1.5, 2.4)
				_charge_light.light_energy = 0.0
		return
	if _cooldown > 0.0:
		play_anim("crouch_cover" if _at_cover else "aim", 0.2)
		return
	if see and facing_error(p.global_position) < 0.35:
		# charge telegraph: the cannon glows and whines for 0.6 s before the burst
		if _charge_t < 0.0:
			_charge_t = 0.0
			Sfx.play_at("sentinel_charge", muzzle_pos(), -2.0, 35.0)
		_charge_t += delta
		play_anim("charge", 0.1)
		_charge_light.light_energy = _charge_t * 6.0
		if _charge_t >= 0.6:
			_charge_t = -1.0
			_shots_left = 3
			_shot_t = 0.0
	else:
		_charge_t = -1.0
		_charge_light.light_energy = 0.0
		play_anim("aim", 0.2)

var _charge_t := -1.0

func _fire_bolt(p: Player) -> void:
	var from := muzzle_pos()
	# lead the target a little, with some error so movement is rewarded
	var lead := p.velocity * clampf(from.distance_to(p.chest()) / 26.0, 0.0, 0.6) * 0.6
	var aim := p.chest() + lead + Vector3(randf_range(-0.35, 0.35), randf_range(-0.2, 0.25), randf_range(-0.35, 0.35))
	var b := Bolt.new()
	b.damage = data.ranged_damage
	b.source = self
	get_parent().add_child(b)
	b.launch(from, aim - from, 24.0)
	Fx.muzzle_flash(from, aim - from, Color(1.0, 0.3, 0.9), true)
	Sfx.play_at("sentinel_bolt", from, -1.0, 45.0)
	play_anim("fire", 0.05, 1.0, true)

func on_hurt(a: float, _i: Dictionary) -> void:
	_hurt_since_move += a
	if randf() < 0.35:
		Sfx.play_at("sentinel_hurt", global_position + Vector3.UP * 1.5, -4.0, 30.0)

func on_stagger() -> void:
	set_state(State.STAGGER)

func on_death() -> void:
	_release_claim()
	_charge_light.light_energy = 0.0
	play_anim("death", 0.1)
	Sfx.play_at("sentinel_death", global_position + Vector3.UP, 0.0, 40.0)
	Fx.burst(global_position + Vector3.UP * 1.3, Color(1.0, 0.3, 0.9), 0.7, 24)

func drop_chance() -> float:
	return 0.55
