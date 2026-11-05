class_name GeneratorPuzzle
extends Node3D
## Power restoration (PRD §5.4): start the generators in the right order (coolant -> regulator -> main, from
## Wren's note and the wall schematic). A wrong order trips the breaker and resets everything, with clear
## feedback — logical, never random.

signal solved_signal

@export var stable_id := "generators"
@export var order: Array[String] = ["B", "C", "A"]
var gens := {}
var progress: Array[String] = []
var solved := false
var _mira_hinted := false

func _ready() -> void:
	solved = Game.flag("puzzle." + stable_id)

func register(g: Generator) -> void:
	gens[g.gen_id] = g
	g.puzzle = self
	g.started.connect(_on_start)
	if solved:
		g.set_running(true)

func _on_start(g: Generator) -> void:
	if solved:
		return
	Sfx.play_at("generator_start", g.global_position + Vector3.UP, -2.0)
	g.set_running(true)
	var expect: String = order[progress.size()]
	if g.gen_id != expect:
		await get_tree().create_timer(1.3, false).timeout
		_trip(g)
		return
	progress.append(g.gen_id)
	Events.message.emit("Generator %s running (%d/3)" % [g.gen_id, progress.size()], 2.0)
	if progress.size() == order.size():
		await get_tree().create_timer(1.0, false).timeout
		solved = true
		Sfx.play("power_on", 0.0)
		Events.camera_shake.emit(0.25, 0.6)
		Game.set_flag("puzzle." + stable_id)
		solved_signal.emit()

func _trip(g: Generator) -> void:
	Sfx.play_at("breaker_trip", g.global_position + Vector3.UP * 1.5, 0.0)
	Fx.burst(g.global_position + Vector3(0, 2.2, 0.6), Color(1.0, 0.8, 0.4), 0.6, 30)
	Events.camera_shake.emit(0.3, 0.3)
	for id in gens.keys():
		(gens[id] as Generator).set_running(false)
	progress.clear()
	Events.message.emit("Breaker tripped — wrong start order", 2.5)
	if not _mira_hinted:
		_mira_hinted = true
		Sfx.say("mira_gen_wrong")
