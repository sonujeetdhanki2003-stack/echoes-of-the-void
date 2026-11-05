class_name InventoryComponent
extends Node
## PRD BP_EOT_InventoryComponent: owned weapons, ammunition reserves, medkits and keycards.

signal changed

const MAX_RESERVE := {"pistol": 96, "rifle": 192}
const MAX_MEDKITS := 3

var weapons: Array[String] = []
var reserve := {"pistol": 0, "rifle": 0}
var medkits := 0
var keycards: Array[String] = []
var parts := 0            # v1.5.0: upgrade parts for the Upgrade Bench

func has_weapon(id: String) -> bool:
	return id in weapons

func add_weapon(id: String) -> bool:
	if id in weapons:
		return false
	weapons.append(id)
	changed.emit()
	return true

func add_ammo(kind: String, amount: int) -> int:
	if not reserve.has(kind):
		return 0
	var before: int = reserve[kind]
	reserve[kind] = mini(MAX_RESERVE[kind], before + amount)
	changed.emit()
	return reserve[kind] - before

func take_ammo(kind: String, amount: int) -> int:
	var n := mini(amount, int(reserve.get(kind, 0)))
	reserve[kind] -= n
	changed.emit()
	return n

func ammo_full(kind: String) -> bool:
	return int(reserve.get(kind, 0)) >= int(MAX_RESERVE.get(kind, 0))

func add_medkit() -> bool:
	if medkits >= MAX_MEDKITS:
		return false
	medkits += 1
	changed.emit()
	return true

func use_medkit() -> bool:
	if medkits <= 0:
		return false
	medkits -= 1
	changed.emit()
	return true

func add_parts(n: int) -> int:
	parts += n
	changed.emit()
	return parts

func take_parts(n: int) -> bool:
	if parts < n:
		return false
	parts -= n
	changed.emit()
	return true

func add_keycard(id: String) -> void:
	if not id in keycards:
		keycards.append(id)
		changed.emit()

func to_dict() -> Dictionary:
	return {"weapons": weapons.duplicate(), "reserve": reserve.duplicate(), "medkits": medkits, "keycards": keycards.duplicate(), "parts": parts}

func from_dict(d: Dictionary) -> void:
	weapons.clear()
	for w in d.get("weapons", []):
		weapons.append(str(w))
	var r: Dictionary = d.get("reserve", {})
	for k in reserve.keys():
		reserve[k] = int(r.get(k, 0))
	medkits = int(d.get("medkits", 0))
	keycards.clear()
	for k in d.get("keycards", []):
		keycards.append(str(k))
	parts = int(d.get("parts", 0))
	changed.emit()
