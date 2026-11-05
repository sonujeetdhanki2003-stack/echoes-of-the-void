class_name Hunter
extends EnemyBase
## v1.1.0 stage 2 (big update PRD 2.3, type B): an aggressive pursuer. It does not zig-zag or hop back: it keeps
## closing, telegraphs one heavy overhead smash, and stays on the player. When it loses sight it follows the last
## known position for LOST_SECS and then searches around it (persistent tracking). Until its own Blender model
## exists (stage 4), it uses the stalker's skeleton and animations, scaled up.

const LOST_SECS := 12.0       # stalker gives up after 10 s and only far away; the hunter keeps tracking
const SEARCH_SECS := 6.0
const SMASH_WINDUP := 0.5
const SMASH_REACH := 2.6

var _attack := ""
var _attack_hit := false
var _cooldown := 0.0
var _searching := false
var _search_pt := Vector3.ZERO
var _search_at := 0.0

func _init() -> void:
	super._init()
	kind = "hunter"
	data = load("res://data/enemies/hunter.tres")

func eye_height() -> float:
	return 0.95

func aim_target() -> Vector3:
	return global_position + Vector3.UP * 0.9 - global_transform.basis.z * 0.5

func hitbox_defs() -> Array:
	return [
		{"bone": "head", "radius": 0.3, "mult": 2.0, "critical": true, "pos": Vector3(0, 0.95, -1.0), "surface": "crystal"},
		{"bone": "spine", "box": Vector3(0.8, 0.7, 1.7), "mult": 1.0, "pos": Vector3(0, 0.8, -0.1)},
	]

func _ready() -> void:
	super._ready()
	if model:
		model.scale = Vector3.ONE * 1.18

func looping_clips() -> Array:
	return ["idle", "walk", "run"]

## persistent tracking: a lost player is followed for LOST_SECS before the hunter searches
func should_give_up() -> bool:
	return perception != null and perception.seconds_since_seen() > LOST_SECS

func think(delta: float) -> void:
	_cooldown -= delta
	match state:
		State.IDLE:
			play_anim("idle")
		State.PATROL:
			patrol(delta)
		State.INVESTIGATE:
			if _searching:
				_search_tick(delta)
			else:
				play_anim("walk", -1.0, data.walk_speed * 1.6 / 2.0)
				if nav_to(target_pos, data.walk_speed * 1.8, delta, 1.5) or state_t > 10.0:
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
		State.STAGGER:
			play_anim("hit", 0.08)
			if state_t > anim_length("hit", 0.35) + 0.05:
				set_state(State.CHASE)

func _chase(delta: float) -> void:
	var p := player()
	if p == null:
		play_anim("idle")
		return
	var d := global_position.distance_to(p.global_position)
	var see := perception.can_see
	if d < SMASH_REACH - 0.2 and _cooldown <= 0.0 and see:
		_start_attack("smash")
		return
	play_anim("run", 0.15, data.run_speed / 9.0)
	nav_to(flank_goal(p.global_position) if see else perception.last_seen, data.run_speed, delta, 1.6)
	if not see and should_give_up():
		target_pos = perception.last_seen
		alerted = false
		GameMode.hunter(self, false)
		_searching = true
		_search_at = 0.0
		_search_pt = target_pos
		set_state(State.INVESTIGATE)

## search the last known spot: walk to a point near it, pick another every 2.2 s, stop after SEARCH_SECS
func _search_tick(delta: float) -> void:
	play_anim("walk", -1.0, data.walk_speed * 1.6 / 2.0)
	if state_t > SEARCH_SECS:
		_searching = false
		set_state(State.PATROL if _patrol.size() > 0 else State.IDLE)
		return
	_search_at += delta
	if nav_to(_search_pt, data.walk_speed * 2.4, delta, 1.2) or _search_at > 2.2:
		_search_at = 0.0
		_search_pt = target_pos + Vector3(randf_range(-3.5, 3.5), 0.0, randf_range(-3.5, 3.5))

func _start_attack(a: String) -> void:
	_attack = a
	_attack_hit = false
	set_state(State.ATTACK)
	play_anim(a, 0.08, 1.0, true)
	Sfx.play_at("hunter_snarl", global_position + Vector3.UP, -2.0, 30.0)

## v1.6.0 (stage D): the hunter's own roar when it first sees the player (its vocal, not the stalker's).
func on_alert() -> void:
	Sfx.play_at("hunter_roar", global_position + Vector3.UP * 1.2, 0.0, 55.0)

func _attack_tick(delta: float) -> void:
	var p := player()
	var total := maxf(anim_length("swipe", 1.0), 0.9)
	if state_t < SMASH_WINDUP:
		if p:
			face(p.global_position, delta, 1.2)
		desired_vel = Vector3.ZERO
	else:
		desired_vel = Vector3.ZERO
	if not _attack_hit and state_t >= SMASH_WINDUP + 0.05 and state_t <= SMASH_WINDUP + 0.3 and p:
		var to := p.global_position - global_position
		to.y = 0.0
		var front := -global_transform.basis.z
		if to.length() < SMASH_REACH and front.angle_to(to.normalized()) < 1.2:
			_attack_hit = true
			deal_damage_to_player(data.melee_damage, "smash")
	if state_t >= total:
		_cooldown = data.attack_cooldown
		set_state(State.CHASE)

func on_stagger() -> void:
	if state != State.ATTACK or state_t < SMASH_WINDUP:
		set_state(State.STAGGER)

func on_death() -> void:
	play_anim("death", 0.1)
	Sfx.play_at("stalker_death", global_position + Vector3.UP, 0.0, 40.0)
	Fx.burst(global_position + Vector3.UP * 0.7, Color(1.0, 0.25, 0.15), 0.9, 30)
