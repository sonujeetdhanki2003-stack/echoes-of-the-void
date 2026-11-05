class_name Terrain
extends RefCounted
## Procedural alien terrain: a noise heightfield flattened along a walkable path, rising into cliffs at the
## edges. Visual mesh with a triplanar-ish ground material + HeightMapShape3D collision (fast in Jolt).

var size := 240.0
var res := 2.0
var noise := FastNoiseLite.new()
var path: PackedVector3Array = []   # walkable spine (y ignored)
var path_width := 14.0
var flats: Array = []               # [Vector3 centre, radius, height]
var amp := 7.0
var edge_rise := 26.0
var origin := Vector3.ZERO
var n := 0
var heights := PackedFloat32Array()

func _init(seed_value: int = 3) -> void:
	noise.seed = seed_value
	noise.frequency = 0.012
	noise.fractal_octaves = 4
	noise.fractal_gain = 0.5

func _path_dist(p: Vector3) -> float:
	var best := INF
	for i in path.size() - 1:
		var a := Vector2(path[i].x, path[i].z)
		var b := Vector2(path[i + 1].x, path[i + 1].z)
		var q := Vector2(p.x, p.z)
		var ab := b - a
		var t := clampf((q - a).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
		best = minf(best, q.distance_to(a + ab * t))
	return best

func height_at(x: float, z: float) -> float:
	var p := Vector3(x, 0, z)
	var h := noise.get_noise_2d(x, z) * amp + noise.get_noise_2d(x * 3.1, z * 3.1) * amp * 0.18
	var d := _path_dist(p) if path.size() > 1 else INF
	# flatten the path to gentle rolls, raise far from it into canyon walls
	var path_h := noise.get_noise_2d(x * 0.5, z * 0.5) * 1.2
	var k := smoothstep(path_width * 0.5, path_width * 1.6, d)
	h = lerpf(path_h, h + smoothstep(path_width * 1.6, path_width * 5.0, d) * edge_rise, k)
	for f in flats:
		var c: Vector3 = f[0]
		var r: float = f[1]
		var fd := Vector2(x - c.x, z - c.z).length()
		h = lerpf(float(f[2]), h, smoothstep(r, r * 1.6, fd))
	# rise at the map border so nothing walks off the world
	var bd := maxf(absf(x - origin.x), absf(z - origin.z)) - (size * 0.5 - 24.0)
	if bd > 0.0:
		h += bd * 1.6
	return h

func build(parent: Node3D, mat: Material) -> void:
	n = int(size / res) + 1
	heights.resize(n * n)
	var x0 := origin.x - size * 0.5
	var z0 := origin.z - size * 0.5
	for j in n:
		for i in n:
			heights[j * n + i] = height_at(x0 + i * res, z0 + j * res)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in n:
		for i in n:
			var h := heights[j * n + i]
			var hl := heights[j * n + maxi(i - 1, 0)]
			var hr := heights[j * n + mini(i + 1, n - 1)]
			var hd := heights[maxi(j - 1, 0) * n + i]
			var hu := heights[mini(j + 1, n - 1) * n + i]
			var nrm := Vector3(hl - hr, 2.0 * res, hd - hu).normalized()
			st.set_normal(nrm)
			st.set_uv(Vector2(x0 + i * res, z0 + j * res) * 0.12)
			# vertex colour darkens steep slopes (cliffs read as rock)
			var slope := 1.0 - nrm.y
			st.set_color(Color(1, 1, 1).lerp(Color(0.45, 0.4, 0.5), clampf(slope * 3.0, 0.0, 1.0)))
			st.add_vertex(Vector3(x0 + i * res, h, z0 + j * res))
	for j in n - 1:
		for i in n - 1:
			var a := j * n + i
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + n)
			st.add_index(a + 1)
			st.add_index(a + n + 1)
			st.add_index(a + n)
	st.generate_tangents()
	var mi := MeshInstance3D.new()
	mi.name = "Terrain"
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	var sb := StaticBody3D.new()
	sb.name = "TerrainBody"
	sb.collision_layer = 1
	sb.add_to_group("nav_source")
	sb.set_meta("surface", "rock")
	var cs := CollisionShape3D.new()
	var hs := HeightMapShape3D.new()
	hs.map_width = n
	hs.map_depth = n
	hs.map_data = heights
	cs.shape = hs
	cs.scale = Vector3(res, 1.0, res)
	sb.add_child(cs)
	parent.add_child(sb)
	sb.global_position = Vector3(origin.x, 0, origin.z)

static func ground_material() -> StandardMaterial3D:
	var m := Themes.pbr("ground_alien", Color(0.62, 0.55, 0.68), 1.0, 0.95, 0.0)
	m.vertex_color_use_as_albedo = true
	m.uv1_scale = Vector3(1, 1, 1)
	return m
