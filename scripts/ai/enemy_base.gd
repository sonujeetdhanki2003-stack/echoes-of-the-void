class_name EnemyBase
extends CharacterBody3D
## PRD BP_EOT_EnemyBase: shared enemy functionality. The PRD's AI Controller + Behaviour Tree + Blackboard map to
## a state machine (State enum + per-type think()), NavigationAgent3D on the area's navmesh, and Perception.

enum State { IDLE, PATROL, INVESTIGATE, ALERT, CHASE, ATTACK, REPOSITION, STAGGER, DEAD, DORMANT }

const GRAVITY := 18.0

var data: EnemyData
var kind := ""
var stable_id := ""
var spawn_opts := {}
var health: HealthComponent
var agent: NavigationAgent3D
var perception: Perception
var model: Node3D
var ap: AnimationPlayer
var skel: Skeleton3D
var state := State.IDLE
var state_t := 0.0
var alerted := false
var dead := false
var target_pos := Vector3.ZERO
var _repath := 0.0
var _anim := ""
var _stagger_acc := 0.0
var _stagger_t := 0.0
var _patrol: Array = []
var _patrol_i := 0
var _home := Vector3.ZERO     # first position, then the last solid ground (out-of-world recovery)
var _home_set := false
var _floor_t := 0.0
var _hit_flash := 0.0
var _emit_mats: Array = []
var move_speed := 0.0
var desired_vel := Vector3.ZERO
var _hum: AudioStreamPlayer3D
var _fallback_visual: Node3D
# stuck recovery (Godot PRD §10 AI): no progress for 1.5 s while trying to move -> skip / re-target + sidestep
var stuck_events := 0
var _stuck_t := 0.0
var _stuck_ref := Vector3.ZERO
var _nav_frame := -10
var _unstick_t := 0.0
var _unstick_dir := Vector3.ZERO
# AI debug overlay (Roadmap Ph5 / Godot PRD Ph5): F3 in a debug build, or --ai_debug
static var debug_ai := false
var _dbg: Label3D

func _init() -> void:
	collision_layer = 4
	collision_mask = 1 | 2 | 4
	add_to_group("enemy")
	add_to_group("actor")
	floor_snap_length = 0.4
	set_meta("surface", "flesh")

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = data.radius
	cap.height = maxf(data.height, data.radius * 2.0 + 0.1)
	cs.shape = cap
	cs.position.y = cap.height * 0.5
	add_child(cs)
	health = HealthComponent.new()
	add_child(health)
	health.setup(data.max_hp * Game.diff("enemy_hp"))
	health.died.connect(_on_died)
	agent = NavigationAgent3D.new()
	agent.path_desired_distance = 0.8
	agent.target_desired_distance = 1.0
	agent.radius = data.radius
	agent.height = data.height
	agent.max_speed = data.run_speed
	agent.path_max_distance = 3.0
	add_child(agent)
	perception = Perception.new()
	add_child(perception)
	perception.setup(self, data, eye_height())
	perception.spotted.connect(func(_p): alert())
	perception.heard.connect(_on_heard)
	_load_model()
	_make_hitboxes()
	for p in spawn_opts.get("patrol", []):
		_patrol.append(p)
	if spawn_opts.get("dormant", false):
		set_state(State.DORMANT)
		visible = false
		perception.enabled = false
		process_mode = Node.PROCESS_MODE_DISABLED
	elif _patrol.size() > 0:
		set_state(State.PATROL)
	if spawn_opts.get("alerted", false):
		call_deferred("alert")

func eye_height() -> float:
	return data.height * 0.85

func aim_target() -> Vector3:
	return global_position + Vector3.UP * data.height * 0.6

# ---------------------------------------------------------------- model & animation
func _load_model() -> void:
	if data.model != "" and ResourceLoader.exists(data.model):
		model = (load(data.model) as PackedScene).instantiate()
		model.rotation.y = PI
		add_child(model)
		ap = model.find_child("AnimationPlayer", true, false)
		skel = model.find_child("Skeleton3D", true, false) as Skeleton3D
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for i in m.mesh.get_surface_count():
				var mat := m.mesh.surface_get_material(i)
				if mat and mat.resource_name.begins_with("Emit") and mat is BaseMaterial3D:
					var dup := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
					m.set_surface_override_material(i, dup)
					dup.emission_energy_multiplier *= 1.5
					_emit_mats.append([dup, dup.emission_energy_multiplier])
		if ap:
			_set_loops()
			ap.playback_default_blend_time = 0.2
		_make_core_light()
	else:
		model = _placeholder()
		add_child(model)
	play_anim("idle")

## M2 readability: a small light in the creature's glowing core, tinted by its emission colour. It lifts the
## silhouette out of dark corridors and fog and pulses with hit flashes (see _update_glow).
var _core_light: OmniLight3D
func _make_core_light() -> void:
	if _emit_mats.is_empty():
		return
	var col: Color = (_emit_mats[0][0] as BaseMaterial3D).emission
	_core_light = OmniLight3D.new()
	_core_light.light_color = col.lerp(Color.WHITE, 0.15)
	_core_light.light_energy = 1.6
	_core_light.omni_range = maxf(2.5, data.height * 1.6)
	_core_light.omni_attenuation = 1.4
	_core_light.shadow_enabled = false
	_core_light.light_specular = 0.6
	_core_light.position = Vector3(0, data.height * 0.62, -0.45)
	add_child(_core_light)

func _set_loops() -> void:
	var loops := looping_clips()
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		for an in lib.get_animation_list():
			lib.get_animation(an).loop_mode = Animation.LOOP_LINEAR if an in loops else Animation.LOOP_NONE

func walk_clip_speed() -> float:
	return 2.0

func looping_clips() -> Array:
	return ["idle", "walk", "run", "aim", "strafe_l", "strafe_r", "crouch_cover", "charge"]

func _placeholder() -> Node3D:
	var n := Node3D.new()
	var mi := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = data.radius
	cm.height = data.height
	mi.mesh = cm
	mi.position.y = data.height * 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.08, 0.16)
	m.roughness = 0.3
	m.metallic = 0.4
	m.emission_enabled = true
	m.emission = Color(0.6, 0.2, 1.0)
	m.emission_energy_multiplier = 0.6
	mi.material_override = m
	n.add_child(mi)
	_emit_mats.append([m, 0.6])
	var eye_m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(data.radius * 1.2, 0.06, 0.05)
	eye_m.mesh = bm
	eye_m.position = Vector3(0, data.height * 0.85, -data.radius * 0.95)
	eye_m.material_override = Fx.glow_mat(Color(0.3, 0.9, 1.0), 3.0)
	n.add_child(eye_m)
	_fallback_visual = n
	return n

func play_anim(name: String, blend: float = -1.0, speed: float = 1.0, restart: bool = false) -> void:
	if ap == null or not ap.has_animation(name):
		return
	if name == _anim and not restart and ap.is_playing():
		ap.speed_scale = speed
		return
	_anim = name
	ap.play(name, blend)
	ap.speed_scale = speed
	if restart:
		ap.seek(0.0, true)

func anim_length(name: String, def: float) -> float:
	if ap and ap.has_animation(name):
		return ap.get_animation(name).length
	return def

## Hitboxes: Area3D on layer "hitbox" following bones (or fixed offsets for stand-ins), with damage multipliers.
func _make_hitboxes() -> void:
	for hb in hitbox_defs():
		var a := Area3D.new()
		a.collision_layer = 8
		a.collision_mask = 0
		a.monitoring = false
		a.set_meta("hit_owner", self)
		a.set_meta("mult", hb.get("mult", 1.0))
		a.set_meta("critical", hb.get("critical", false))
		a.set_meta("surface", hb.get("surface", "flesh"))
		var cs := CollisionShape3D.new()
		if hb.has("box"):
			var bs := BoxShape3D.new()
			bs.size = hb["box"]
			cs.shape = bs
		else:
			var sp := SphereShape3D.new()
			sp.radius = hb.get("radius", 0.3)
			cs.shape = sp
		a.add_child(cs)
		var bone: String = hb.get("bone", "")
		if skel and bone != "" and skel.find_bone(bone) != -1:
			var ba := BoneAttachment3D.new()
			ba.bone_name = bone
			skel.add_child(ba)
			ba.add_child(a)
			a.position = hb.get("bone_offset", Vector3.ZERO)
		else:
			add_child(a)
			a.position = hb.get("pos", Vector3(0, data.height * 0.6, 0))

func hitbox_defs() -> Array:
	return []

# ---------------------------------------------------------------- state machine
func set_state(s: State) -> void:
	state = s
	state_t = 0.0

func _physics_process(delta: float) -> void:
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, 10.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 10.0 * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	# v1.0.1: an enemy that somehow leaves the world is put back at its post instead of being lost for good
	if not _home_set:
		_home = global_position     # (the area sets the position after _ready, so it is read on the first physics frame)
		_home_set = true
	if global_position.y < _home.y - 40.0:
		global_position = _home
		velocity = Vector3.ZERO
		_floor_t = 0.0
	elif is_on_floor():
		_floor_t += delta
		if _floor_t > 0.3:
			_home = global_position     # last solid ground
	else:
		_floor_t = 0.0
	state_t += delta
	_stagger_t = maxf(0.0, _stagger_t - delta)
	_stagger_acc = maxf(0.0, _stagger_acc - data.stagger_threshold * 0.5 * delta)
	perception.update(delta, alerted)
	desired_vel = Vector3.ZERO
	think(delta)
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	hv = hv.lerp(desired_vel, 1.0 - exp(-8.0 * delta))
	hv += _separation() * delta * 6.0
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	_update_glow(delta)
	if debug_ai or _dbg:
		_debug_label()

func _debug_label() -> void:
	if not debug_ai:
		if _dbg:
			_dbg.visible = false
		return
	if _dbg == null:
		_dbg = Label3D.new()
		_dbg.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_dbg.no_depth_test = true
		_dbg.fixed_size = true
		_dbg.pixel_size = 0.0012
		_dbg.font_size = 22
		_dbg.outline_size = 6
		_dbg.modulate = Color(0.6, 1.0, 0.75)
		add_child(_dbg)
		_dbg.position = Vector3(0, data.height + 0.45, 0)
	_dbg.visible = true
	_dbg.text = "%s  %s\nHP %d/%d%s%s" % [kind.to_upper(), State.keys()[state], int(health.hp), int(health.max_hp),
		"  ALERT" if alerted else "", ("  STUCK x%d" % stuck_events) if stuck_events > 0 else ""]

## Override per enemy type.
func think(_delta: float) -> void:
	pass

func _separation() -> Vector3:
	var push := Vector3.ZERO
	for e in get_tree().get_nodes_in_group("enemy"):
		if e == self or not (e is Node3D):
			continue
		var d := global_position - (e as Node3D).global_position
		d.y = 0.0
		var l := d.length()
		var r := data.radius * 2.2
		if l < r and l > 0.01:
			push += d / l * (r - l)
	return push

func player() -> Player:
	var p: Player = GameMode.player
	return p if p != null and is_instance_valid(p) and not p.dead else null

func dist_to_player() -> float:
	var p := player()
	return global_position.distance_to(p.global_position) if p else INF

func face(pos: Vector3, delta: float, speed_mult: float = 1.0) -> void:
	var d := pos - global_position
	d.y = 0.0
	if d.length() < 0.05:
		return
	var yaw := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-data.turn_speed * speed_mult * delta))

func facing_error(pos: Vector3) -> float:
	var d := pos - global_position
	d.y = 0.0
	return absf(angle_difference(rotation.y, atan2(-d.x, -d.z)))

## Steer along the navmesh toward pos at speed; returns true when arrived.
func nav_to(pos: Vector3, speed: float, delta: float, arrive: float = 1.2) -> bool:
	var f := Engine.get_physics_frames()
	if f - _nav_frame > 2:
		_stuck_t = 0.0
		_stuck_ref = global_position
	_nav_frame = f
	if _unstick_t > 0.0:
		_unstick_t -= delta
		desired_vel = _unstick_dir * speed
		move_speed = speed
		return false
	_repath -= delta
	if _repath <= 0.0 or target_pos.distance_to(pos) > 1.5:
		_repath = 0.25
		target_pos = pos
		agent.target_position = pos
	var flat := global_position.distance_to(Vector3(pos.x, global_position.y, pos.z))
	if flat <= arrive:
		return true
	var next := agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.05 or agent.is_navigation_finished():
		dir = pos - global_position
		dir.y = 0.0
	if dir.length() > 0.01:
		desired_vel = dir.normalized() * speed
		face(global_position + dir, delta)
	move_speed = speed
	_stuck_t += delta
	if _stuck_t >= 1.5:
		var moved := Vector2(global_position.x - _stuck_ref.x, global_position.z - _stuck_ref.z).length()
		if speed > 0.5 and moved < 0.25:
			_on_stuck(pos, dir)
		_stuck_t = 0.0
		_stuck_ref = global_position
	return false

## No progress: a patroller gives up on this point; a hunter snaps its goal back onto the navmesh and sidesteps.
func _on_stuck(pos: Vector3, dir: Vector3) -> void:
	stuck_events += 1
	if state == State.PATROL and _patrol.size() > 1:
		_patrol_i = (_patrol_i + 1) % _patrol.size()
	else:
		var map := get_world_3d().navigation_map
		target_pos = NavigationServer3D.map_get_closest_point(map, pos)
		agent.target_position = target_pos
		_repath = 0.6
	var side := Vector3(-dir.z, 0.0, dir.x).normalized()
	if side.length() < 0.5:
		side = global_basis.x
	_unstick_dir = side * (1.0 if randf() < 0.5 else -1.0)
	_unstick_t = 0.5

func patrol(delta: float) -> void:
	if _patrol.is_empty():
		play_anim("idle")
		return
	var p: Vector3 = _patrol[_patrol_i]
	play_anim("walk", -1.0, data.walk_speed / walk_clip_speed())
	if nav_to(p, data.walk_speed, delta, 0.8):
		_patrol_i = (_patrol_i + 1) % _patrol.size()

# ---------------------------------------------------------------- reactions
func alert() -> void:
	if alerted or dead or state == State.DORMANT:
		return
	alerted = true
	perception.awareness = 1.0
	GameMode.hunter(self, true)
	Events.enemy_alerted.emit(self)
	on_alert()
	# alert nearby allies so encounters feel coordinated
	for e in get_tree().get_nodes_in_group("enemy"):
		if e != self and e is EnemyBase and not (e as EnemyBase).alerted and not (e as EnemyBase).dead:
			if (e as EnemyBase).global_position.distance_to(global_position) < 16.0 and (e as EnemyBase).state != State.DORMANT:
				(e as EnemyBase).call_deferred("alert")

func on_alert() -> void:
	set_state(State.CHASE)

func _on_heard(pos: Vector3, loud: bool) -> void:
	if alerted or dead or state == State.DORMANT:
		return
	if loud:
		alert()
	else:
		target_pos = pos
		set_state(State.INVESTIGATE)

## Called by weapons. Returns true if this hit killed.
func take_hit(dmg: float, info: Dictionary) -> bool:
	if dead:
		return false
	var applied := health.take_damage(dmg * damage_mult(info), info)
	_hit_flash = 1.0
	_stagger_acc += applied
	if not alerted:
		alert()
	if _stagger_acc >= data.stagger_threshold and _stagger_t <= 0.0 and not dead:
		_stagger_acc = 0.0
		_stagger_t = 2.0
		on_stagger()
	on_hurt(applied, info)
	return dead

## v1.6.0 (stage B): a melee strike. Always staggers the enemy for MELEE_STAGGER seconds (the finishing window).
const MELEE_STAGGER := 1.8
func melee_hit(dmg: float, info: Dictionary) -> bool:
	var killed := take_hit(dmg, info)
	if not dead and _stagger_t < MELEE_STAGGER:
		_stagger_acc = 0.0
		_stagger_t = MELEE_STAGGER
		on_stagger()
	return killed

## True while an enemy is staggered: a melee hit now is a finishing move.
func is_staggered() -> bool:
	return not dead and _stagger_t > 0.0

## v1.6.0 (stage B): flanking. Alerted melee-capable enemies that are close to the player spread around it on
## two rings instead of stacking on one side. Computed once per physics frame for the whole group.
const FLANK_KINDS := ["brute", "stalker", "hunter", "experimental"]
const FLANK_RANGE := 16.0
static var _flank_frame := -1
static var _flank_goals := {}

static func _flank_compute(pp: Vector3, tree: SceneTree) -> void:
	_flank_frame = Engine.get_physics_frames()
	_flank_goals.clear()
	var members: Array = []
	for e in tree.get_nodes_in_group("enemy"):
		if not (e is EnemyBase) or not is_instance_valid(e):
			continue
		var en := e as EnemyBase
		if en.dead or not en.alerted or not (en.kind in FLANK_KINDS):
			continue
		if en.state != State.CHASE and en.state != State.ATTACK:
			continue
		var d := Vector2(en.global_position.x - pp.x, en.global_position.z - pp.z)
		if d.length() > FLANK_RANGE:
			continue
		members.append([atan2(d.y, d.x), en])
	if members.size() < 2:
		return
	members.sort_custom(func(a, b): return a[0] < b[0])
	var n := members.size()
	var a0: float = members[0][0]
	for i in n:
		var a := a0 + float(i) * TAU / float(n)
		var r := 1.6 + 0.6 * float(i % 2)
		_flank_goals[members[i][1].get_instance_id()] = pp + Vector3(cos(a), 0.0, sin(a)) * r

## Where this enemy should walk to reach the player. Alone (or outside a group) it is the player's position.
func flank_goal(pp: Vector3) -> Vector3:
	if not alerted or dead or not (kind in FLANK_KINDS):
		return pp
	if _flank_frame != Engine.get_physics_frames():
		_flank_compute(pp, get_tree())
	return _flank_goals.get(get_instance_id(), pp)

func damage_mult(_info: Dictionary) -> float:
	return 1.0

func on_hurt(_amount: float, _info: Dictionary) -> void:
	pass

func on_stagger() -> void:
	pass

## Wake a dormant (hidden) enemy: vent ambushes, encounter waves.
func awaken(alert_now: bool = true) -> void:
	if state != State.DORMANT:
		return
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	perception.enabled = true
	set_state(State.IDLE)
	if alert_now:
		alert()

func _on_died(_info: Dictionary) -> void:
	dead = true
	set_state(State.DEAD)
	GameMode.hunter(self, false)
	collision_layer = 0
	collision_mask = 1
	for a in find_children("*", "Area3D", true, false):
		(a as Area3D).collision_layer = 0
	if stable_id != "":
		Game.set_flag("dead." + stable_id)
	Game.state["stats"]["kills"] += 1
	Events.enemy_killed.emit(self, kind)
	on_death()
	_drop()
	if _hum:
		_hum.queue_free()
	var t := get_tree().create_timer(25.0, false)
	t.timeout.connect(func():
		if is_instance_valid(self):
			var tw := create_tween()
			tw.tween_property(model, "position:y", model.position.y - 1.5, 2.0)
			tw.tween_callback(queue_free))

func on_death() -> void:
	play_anim("death", 0.15)

## Dynamic drops: a struggling player gets ammo and sometimes a medkit, so fights can't strand them.
func _drop() -> void:
	var p := player()
	if p == null:
		return
	var w_id := p.combat.current_id()
	var low_pistol := int(p.inventory.reserve["pistol"]) < 14
	var low_rifle := p.inventory.has_weapon("rifle") and int(p.inventory.reserve["rifle"]) < 30
	var roll := randf()
	var kind_drop := ""
	if low_rifle and (w_id == "rifle" or roll < 0.5):
		kind_drop = "ammo_rifle"
	elif low_pistol:
		kind_drop = "ammo_pistol"
	elif p.health.frac() < 0.35 and p.inventory.medkits == 0 and roll < 0.5:
		kind_drop = "medkit"
	elif roll < drop_chance():
		kind_drop = "ammo_rifle" if p.inventory.has_weapon("rifle") and randf() < 0.6 else "ammo_pistol"
	if kind_drop == "":
		return
	var pk := Pickup.new()
	pk.kind = kind_drop
	pk.amount = 24 if kind_drop == "ammo_rifle" else 12
	get_parent().add_child(pk)
	pk.global_position = global_position + Vector3(randf_range(-0.4, 0.4), 0.1, randf_range(-0.4, 0.4))

func drop_chance() -> float:
	return 0.35

func _update_glow(delta: float) -> void:
	_hit_flash = maxf(0.0, _hit_flash - delta * 6.0)
	for pair in _emit_mats:
		var m: BaseMaterial3D = pair[0]
		m.emission_energy_multiplier = float(pair[1]) * (1.0 + _hit_flash * 3.0) * (0.0 if dead and state_t > 1.5 else 1.0)
	if _core_light:
		_core_light.light_energy = 1.6 * (1.0 + _hit_flash * 2.0) * (0.0 if dead and state_t > 1.5 else 1.0)

func deal_damage_to_player(amount: float, kind_name: String = "melee") -> void:
	var p := player()
	if p:
		p.health.take_damage(amount, {"pos": global_position, "kind": kind_name, "source": self})
