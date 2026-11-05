class_name Experimental
extends Hunter
## v1.1.0 stage 2 (big update PRD 2.3, type D): an unpredictable organism. In a chase it jukes sideways at random,
## sometimes stops to sniff, and at close range releases a spore cloud: the cloud hurts whoever stands in it for
## SPORE_SECS. Its model is the brute's, scaled down, until its own model exists (stage 4).

const SPORE_RANGE := 9.0
const SPORE_RADIUS := 3.2
const SPORE_SECS := 5.0
const SPORE_DPS := 5.0
const SPORE_WINDUP := 0.7
const JUKE_SPEED := 7.0
const JUKE_SECS := 0.35

var _juke_t := 0.0
var _juke_run := 0.0
var _juke_dir := Vector3.ZERO
var _sniff_t := 0.0
var _spore_cd := 4.0
var _spore_t := 0.0
var _spore_pos := Vector3.ZERO
var _cloud: MeshInstance3D

func _init() -> void:
	super._init()
	kind = "experimental"
	data = load("res://data/enemies/experimental.tres")

func eye_height() -> float:
	return 1.4

func hitbox_defs() -> Array:
	return [
		{"bone": "back_crystal", "radius": 0.55, "mult": 1.8, "critical": true, "pos": Vector3(0, 2.2, 0.55), "bone_offset": Vector3.ZERO, "surface": "crystal"},
		{"bone": "head", "radius": 0.3, "mult": 1.2, "critical": false, "pos": Vector3(0, 2.4, -0.4), "surface": "flesh"},
	]

func _ready() -> void:
	# EnemyBase._ready builds the model; the Hunter's scale-up is replaced by this one
	super._ready()
	if model:
		model.scale = Vector3.ONE * 0.8

func looping_clips() -> Array:
	return ["idle", "walk"]

func think(delta: float) -> void:
	super.think(delta)
	_spore_cd -= delta
	if _spore_t > 0.0:
		_spore_t -= delta
		var p := player()
		if p and not p.dead and p.global_position.distance_to(_spore_pos) < SPORE_RADIUS:
			deal_damage_to_player(SPORE_DPS * delta, "spores")
		if _spore_t <= 0.0 and is_instance_valid(_cloud):
			_cloud.queue_free()
			_cloud = null

func _chase(delta: float) -> void:
	var p := player()
	if p == null:
		play_anim("idle")
		return
	var d := global_position.distance_to(p.global_position)
	var see := perception.can_see
	if see and _spore_cd <= 0.0 and d < SPORE_RANGE and d > 3.0:
		_start_attack("spore")
		return
	if d < SMASH_REACH - 0.2 and _cooldown <= 0.0 and see:
		_start_attack("smash")
		return
	if _sniff_t > 0.0:
		_sniff_t -= delta
		play_anim("idle")
		return
	_juke_t -= delta
	if _juke_t <= 0.0:
		pick_juke()
	_juke_run = maxf(0.0, _juke_run - delta)
	play_anim("walk", 0.15, data.run_speed / 4.0)
	nav_to(flank_goal(p.global_position) if see else perception.last_seen, data.run_speed, delta, 1.6)
	if _juke_run > 0.0:
		desired_vel += _juke_dir * JUKE_SPEED
	if not see and should_give_up():
		target_pos = perception.last_seen
		alerted = false
		GameMode.hunter(self, false)
		_searching = true
		_search_at = 0.0
		_search_pt = target_pos
		set_state(State.INVESTIGATE)

## a random sideways burst; sometimes a short sniff before it
func pick_juke() -> void:
	if randf() < 0.35:
		Sfx.play_at("exp_click", global_position + Vector3.UP * 0.4, -4.0, 22.0)
	_juke_t = randf_range(1.2, 3.0)
	var side := global_transform.basis.x * (1.0 if randf() < 0.5 else -1.0)
	_juke_dir = side * randf_range(0.6, 1.0)
	_juke_run = JUKE_SECS
	if randf() < 0.25:
		_sniff_t = randf_range(0.4, 0.9)
		Sfx.play_at("exp_sniff", global_position + Vector3.UP * 0.6, -6.0, 18.0)

func _attack_tick(delta: float) -> void:
	if _attack == "spore":
		_spore_tick(delta)
	else:
		super._attack_tick(delta)

func _spore_tick(delta: float) -> void:
	var p := player()
	if p:
		face(p.global_position, delta, 1.0)
	desired_vel = Vector3.ZERO
	if state_t >= SPORE_WINDUP:
		release_spores()
		_spore_cd = 7.0
		set_state(State.CHASE)

## the cloud: a translucent sphere that stays where it was released, for SPORE_SECS
func release_spores() -> void:
	_spore_pos = global_position
	_spore_t = SPORE_SECS
	if is_instance_valid(_cloud):
		_cloud.queue_free()
	_cloud = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = SPORE_RADIUS
	sm.height = SPORE_RADIUS * 2.0
	_cloud.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.55, 0.9, 0.25, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(0.4, 0.9, 0.2)
	mat.emission_energy_multiplier = 0.6
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cloud.material_override = mat
	var host: Node = get_parent() if get_parent() else self
	host.add_child(_cloud)
	_cloud.global_position = _spore_pos + Vector3.UP * 0.6
	Fx.burst(_spore_pos + Vector3.UP * 0.5, Color(0.6, 1.0, 0.3), 1.2, 40)
	Events.message.emit("Spores in the air: get out of the cloud", 2.5)
	Sfx.play_at("exp_squelch", _spore_pos, 0.0, 30.0)

func on_stagger() -> void:
	if state != State.ATTACK or state_t < SPORE_WINDUP:
		set_state(State.STAGGER)
