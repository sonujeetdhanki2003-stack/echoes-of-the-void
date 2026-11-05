class_name UpgradeBench
extends Interactable
## v1.5.0: the Upgrade Bench. Use it to spend upgrade parts on the weapons you carry: damage, reload, magazine and
## accuracy, three levels each (see scripts/data/upgrades.gd).

var model: Node3D
var lamp: OmniLight3D

func _ready() -> void:
	super._ready()
	range_m = 2.3
	focus_offset = Vector3(0, 1.1, 0.25)
	model = Props.make("med_cabinet", true)
	add_child(model)
	lamp = OmniLight3D.new()
	lamp.omni_range = 2.5
	lamp.position = Vector3(0, 1.9, 0.5)
	add_child(lamp)

func get_prompt() -> String:
	var n := GameMode.player.inventory.parts if GameMode.player != null else 0
	return "Use upgrade bench (%d parts)" % n

func can_interact(_p: Player) -> bool:
	return true

func interact(p: Player) -> void:
	p.anim.interact()
	GameMode.ui.open_bench(p)

func _process(_d: float) -> void:
	lamp.light_color = Color(1.0, 0.6, 0.2)
	lamp.light_energy = 0.9
