extends Node
## Diagnostic (1.9.3): vertices of a model outside a radius (--driver=propfoot --name=antenna_mast --r=1.0): y range
func _ready() -> void:
	await get_tree().process_frame
	var n := Game.arg("name", "antenna_mast")
	var rr := float(Game.arg("r", "1.0"))
	var inst := Props.instance(n)
	add_child(inst)
	var lo := 1e9; var hi := -1e9; var c := 0
	var xs := [1e9, -1e9]; var zs := [1e9, -1e9]
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null: continue
		for v in m.mesh.get_faces():
			if Vector2(v.x, v.z).length() > rr:
				c += 1
				lo = minf(lo, v.y); hi = maxf(hi, v.y)
				xs[0] = minf(xs[0], v.x); xs[1] = maxf(xs[1], v.x); zs[0] = minf(zs[0], v.z); zs[1] = maxf(zs[1], v.z)
	print("FOOT n=%d y[%.3f,%.3f] x[%.2f,%.2f] z[%.2f,%.2f]" % [c, lo, hi, xs[0], xs[1], zs[0], zs[1]])
	get_tree().quit(0)
