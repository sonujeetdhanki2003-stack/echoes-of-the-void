class_name SecurityGate
extends Node3D
## The heavy Security Sector gate (two leaves sliding 2.3 m). Opens when its flag is set.

@export var open_flag := "puzzle.security_code"
var model: Node3D
var leaf_l: Node3D
var leaf_r: Node3D
var col: CollisionShape3D
var _open := false
var _l0 := Vector3.ZERO
var _r0 := Vector3.ZERO

func _ready() -> void:
	model = Props.instance("security_gate")
	add_child(model)
	leaf_l = Props.part(model, "LeafL")
	leaf_r = Props.part(model, "LeafR")
	if leaf_l:
		_l0 = leaf_l.position
	if leaf_r:
		_r0 = leaf_r.position
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	add_child(sb)
	col = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(4.6, 4.6, 0.6)
	col.shape = bs
	col.position.y = 2.3
	sb.add_child(col)
	if Game.flag(open_flag):
		_set_open(1.0)
		col.disabled = true
		_open = true
	Events.flag_set.connect(func(f):
		if f == open_flag and not _open:
			open_gate())

func open_gate() -> void:
	_open = true
	Sfx.play_at("gate_open", global_position + Vector3.UP * 2.5, 2.0, 50.0)
	Events.camera_shake.emit(0.2, 1.6)
	var tw := create_tween()
	tw.tween_method(_set_open, 0.0, 1.0, 3.0).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	tw.tween_callback(func(): col.disabled = true)

func _set_open(t: float) -> void:
	if leaf_l:
		leaf_l.position = _l0 + Vector3(-2.3 * t, 0, 0)
	if leaf_r:
		leaf_r.position = _r0 + Vector3(2.3 * t, 0, 0)
	if leaf_l == null and leaf_r == null and model:
		model.position.y = -4.8 * t
