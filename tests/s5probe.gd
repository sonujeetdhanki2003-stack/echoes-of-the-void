extends Node
## diagnostic for stage 5 part placement (not a regression test)
func _hit(p: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.2, 0), p + Vector3(0, -1.5, 0))
	q.collide_with_areas = false
	return not get_viewport().world_3d.direct_space_state.intersect_ray(q).is_empty()

func _ready() -> void:
	await get_tree().process_frame
	Game.SAVE_PATH = "user://s5probe.json"
	Game.settings["touch"] = "off"
	Game.apply_settings()
	var cands := {
		"reactor": [at_(9.0, 1.2, 0.6, 0), at_(10.0, 1.2, 0, 0.6), at_(3.0, 1.2, 0.6, 0), at_(6.0, 2.2, 0, 0.5), at_(12.0, 3.0, 0.0, 0.5), at_(1.5, 6.0, 0, 0)],
		"research": [at_(2.4, 2.4, 0.5, 0), at_(7.2, 3.6, 0, 0.5), at_(12.0, 1.0, 0, 0.5), at_(6.0, 1.2, 0.5, 0), at_(4.0, 4.0, 0, 0), at_(10.0, 6.0, 0, 0)],
		"security": [at_(0.6, 2.6, 0, 0.5), at_(3.6, 5.2, 0, 0.6), at_(7.6, 1.6, 0, 0.6), at_(12.0, 3.6, 0.5, 0), at_(6.0, 2.4, 0.6, 0), at_(8.0, 3.0, 0, 0), at_(11.0, 7.0, 0, 0), at_(4.4, 8.0, 0, 0)],
	}
	for area in cands.keys():
		await GameMode.load_area(area, area + "_start", true)
		await get_tree().process_frame
		var s := ""
		for c in cands[area]:
			s += " (%.1f,%.1f,%.1f)=%s" % [c.x, c.y, c.z, str(_hit(c))]
		print("PROBE " + area + s)
	get_tree().quit(0)

func at_(cx: float, cz: float, dx: float, dz: float) -> Vector3:
	return GameMode.world_root.get("cur_area").at(cx + dx, cz + dz) if false else Vector3.ZERO
