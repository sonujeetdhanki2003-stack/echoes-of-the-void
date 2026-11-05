class_name ConduitConsole
extends Interactable
## Energy alignment puzzle (PRD §5.4): opens the conduit-rotation board. The board logic lives in
## ConduitBoard (pure data, unit-tested); this node is the in-world console.

signal solved

@export var flag_on_success := "puzzle.conduits"
var board := ConduitBoard.new()
var model: Node3D
var screen_mesh: MeshInstance3D

func _ready() -> void:
	super._ready()
	range_m = 2.8
	focus_offset = Vector3(0, 1.4, 0.4)
	model = Props.make("conduit_console", true)
	add_child(model)
	board.setup_default()
	if Game.flag(flag_on_success):
		board.load_solved()

func get_prompt() -> String:
	return "" if Game.flag(flag_on_success) else "Use power routing console"

func can_focus(p: Player) -> bool:
	return super.can_focus(p) and not Game.flag(flag_on_success)

func interact(p: Player) -> void:
	p.anim.interact()
	Sfx.play_at("terminal_beep", focus_point(), -6.0)
	if GameMode.ui:
		GameMode.ui.open_conduits(self)

func on_board_solved() -> void:
	Sfx.play_at("conduit_connect", focus_point(), 0.0)
	Game.set_flag(flag_on_success)
	solved.emit()
