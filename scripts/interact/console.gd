class_name Console
extends Interactable
## A generic terminal/console/panel. Calls `action` when used (if `requires` is met). Optional one-shot.

signal used(player: Player)

@export var requires := ""          # flag required
@export var requires_text := "No power"
@export var one_shot := true
@export var model_name := ""
@export var done_prompt := ""
var action: Callable
var model: Node3D
var screen_light: OmniLight3D
var _screen_color := Color(0.35, 0.8, 1.0)

func _ready() -> void:
	super._ready()
	if model_name != "":
		model = Props.make(model_name, true)
		add_child(model)
	screen_light = OmniLight3D.new()
	screen_light.light_color = _screen_color
	screen_light.light_energy = 0.8
	screen_light.omni_range = 2.5
	screen_light.position = focus_offset + Vector3(0, 0.1, 0.5)
	add_child(screen_light)

func set_screen_color(c: Color) -> void:
	_screen_color = c
	if screen_light:
		screen_light.light_color = c

func is_done() -> bool:
	return one_shot and stable_id != "" and Game.flag(done_flag())

func can_focus(p: Player) -> bool:
	return super.can_focus(p) and not (is_done() and done_prompt == "")

func get_prompt() -> String:
	if is_done():
		return done_prompt
	if requires != "" and not Game.flag(requires):
		return requires_text
	return prompt

func can_interact(_p: Player) -> bool:
	return not is_done() and (requires == "" or Game.flag(requires))

func denied(_p: Player) -> void:
	if not is_done():
		Sfx.play_at("keypad_err", focus_point(), -6.0)
		Events.message.emit(requires_text, 1.8)

func interact(p: Player) -> void:
	if not can_interact(p):
		denied(p)
		return
	Sfx.play_at("terminal_beep", focus_point(), -6.0)
	p.anim.interact()
	if one_shot and stable_id != "":
		Game.set_flag(done_flag())
	used.emit(p)
	if action.is_valid():
		action.call(p)
