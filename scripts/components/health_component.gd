class_name HealthComponent
extends Node
## PRD BP_EOT_HealthComponent: health, damage and death for anything that can be hurt.

signal damaged(amount: float, info: Dictionary)
signal healed(amount: float)
signal died(info: Dictionary)
signal changed(hp: float, max_hp: float)

@export var max_hp := 100.0
@export var hp := 100.0
var dmg_mult := 1.0          # difficulty scaling for the owner
var invulnerable := false
var dead := false

func setup(max_value: float, current: float = -1.0) -> void:
	max_hp = max_value
	hp = max_value if current < 0.0 else clampf(current, 0.0, max_value)
	dead = hp <= 0.0
	changed.emit(hp, max_hp)

## info: {pos: Vector3, dir: Vector3, critical: bool, source: Node, kind: String}
func take_damage(amount: float, info: Dictionary = {}) -> float:
	if dead or invulnerable or amount <= 0.0:
		return 0.0
	var a := amount * dmg_mult
	hp = maxf(0.0, hp - a)
	damaged.emit(a, info)
	changed.emit(hp, max_hp)
	if hp <= 0.0:
		dead = true
		died.emit(info)
	return a

func heal(amount: float) -> void:
	if dead:
		return
	var before := hp
	hp = minf(max_hp, hp + amount)
	if hp > before:
		healed.emit(hp - before)
		changed.emit(hp, max_hp)

func revive(value: float) -> void:
	dead = false
	hp = clampf(value, 1.0, max_hp)
	changed.emit(hp, max_hp)

func frac() -> float:
	return hp / maxf(1.0, max_hp)
