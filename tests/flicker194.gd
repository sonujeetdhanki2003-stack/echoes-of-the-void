extends Node
## 1.9.4 flicker audit (bugs 4, 14): transparent surfaces of every prop in an area and their render settings.
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	var areas := [["cryo","cryo_hub"],["research","research_hub"],["security","security_hub"],["reactor","reactor_hub"],["exterior","exterior_hub"],["extraction","extraction_hub"],["hollows","hollows_hub"]]
	for a in areas:
		await GameMode.load_area(a[0], a[1], true)
		await get_tree().physics_frame
		var rows := {}
		_walk(GameMode.area, a[0], rows)
		for c in _find_mm(GameMode.area):
			if String(c.name).contains("_glass"):
				glass_total[0] += 1
				if c.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
					glass_total[1] += 1
		for k in rows.keys():
			print("TR ", a[0], " ", k, " x", rows[k])
	print("TRANSPARENT_CASTING_SHADOW ", shadow_on[0])
	print("GLASS_MM_TOTAL ", glass_total[0], " casting_shadow ", glass_total[1])
	get_tree().quit(0)

var shadow_on := [0]
var glass_total := [0, 0]
func _walk(n: Node, area: String, rows: Dictionary) -> void:
	if n is MeshInstance3D and n.mesh != null:
		var mi: MeshInstance3D = n
		var root: Node = mi
		while root.get_parent() and not root.has_meta("prop") and root.get_parent() != GameMode.area:
			root = root.get_parent()
		var pname := str(root.get_meta("prop")) if root.has_meta("prop") else "scene"
		for s in mi.mesh.get_surface_count():
			var m := mi.get_active_material(s)
			if m is BaseMaterial3D:
				var bm := m as BaseMaterial3D
				if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
					if mi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
						shadow_on[0] += 1
						if shadow_on[0] <= 12: print("PATH ", area, " ", mi.get_path(), " ", bm.resource_name, " cls=", mi.mesh.get_class(), " blend=", (mi.mesh as ArrayMesh).get_blend_shape_count() if mi.mesh is ArrayMesh else -1, " skin=", mi.skin != null)
					var key := "%s surf=%d mat=%s tr=%d dd=%d cull=%d shadow=%d" % [pname, s, bm.resource_name, bm.transparency, bm.depth_draw_mode, bm.cull_mode, mi.cast_shadow]
					rows[key] = int(rows.get(key, 0)) + 1
	for c in n.get_children():
		_walk(c, area, rows)

func _find_mm(n: Node) -> Array:
	var r := []
	for c in n.get_children():
		if c is MultiMeshInstance3D: r.append(c)
		r.append_array(_find_mm(c))
	return r
