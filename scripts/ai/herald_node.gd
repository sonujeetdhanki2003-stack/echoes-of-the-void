class_name HeraldNode
extends Node
## Hit proxy for one of the Herald's resonance nodes (weapons call take_hit on the hitbox's hit_owner).

var herald: Herald
var node_id := ""

func take_hit(dmg: float, _info: Dictionary) -> bool:
	if herald == null:
		return false
	return herald.node_hit(node_id, dmg)
