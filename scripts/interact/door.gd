class_name Door
extends Interactable
## Sliding two-leaf door in a kit_door_frame opening. Opens by proximity when unlocked; locks are a flag that
## must be set ("power", a code, a keycard, a story flag). Locked doors explain themselves when used.

signal opened

@export var lock_flag := ""          # Game flag required to open ("" = unlocked)
@export var keycard := ""            # keycard id required
@export var locked_text := "Locked"
@export var auto := true             # open when someone approaches
@export var stays_open := false
@export var travel_area := ""        # walking through it loads another area
@export var travel_checkpoint := ""
var leaves: Array[Node3D] = []
var _open := 0.0
var _target := 0.0
var _sense: Area3D
var _status_mats: Array = []
var _body: AnimatableBody3D
var _shapes: Array = []
var _was_open := false
var _occupants := 0

func _ready() -> void:
	super._ready()
	prompt = "Open"
	range_m = 2.8
	focus_offset = Vector3(0, 1.4, 0)
	_build()
	if stable_id != "" and Game.flag("door." + stable_id) and stays_open:
		_open = 1.0
		_target = 1.0
	_apply()

func _build() -> void:
	_body = AnimatableBody3D.new()
	_body.collision_layer = 1
	_body.sync_to_physics = false
	add_child(_body)
	for side in [-1.0, 1.0]:
		var holder := Node3D.new()
		holder.position = Vector3(0.6 * side, 0, 0)
		add_child(holder)
		var leaf: Node3D
		var path := Props.model_path("kit_door_leaf")
		if path != "":
			leaf = (load(path) as PackedScene).instantiate()
		else:
			leaf = Node3D.new()
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(1.25, 3.0, 0.1)
			mi.mesh = bm
			mi.position.y = 1.5
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.6, 0.62, 0.65)
			m.metallic = 0.6
			m.roughness = 0.4
			mi.material_override = m
			leaf.add_child(mi)
		if side < 0.0:
			leaf.rotation.y = PI
		holder.add_child(leaf)
		leaves.append(holder)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(1.25, 3.0, 0.16)
		cs.shape = bs
		cs.position = Vector3(0.6 * side, 1.5, 0)
		_body.add_child(cs)
		_shapes.append(cs)
	# status light over the door (both faces)
	for z in [-0.3, 0.3]:
		var s := MeshInstance3D.new()
		var bm2 := BoxMesh.new()
		bm2.size = Vector3(0.5, 0.08, 0.04)
		s.mesh = bm2
		s.position = Vector3(0, 3.22, z)
		var mat := StandardMaterial3D.new()
		mat.emission_enabled = true
		mat.emission_energy_multiplier = 3.0
		s.material_override = mat
		add_child(s)
		_status_mats.append(mat)
	_sense = Area3D.new()
	_sense.collision_layer = 0
	_sense.collision_mask = 2 | 4
	var sc := CollisionShape3D.new()
	var sb := BoxShape3D.new()
	sb.size = Vector3(3.0, 3.0, 5.5)
	sc.shape = sb
	sc.position.y = 1.5
	_sense.add_child(sc)
	add_child(_sense)
	_sense.body_entered.connect(_on_body.bind(1))
	_sense.body_exited.connect(_on_body.bind(-1))

func is_locked() -> bool:
	if lock_flag != "" and not Game.flag(lock_flag):
		return true
	if keycard != "":
		var p: Player = GameMode.player
		if p == null or not keycard in p.inventory.keycards:
			return true
	return false

func get_prompt() -> String:
	if is_locked():
		return locked_text
	return "Open" if _target < 0.5 else ""

func can_focus(p: Player) -> bool:
	return super.can_focus(p) and (is_locked() or not auto) and _target < 0.5

func can_interact(_p: Player) -> bool:
	return not is_locked()

func denied(_p: Player) -> void:
	Sfx.play_at("door_locked", global_position + Vector3.UP * 1.5, -4.0)
	Events.message.emit(locked_text, 2.0)

func interact(p: Player) -> void:
	if is_locked():
		denied(p)
		return
	if keycard != "" and stable_id != "":
		Game.set_flag("door." + stable_id)
	open_door()

func open_door() -> void:
	if _target >= 1.0:
		return
	_target = 1.0
	Sfx.play_at("door_open", global_position + Vector3.UP * 1.5, -3.0)
	if stable_id != "":
		Game.set_flag("door." + stable_id)
	opened.emit()

func close_door() -> void:
	if _target <= 0.0 or stays_open:
		return
	_target = 0.0
	Sfx.play_at("door_close", global_position + Vector3.UP * 1.5, -6.0)

func _on_body(_b: Node, d: int) -> void:
	_occupants = maxi(0, _occupants + d)
	if not auto:
		return
	if _occupants > 0 and not is_locked():
		open_door()
	elif _occupants == 0 and not stays_open:
		await get_tree().create_timer(1.2, false).timeout
		if _occupants == 0 and is_instance_valid(self):
			close_door()

func _physics_process(delta: float) -> void:
	var before := _open
	_open = move_toward(_open, _target, delta / 0.55)
	if absf(before - _open) > 0.0001:
		_apply()
	# a door that was locked and became unlocked while someone stands at it
	if auto and _occupants > 0 and _target < 0.5 and not is_locked():
		open_door()
	var c: Color
	if is_locked():
		c = Color(1.0, 0.12, 0.08)
	elif _open > 0.5:
		c = Color(0.25, 1.0, 0.45)
	else:
		c = Color(0.3, 0.75, 1.0)
	for m in _status_mats:
		(m as StandardMaterial3D).emission = c
		(m as StandardMaterial3D).albedo_color = c * 0.3

func _apply() -> void:
	var e := ease(_open, -2.2)
	for i in leaves.size():
		var side := -1.0 if i == 0 else 1.0
		leaves[i].position.x = side * (0.6 + 1.25 * e)
		(_shapes[i] as CollisionShape3D).position.x = side * (0.6 + 1.25 * e)
		(_shapes[i] as CollisionShape3D).disabled = e > 0.92
