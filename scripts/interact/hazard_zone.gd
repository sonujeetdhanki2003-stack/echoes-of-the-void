class_name HazardZone
extends Area3D
## Environmental hazard (Post-PRD Roadmap Ph6 "Level 4: environmental hazards", Doc 03 Ph8): a ruptured steam vent
## or a torn power cable on a visible, audible cycle — IDLE -> WARN (hiss / crackle, amber light) -> ACTIVE (a
## jet of steam or arcing sparks; damage while the player stands inside). Hazards sit BESIDE the route, so they
## punish carelessness in a fight but never block progress. Enemies are not affected (mask = player only).

@export var kind := "steam"          # "steam" | "arc"
@export var size := Vector3(2.2, 2.6, 2.2)
@export var idle_secs := 2.8
@export var warn_secs := 0.9
@export var active_secs := 1.7
@export var dps := 14.0
@export var phase_offset := 0.0

var hits := 0                        # damage ticks dealt (tests)
var state := 0                       # 0 idle, 1 warn, 2 active
var _t := 0.0
var _tick := 0.0
var _inside: Player = null
var _light: OmniLight3D
var _jet: CPUParticles3D
var _warn: CPUParticles3D

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	add_to_group("hazard")
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position.y = size.y * 0.5
	add_child(cs)
	body_entered.connect(func(b): if b is Player: _inside = b)
	body_exited.connect(func(b): if b == _inside: _inside = null)
	var steam := kind == "steam"
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.15) if steam else Color(0.55, 0.8, 1.0)
	_light.light_energy = 0.0
	_light.omni_range = 5.0
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.6 if steam else 1.6, 0)
	add_child(_light)
	_jet = _particles(steam, false)
	_warn = _particles(steam, true)
	_t = fmod(phase_offset, idle_secs + warn_secs + active_secs)

func _particles(steam: bool, warn: bool) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.local_coords = false
	var q := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = Fx._smoke_tex() if steam else Fx._flash_tex()
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if not steam:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	p.mesh = q
	var grad := Gradient.new()
	if steam:
		p.amount = maxi(8, int((14 if warn else 70) * Fx.particle_scale))
		p.lifetime = 0.8 if warn else 1.3
		p.direction = Vector3.UP
		p.spread = 25.0 if warn else 9.0
		p.initial_velocity_min = 0.6 if warn else 5.5
		p.initial_velocity_max = 1.2 if warn else 8.0
		p.gravity = Vector3(0, 0.6, 0)
		p.damping_min = 1.5
		p.damping_max = 2.5
		p.scale_amount_min = 0.25 if warn else 0.45
		p.scale_amount_max = 0.5 if warn else 1.1
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.4))
		sc.add_point(Vector2(1, 2.4))
		p.scale_amount_curve = sc
		grad.set_color(0, Color(0.85, 0.88, 0.9, 0.0))
		grad.add_point(0.15, Color(0.85, 0.88, 0.9, 0.3 if warn else 0.42))
		grad.set_color(grad.get_point_count() - 1, Color(0.8, 0.82, 0.85, 0.0))
		p.position = Vector3(0, 0.08, 0)
	else:
		p.amount = maxi(8, int((10 if warn else 60) * Fx.particle_scale))
		p.lifetime = 0.45
		p.explosiveness = 0.3 if warn else 0.15
		p.direction = Vector3(0, -0.3, 0)
		p.spread = 180.0
		p.initial_velocity_min = 1.5
		p.initial_velocity_max = 3.5 if warn else 6.5
		p.gravity = Vector3(0, -9.0, 0)
		p.scale_amount_min = 0.03
		p.scale_amount_max = 0.05 if warn else 0.08
		grad.set_color(0, Color(0.85, 0.95, 1.0, 1.0))
		grad.set_color(1, Color(0.3, 0.6, 1.0, 0.0))
		p.position = Vector3(0, 1.6, 0)
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		p.emission_sphere_radius = 0.5 if not warn else 0.25
	p.color_ramp = grad
	add_child(p)
	return p

func _physics_process(delta: float) -> void:
	_t += delta
	var cycle := idle_secs + warn_secs + active_secs
	var ph := fmod(_t, cycle)
	var s := 0 if ph < idle_secs else (1 if ph < idle_secs + warn_secs else 2)
	if s != state:
		state = s
		_enter(s)
	if state == 1:
		_light.light_energy = 0.6 + 0.6 * absf(sin(_t * 18.0))
	elif state == 2:
		_light.light_energy = (2.2 + 1.8 * randf()) if kind == "arc" else 1.4
		if _inside and is_instance_valid(_inside) and not _inside.dead:
			_tick -= delta
			if _tick <= 0.0:
				_tick = 0.5
				hits += 1
				_inside.health.take_damage(dps * 0.5, {"kind": "hazard", "pos": global_position})
	else:
		_light.light_energy = move_toward(_light.light_energy, 0.0, delta * 4.0)

func _enter(s: int) -> void:
	_warn.emitting = s == 1
	_jet.emitting = s == 2
	if s == 1:
		Sfx.play_at("steam_hiss" if kind == "steam" else "sparks_2", global_position + Vector3.UP, -8.0, 16.0, 1.3)
	elif s == 2:
		_tick = 0.0
		Sfx.play_at("vent_burst" if kind == "steam" else "sparks_1", global_position + Vector3.UP, -2.0, 22.0)
