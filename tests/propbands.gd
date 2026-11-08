extends Node
## Diagnostic (1.9.3): horizontal extent of a model's vertices per height band (--driver=propbands --name=antenna_mast)
func _ready() -> void:
	await get_tree().process_frame
	var n := Game.arg("name", "antenna_mast")
	var inst := Props.instance(n)
	add_child(inst)
	var bands := {}
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		for v in m.mesh.get_faces():
			var k := int(floor(v.y / 1.0))
			if not bands.has(k):
				bands[k] = [v.x, v.x, v.z, v.z, 0]
			var b: Array = bands[k]
			b[0] = minf(b[0], v.x); b[1] = maxf(b[1], v.x); b[2] = minf(b[2], v.z); b[3] = maxf(b[3], v.z); b[4] += 1
	var ks := bands.keys(); ks.sort()
	for k in ks:
		var b: Array = bands[k]
		print("BAND y=%d x[%.2f,%.2f] z[%.2f,%.2f] n=%d" % [k, b[0], b[1], b[2], b[3], b[4] / 1])
	get_tree().quit(0)
