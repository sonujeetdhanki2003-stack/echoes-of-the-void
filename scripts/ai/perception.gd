class_name Perception
extends Node
## AI Perception (PRD "AI Perception"): sight (range, field-of-view cone, line of sight) and hearing
## (Events.noise). Builds awareness over time; full awareness alerts the owner.

signal spotted(player: Player)
signal heard(pos: Vector3, loud: bool)

var owner_enemy: Node3D
var sight_range := 28.0
var fov_deg := 120.0
var hearing := 1.0
var eye_height := 1.5
var awareness := 0.0
var can_see := false
var last_seen := Vector3.ZERO
var last_seen_t := -100.0
var _t := 0.0
var enabled := true

func setup(e: Node3D, d: EnemyData, eye: float) -> void:
	owner_enemy = e
	sight_range = d.sight_range
	fov_deg = d.sight_fov
	hearing = d.hearing
	eye_height = eye
	_t = randf() * 0.2
	Events.noise.connect(_on_noise)

func eye() -> Vector3:
	return owner_enemy.global_position + Vector3.UP * eye_height

func now() -> float:
	# game time (physics frames), so pauses, slow-motion and fixed-fps test runs all count the same
	return float(Engine.get_physics_frames()) / float(Engine.physics_ticks_per_second)

func seconds_since_seen() -> float:
	return now() - last_seen_t

func update(delta: float, alerted: bool) -> void:
	if not enabled:
		return
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.15
	var p: Player = GameMode.player
	if p == null or p.dead or not is_instance_valid(p):
		can_see = false
		return
	var to := p.chest() - eye()
	var d := to.length()
	can_see = false
	if d <= sight_range * (1.25 if alerted else 1.0):
		var fwd := -owner_enemy.global_transform.basis.z
		var ang := rad_to_deg(fwd.angle_to(Vector3(to.x, 0, to.z).normalized()))
		var in_cone := ang <= fov_deg * 0.5 or d < 3.0 or alerted
		if in_cone and _los(eye(), p.chest(), p):
			can_see = true
			last_seen = p.global_position
			last_seen_t = now()
			if not alerted:
				# closer, lit, moving and standing players are noticed faster; crouching helps stealth
				var rate := lerpf(3.5, 0.6, clampf(d / sight_range, 0.0, 1.0))
				if p.crouching:
					rate *= 0.55
				if p.lamp_on:
					rate *= 1.35
				awareness += rate * 0.15
				if awareness >= 1.0:
					spotted.emit(p)
	if not can_see and not alerted:
		awareness = maxf(0.0, awareness - 0.06)

func _los(from: Vector3, to: Vector3, p: Player) -> bool:
	var q := PhysicsRayQueryParameters3D.create(from, to, 1)
	q.exclude = [owner_enemy.get_rid(), p.get_rid()]
	return owner_enemy.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

func has_los_to(pos: Vector3) -> bool:
	var p: Player = GameMode.player
	if p == null:
		return false
	return _los(pos, p.chest(), p)

func _on_noise(pos: Vector3, radius: float, source: Node) -> void:
	if not enabled or not is_instance_valid(owner_enemy) or source == owner_enemy:
		return
	var d := owner_enemy.global_position.distance_to(pos)
	var r := radius * hearing
	if d > r:
		return
	var loud := radius >= 20.0 and d < r * 0.65
	heard.emit(pos, loud)
