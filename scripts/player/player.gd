class_name Player
extends CharacterBody3D
## PRD BP_EOT_PlayerCharacter: movement and character state only. Input and the camera live in
## PlayerController; health, weapons, interaction and inventory are child components.

signal died
signal landed(speed: float)

const WALK := 1.9
const RUN := 4.1
const SPRINT := 6.3
const CROUCH := 1.6
const AIM_MOVE := 2.3
const ACCEL := 9.0
const DECEL := 12.0
const AIR_CONTROL := 0.35
const JUMP_V := 5.2
const GRAVITY := 14.5
const STAND_H := 1.8
const CROUCH_H := 1.15
const RADIUS := 0.36

var health: HealthComponent
var inventory: InventoryComponent
var combat: CombatComponent
var interaction: InteractionComponent
var controller: PlayerController
var anim: PlayerAnim
var model_root: Node3D
var shape: CollisionShape3D
var capsule: CapsuleShape3D

var stamina := 100.0
var exhausted := false
var _stamina_delay := 0.0
var crouching := false
var sprinting := false
var aiming := false
var move_input := Vector2.ZERO        # set by the controller (x = right, y = forward)
var wish_sprint := false
var locked := false                   # cinematics, puzzles, menus
var dead := false
var _coyote := 0.0
var _jump_buffer := 0.0
var _was_on_floor := true
var _fall_speed := 0.0
var _face_yaw := 0.0
var _strafe_timer := 0.0              # face the camera for a moment after shooting
var lamp: SpotLight3D
var lamp_on := false
var _step_t := 0.0
var touch_move := Vector2.ZERO
var ground_kind := "metal"
var hit_flinch := 0.0
var _safe_pos := Vector3.ZERO         # last place the player stood on solid ground (out-of-world recovery)
var _safe_t := 0.0
var _has_safe := false
const FALL_LIMIT := 40.0
signal recovered_from_fall

func _init() -> void:
	name = "Player"
	collision_layer = 2
	collision_mask = 1 | 4 | 64
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(48.0)
	add_to_group("player")
	add_to_group("actor")

func _ready() -> void:
	capsule = CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = STAND_H
	shape = CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	shape.shape = capsule
	shape.position.y = STAND_H * 0.5
	add_child(shape)
	model_root = Node3D.new()
	model_root.name = "VisualRoot"
	add_child(model_root)
	health = HealthComponent.new()
	health.name = "Health"
	add_child(health)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	inventory = InventoryComponent.new()
	inventory.name = "Inventory"
	add_child(inventory)
	anim = PlayerAnim.new()
	anim.name = "Anim"
	add_child(anim)
	anim.setup(self)
	combat = CombatComponent.new()
	combat.name = "Combat"
	add_child(combat)
	interaction = InteractionComponent.new()
	interaction.name = "Interaction"
	add_child(interaction)
	controller = PlayerController.new()
	controller.name = "Controller"
	add_child(controller)
	controller.setup(self)
	combat.setup(self)
	interaction.setup(self)
	lamp = SpotLight3D.new()
	lamp.name = "HelmetLamp"
	lamp.light_color = Color(0.85, 0.93, 1.0)
	lamp.light_energy = 3.0
	lamp.spot_range = 24.0
	lamp.spot_angle = 32.0
	lamp.spot_attenuation = 0.8
	lamp.shadow_enabled = true
	lamp.visible = false
	add_child(lamp)
	health.dmg_mult = Game.diff("dmg_taken")

func chest() -> Vector3:
	return global_position + Vector3.UP * (0.85 if crouching else 1.3)

func head() -> Vector3:
	return global_position + Vector3.UP * (1.05 if crouching else 1.62)

func forward() -> Vector3:
	return -global_transform.basis.z

# ---------------------------------------------------------------- state io (save/load)
func apply_state(p: Dictionary) -> void:
	health.setup(float(p.get("max_hp", 100.0)), float(p.get("hp", 100.0)))
	stamina = float(p.get("stamina", 100.0))
	inventory.from_dict({"weapons": p.get("weapons", []), "reserve": p.get("reserve", {}), "medkits": p.get("medkits", 0), "keycards": p.get("keycards", []), "parts": p.get("parts", 0)})
	combat.restore(p.get("mag", {}), str(p.get("equipped", "")))
	set_lamp(bool(p.get("lamp", false)))

func snapshot() -> Dictionary:
	var inv := inventory.to_dict()
	return {
		"hp": health.hp, "max_hp": health.max_hp, "stamina": stamina, "medkits": inv["medkits"],
		"weapons": inv["weapons"], "equipped": combat.current_id(), "mag": combat.mags(),
		"reserve": inv["reserve"], "keycards": inv["keycards"], "lamp": lamp_on, "parts": inv["parts"],
	}

# ---------------------------------------------------------------- movement
var melee_cd := 0.0                    # v1.6.0: seconds until the next melee swing

func try_melee() -> bool:
	if dead or locked or melee_cd > 0.0:
		return false
	melee_cd = Melee.COOLDOWN
	anim.melee()
	Sfx.play("melee_swing", -4.0, randf_range(0.95, 1.05))
	var r := Melee.swing(self)
	if r == "":
		Sfx.play("brute_swipe", -8.0)
		return false
	return true

func _physics_process(delta: float) -> void:
	melee_cd = maxf(0.0, melee_cd - delta)
	if dead:
		velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECEL * delta)
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	var on_floor := is_on_floor()
	# v1.0.1: out-of-world recovery. A physics glitch or an unlucky jump must never end the run in a bottomless fall.
	if on_floor and not locked:
		_safe_t -= delta
		if _safe_t <= 0.0:
			_safe_t = 0.4
			_safe_pos = global_position
			_has_safe = true
	if (_has_safe and global_position.y < _safe_pos.y - FALL_LIMIT) or global_position.y < -300.0:
		recover_from_fall()
		return
	if on_floor:
		_coyote = 0.12
	else:
		_coyote -= delta
	_jump_buffer -= delta
	hit_flinch = maxf(0.0, hit_flinch - delta)

	var mv := move_input if not locked else Vector2.ZERO
	if mv.length() > 1.0:
		mv = mv.normalized()
	aiming = controller.aim_held and not locked and combat.has_weapon_out()
	var want_sprint := wish_sprint and mv.y > 0.3 and not aiming and not crouching and not exhausted and on_floor and not combat.reloading_blocks_sprint()
	sprinting = want_sprint and mv.length() > 0.5
	var speed := RUN
	if crouching:
		speed = CROUCH
	elif aiming:
		speed = AIM_MOVE
	elif sprinting:
		speed = SPRINT
	if hit_flinch > 0.0:
		speed *= 0.6
	var analog := mv.length()
	var cam_basis := controller.yaw_basis()
	var wish := (cam_basis * Vector3(mv.x, 0.0, -mv.y))
	wish.y = 0.0
	var target := wish.normalized() * speed * clampf(analog, 0.0, 1.0) if analog > 0.05 else Vector3.ZERO
	var hv := Vector3(velocity.x, 0.0, velocity.z)
	var k := (ACCEL if target.length() > hv.length() else DECEL) * (1.0 if on_floor else AIR_CONTROL)
	hv = hv.lerp(target, 1.0 - exp(-k * delta))
	if hv.distance_to(target) < 0.02:
		hv = target
	velocity.x = hv.x
	velocity.z = hv.z
	if not on_floor:
		velocity.y -= GRAVITY * delta
		_fall_speed = maxf(_fall_speed, -velocity.y)
	# jump (buffered, with coyote time)
	if _jump_buffer > 0.0 and _coyote > 0.0 and not crouching and stamina >= 8.0:
		velocity.y = JUMP_V
		_coyote = 0.0
		_jump_buffer = 0.0
		_drain(10.0)
		anim.jump()
		Sfx.play("jump", -10.0)
	move_and_slide()
	var now_floor := is_on_floor()
	if now_floor and not _was_on_floor:
		if _fall_speed > 3.0:
			anim.land(_fall_speed)
			Sfx.play_at("land", global_position, -6.0 + minf(6.0, _fall_speed))
			Events.emit_noise(global_position, 6.0, self)
			if _fall_speed > 14.0:
				health.take_damage((_fall_speed - 14.0) * 6.0, {"kind": "fall"})
		landed.emit(_fall_speed)
		_fall_speed = 0.0
	_was_on_floor = now_floor
	# facing: toward movement, or toward the camera while aiming / just after firing
	_strafe_timer = maxf(0.0, _strafe_timer - delta)
	var strafe := aiming or _strafe_timer > 0.0 or combat.firing_held()
	if strafe:
		_face_yaw = controller.yaw
	elif hv.length() > 0.4:
		_face_yaw = atan2(-hv.x, -hv.z)
	var turn := 16.0 if strafe else 9.0
	rotation.y = lerp_angle(rotation.y, _face_yaw, 1.0 - exp(-turn * delta))
	_update_stamina(delta)
	_footsteps(delta, hv.length(), now_floor)

func face_camera_for(secs: float) -> void:
	_strafe_timer = maxf(_strafe_timer, secs)

func request_jump() -> void:
	if locked or dead:
		return
	if crouching:
		set_crouch(false)
		return
	_jump_buffer = 0.14

func set_crouch(on: bool) -> void:
	if on == crouching or dead:
		return
	if not on and not _can_stand():
		Events.message.emit("Not enough room to stand", 1.2)
		return
	crouching = on
	var h := CROUCH_H if on else STAND_H
	capsule.height = h
	shape.position.y = h * 0.5

func _can_stand() -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := CapsuleShape3D.new()
	s.radius = RADIUS - 0.04
	s.height = STAND_H - 0.1
	q.shape = s
	q.transform = Transform3D(Basis(), global_position + Vector3.UP * (STAND_H * 0.5 + 0.05))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func _drain(v: float) -> void:
	stamina = maxf(0.0, stamina - v)
	_stamina_delay = 0.9
	if stamina <= 0.0:
		exhausted = true

func _update_stamina(delta: float) -> void:
	if sprinting:
		_drain(17.0 * delta)
	else:
		_stamina_delay -= delta
		if _stamina_delay <= 0.0:
			stamina = minf(100.0, stamina + (26.0 if not crouching else 32.0) * delta)
	if exhausted and stamina >= 35.0:
		exhausted = false
	Sfx.loop("breath", "breath_exhausted", exhausted and not dead, -8.0)

func _footsteps(delta: float, spd: float, on_floor: bool) -> void:
	if not on_floor or spd < 0.6:
		_step_t = 0.0
		return
	var interval := 0.56 if spd < 2.5 else (0.36 if spd < 5.0 else 0.29)
	_step_t += delta
	if _step_t >= interval:
		_step_t = 0.0
		var vol := -16.0 if crouching else (-11.0 if spd < 5.0 else -8.0)
		Sfx.play_at("footstep_" + ground_kind, global_position, vol, 25.0)
		if sprinting:
			Events.emit_noise(global_position, 9.0, self)
		elif not crouching and spd > 3.0:
			Events.emit_noise(global_position, 4.5, self)

# ---------------------------------------------------------------- actions
func set_lamp(on: bool) -> void:
	lamp_on = on
	if lamp:
		lamp.visible = on
	anim.set_lamp(on)

func toggle_lamp() -> void:
	set_lamp(not lamp_on)
	Sfx.play("lamp_on" if lamp_on else "lamp_off", -8.0)

func use_medkit() -> void:
	if locked or dead or anim.busy_full():
		return
	if health.hp >= health.max_hp - 0.5:
		Events.message.emit("Health is full", 1.2)
		return
	if not inventory.use_medkit():
		Events.message.emit("No medkits", 1.2)
		return
	combat.cancel_reload()
	anim.heal()
	Sfx.play("heal", -4.0)
	await get_tree().create_timer(0.55, false).timeout
	if not dead:
		health.heal(50.0)
		Events.player_healed.emit(50.0)

func _on_damaged(amount: float, info: Dictionary) -> void:
	var src: Vector3 = info.get("pos", global_position + forward())
	var dir := (src - global_position)
	dir.y = 0.0
	Events.player_damaged.emit(amount, dir.normalized() if dir.length() > 0.01 else forward())
	Events.camera_shake.emit(clampf(amount / 30.0, 0.15, 0.8), 0.25)
	if amount >= 8.0:
		hit_flinch = 0.25
		anim.hit()
	Sfx.play("suit_hurt", -4.0)

func _on_died(_info: Dictionary) -> void:
	if dead:
		return
	dead = true
	locked = true
	combat.cancel_reload()
	anim.die()
	Sfx.loop("breath", "", false)
	Sfx.play("player_death", -2.0)
	Events.player_died.emit()
	died.emit()

## Put the player back on the last solid ground they stood on (or the checkpoint) and take no fall damage.
func recover_from_fall() -> void:
	var at := _safe_pos if _has_safe else Vector3(global_position.x, 2.0, global_position.z)
	global_position = at + Vector3.UP * 0.15
	velocity = Vector3.ZERO
	_fall_speed = 0.0
	recovered_from_fall.emit()
	Events.message.emit("Back on solid ground", 1.6)

## Teleport (checkpoints, cinematics).
func place(xf: Transform3D) -> void:
	global_position = xf.origin
	_safe_pos = xf.origin
	_has_safe = true
	var yaw := xf.basis.get_euler().y
	rotation = Vector3(0.0, yaw, 0.0)
	_face_yaw = yaw
	velocity = Vector3.ZERO
	controller.snap_to(yaw)
