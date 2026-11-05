class_name Interactable
extends Node3D
## The interaction contract (PRD BPI_Interactable). Any node in the "interactable" group that implements
## get_prompt / can_interact / interact works with the player's InteractionComponent; this base supplies
## defaults, a stable save ID and a highlight.

@export var stable_id := ""
@export var prompt := "Use"
@export var range_m := 2.3
@export var focus_offset := Vector3(0, 1.2, 0)
var enabled := true
var _hl: OmniLight3D

func _ready() -> void:
	add_to_group("interactable")

func get_prompt() -> String:
	return prompt

func can_focus(_p: Player) -> bool:
	return enabled and visible

func can_interact(_p: Player) -> bool:
	return enabled

func interact(_p: Player) -> void:
	pass

func interact_range() -> float:
	return range_m

func focus_point() -> Vector3:
	return global_transform * focus_offset

func set_highlight(on: bool) -> void:
	if on and _hl == null:
		_hl = OmniLight3D.new()
		_hl.light_color = Color(0.55, 0.85, 1.0)
		_hl.light_energy = 0.6
		_hl.omni_range = 1.4
		add_child(_hl)
		_hl.position = focus_offset + Vector3(0, 0.2, 0.3)
	if _hl:
		_hl.visible = on

func done_flag() -> String:
	return "used." + stable_id
