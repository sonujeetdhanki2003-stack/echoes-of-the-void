class_name Keypad
extends Interactable
## Security access puzzle (PRD §5.4): a keypad that takes a 4-digit override code learned from the logs.

signal unlocked

@export var code := "0417"
@export var hint := "OVERRIDE (MMDD)"
@export var flag_on_success := "puzzle.security_code"
var misses := 0
var model: Node3D

func _ready() -> void:
	super._ready()
	range_m = 2.2
	focus_offset = Vector3(0, 1.3, 0.1)
	model = Props.make("keypad_panel", false)
	add_child(model)
	model.position.y = 1.2

func get_prompt() -> String:
	return "" if Game.flag(flag_on_success) else "Use keypad"

func can_focus(p: Player) -> bool:
	return super.can_focus(p) and not Game.flag(flag_on_success)

func interact(p: Player) -> void:
	p.anim.interact()
	Sfx.play_at("keypad_beep", focus_point(), -6.0)
	if GameMode.ui:
		GameMode.ui.open_keypad(self)

## Called by the keypad overlay. Returns true when the code is right.
func submit(entry: String) -> bool:
	if entry == code:
		Sfx.play_at("keypad_ok", focus_point(), -2.0)
		Game.set_flag(flag_on_success)
		unlocked.emit()
		return true
	misses += 1
	Sfx.play_at("keypad_err", focus_point(), -2.0)
	if misses >= 3 and misses % 3 == 0:
		Sfx.say("mira_code_hint")
	return false
