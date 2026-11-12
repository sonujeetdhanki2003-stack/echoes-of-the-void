class_name LevelBuilder
extends RefCounted
## Builds facility geometry from a 4 m cell grid using the modular kit (assets/models/env/kit_*.glb) when it is
## present and procedural stand-ins when it is not. Visuals are batched into MultiMeshes per piece; collision
## is merged boxes, so layout code never depends on the art.
##
## Rooms: {id, x, z, w, d (cells), y (floor height m), h (tiers of 4 m), floor: "solid"|"grate", ceiling: bool}
## Openings: edge between two cells -> "door" | "open" | "window" | "wall" (forced)

const CELL := 4.0
const WALL_T := 0.42
const KIT_DIR := "res://assets/models/env/"

var area: Node3D
var theme: Dictionary
var cells := {}            # Vector2i -> room id
var rooms := {}            # id -> room dict
var openings := {}         # edge key -> kind
var _mm := {}              # piece key -> Array[Transform3D]
var placed: Array = []      # 1.9.4: every kit piece as [piece, transform] (a MultiMesh cannot be read back; the scene audits use this)
var _mesh_cache := {}
var geo: Node3D            # visual root
var col: StaticBody3D      # collision root
var rng := RandomNumberGenerator.new()
var wall_edges: Array = []   # solid wall faces for dressing: {pos (floor-level centre), in, along, room, piece}
var door_edges: Array = []   # {pos, along, rooms: [a, b]}
var wall_variants := ["kit_wall", "kit_wall", "kit_wall", "kit_wall_pipes", "kit_wall_vent", "kit_wall_screen"]

func _init(a: Node3D, th: Dictionary, seed_value: int = 7) -> void:
	area = a
	theme = th
	rng.seed = seed_value
	geo = Node3D.new()
	geo.name = "Geometry"
	area.add_child(geo)
	col = StaticBody3D.new()
	col.name = "Collision"
	col.collision_layer = 1
	col.collision_mask = 0
	col.add_to_group("nav_source")
	area.add_child(col)

# ---------------------------------------------------------------- layout
func room(id: String, x: int, z: int, w: int, d: int, opts: Dictionary = {}) -> Dictionary:
	var r := {"id": id, "x": x, "z": z, "w": w, "d": d, "y": float(opts.get("y", 0.0)), "h": int(opts.get("h", 1)),
		"floor": opts.get("floor", "solid"), "ceiling": opts.get("ceiling", true), "lights": opts.get("lights", true),
		"light_color": opts.get("light_color", theme.get("light_color", Color.WHITE)), "light_energy": float(opts.get("light_energy", theme.get("light_energy", 1.0))),
		"walls": opts.get("walls", true), "variants": opts.get("variants", wall_variants), "dark": float(opts.get("dark", 0.0))}
	rooms[id] = r
	for i in w:
		for j in d:
			cells[Vector2i(x + i, z + j)] = id
	return r

func center(id: String) -> Vector3:
	var r: Dictionary = rooms[id]
	return Vector3((r["x"] + r["w"] * 0.5) * CELL, r["y"], (r["z"] + r["d"] * 0.5) * CELL)

## World position of a cell's centre (floor level of its room).
func cell_pos(cx: float, cz: float, y: float = INF) -> Vector3:
	var yy := y
	if y == INF:
		var id: Variant = cells.get(Vector2i(int(floor(cx)), int(floor(cz))))
		yy = rooms[id]["y"] if id != null else 0.0
	return Vector3((cx + 0.5) * CELL, yy, (cz + 0.5) * CELL)

## Opening on the edge between cell a and the neighbour in direction dir ("n" = -z, "s" = +z, "e" = +x, "w" = -x).
func open(a: Vector2i, dir: String, kind: String = "door") -> Vector3:
	var k := _edge_key(a, dir)
	openings[k] = kind
	return edge_center(a, dir)

func edge_center(a: Vector2i, dir: String) -> Vector3:
	var id: Variant = cells.get(a)
	var y: float = rooms[id]["y"] if id != null else 0.0
	var c := Vector3((a.x + 0.5) * CELL, y, (a.y + 0.5) * CELL)
	match dir:
		"n": c.z -= CELL * 0.5
		"s": c.z += CELL * 0.5
		"e": c.x += CELL * 0.5
		"w": c.x -= CELL * 0.5
	return c

func edge_yaw(dir: String) -> float:
	# yaw of a door placed on this edge so its -Z faces from cell a into the neighbour
	match dir:
		"n": return 0.0
		"s": return PI
		"e": return -PI * 0.5
		_: return PI * 0.5

func _edge_key(a: Vector2i, dir: String) -> String:
	match dir:
		"n": return "h:%d:%d" % [a.x, a.y]
		"s": return "h:%d:%d" % [a.x, a.y + 1]
		"w": return "v:%d:%d" % [a.x, a.y]
		_: return "v:%d:%d" % [a.x + 1, a.y]

# ---------------------------------------------------------------- build
func build() -> void:
	var done_edges := {}
	for id in rooms.keys():
		var r: Dictionary = rooms[id]
		_floor_ceiling(r)
	for cellv in cells.keys():
		var c: Vector2i = cellv
		var id: String = cells[c]
		var r: Dictionary = rooms[id]
		for dir in ["n", "s", "e", "w"]:
			var k := _edge_key(c, dir)
			if done_edges.has(k):
				continue
			done_edges[k] = true
			var nb: Vector2i = c + {"n": Vector2i(0, -1), "s": Vector2i(0, 1), "e": Vector2i(1, 0), "w": Vector2i(-1, 0)}[dir]
			var nid: Variant = cells.get(nb)
			var kind: String = openings.get(k, "")
			if nid != null and nid == id and kind == "":
				continue  # interior of a room
			if kind == "":
				kind = "wall"
			var nr: Variant = rooms.get(nid) if nid != null else null
			if not r["walls"] and (nr == null or not nr["walls"]):
				continue
			var y0: float = r["y"]
			var top: float = r["y"] + r["h"] * CELL
			if nr != null:
				y0 = minf(y0, nr["y"])
				top = maxf(top, nr["y"] + nr["h"] * CELL)
				if kind == "open":
					# a wide opening between rooms of different heights still needs the step face
					if absf(r["y"] - nr["y"]) > 0.05:
						_wall_strip(c, dir, y0, maxf(r["y"], nr["y"]), r)
					var low_top := minf(r["y"] + r["h"] * CELL, nr["y"] + nr["h"] * CELL)
					if top - low_top > 0.1:
						_wall_strip(c, dir, low_top, top, r)
					continue
			_edge_piece(c, dir, kind, y0, top, r, nr)
	_flush()

func _floor_ceiling(r: Dictionary) -> void:
	var x0: float = r["x"] * CELL
	var z0: float = r["z"] * CELL
	var w: float = r["w"] * CELL
	var d: float = r["d"] * CELL
	var y: float = r["y"]
	if r["floor"] != "none":
		box_collider(Vector3(x0 + w * 0.5, y - 0.25, z0 + d * 0.5), Vector3(w, 0.5, d))
		if r["floor"] == "solid":
			occluder(Vector3(x0 + w * 0.5, y - 0.3, z0 + d * 0.5), Vector3(w - 0.05, 0.2, d - 0.05))
	if r["ceiling"]:
		box_collider(Vector3(x0 + w * 0.5, y + r["h"] * CELL + 0.25, z0 + d * 0.5), Vector3(w, 0.5, d))
	for i in r["w"]:
		for j in r["d"]:
			var p := Vector3(x0 + (i + 0.5) * CELL, y, z0 + (j + 0.5) * CELL)
			var fpiece := "kit_floor_grate" if r["floor"] == "grate" else "kit_floor"
			if r["floor"] != "none":
				_add(fpiece, Transform3D(Basis(Vector3.UP, (rng.randi() % 4) * PI * 0.5), p))
			if r["ceiling"]:
				var lit: bool = r["lights"] and ((i + j) % 2 == 0)
				_add("kit_ceiling" if lit else "kit_ceiling_plain", Transform3D(Basis(Vector3.UP, PI * 0.5 * ((i) % 2)), p + Vector3.UP * (r["h"] - 1) * CELL))

## Kit walls show their detailed face on local +Z. Turn that face toward the cell `dir` is relative to.
func _wall_basis(dir: String) -> Basis:
	match dir:
		"n": return Basis(Vector3.UP, 0.0)
		"s": return Basis(Vector3.UP, PI)
		"w": return Basis(Vector3.UP, PI * 0.5)
		_: return Basis(Vector3.UP, -PI * 0.5)

func _opposite(dir: String) -> String:
	return {"n": "s", "s": "n", "e": "w", "w": "e"}[dir]

func _edge_piece(c: Vector2i, dir: String, kind: String, y0: float, top: float, r: Dictionary, nr: Variant = null) -> void:
	var ec := edge_center(c, dir)
	ec.y = y0
	var b := _wall_basis(dir)
	var b2 := _wall_basis(_opposite(dir))
	var inward := b.z * 0.02     # shared walls: two back-to-back panels, each nudged toward its own room
	var along := Vector3.RIGHT if dir in ["n", "s"] else Vector3.BACK
	var normal := Vector3.BACK if dir in ["n", "s"] else Vector3.RIGHT
	var tiers := int(round((top - y0) / CELL))
	for t in maxi(1, tiers):
		var yy := y0 + t * CELL
		var xf := Transform3D(b, ec + Vector3.UP * yy - Vector3.UP * y0 * 0.0)
		xf.origin.y = yy
		if t == 0 and kind == "door":
			_add("kit_door_frame", xf)
			door_edges.append({"pos": xf.origin, "along": b.x, "in": b.z, "rooms": [r["id"], (nr as Dictionary)["id"] if nr != null else ""]})
			# posts and lintel collision (opening 2.4 wide x 3 tall)
			var post_w := (CELL - 2.4) * 0.5
			for s in [-1.0, 1.0]:
				box_collider(xf.origin + along * s * (1.2 + post_w * 0.5) + Vector3.UP * CELL * 0.5, _sz(along, normal, post_w, CELL))
			box_collider(xf.origin + along * 0.0 + Vector3.UP * 3.5, _sz(along, normal, 2.4, 1.0))
		elif t == 0 and kind == "window":
			_add("kit_wall_window", xf)
			box_collider(xf.origin + Vector3.UP * CELL * 0.5, _sz(along, normal, CELL, CELL))
		elif t == 0 and kind == "vent":
			_add("kit_wall_vent", xf)
			box_collider(xf.origin + Vector3.UP * CELL * 0.5, _sz(along, normal, CELL, CELL))
		else:
			var variants: Array = r["variants"]
			var piece: String = variants[rng.randi() % variants.size()] if t == 0 else "kit_wall_upper"
			piece = _maybe_damaged(piece, r, c, dir)
			_add(piece, Transform3D(b, xf.origin + inward))
			if piece == "kit_wall_damaged":
				_damaged_collider(xf.origin, b, along, normal)
			if t == 0 and r["walls"]:
				wall_edges.append({"pos": Vector3(xf.origin.x, r["y"], xf.origin.z), "in": b.z, "along": b.x, "room": r["id"], "piece": piece})
			if nr != null:
				var variants2: Array = (nr as Dictionary)["variants"]
				var piece2: String = variants2[rng.randi() % variants2.size()] if t == 0 else "kit_wall_upper"
				piece2 = _maybe_damaged(piece2, nr, c, dir)
				_add(piece2, Transform3D(b2, xf.origin - inward))
				if piece2 == "kit_wall_damaged":
					_damaged_collider(xf.origin, b2, along, normal)
				if t == 0 and (nr as Dictionary)["walls"]:
					wall_edges.append({"pos": Vector3(xf.origin.x, (nr as Dictionary)["y"], xf.origin.z), "in": b2.z, "along": b2.x, "room": (nr as Dictionary)["id"], "piece": piece2})
			box_collider(xf.origin + Vector3.UP * CELL * 0.5, _sz(along, normal, CELL, CELL))
			occluder(xf.origin + Vector3.UP * CELL * 0.5, _sz(along, normal, CELL - 0.05, CELL - 0.05))

## Some plain walls become the damaged variant (torn plates + crystal growth), at the area theme's rate.
## Used sparingly: at most DAMAGED_MAX per area, and never on a wall section beside a door frame (the torn plates
## and crystals would crowd the doorway). The rng draw happens whether or not the wall qualifies, so the rest of the
## layout (wall variants, dressing) stays the same as before the cap.
const DAMAGED_MAX := 3
var damaged_count := 0
func _maybe_damaged(piece: String, r: Dictionary, c: Vector2i = Vector2i.ZERO, dir: String = "") -> String:
	if piece != "kit_wall" or not r["walls"] or float(r.get("dark", 0.0)) > 0.5:
		return piece
	if rng.randf() < float(theme.get("damaged", 0.0)) and ResourceLoader.exists(KIT_DIR + "kit_wall_damaged.glb"):
		if damaged_count >= DAMAGED_MAX or (dir != "" and _beside_door(c, dir)):
			return piece
		damaged_count += 1
		return "kit_wall_damaged"
	return piece

## True when the wall section next to this one (same wall line, one cell either way) is a door.
func _beside_door(c: Vector2i, dir: String) -> bool:
	var step := Vector2i(1, 0) if dir in ["n", "s"] else Vector2i(0, 1)
	for nb in [c - step, c + step]:
		if openings.get(_edge_key(nb, dir), "") == "door":
			return true
	return false

## The torn plates and crystals stick up to 0.58 m into the room: block them so the player can't stand inside.
## Tear area from the model (Blender x -0.5..1.45, z 0.76..3.07) = local x -0.5..1.45, y 0.76..3.07; the box runs
## from the wall face (local z 0.15) 0.5 m into the room.
func _damaged_collider(o: Vector3, b: Basis, along: Vector3, normal: Vector3) -> void:
	box_collider(o + b.x * 0.475 + Vector3.UP * 1.915 + b.z * 0.40, _dmg_size(along, normal))

func _dmg_size(along: Vector3, normal: Vector3) -> Vector3:
	# 1.95 m along the wall, 0.5 m deep, 2.31 m tall
	return (along.abs() * 1.95 + normal.abs() * 0.5 + Vector3.UP * 2.31)

func _wall_strip(c: Vector2i, dir: String, y0: float, y1: float, _r: Dictionary) -> void:
	var ec := edge_center(c, dir)
	var along := Vector3.RIGHT if dir in ["n", "s"] else Vector3.BACK
	var normal := Vector3.BACK if dir in ["n", "s"] else Vector3.RIGHT
	var h := y1 - y0
	box(Vector3(ec.x, y0 + h * 0.5, ec.z), _sz(along, normal, CELL, h), "Dark", true)

func _sz(along: Vector3, normal: Vector3, w: float, h: float) -> Vector3:
	return along.abs() * w + normal.abs() * WALL_T + Vector3.UP * h

## Occlusion culling (Post-PRD Phase 10): solid wall and floor slabs are box occluders, so rooms behind walls
## and decks below floors are not drawn. Enabled by rendering/occlusion_culling/use_occlusion_culling.
var _occ_root: Node3D
var _occ_enabled: int = -1
func occluder(center: Vector3, size: Vector3) -> void:
	# the web export is built without occlusion culling (project setting .web=false): adding occluders there only warns
	if _occ_enabled < 0:
		_occ_enabled = 1 if bool(ProjectSettings.get_setting("rendering/occlusion_culling/use_occlusion_culling", true)) else 0
	if _occ_enabled == 0:
		return
	if _occ_root == null:
		_occ_root = Node3D.new()
		_occ_root.name = "Occluders"
		area.add_child(_occ_root)
	var oi := OccluderInstance3D.new()
	var bo := BoxOccluder3D.new()
	bo.size = Vector3(maxf(size.x, 0.1), maxf(size.y, 0.1), maxf(size.z, 0.1))
	oi.occluder = bo
	_occ_root.add_child(oi)
	oi.position = center

func box_collider(center: Vector3, size: Vector3, parent: Node3D = null) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	(parent if parent else col).add_child(cs)
	cs.position = center
	return cs

## A solid box with a theme material (cover blocks, platforms, step faces).
func box(center: Vector3, size: Vector3, mat_key: String = "Panel", collide: bool = true, yaw: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(mat_key)
	geo.add_child(mi)
	mi.position = center
	mi.rotation.y = yaw
	if collide:
		var cs := box_collider(center, size)
		cs.rotation.y = yaw
	return mi

func mat(key: String) -> Material:
	var mats: Dictionary = theme.get("materials", {})
	if mats.has(key):
		return mats[key]
	return mats.get("Panel", StandardMaterial3D.new())

# ---------------------------------------------------------------- batching
func _add(piece: String, xf: Transform3D) -> void:
	if not _mm.has(piece):
		_mm[piece] = []
	_mm[piece].append(xf)
	placed.append([piece, xf])

## Kit pieces are batched per piece type AND per 12 m chunk (Post-PRD Phase 10 draw-call/culling pass): one
## area-wide MultiMesh can't be frustum-, occlusion- or shadow-culled, so every light's shadow pass drew the
## whole level. Chunks keep the draw count low while letting the renderer skip what is off-screen.
const CHUNK := 12.0
const NO_SHADOW := ["wall_vent", "wall_panel_access", "fire_ext_cabinet", "cable_run_wall"]
func _flush() -> void:
	for piece in _mm.keys():
		var all: Array = _mm[piece]
		var mesh := piece_mesh(piece)
		if mesh == null:
			continue
		# 1.9.4 (bugs 4, 14): a piece's transparent surfaces (window panes) go in their own batch and cast no shadow
		var parts := _piece_parts(piece, mesh)
		for part in parts:
			var pm: Mesh = part[0]
			var glass: bool = part[1]
			var chunks := {}
			for xf in all:
				var o: Vector3 = (xf as Transform3D).origin
				var key := Vector3i(floori(o.x / CHUNK), floori(o.y / 6.0), floori(o.z / CHUNK))
				if not chunks.has(key):
					chunks[key] = []
				chunks[key].append(xf)
			for key in chunks.keys():
				var xfs: Array = chunks[key]
				var mm := MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = pm
				mm.instance_count = xfs.size()
				for i in xfs.size():
					mm.set_instance_transform(i, xfs[i])
				var mmi := MultiMeshInstance3D.new()
				mmi.name = "MM_%s%s_%d_%d_%d" % [piece, "_glass" if glass else "", key.x, key.y, key.z]
				mmi.multimesh = mm
				mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if (glass or piece in NO_SHADOW) else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				geo.add_child(mmi)
	_mm.clear()

var _part_cache := {}
## [[mesh, is_glass], ...]: the opaque part of a piece and, when it has one, its transparent part.
func _piece_parts(piece: String, mesh: Mesh) -> Array:
	if _part_cache.has(piece):
		return _part_cache[piece]
	var out := [[mesh, false]]
	var am := mesh as ArrayMesh
	if am != null and am.get_blend_shape_count() == 0:
		var mats: Array = []
		for s in am.get_surface_count():
			mats.append(am.surface_get_material(s))
		var parts := Props.split_mesh(am, mats)
		if parts[1] != null:
			out = []
			if parts[0] != null:
				out.append([parts[0], false])
			out.append([parts[1], true])
	_part_cache[piece] = out
	return out

## The mesh for a kit piece: the GLB's mesh with the area theme's materials applied by slot name, or a stand-in.
func piece_mesh(piece: String) -> Mesh:
	if _mesh_cache.has(piece):
		return _mesh_cache[piece]
	var m: Mesh = null
	var path := KIT_DIR + piece + ".glb"
	if not ResourceLoader.exists(path):
		# a missing wall/ceiling variant borrows the base piece rather than mixing in a stand-in
		if piece.begins_with("kit_wall") and piece != "kit_wall_window" and ResourceLoader.exists(KIT_DIR + "kit_wall.glb"):
			path = KIT_DIR + "kit_wall.glb"
		elif piece == "kit_ceiling_plain" and ResourceLoader.exists(KIT_DIR + "kit_ceiling.glb"):
			path = KIT_DIR + "kit_ceiling.glb"
	if ResourceLoader.exists(path):
		m = _mesh_from_glb(path)
	if m == null:
		m = KitFallback.make(piece, self)
	if m:
		m = _theme_mesh(m)
		if piece == "kit_wall_damaged":
			m = _animate_damaged(m)
	_mesh_cache[piece] = m
	return m

## The damaged wall's own copies of EmitLight (flickers: a failing strip) and EmitCrystal (slow pulse), so the
## intact walls' lights stay steady. One EmissiveAnim node per area drives them (shared by every instance).
func _animate_damaged(m: Mesh) -> Mesh:
	var anim := EmissiveAnim.new()
	anim.name = "DamagedWallEmissive"
	for s in m.get_surface_count():
		var nm := (m as ArrayMesh).surface_get_name(s) if m is ArrayMesh else ""
		var cur := m.surface_get_material(s) as BaseMaterial3D
		if cur == null or not cur.emission_enabled:
			continue
		if nm.begins_with("EmitLight"):
			var ml := cur.duplicate() as BaseMaterial3D
			m.surface_set_material(s, ml)
			anim.add(ml, "flicker")
		elif nm.begins_with("EmitCrystal"):
			var mc := cur.duplicate() as BaseMaterial3D
			m.surface_set_material(s, mc)
			anim.add(mc, "pulse")
	if anim.count() > 0:
		geo.add_child(anim)
	else:
		anim.free()
	return m

func _mesh_from_glb(path: String) -> Mesh:
	var ps: PackedScene = load(path)
	if ps == null:
		return null
	var inst := ps.instantiate()
	var meshes := inst.find_children("*", "MeshInstance3D", true, false)
	if meshes.is_empty():
		inst.free()
		return null
	# merge every mesh instance into one ArrayMesh in the piece's local space
	var am := ArrayMesh.new()
	var by_mat := {}
	for mi_node in meshes:
		var mi := mi_node as MeshInstance3D
		var xf := _rel_xform(inst, mi)
		for s in mi.mesh.get_surface_count():
			var mt: Material = mi.get_active_material(s)
			var key := mt.resource_name if mt else "none"
			if not by_mat.has(key):
				var st := SurfaceTool.new()
				st.begin(Mesh.PRIMITIVE_TRIANGLES)
				by_mat[key] = [st, mt]
			(by_mat[key][0] as SurfaceTool).append_from(mi.mesh, s, xf)
	for key in by_mat.keys():
		var st: SurfaceTool = by_mat[key][0]
		st.commit(am)
		am.surface_set_material(am.get_surface_count() - 1, by_mat[key][1])
		am.surface_set_name(am.get_surface_count() - 1, key)
	inst.free()
	return am

func _rel_xform(root: Node, n: Node3D) -> Transform3D:
	var xf := n.transform
	var p := n.get_parent()
	while p and p != root:
		if p is Node3D:
			xf = (p as Node3D).transform * xf
		p = p.get_parent()
	return xf

func _theme_mesh(m: Mesh) -> Mesh:
	var mats: Dictionary = theme.get("materials", {})
	if mats.is_empty():
		return m
	var out: Mesh = m.duplicate()
	for s in out.get_surface_count():
		var nm := ""
		if out is ArrayMesh:
			nm = (out as ArrayMesh).surface_get_name(s)
		var cur := out.surface_get_material(s)
		if nm == "" and cur:
			nm = cur.resource_name
		if mats.has(nm):
			out.surface_set_material(s, mats[nm])
			continue
		for key in ["PanelAlt", "Panel", "Trim", "Floor", "Dark", "Metal", "Accent", "Hazard", "Rubber", "Grate", "EmitLight", "Glass", "Screen", "EmitDoor"]:
			if nm.begins_with(key) and mats.has(key):
				out.surface_set_material(s, mats[key])
				break
	return out
