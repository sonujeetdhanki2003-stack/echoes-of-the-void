extends Node
## Prints the runtime node tree of the player (Doc 03 Phase 2 node architecture evidence).
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("cryo", "cryo_hub", true)
	var p: Node = GameMode.player
	_dump(p, 0, 3)
	var c = p.controller
	print("TREE controller rig: ")
	_dump(c, 0, 4)
	get_tree().quit()

func _dump(n: Node, d: int, maxd: int) -> void:
	if d > maxd:
		return
	var skip := n is Skeleton3D or n is BoneAttachment3D
	print("TREE " + "  ".repeat(d) + n.name + " (" + n.get_class() + ")")
	if skip and d > 1:
		return
	for ch in n.get_children():
		if ch is MeshInstance3D and d >= 2:
			continue
		_dump(ch, d + 1, maxd)
