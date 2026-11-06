class_name Herald
extends Node3D
## THE HERALD (PRD final boss): a 14 m colossus risen from the chasm beside the launch pad. Stationary; three
## resonance nodes are its weak points.
##   Phase 1 — arm SLAMS at the player (1.2 s telegraph ring) and SHARD rain. Shoulder nodes are open.
##   Phase 2 — both shoulders broken: roar, SUMMONS Stalkers from crystal vents, sweeping BEAM from the maw
##             (break line of sight behind cover), slams continue. After 35 s the chest plates part.
##   Phase 3 — the chest node glows: faster slams, beam and shards. Destroy it to win.

signal phase_changed(p: int)
signal defeated

const SHOULDER_HP := 340.0
const CHEST_HP := 520.0

var model: Node3D
var ap: AnimationPlayer
var skel: Skeleton3D
var phase := 0                 # 0 = dormant/rising, 1..3 fighting, 4 dead
var nodes := {}                # id -> {hp, max, area, mesh, alive}
var vents: Array = []          # summon positions
var arena_center := Vector3.ZERO
var arena_radius := 16.0
var _t := 0.0
var _next_attack := 3.0
var _busy := false
var _slam_side := 0
var _attack_count := 0
var _phase2_t := 0.0
var _summons := 0
var beam_mesh: MeshInstance3D
var beam_light: OmniLight3D
var _beam_on := false
var _beam_from := Vector3.ZERO
var _beam_to := Vector3.ZERO
var _beam_tick := 0.0
var _hum: AudioStreamPlayer3D
var json := {}
var difficulty_speed := 1.0
var base_yaw := 0.0

func _ready() -> void:
	add_to_group("boss")
	var path := "res://assets/models/herald.glb"
	if ResourceLoader.exists(path):
		model = (load(path) as PackedScene).instantiate()
		model.rotation.y = PI
		add_child(model)
		ap = model.find_child("AnimationPlayer", true, false)
		skel = model.find_child("Skeleton3D", true, false) as Skeleton3D
		if ap:
			for lib_name in ap.get_animation_library_list():
				var lib := ap.get_animation_library(lib_name)
				for an in lib.get_animation_list():
					lib.get_animation(an).loop_mode = Animation.LOOP_LINEAR if an == "idle" else Animation.LOOP_NONE
	else:
		model = _placeholder()
		add_child(model)
	var jp := "res://assets/models/herald.json"
	if FileAccess.file_exists(jp):
		var jj := JSON.new()
		if jj.parse(FileAccess.get_file_as_string(jp)) == OK and jj.data is Dictionary:
			json = jj.data
	_make_nodes()
	_make_body_collision()
	beam_mesh = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.55
	cm.bottom_radius = 0.55
	cm.height = 1.0
	beam_mesh.mesh = cm
	beam_mesh.material_override = Fx.glow_mat(Color(0.75, 0.35, 1.0), 9.0)
	beam_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam_mesh.top_level = true
	beam_mesh.visible = false
	add_child(beam_mesh)
	beam_light = OmniLight3D.new()
	beam_light.light_color = Color(0.75, 0.35, 1.0)
	beam_light.omni_range = 14.0
	beam_light.light_energy = 0.0
	beam_light.top_level = true
	add_child(beam_light)
	visible = false
	difficulty_speed = {"story": 0.8, "normal": 1.0, "hard": 1.2}.get(Game.settings["difficulty"], 1.0)

func _placeholder() -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 3.5
	cm.height = 14.0
	body.mesh = cm
	body.position.y = 5.0
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.08, 0.05, 0.12)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.2, 0.9)
	m.emission_energy_multiplier = 0.4
	body.material_override = m
	n.add_child(body)
	for s in [-1.0, 1.0]:
		var arm := MeshInstance3D.new()
		var am := CapsuleMesh.new()
		am.radius = 1.0
		am.height = 11.0
		arm.mesh = am
		arm.position = Vector3(4.5 * s, 6.0, 2.0)
		arm.rotation.x = 0.6
		arm.material_override = m
		n.add_child(arm)
	return n

func _bone_pos(bone: String, fallback: Vector3) -> Vector3:
	if skel and skel.find_bone(bone) != -1:
		return skel.global_transform * skel.get_bone_global_pose(skel.find_bone(bone)).origin
	return global_transform * fallback

func _make_nodes() -> void:
	var defs := {"node_l": [Vector3(-3.6, 11.0, 0.8), SHOULDER_HP], "node_r": [Vector3(3.6, 11.0, 0.8), SHOULDER_HP], "node_c": [Vector3(0, 8.6, 2.0), CHEST_HP]}
	for id in defs.keys():
		var hp: float = defs[id][1] * Game.diff("enemy_hp")
		var a := Area3D.new()
		a.collision_layer = 8
		a.collision_mask = 0
		a.monitoring = false
		var proxy := HeraldNode.new()
		proxy.herald = self
		proxy.node_id = id
		a.add_child(proxy)
		a.set_meta("hit_owner", proxy)
		a.set_meta("mult", 1.0)
		a.set_meta("critical", true)
		a.set_meta("surface", "crystal")
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.1 if id != "node_c" else 1.3
		cs.shape = sp
		a.add_child(cs)
		var mesh: Node3D = model.find_child(id, true, false) as Node3D
		var bone: String = "bone_" + str(id)
		if skel and skel.find_bone(bone) == -1 and skel.find_bone(id) != -1:
			bone = id
		if skel and skel.find_bone(bone) != -1:
			var ba := BoneAttachment3D.new()
			ba.bone_name = bone
			skel.add_child(ba)
			ba.add_child(a)
		else:
			add_child(a)
			a.position = defs[id][0]
		if mesh == null:
			var mi := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = 0.9
			sm.height = 1.8
			mi.mesh = sm
			mi.material_override = Fx.glow_mat(Color(0.3, 0.9, 1.0), 6.0)
			a.add_child(mi)
			mesh = mi
		var l := OmniLight3D.new()
		l.light_color = Color(0.3, 0.9, 1.0)
		l.light_energy = 3.0
		l.omni_range = 6.0
		a.add_child(l)
		nodes[id] = {"hp": hp, "max": hp, "area": a, "mesh": mesh, "light": l, "alive": true, "shape": cs}
	_set_node_open("node_c", false)

func _set_node_open(id: String, open: bool) -> void:
	var n: Dictionary = nodes[id]
	(n["shape"] as CollisionShape3D).disabled = not open
	(n["light"] as OmniLight3D).light_energy = 3.0 if open else 0.3
	if n["mesh"] is GeometryInstance3D:
		(n["mesh"] as GeometryInstance3D).transparency = 0.0 if open else 0.6

func _make_body_collision() -> void:
	# the torso blocks shots aimed past the nodes (and sparks off its plates)
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.set_meta("surface", "crystal")
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 2.6
	cap.height = 12.0
	cs.shape = cap
	cs.position = Vector3(0, 4.5, -0.8)
	sb.add_child(cs)
	add_child(sb)

func play(clip: String, blend: float = 0.25) -> float:
	if ap and ap.has_animation(clip):
		ap.play(clip, blend)
		return ap.get_animation(clip).length
	return {"rise": 6.0, "slam_l": 2.6, "slam_r": 2.6, "sweep": 4.0, "shard": 2.0, "summon": 2.0, "roar": 2.5, "stagger": 1.5, "death": 6.0}.get(clip, 1.5)

func clip_event(clip: String, ev: String, def: float) -> float:
	for c in json.get("clips", []):
		if c.get("name") == clip:
			var e: Dictionary = c.get("events", {})
			if e.has(ev):
				var v: Variant = e[ev]
				return float(v[0]) if v is Array else float(v)
	return def

# ---------------------------------------------------------------- flow
func rise() -> void:
	visible = true
	var len := play("rise", 0.0)
	if ap == null:
		position.y -= 16.0
		create_tween().tween_property(self, "position:y", position.y + 16.0, 5.5).set_trans(Tween.TRANS_SINE)
	Sfx.play_at("herald_rise", global_position + Vector3.UP * 6.0, 6.0, 200.0)
	Events.camera_shake.emit(0.6, len)
	await get_tree().create_timer(len, false).timeout
	play("idle", 0.4)

func start_fight() -> void:
	base_yaw = rotation.y
	phase = 1
	_next_attack = 2.0
	_hum = Sfx.emitter("herald_hum", self, 0.0, 120.0)
	_update_bar()
	phase_changed.emit(1)

func _process(delta: float) -> void:
	_t += delta
	if _beam_on:
		_beam_tick -= delta
	if phase < 1 or phase > 3:
		return
	if phase == 2:
		_phase2_t += delta
		if _phase2_t > 35.0 and not _busy:
			_enter_phase3()
			return
	_next_attack -= delta
	if _next_attack <= 0.0 and not _busy:
		_choose_attack()

func _choose_attack() -> void:
	var p: Player = GameMode.player
	if p == null or p.dead:
		_next_attack = 1.0
		return
	_attack_count += 1
	match phase:
		1:
			if _attack_count % 3 == 0:
				_shards(6)
			else:
				_slam()
		2:
			if _summons < 2 and (_attack_count % 4 == 1):
				_summon()
			elif _attack_count % 2 == 0:
				_sweep()
			else:
				_slam()
		3:
			var r := _attack_count % 3
			if r == 0:
				_sweep()
			elif r == 1:
				_slam()
			else:
				_shards(9)

func _gap() -> float:
	var base := 2.6 if phase == 1 else (2.2 if phase == 2 else 1.6)
	return base / difficulty_speed

## v1.6.0 (stage B): the wind-up cues on screen (constants, so a test reads them from the exported build too).
## v1.9.0 (stage G): readable wind-ups. The slam never lands sooner than this after its cue (phase 3 used to cut it to about 1.16 s), and the shard rain waits longer before it lands.
const SLAM_MIN_WINDUP := 1.3
const SHARD_BASE_DELAY := 1.1
const CUE_SLAM := "SLAM: get out of the red ring"
const CUE_SWEEP := "SWEEP: the maw is charging - sidestep or break line of sight"

func _slam() -> void:
	_busy = true
	var p: Player = GameMode.player
	_slam_side = 1 - _slam_side
	var clip := "slam_l" if _slam_side == 0 else "slam_r"
	var len := play(clip, 0.2)
	var hit_t := maxf(SLAM_MIN_WINDUP, clip_event(clip, "hit", 1.33) / (1.15 if phase == 3 else 1.0))
	if ap and phase == 3:
		ap.speed_scale = 1.15
	# target: where the player is now, pulled into reach
	# turn toward the player (within its reach arc), then the palm lands where the JSON says it does
	var to := p.global_position - global_position
	var want_yaw := atan2(-to.x, -to.z)
	var d_yaw := clampf(angle_difference(base_yaw, want_yaw), -0.8, 0.8)
	var tw := create_tween()
	tw.tween_property(self, "rotation:y", base_yaw + d_yaw, 0.35).set_trans(Tween.TRANS_SINE)
	var palm_local := Vector3(-2.79 if clip == "slam_l" else 2.79, 1.06, -11.44)
	var sl: Dictionary = json.get("slam_impacts", {}).get(clip, {})
	if sl.has("palm_mid_godot"):
		var pm: Array = sl["palm_mid_godot"]
		palm_local = Vector3(-float(pm[0]), float(pm[1]), -float(pm[2]))
	var target := (Transform3D(Basis(Vector3.UP, base_yaw + d_yaw), global_position)) * palm_local
	var gq := PhysicsRayQueryParameters3D.create(target + Vector3.UP * 10.0, target + Vector3.DOWN * 20.0, 1)
	var gh := get_world_3d().direct_space_state.intersect_ray(gq)
	if gh:
		target = gh["position"]
	Fx.telegraph(target + Vector3.UP * 0.05, 5.0, hit_t)
	if GameMode.ui and target.distance_to(p.global_position) < 9.0:
		GameMode.ui.toast(CUE_SLAM, hit_t)
	Sfx.play_at("herald_windup", global_position + Vector3.UP * 10.0, 0.0, 150.0)
	await get_tree().create_timer(hit_t, false).timeout
	if phase > 3:
		return
	Sfx.play_at("herald_slam", target, 6.0, 120.0)
	Fx.burst(target + Vector3.UP * 0.3, Color(0.8, 0.5, 1.0), 2.0, 60)
	Events.camera_shake.emit(0.8, 0.6)
	if p and not p.dead and Vector2(p.global_position.x - target.x, p.global_position.z - target.z).length() < 5.0:
		p.health.take_damage(34.0, {"pos": target, "kind": "slam", "source": self})
		var push := p.global_position - target
		push.y = 0.0
		p.velocity += push.normalized() * 8.0 + Vector3.UP * 5.0
	await get_tree().create_timer(maxf(0.2, len - hit_t - 0.4), false).timeout
	if ap:
		ap.speed_scale = 1.0
	create_tween().tween_property(self, "rotation:y", base_yaw, 0.6).set_trans(Tween.TRANS_SINE)
	play("idle", 0.4)
	_busy = false
	_next_attack = _gap()

func _shards(count: int) -> void:
	_busy = true
	var len := play("shard", 0.2)
	var rel := clip_event("shard", "release", 0.8)
	await get_tree().create_timer(rel, false).timeout
	Sfx.play_at("herald_shard", global_position + Vector3.UP * 10.0, 2.0, 150.0)
	var p: Player = GameMode.player
	for i in count:
		if p == null or phase > 3:
			break
		var off := Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)) if i > 0 else Vector3.ZERO
		var spot := p.global_position + off + p.velocity * 0.6 * (1.0 if i == 0 else 0.0)
		_drop_shard(spot, SHARD_BASE_DELAY + i * 0.12)
	await get_tree().create_timer(maxf(0.2, len - rel), false).timeout
	play("idle", 0.4)
	_busy = false
	_next_attack = _gap()

func _drop_shard(spot: Vector3, delay: float) -> void:
	var q := PhysicsRayQueryParameters3D.create(spot + Vector3.UP * 20.0, spot + Vector3.DOWN * 20.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var ground: Vector3 = hit["position"] if hit else spot
	Fx.telegraph(ground + Vector3.UP * 0.05, 1.8, delay, Color(0.8, 0.3, 1.0))
	await get_tree().create_timer(delay, false).timeout
	var s := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.45
	cm.height = 2.6
	s.mesh = cm
	s.material_override = Fx.glow_mat(Color(0.7, 0.35, 1.0), 3.0)
	get_parent().add_child(s)
	s.global_position = ground + Vector3.UP * 14.0
	s.rotation.x = PI
	var tw := create_tween()
	tw.tween_property(s, "global_position", ground + Vector3.UP * 1.0, 0.25).set_ease(Tween.EASE_IN)
	await tw.finished
	Sfx.play_at("shard_impact", ground, 0.0, 50.0)
	Fx.burst(ground + Vector3.UP * 0.3, Color(0.75, 0.4, 1.0), 0.8, 20)
	var p: Player = GameMode.player
	if p and not p.dead and p.global_position.distance_to(ground) < 1.9:
		p.health.take_damage(16.0, {"pos": ground, "kind": "shard", "source": self})
	await get_tree().create_timer(1.2, false).timeout
	if is_instance_valid(s):
		s.queue_free()

func _summon() -> void:
	_busy = true
	_summons += 1
	var len := play("summon", 0.2)
	Sfx.play_at("herald_roar", global_position + Vector3.UP * 10.0, 4.0, 200.0)
	await get_tree().create_timer(len * 0.5, false).timeout
	var area: Node = GameMode.area
	var picks := vents.duplicate()
	picks.shuffle()
	for i in mini(2 + (1 if phase == 3 else 0), picks.size()):
		var v: Vector3 = picks[i]
		Fx.burst(v + Vector3.UP, Color(0.8, 0.4, 1.0), 1.2, 40)
		Sfx.play_at("crystal_spawn", v, 2.0, 60.0)
		if area and area.has_method("enemy"):
			area.enemy("stalker", "herald_summon_%d_%d" % [_summons, i], v, 0.0, {"alerted": true})
	await get_tree().create_timer(len * 0.5, false).timeout
	play("idle", 0.4)
	_busy = false
	_next_attack = _gap()

func _sweep() -> void:
	_busy = true
	var len := play("sweep", 0.2)
	var s0 := clip_event("sweep", "sweep_start", 0.9)
	var s1 := clip_event("sweep", "sweep_end", 3.4)
	Sfx.play_at("herald_charge", global_position + Vector3.UP * 10.0, 2.0, 150.0)
	# telegraph: the maw glows for the wind-up
	beam_light.light_energy = 4.0
	if GameMode.ui:
		GameMode.ui.toast(CUE_SWEEP, s0)
	await get_tree().create_timer(s0, false).timeout
	if phase > 3:
		return
	var loop := Sfx.emitter("herald_beam", self, 4.0, 150.0)
	_beam_on = true
	beam_mesh.visible = true
	var p: Player = GameMode.player
	var to_p := (p.global_position - global_position) if p else Vector3(-1, 0, 0)
	to_p.y = 0.0
	var mid_ang := atan2(to_p.z, to_p.x)
	var dur := (s1 - s0)
	var t := 0.0
	while t < dur and phase <= 3:
		var k := t / dur
		var ang := mid_ang + lerpf(1.0, -1.0, k)
		var dist := clampf(to_p.length(), 8.0, 26.0)
		var gp := global_position + Vector3(cos(ang), 0, sin(ang)) * dist
		gp.y = (p.global_position.y if p else 0.0) + 1.1
		_beam_from = _bone_pos("beam", Vector3(0, 11.0, 2.5))
		_beam_to = _beam_from + (gp - _beam_from).normalized() * 60.0
		_beam_visual()
		_beam_damage(p)
		await get_tree().process_frame
		t += get_process_delta_time()
	_beam_on = false
	beam_mesh.visible = false
	beam_light.light_energy = 0.0
	if loop:
		loop.queue_free()
	await get_tree().create_timer(maxf(0.2, len - s1), false).timeout
	play("idle", 0.4)
	_busy = false
	_next_attack = _gap()

func _beam_visual() -> void:
	# clip the beam at the first world hit
	var q := PhysicsRayQueryParameters3D.create(_beam_from, _beam_to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = hit["position"] if hit else _beam_to
	var mid := (_beam_from + end) * 0.5
	var len := _beam_from.distance_to(end)
	beam_mesh.global_position = mid
	beam_mesh.scale = Vector3(1, len, 1)
	var dir := (end - _beam_from).normalized()
	beam_mesh.global_basis = Basis(Quaternion(Vector3.UP, dir))
	beam_light.global_position = end + Vector3.UP * 0.5
	beam_light.light_energy = 5.0
	if hit and randf() < 0.3:
		Fx.impact(end, hit["normal"], "crystal", 1.5)

func _beam_damage(p: Player) -> void:
	if p == null or p.dead or _beam_tick > 0.0:
		return
	var c := p.chest() if not p.crouching else p.global_position + Vector3.UP * 0.7
	var seg := _beam_to - _beam_from
	var tt := clampf((c - _beam_from).dot(seg) / seg.length_squared(), 0.0, 1.0)
	var closest := _beam_from + seg * tt
	if closest.distance_to(c) > 1.1:
		return
	# cover blocks the beam
	var q := PhysicsRayQueryParameters3D.create(_beam_from, c, 1)
	q.exclude = [p.get_rid()]
	if get_world_3d().direct_space_state.intersect_ray(q):
		return
	_beam_tick = 0.25
	p.health.take_damage(9.0, {"pos": _beam_from, "kind": "beam", "source": self})

# ---------------------------------------------------------------- damage
func node_hit(id: String, dmg: float) -> bool:
	var n: Dictionary = nodes[id]
	if not n["alive"] or phase < 1 or phase > 3:
		return false
	if (n["shape"] as CollisionShape3D).disabled:
		return false
	n["hp"] = float(n["hp"]) - dmg
	(n["light"] as OmniLight3D).light_energy = 8.0
	get_tree().create_timer(0.08, false).timeout.connect(func():
		if n["alive"] and is_instance_valid(n["light"]):
			(n["light"] as OmniLight3D).light_energy = 3.0)
	_update_bar()
	if float(n["hp"]) <= 0.0:
		_break_node(id)
		return true
	return false

func _break_node(id: String) -> void:
	var n: Dictionary = nodes[id]
	n["alive"] = false
	(n["shape"] as CollisionShape3D).disabled = true
	(n["light"] as OmniLight3D).light_energy = 0.0
	if n["mesh"]:
		(n["mesh"] as Node3D).visible = false
	var a: Area3D = n["area"]
	Fx.burst(a.global_position, Color(0.3, 0.9, 1.0), 2.5, 70)
	Sfx.play_at("node_break", a.global_position, 6.0, 200.0)
	Events.camera_shake.emit(0.5, 0.6)
	Game.state["stats"]["kills"] += 0
	if id == "node_c":
		_die()
		return
	_busy = true
	play("stagger", 0.15)
	await get_tree().create_timer(1.5, false).timeout
	_busy = false
	if not nodes["node_l"]["alive"] and not nodes["node_r"]["alive"] and phase == 1:
		_enter_phase2()
	else:
		play("idle", 0.3)
		_next_attack = 1.0

func _enter_phase2() -> void:
	phase = 2
	_phase2_t = 0.0
	_busy = true
	var len := play("roar", 0.2)
	Sfx.play_at("herald_roar", global_position + Vector3.UP * 10.0, 8.0, 250.0)
	Events.camera_shake.emit(0.7, len)
	phase_changed.emit(2)
	await get_tree().create_timer(len, false).timeout
	play("idle", 0.3)
	_busy = false
	_attack_count = 0
	_next_attack = 0.5

func _enter_phase3() -> void:
	phase = 3
	_busy = true
	var len := play("roar", 0.2)
	Sfx.play_at("herald_roar", global_position + Vector3.UP * 10.0, 8.0, 250.0)
	_set_node_open("node_c", true)
	phase_changed.emit(3)
	_update_bar()
	await get_tree().create_timer(len, false).timeout
	play("idle", 0.3)
	_busy = false
	_next_attack = 1.0

func _update_bar() -> void:
	var total := 0.0
	var mx := 0.0
	for id in nodes.keys():
		total += maxf(0.0, float(nodes[id]["hp"]))
		mx += float(nodes[id]["max"])
	Events.boss_health.emit("THE HERALD", total / mx, phase >= 1 and phase <= 3)

func _die() -> void:
	phase = 4
	_beam_on = false
	beam_mesh.visible = false
	Events.boss_health.emit("THE HERALD", 0.0, false)
	if _hum:
		_hum.queue_free()
	var len := play("death", 0.2)
	Sfx.play_at("herald_death", global_position + Vector3.UP * 8.0, 8.0, 300.0)
	Events.camera_shake.emit(0.9, 3.0)
	for e in get_tree().get_nodes_in_group("enemy"):
		if e is EnemyBase and not (e as EnemyBase).dead:
			(e as EnemyBase).health.take_damage(9999.0, {"kind": "boss_death"})
	defeated.emit()
	await get_tree().create_timer(len, false).timeout
	if ap == null:
		create_tween().tween_property(self, "position:y", position.y - 20.0, 4.0)
