extends Node
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area(Game.arg("area", "security"), Game.arg("area", "security") + "_start", true)
	var p: Player = GameMode.player
	p.combat.give("rifle")
	for i in 30:
		await get_tree().process_frame
	var w = p.combat.current
	print("WPROBE weapon ", w, " visible=", w.visible, " in_tree=", w.is_visible_in_tree(), " gpos=", w.global_position, " scale=", w.global_transform.basis.get_scale())
	print("WPROBE player ", p.global_position, " hand_attach ", p.anim.hand_attach, " ", p.anim.hand_attach.global_position if p.anim.hand_attach else null)
	for mi in w.find_children("*", "MeshInstance3D", true, false):
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		print("WPROBE mesh ", mi.name, " ", aabb.position, " size ", aabb.size, " vis ", mi.is_visible_in_tree(), " layers ", mi.layers)
	var sk: Skeleton3D = p.anim.skel
	print("WPROBE bone prop.R idx ", sk.find_bone("prop.R"), " pose ", sk.global_transform * sk.get_bone_global_pose(sk.find_bone("prop.R")).origin)
	get_tree().quit()
