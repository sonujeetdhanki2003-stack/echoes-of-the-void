class_name KitFallback
extends RefCounted
## Procedural stand-ins for kit pieces, used until (or unless) the Blender kit GLB exists. Built from bevel-less
## boxes grouped into named surfaces ("Panel", "Trim", "Floor", "Dark", "EmitLight", "Glass", "Screen") so the
## area themes colour them exactly like the real kit.

static func make(piece: String, _b: LevelBuilder) -> Mesh:
	var parts: Array = []   # [center, size, key]
	var C := 4.0
	match piece:
		"kit_floor":
			parts.append([Vector3(0, -0.1, 0), Vector3(C, 0.2, C), "Floor"])
			for i in [-1.0, 1.0]:
				parts.append([Vector3(i * 1.0, 0.005, 0), Vector3(0.04, 0.012, C), "Trim"])
		"kit_floor_grate":
			parts.append([Vector3(0, -0.06, 0), Vector3(C, 0.12, C), "Dark"])
			for i in range(-3, 4):
				parts.append([Vector3(i * 0.55, 0.0, 0), Vector3(0.06, 0.04, C), "Trim"])
		"kit_ceiling", "kit_ceiling_plain":
			parts.append([Vector3(0, C + 0.1, 0), Vector3(C, 0.2, C), "Dark"])
			parts.append([Vector3(0, C - 0.02, -1.0), Vector3(C, 0.06, 0.2), "Trim"])
			parts.append([Vector3(0, C - 0.02, 1.0), Vector3(C, 0.06, 0.2), "Trim"])
			if piece == "kit_ceiling":
				parts.append([Vector3(0, C - 0.04, 0), Vector3(2.6, 0.04, 0.32), "EmitLight"])
		"kit_wall", "kit_wall_pipes", "kit_wall_vent", "kit_wall_screen", "kit_wall_upper", "kit_wall_window":
			_wall(parts, piece, C)
		"kit_door_frame":
			var pw := (C - 2.4) * 0.5
			for s in [-1.0, 1.0]:
				parts.append([Vector3(s * (1.2 + pw * 0.5), C * 0.5, 0), Vector3(pw, C, 0.3), "Panel"])
				parts.append([Vector3(s * 1.28, 1.5, 0), Vector3(0.16, 3.0, 0.42), "Trim"])
				parts.append([Vector3(s * 1.28, 3.1, 0), Vector3(0.18, 0.14, 0.44), "EmitDoor"])
			parts.append([Vector3(0, 3.5, 0), Vector3(2.4, 1.0, 0.3), "Panel"])
			parts.append([Vector3(0, 3.06, 0), Vector3(2.72, 0.14, 0.42), "Trim"])
		_:
			return null
	return build(parts)

static func _wall(parts: Array, piece: String, C: float) -> void:
	if piece == "kit_wall_window":
		parts.append([Vector3(0, 0.5, 0), Vector3(C, 1.0, 0.3), "Panel"])
		parts.append([Vector3(0, 3.5, 0), Vector3(C, 1.0, 0.3), "Panel"])
		for s in [-1.0, 1.0]:
			parts.append([Vector3(s * 1.8, 2.0, 0), Vector3(0.4, 2.0, 0.3), "Panel"])
		parts.append([Vector3(0, 2.0, 0), Vector3(3.2, 2.0, 0.05), "Glass"])
		parts.append([Vector3(0, 1.0, 0), Vector3(C, 0.08, 0.36), "Trim"])
		parts.append([Vector3(0, 3.0, 0), Vector3(C, 0.08, 0.36), "Trim"])
		return
	# base slab with inset panel look: a recessed centre, raised frame, skirting and a light strip
	parts.append([Vector3(0, C * 0.5, 0), Vector3(C, C, 0.22), "Panel"])
	for s in [-1.0, 1.0]:
		parts.append([Vector3(0, 0.12, s * 0.13), Vector3(C, 0.24, 0.06), "Dark"])
		parts.append([Vector3(0, C - 0.1, s * 0.13), Vector3(C, 0.2, 0.06), "Trim"])
		parts.append([Vector3(s * 1.96, C * 0.5, 0), Vector3(0.08, C, 0.34), "Trim"])
		parts.append([Vector3(0, 1.2, s * 0.125), Vector3(C - 0.2, 0.05, 0.05), "Trim"])
		if piece == "kit_wall":
			parts.append([Vector3(0, 2.6, s * 0.12), Vector3(1.4, 0.05, 0.04), "EmitLight"])
		if piece == "kit_wall_pipes":
			for k in 3:
				parts.append([Vector3(0, 2.2 + k * 0.28, s * 0.22), Vector3(C, 0.16, 0.16), "Dark"])
		if piece == "kit_wall_vent":
			parts.append([Vector3(0, 0.75, s * 0.13), Vector3(1.2, 0.7, 0.06), "Dark"])
			for k in 5:
				parts.append([Vector3(0, 0.5 + k * 0.12, s * 0.16), Vector3(1.1, 0.03, 0.03), "Trim"])
		if piece == "kit_wall_screen":
			parts.append([Vector3(0.6, 1.9, s * 0.13), Vector3(1.4, 0.8, 0.05), "Screen"])

static func build(parts: Array) -> ArrayMesh:
	var by_key := {}
	for p in parts:
		var key: String = p[2]
		if not by_key.has(key):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			by_key[key] = st
		_box(by_key[key], p[0], p[1])
	var am := ArrayMesh.new()
	for key in by_key.keys():
		var st: SurfaceTool = by_key[key]
		st.generate_tangents()
		st.commit(am)
		am.surface_set_name(am.get_surface_count() - 1, key)
	return am

static func _box(st: SurfaceTool, c: Vector3, s: Vector3) -> void:
	var h := s * 0.5
	var faces := [
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0)], [Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 1, 0)],
		[Vector3(0, 1, 0), Vector3(1, 0, 0), Vector3(0, 0, -1)], [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(0, 0, 1)],
	]
	for f in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var v: Vector3 = f[2]
		var hu := absf(u.dot(h))
		var hv := absf(v.dot(h))
		var hn := absf(n.dot(h))
		var o := c + n * hn
		var corners := [o - u * hu - v * hv, o + u * hu - v * hv, o + u * hu + v * hv, o - u * hu + v * hv]
		# world-ish UVs (metres / 2) so textures tile at a consistent scale
		var uvs := []
		for q in corners:
			var qq: Vector3 = q
			uvs.append(Vector2(qq.dot(u), -qq.dot(v)) * 0.5)
		for idx in [0, 2, 1, 0, 3, 2]:
			st.set_normal(n)
			st.set_uv(uvs[idx])
			st.add_vertex(corners[idx])
