class_name Dressing
extends RefCounted
## Interior dressing pass (realism review: "plain flat panels — add grime, decals, cables and contrast"). Runs after an
## area's build() on the solid wall faces the LevelBuilder recorded:
##  - wall dressing models (cable runs, pipe runs, vents, access panels, fire cabinets) batched into the kit MultiMeshes;
##  - ceiling cable sags;
##  - Godot Decals: baseboard dust, leak streaks, floor stains, scorch, crystal residue, drag marks, hazard tape at doors,
##    zone signs near the area entrance, O2 labels / deck numbers / arrows beside doors, the ORPHEUS logo in hubs.
## Everything is seeded from the area, so the same area always dresses the same way. The Compatibility renderer (web)
## has no decals; they are simply not drawn there.

const DECAL_DIR := "res://assets/textures/decals/"
const SIGN := {"cryo": "sign_cryo_bay_01", "research": "sign_research_lab_b", "security": "sign_security_checkpoint", "reactor": "sign_reactor_core"}
static var _tex := {}
static var _info := {}

static func dress(area: Node3D, b: LevelBuilder, theme_id: String, seed_value: int) -> Dictionary:
	var stats := {"models": 0, "decals": 0}
	if b == null or b.wall_edges.is_empty():
		return stats
	_load_info()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 7919 + 17
	var holder := Node3D.new()
	holder.name = "Dressing"
	area.add_child(holder)
	var infected := theme_id in ["research", "reactor"]
	var industrial := theme_id in ["security", "reactor"]
	var near_door := {}
	for d in b.door_edges:
		for w in b.wall_edges:
			var dd: float = (w["pos"] as Vector3).distance_to(d["pos"])
			if dd < LevelBuilder.CELL + 0.2 and absf((w["in"] as Vector3).dot(d["in"])) > 0.9:
				near_door[b.wall_edges.find(w)] = (d["pos"] as Vector3)
	var fire_rooms := {}
	for i in b.wall_edges.size():
		var w: Dictionary = b.wall_edges[i]
		if w["piece"] == "kit_wall_damaged":
			# crystal growth spills onto the floor under the tear
			_floor_decal(holder, (w["pos"] as Vector3) + (w["in"] as Vector3) * 0.9 + (w["along"] as Vector3) * 0.4, "crystal_residue", rng.randf() * TAU, stats)
			_wall_decal(holder, w, "scorch_mark", 0.4, 1.9, 2.6, 2.6, 0.7, stats)
			continue
		if w["piece"] != "kit_wall":
			# pipe / screen / vent variants already carry their own detail: only grime them
			if rng.randf() < 0.55:
				_wall_decal(holder, w, "corner_ao_dust", 0.0, 0.5, 4.0, 1.0, 0.85, stats)
			continue
		var top := float((b.rooms[w["room"]] as Dictionary)["h"]) * LevelBuilder.CELL
		# baseboard dust on most walls, leak streaks under the ceiling on some
		if rng.randf() < 0.8:
			_wall_decal(holder, w, "corner_ao_dust", 0.0, 0.5, 4.0, 1.0, 0.9, stats)
		if rng.randf() < 0.3:
			var leak := "grime_leak_a" if rng.randf() < 0.5 else "grime_leak_b"
			var lw := 1.0 if leak == "grime_leak_a" else 1.2
			_wall_decal(holder, w, leak, rng.randf_range(-1.2, 1.2), minf(top, 4.0) - 1.3, lw, lw * 2.0, 0.9, stats)
		# one wall item at most, so walls stay readable
		var roll := rng.randf()
		var door_pos: Variant = near_door.get(i)
		if door_pos != null:
			# beside a door: O2 label at eye height on the door side, sometimes a deck number / arrows
			var side := 1.0 if ((door_pos as Vector3) - (w["pos"] as Vector3)).dot(w["along"]) > 0.0 else -1.0
			_wall_decal(holder, w, "label_o2_level", side * 1.25, 1.55, 0.4, 0.2, 1.0, stats)
			if rng.randf() < 0.45:
				_wall_decal(holder, w, "sign_deck_3" if rng.randf() < 0.5 else "sign_wayfinding_arrows", -side * 0.6, 2.2, 0.6, 0.6, 1.0, stats)
			if industrial and rng.randf() < 0.5:
				_wall_decal(holder, w, "stencil_authorized_only", -side * 0.4, 1.3, 1.2, 0.6, 0.9, stats)
		elif not fire_rooms.has(w["room"]) and roll < 0.18:
			fire_rooms[w["room"]] = true
			_model(b, w, "fire_ext_cabinet", 1.1, 1.0, stats)
			_wall_decal(holder, w, "sign_fire_extinguisher", 1.1, 2.15, 0.3, 0.6, 1.0, stats)
		elif roll < 0.42:
			_model(b, w, "cable_run_wall", -2.0, minf(top, 4.0) - 0.75, stats)
		elif roll < 0.58 and industrial:
			_model(b, w, "pipe_run_wall", -2.0, minf(top, 4.0) - 1.25, stats)
		elif roll < 0.68:
			_model(b, w, "wall_vent", rng.randf_range(-1.0, 1.0), 0.42, stats)
		elif roll < 0.78:
			_model(b, w, "wall_panel_access", rng.randf_range(-0.9, 0.9), 1.25, stats)
	# rooms: ceiling cables, floor stains, residue, scorch, drag marks
	for id in b.rooms.keys():
		var r: Dictionary = b.rooms[id]
		if not r["walls"]:
			continue
		var cells: int = int(r["w"]) * int(r["d"])
		var ceil_y: float = float(r["y"]) + float(r["h"]) * LevelBuilder.CELL
		if r["ceiling"]:
			for k in mini(3, maxi(1, cells / 3)):
				if rng.randf() < 0.6:
					var p := _room_point(r, rng, 0.8)
					p.y = ceil_y
					b._add("cable_sag", Transform3D(Basis(Vector3.UP, rng.randf() * PI), p))
					stats["models"] += 1
		var n_floor := clampi(cells / 2, 1, 4)
		for k in n_floor:
			var x := rng.randf()
			var kind := "floor_stain_water"
			if industrial and x < 0.45:
				kind = "floor_stain_oil"
			elif infected and x < 0.55:
				kind = "crystal_residue"
			elif x < 0.62 and theme_id != "cryo":
				kind = "scorch_mark"
			elif x < 0.72:
				kind = "footprints_drag"
			elif x > 0.9:
				continue
			_floor_decal(holder, _room_point(r, rng, 1.0), kind, rng.randf() * TAU, stats)
	# corner trim columns where two plain walls of a room meet; a catwalk ring high in tall halls (reactor ring)
	var plain := {}
	for w in b.wall_edges:
		var pp: Vector3 = w["pos"]
		plain["%s|%d|%d" % [w["room"], roundi(pp.x * 2.0), roundi(pp.z * 2.0)]] = true
	var C := LevelBuilder.CELL
	for id in b.rooms.keys():
		var r: Dictionary = b.rooms[id]
		if not r["walls"]:
			continue
		var x0: float = float(r["x"]) * C
		var z0: float = float(r["z"]) * C
		var x1: float = float(r["x"] + r["w"]) * C
		var z1: float = float(r["z"] + r["d"]) * C
		for cx in [[x0, 1.0], [x1, -1.0]]:
			for cz in [[z0, 1.0], [z1, -1.0]]:
				var ex: float = cx[0] + cx[1] * C * 0.5     # centre of the edge running along X from this corner
				var ez: float = cz[0] + cz[1] * C * 0.5
				if plain.has("%s|%d|%d" % [id, roundi(ex * 2.0), roundi(cz[0] * 2.0)]) and plain.has("%s|%d|%d" % [id, roundi(cx[0] * 2.0), roundi(ez * 2.0)]):
					for t in int(r["h"]):
						b._add("kit_corner", Transform3D(Basis(), Vector3(cx[0] + cx[1] * 0.16, float(r["y"]) + t * C, cz[0] + cz[1] * 0.16)))
						stats["models"] += 1
		if int(r["h"]) >= 3:
			var cy: float = float(r["y"]) + 8.0
			for i in int(r["w"]):
				for zz in [[z0, 1.0], [z1, -1.0]]:
					b._add("kit_catwalk", Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x0 + (i + 0.5) * C, cy, zz[0] + zz[1] * 1.12)))
					stats["models"] += 1
			for k in int(r["d"]):
				for xx in [[x0, 1.0], [x1, -1.0]]:
					b._add("kit_catwalk", Transform3D(Basis(), Vector3(xx[0] + xx[1] * 1.12, cy + 0.01, z0 + (k + 0.5) * C)))
					stats["models"] += 1
	# hazard tape across every door threshold, both sides
	for d in b.door_edges:
		for s in [-1.0, 1.0]:
			var p: Vector3 = (d["pos"] as Vector3) + (d["in"] as Vector3) * 0.55 * s
			var yaw := atan2((d["along"] as Vector3).z, (d["along"] as Vector3).x)
			_floor_decal(holder, p, "hazard_tape", -yaw, stats, Vector2(2.4, 0.25))
	# zone sign + logo: on the plain wall nearest the area's first checkpoint, facing into the room
	var cps: Dictionary = area.get("checkpoints")
	if SIGN.has(theme_id) and cps and not cps.is_empty():
		var start: Vector3 = (cps.values()[0] as Transform3D).origin
		var best := -1
		var bd := INF
		for i in b.wall_edges.size():
			var w: Dictionary = b.wall_edges[i]
			var dd := (w["pos"] as Vector3).distance_to(start)
			if w["piece"] == "kit_wall" and dd < bd:
				bd = dd
				best = i
		if best >= 0:
			_wall_decal(holder, b.wall_edges[best], SIGN[theme_id], 0.0, 2.35, 1.2, 0.6, 1.0, stats)
			_wall_decal(holder, b.wall_edges[best], "hazard_tape", 0.0, 1.85, 4.0, 0.25, 1.0, stats)
		# the station logo on the widest room's far wall
		var big := ""
		var area_max := 0
		for id in b.rooms.keys():
			var rr: Dictionary = b.rooms[id]
			if rr["walls"] and int(rr["w"]) * int(rr["d"]) > area_max:
				area_max = int(rr["w"]) * int(rr["d"])
				big = id
		for w in b.wall_edges:
			if w["room"] == big and w["piece"] == "kit_wall" and (w["pos"] as Vector3).distance_to(start) > 8.0:
				_wall_decal(holder, w, "logo_orpheus", 0.0, 2.2, 1.4, 1.4, 0.9, stats)
				break
	return stats

static func _room_point(r: Dictionary, rng: RandomNumberGenerator, margin: float) -> Vector3:
	var x0: float = float(r["x"]) * LevelBuilder.CELL + margin
	var z0: float = float(r["z"]) * LevelBuilder.CELL + margin
	var x1: float = float(r["x"] + r["w"]) * LevelBuilder.CELL - margin
	var z1: float = float(r["z"] + r["d"]) * LevelBuilder.CELL - margin
	return Vector3(rng.randf_range(x0, x1), float(r["y"]), rng.randf_range(z0, z1))

## A dressing model on a wall face: `off` metres along the wall from its centre, origin `h` metres above the floor.
static func _model(b: LevelBuilder, w: Dictionary, piece: String, off: float, h: float, stats: Dictionary) -> void:
	var inn: Vector3 = w["in"]
	var along: Vector3 = w["along"]
	var basis := Basis(along, Vector3.UP, inn)
	var pos: Vector3 = (w["pos"] as Vector3) + inn * 0.22 + along * off + Vector3.UP * h
	b._add(piece, Transform3D(basis, pos))
	stats["models"] += 1

static func _load_info() -> void:
	if not _info.is_empty():
		return
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(DECAL_DIR + "decals.json"))
	if j is Dictionary and j.has("decals"):
		for d in j["decals"]:
			_info[str(d["file"]).get_basename().get_file()] = d

static func _tex_of(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path) if ResourceLoader.exists(path) else null
	return _tex[path]

static func _decal(name: String) -> Decal:
	var albedo := _tex_of(DECAL_DIR + name + ".png")
	if albedo == null:
		return null
	var d := Decal.new()
	d.texture_albedo = albedo
	d.texture_normal = _tex_of(DECAL_DIR + name + "_normal.png")
	d.texture_orm = _tex_of(DECAL_DIR + name + "_orm.png")
	var em := _tex_of(DECAL_DIR + name + "_emission.png")
	if em:
		d.texture_emission = em
		d.emission_energy = 0.9
	d.upper_fade = 0.0
	d.lower_fade = 0.0
	d.distance_fade_enabled = true
	d.distance_fade_begin = 28.0
	d.distance_fade_length = 8.0
	d.cull_mask = 1
	return d

## A decal on a wall: centred `off` along the wall, `cy` above the floor, w x h metres.
static func _wall_decal(holder: Node3D, w: Dictionary, name: String, off: float, cy: float, dw: float, dh: float, mix: float, stats: Dictionary) -> void:
	var d := _decal(name)
	if d == null:
		return
	d.albedo_mix = mix
	var inn: Vector3 = w["in"]
	var along: Vector3 = w["along"]
	d.size = Vector3(dw, 0.32, dh)
	holder.add_child(d)
	# local +Y = out of the wall (the decal projects along -Y into it); local Z = down so the texture is upright
	d.global_transform = Transform3D(Basis(along, inn, Vector3.DOWN), (w["pos"] as Vector3) + inn * 0.2 + along * off + Vector3.UP * cy)
	stats["decals"] += 1

static func _floor_decal(holder: Node3D, p: Vector3, name: String, yaw: float, stats: Dictionary, size := Vector2.ZERO) -> void:
	var d := _decal(name)
	if d == null:
		return
	var sz := size
	if sz == Vector2.ZERO:
		var inf: Dictionary = _info.get(name, {})
		var s: Array = inf.get("size_m", [1.5, 1.5])
		sz = Vector2(float(s[0]), float(s[1]))
	d.size = Vector3(sz.x, 0.24, sz.y)
	d.albedo_mix = 0.9
	holder.add_child(d)
	d.global_transform = Transform3D(Basis(Vector3.UP, yaw), p + Vector3.UP * 0.02)
	stats["decals"] += 1
