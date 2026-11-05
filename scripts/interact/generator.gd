class_name Generator
extends Interactable
## One generator of the power-restoration puzzle (PRD §5.4). The GeneratorPuzzle owns the sequence logic.

signal started(gen: Generator)

@export var gen_id := "A"
@export var label := "MAIN"
var puzzle: Node
var running := false
var model: Node3D
var lamp: OmniLight3D
var lamp_mat: StandardMaterial3D
var fan: Node3D
var hum: AudioStreamPlayer3D
var _spin := 0.0

func _ready() -> void:
	super._ready()
	range_m = 2.6
	focus_offset = Vector3(0, 1.3, 0.9)
	model = Props.make("generator", true)
	add_child(model)
	fan = Props.part(model, "Fan")
	lamp = OmniLight3D.new()
	lamp.light_energy = 1.4
	lamp.omni_range = 4.0
	lamp.position = Vector3(0, 2.7, 0.4)
	add_child(lamp)
	# a big painted label so the puzzle reads at a glance
	var l3 := Label3D.new()
	l3.text = "GEN %s\n%s" % [gen_id, label]
	l3.font_size = 64
	l3.pixel_size = 0.004
	l3.outline_size = 8
	l3.modulate = Color(1.0, 0.92, 0.75)
	l3.position = Vector3(0, 1.95, 0.85)
	l3.font = load("res://assets/fonts/Rajdhani-Bold.ttf")
	add_child(l3)
	set_running(false)

func get_prompt() -> String:
	return "Start generator %s (%s)" % [gen_id, label] if not running else ""

func can_focus(p: Player) -> bool:
	return super.can_focus(p) and not running and puzzle and not puzzle.solved

func interact(p: Player) -> void:
	if running:
		return
	p.anim.interact()
	started.emit(self)

func set_running(on: bool) -> void:
	running = on
	lamp.light_color = Color(0.3, 1.0, 0.4) if on else Color(1.0, 0.25, 0.1)
	lamp.light_energy = 1.6 if on else 0.9
	if on and hum == null:
		hum = Sfx.emitter("generator_loop", self, -6.0, 18.0)
	elif not on and hum:
		hum.queue_free()
		hum = null

func _process(delta: float) -> void:
	_spin = lerpf(_spin, 14.0 if running else 0.0, delta * 1.5)
	if fan:
		fan.rotate_object_local(Vector3.FORWARD, _spin * delta)
