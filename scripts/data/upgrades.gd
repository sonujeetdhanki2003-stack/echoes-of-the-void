class_name Upgrades
extends RefCounted
## v1.5.0: weapon upgrades, bought at the Upgrade Bench with upgrade parts (one part per level, three levels per stat).
## Levels live in Game.state["upgrades"][weapon_id][stat] and are saved with the game.
## Effects (applied to a copy of the weapon's table entry, never to the shared resource):
##   damage    +15 % per level
##   reload    reload time -10 % per level
##   magazine  +2 rounds per level
##   accuracy  hip and aimed spread -12 % per level

const STATS := ["damage", "reload", "magazine", "accuracy"]
const MAX_LEVEL := 3
const COST := 1

static func levels(id: String) -> Dictionary:
	var all: Dictionary = Game.state.get("upgrades", {})
	var d: Dictionary = all.get(id, {})
	var out := {}
	for s in STATS:
		out[s] = clampi(int(d.get(s, 0)), 0, MAX_LEVEL)
	return out

static func level(id: String, stat: String) -> int:
	return int(levels(id).get(stat, 0))

static func apply(d: WeaponData) -> void:
	var l := levels(d.id)
	d.damage *= 1.0 + 0.15 * float(l["damage"])
	d.reload_time *= 1.0 - 0.10 * float(l["reload"])
	d.mag_size += 2 * int(l["magazine"])
	var acc := 1.0 - 0.12 * float(l["accuracy"])
	d.spread_hip *= acc
	d.spread_aim *= acc

## True when the purchase happened (a part is taken and the level goes up).
static func buy(inv: InventoryComponent, id: String, stat: String) -> bool:
	if not stat in STATS or inv.parts < COST or level(id, stat) >= MAX_LEVEL:
		return false
	if not Game.state.has("upgrades"):
		Game.state["upgrades"] = {}
	var all: Dictionary = Game.state["upgrades"]
	if not all.has(id):
		all[id] = {}
	all[id][stat] = level(id, stat) + 1
	inv.take_parts(COST)
	return true

static func cost_line(id: String, stat: String) -> String:
	var lv := level(id, stat)
	return "MAX" if lv >= MAX_LEVEL else "%d part" % COST
