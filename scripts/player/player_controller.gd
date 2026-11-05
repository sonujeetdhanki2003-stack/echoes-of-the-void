class_name PlayerController
extends Node
## PRD BP_EOT_PlayerController: input and the third-person camera (spring arm with collision,
## over-the-shoulder aim, recoil, shake). Touch controls and gamepads feed the same entry points.

const ARM_LEN := 3.1
const ARM_AIM := 1.25
const ARM_CROUCH := 2.6
const SHOULDER := 0.62
const PIVOT_H := 1.58
const PIVOT_H_CROUCH := 1.12
const PITCH_MIN := -68.0
const PITCH_MAX := 62.0

var player: Player
var rig: Node3D
var pitch_node: Node3D
var arm: SpringArm3D
var cam: Camera3D
var yaw := 0.0
var pitch := -8.0
var aim_held := false
var fire_held := false
var aim_toggle := false       # touch: aim is a toggle
var shoulder_side := 1.0
var _shoulder := 1.0
var _recoil := Vector2.ZERO
var _recoil_target := Vector2.ZERO
var _trauma := 0.0
var _shake_t := 0.0
var _noise := FastNoiseLite.new()
var _aim_blend := 0.0
var _pivot_h := PIVOT_H
var enabled := true
var sprint_toggle := false

func setup(p: Player) -> void:
	player = p
	rig = Node3D.new()
	rig.name = "CameraPivot"
	rig.top_level = true
	p.add_child.call_deferred(rig)
	pitch_node = Node3D.new()
	pitch_node.name = "Pitch"
	rig.add_child(pitch_node)
	arm = SpringArm3D.new()
	arm.name = "SpringArm3D"
	arm.spring_length = ARM_LEN
	arm.margin = 0.12
	var sph := SphereShape3D.new()
	sph.radius = 0.22
	arm.shape = sph
	arm.collision_mask = 1
	pitch_node.add_child(arm)
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.fov = float(Game.settings["fov"])
	cam.near = 0.06
	cam.far = 400.0
	arm.add_child(cam)
	_side_shape = SphereShape3D.new()
	_side_shape.radius = 0.3
	_make_character_lights()
	_noise.frequency = 2.2
	Events.camera_shake.connect(shake)

func _ready() -> void:
	await get_tree().process_frame
	if is_instance_valid(player):
		arm.add_excluded_object(player.get_rid())
		rig.global_position = player.global_position + Vector3.UP * PIVOT_H

func yaw_basis() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(yaw))

func snap_to(y: float) -> void:
	yaw = rad_to_deg(y)
	pitch = -8.0
	if rig and is_instance_valid(player) and rig.is_inside_tree() and player.is_inside_tree():
		rig.global_position = player.global_position + Vector3.UP * _pivot_h
		rig.reset_physics_interpolation()

func make_current() -> void:
	cam.make_current()

## Look input in degrees (mouse/touch deltas are scaled by the caller).
func look(d: Vector2) -> void:
	if not enabled or player.locked:
		return
	var inv := -1.0 if Game.settings["invert_y"] else 1.0
	yaw -= d.x
	pitch = clampf(pitch - d.y * inv, PITCH_MIN, PITCH_MAX)

func add_recoil(p: float, y: float) -> void:
	_recoil_target += Vector2(p, y)

func shake(strength: float, secs: float) -> void:
	_trauma = clampf(maxf(_trauma, strength), 0.0, 1.0)
	_shake_t = maxf(_shake_t, secs)

## Camera distance (Doc 03 Phase 3): Ctrl + mouse wheel, PageUp/PageDown, trackpad or touch pinch, or the
## Settings slider; the SpringArm3D length scales between 0.7x and 1.5x and the choice persists with the settings.
func zoom_camera(delta_mult: float) -> void:
	var v := clampf(float(Game.settings.get("cam_distance", 1.0)) + delta_mult, 0.7, 1.5)
	Game.settings["cam_distance"] = v
	_zoom_save_t = 1.0

var _zoom_save_t := 0.0

func _unhandled_input(event: InputEvent) -> void:
	if not enabled or not is_instance_valid(player) or GameMode.ui_blocking():
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).ctrl_pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_camera(-0.06 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else 0.06)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventMagnifyGesture:
		zoom_camera((1.0 - (event as InputEventMagnifyGesture).factor) * 0.8)
		return
	if event.is_action_pressed("cam_closer"):
		zoom_camera(-0.1)
		return
	if event.is_action_pressed("cam_farther"):
		zoom_camera(0.1)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := event as InputEventMouseMotion
		var s := 0.085 * float(Game.settings["sensitivity"]) * (0.6 if aim_held else 1.0)
		look(m.relative * s)
		return
	if player.locked:
		return
	if event.is_action_pressed("jump"):
		player.request_jump()
	elif event.is_action_pressed("crouch"):
		player.set_crouch(not player.crouching)
	elif event.is_action_pressed("interact"):
		player.interaction.interact()
	elif event.is_action_pressed("reload"):
		player.combat.reload()
	elif event.is_action_pressed("weapon_1"):
		player.combat.equip("pistol")
	elif event.is_action_pressed("weapon_2"):
		player.combat.equip("rifle")
	elif event.is_action_pressed("weapon_3") and player.inventory.has_weapon("shotgun"):
		player.combat.equip("shotgun")
	elif event.is_action_pressed("weapon_4") and player.inventory.has_weapon("precision"):
		player.combat.equip("precision")
	elif event.is_action_pressed("weapon_5") and player.inventory.has_weapon("breach"):
		player.combat.equip("breach")
	elif event.is_action_pressed("weapon_next") or event.is_action_pressed("weapon_prev"):
		player.combat.cycle()
	elif event.is_action_pressed("melee"):
		player.try_melee()
	elif event.is_action_pressed("medkit"):
		player.use_medkit()
	elif event.is_action_pressed("lamp"):
		player.toggle_lamp()
	elif event.is_action_pressed("shoulder_swap"):
		shoulder_side = -shoulder_side

func _process(delta: float) -> void:
	if not is_instance_valid(player) or rig == null:
		return
	var blocked := GameMode.ui_blocking() or player.locked or not enabled
	if not blocked:
		# held inputs (keyboard/mouse/gamepad; touch writes touch_move and the toggles)
		var mv := Input.get_vector("move_left", "move_right", "move_back", "move_forward")
		if player.touch_move.length() > 0.01:
			mv = player.touch_move
		player.move_input = mv
		player.wish_sprint = Input.is_action_pressed("sprint") or sprint_toggle
		if sprint_toggle and mv.length() < 0.2:
			sprint_toggle = false
		aim_held = Input.is_action_pressed("aim") or aim_toggle
		fire_held = Input.is_action_pressed("fire") or player.combat.touch_fire
		var look_v := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		if look_v.length() > 0.0:
			look(look_v * 160.0 * delta * float(Game.settings["sensitivity"]) * (0.55 if aim_held else 1.0))
	else:
		player.move_input = Vector2.ZERO
		aim_held = false
		fire_held = false
	if _zoom_save_t > 0.0:
		_zoom_save_t -= delta
		if _zoom_save_t <= 0.0:
			Game.save_settings()
	# recoil: kick toward the target quickly, then recover
	_recoil = _recoil.lerp(_recoil_target, 1.0 - exp(-28.0 * delta))
	_recoil_target = _recoil_target.lerp(Vector2.ZERO, 1.0 - exp(-7.0 * delta))
	# follow the player's interpolated position
	var p_xf := player.get_global_transform_interpolated()
	var want_h := PIVOT_H_CROUCH if player.crouching else PIVOT_H
	_pivot_h = lerpf(_pivot_h, want_h, 1.0 - exp(-10.0 * delta))
	var target := p_xf.origin + Vector3.UP * _pivot_h
	rig.global_position = rig.global_position.lerp(target, 1.0 - exp(-22.0 * delta))
	var aiming := player.aiming
	_aim_blend = lerpf(_aim_blend, 1.0 if aiming else 0.0, 1.0 - exp(-14.0 * delta))
	_shoulder = lerpf(_shoulder, shoulder_side, 1.0 - exp(-10.0 * delta))
	var len_base := (ARM_CROUCH if player.crouching else ARM_LEN) * float(Game.settings.get("cam_distance", 1.0))
	arm.spring_length = lerpf(len_base, ARM_AIM, _aim_blend)
	var side_x := SHOULDER * _shoulder * lerpf(0.85, 1.0, _aim_blend)
	# v1.0.1: the over-the-shoulder offset is checked against the walls too. Standing within ~0.85 m of a wall on the
	# camera side used to put the arm's start point inside the wall: the spring arm then found nothing to hit and the
	# camera ended up outside the room.
	var lim := _side_limit(side_x)
	_side_free = minf(lim, _side_free + 4.0 * delta) if lim >= _side_free else lim
	if absf(side_x) > _side_free:
		side_x = signf(side_x) * _side_free
	arm.position = Vector3(side_x, lerpf(0.0, 0.08, _aim_blend), 0.0)
	# shake
	var shake_off := Vector2.ZERO
	if _shake_t > 0.0:
		_shake_t -= delta
		var amt := _trauma * _trauma * float(Game.settings["camera_shake"]) * (0.25 if Feedback.reduce_motion() else 1.0)
		var tt := Time.get_ticks_msec() * 0.001
		shake_off = Vector2(_noise.get_noise_2d(tt * 40.0, 0.0), _noise.get_noise_2d(0.0, tt * 40.0)) * 3.5 * amt
		if _shake_t <= 0.0:
			_trauma = 0.0
	rig.rotation_degrees = Vector3(0.0, yaw + _recoil.y + shake_off.x, 0.0)
	pitch_node.rotation_degrees = Vector3(pitch + _recoil.x + shake_off.y, 0.0, 0.0)
	# field of view
	var base_fov := float(Game.settings["fov"])
	var want_fov := base_fov
	if aiming:
		want_fov = player.combat.aim_fov(base_fov)
	elif player.sprinting:
		want_fov = base_fov + 6.0
	cam.fov = lerpf(cam.fov, want_fov, 1.0 - exp(-10.0 * delta))
	# keep the helmet lamp pointing where the camera looks
	if player.lamp:
		var hp := player.head() + player.forward() * 0.2
		player.lamp.global_position = hp
		var aim_pt := aim_point(30.0)
		if hp.distance_to(aim_pt) > 0.5:
			player.lamp.look_at(aim_pt, Vector3.UP)

## The ray through the crosshair: origin at the camera, pushed past the player so walls behind the camera
## don't eat shots.
var _side_free := SHOULDER
var _side_shape: SphereShape3D

## How far the camera arm may sit to the side of the pivot before it would enter a wall (metres, >= 0).
func _side_limit(want: float) -> float:
	if absf(want) < 0.01 or not rig.is_inside_tree():
		return SHOULDER
	var side: Vector3 = rig.global_transform.basis.x * signf(want)
	var from := rig.global_position
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _side_shape
	q.transform = Transform3D(Basis(), from)
	q.motion = side * SHOULDER
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	var space := player.get_world_3d().direct_space_state
	var r := space.cast_motion(q)
	var lim := SHOULDER if r.size() < 2 else SHOULDER * float(r[0])
	# concave level collision lets a sweep start "inside" a wall without a hit: also test where the arm would start
	var oq := PhysicsShapeQueryParameters3D.new()
	oq.shape = _side_shape
	oq.collision_mask = 1
	oq.exclude = [player.get_rid()]
	for k in 5:
		oq.transform = Transform3D(Basis(), from + side * minf(lim, absf(want)))
		if space.intersect_shape(oq, 1).is_empty():
			break
		lim = maxf(0.0, lim - SHOULDER * 0.25)
	return lim

func aim_ray() -> Array:
	var o := cam.global_position
	var d := -cam.global_transform.basis.z
	var push := maxf(0.0, (player.chest() - o).dot(d))
	return [o + d * push, d]

func aim_point(dist: float) -> Vector3:
	var r := aim_ray()
	var q := PhysicsRayQueryParameters3D.create(r[0], r[0] + r[1] * dist, 1 | 4)
	q.exclude = [player.get_rid()]
	var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
	return hit["position"] if hit else r[0] + r[1] * dist


## Character lights (M2 lighting pass): a soft key from the camera side and a rim from behind/above that only
## light the astronaut and the weapon (visual layer 2), so Kabir reads clearly in dark rooms without flattening
## the set lighting. Cheap: no shadows, small ranges.
var fill_light: OmniLight3D
var rim_light: OmniLight3D

func _make_character_lights() -> void:
	fill_light = OmniLight3D.new()
	fill_light.name = "CharFill"
	fill_light.light_color = Color(0.92, 0.95, 1.0)
	fill_light.light_energy = 0.55
	fill_light.omni_range = 7.0
	fill_light.omni_attenuation = 1.2
	fill_light.light_cull_mask = 2
	fill_light.light_specular = 0.25
	fill_light.position = Vector3(-0.6, 0.5, 0.2)
	cam.add_child(fill_light)
	rim_light = OmniLight3D.new()
	rim_light.name = "CharRim"
	rim_light.light_color = Color(0.6, 0.85, 1.0)
	rim_light.light_energy = 1.4
	rim_light.omni_range = 3.2
	rim_light.omni_attenuation = 1.4
	rim_light.light_cull_mask = 2
	rim_light.light_specular = 0.9
	player.add_child(rim_light)
	rim_light.position = Vector3(0.0, 2.3, 1.1)

## Area tint for the rim (called by the area on enter): the rim picks up the room's key colour.
func set_rim_tint(c: Color, energy: float = 1.4) -> void:
	if rim_light:
		rim_light.light_color = c.lerp(Color.WHITE, 0.35)
		rim_light.light_energy = energy
