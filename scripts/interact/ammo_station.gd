class_name AmmoStation
extends Interactable
## A wall dispenser that tops up energy cells (and in boss arenas, a medkit). Recharges over time, so a player can
## never be stranded without ammunition (no softlocks).

@export var recharge := 45.0
@export var give_medkit := false
var _ready_at := 0.0
var model: Node3D
var lamp: OmniLight3D

func _ready() -> void:
	super._ready()
	range_m = 2.3
	focus_offset = Vector3(0, 1.2, 0.25)
	model = Props.make("med_cabinet", true)
	add_child(model)
	lamp = OmniLight3D.new()
	lamp.omni_range = 2.5
	lamp.position = Vector3(0, 1.9, 0.5)
	add_child(lamp)

func _now() -> float:
	return Time.get_ticks_msec() / 1000.0

func get_prompt() -> String:
	if _now() < _ready_at:
		return "Recharging (%ds)" % int(ceil(_ready_at - _now()))
	return "Resupply" + (" (cells + medkit)" if give_medkit else " (energy cells)")

func can_interact(_p: Player) -> bool:
	return _now() >= _ready_at

func denied(_p: Player) -> void:
	Events.message.emit("Dispenser recharging", 1.2)

func interact(p: Player) -> void:
	if not can_interact(p):
		return
	var got := 0
	got += p.inventory.add_ammo("pistol", 36)
	if p.inventory.has_weapon("rifle"):
		got += p.inventory.add_ammo("rifle", 64)
	var med := false
	if give_medkit:
		med = p.inventory.add_medkit()
	if got == 0 and not med:
		Events.message.emit("You're fully stocked", 1.4)
		return
	Sfx.play("ammo_pickup", -2.0)
	Events.message.emit("Resupplied" + (" + medkit" if med else ""), 1.6)
	p.anim.interact()
	_ready_at = _now() + recharge

func _process(_d: float) -> void:
	lamp.light_color = Color(0.3, 1.0, 0.5) if _now() >= _ready_at else Color(1.0, 0.4, 0.15)
	lamp.light_energy = 0.9
