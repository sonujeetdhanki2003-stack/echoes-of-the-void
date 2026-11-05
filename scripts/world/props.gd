class_name Props
extends RefCounted
## Environment props from assets/models/env/<name>.glb with automatic box collision from their bounds.
## A missing model becomes a neutral stand-in of the right size, so levels are playable before the art lands.

const DIR := "res://assets/models/env/"
const SIZES := {
	"cryo_pod": Vector3(1.3, 2.4, 1.2), "med_bed": Vector3(1.0, 0.9, 2.2), "med_cabinet": Vector3(1.2, 2.0, 0.5),
	"lab_table": Vector3(2.0, 0.95, 0.9), "lab_table_clutter": Vector3(2.0, 1.2, 0.9), "lab_equipment": Vector3(1.0, 1.4, 0.8),
	"containment_tube": Vector3(1.4, 3.0, 1.4), "containment_tube_broken": Vector3(1.6, 3.0, 1.6), "terminal": Vector3(0.9, 1.3, 0.7),
	"console_large": Vector3(3.0, 1.3, 1.1), "server_rack": Vector3(0.8, 2.2, 1.0), "generator": Vector3(2.2, 2.5, 1.6),
	"keypad_panel": Vector3(0.35, 0.5, 0.12), "door_panel": Vector3(0.3, 0.45, 0.12), "conduit_console": Vector3(3.0, 2.2, 0.5),
	"crate_small": Vector3(0.8, 0.7, 0.8), "crate_large": Vector3(1.6, 1.4, 1.6), "barrel": Vector3(0.7, 1.0, 0.7),
	"locker": Vector3(0.7, 2.0, 0.6), "chair": Vector3(0.6, 1.0, 0.6), "desk": Vector3(1.6, 0.8, 0.8), "monitor": Vector3(0.6, 0.45, 0.2),
	"pipe_straight": Vector3(0.4, 0.4, 4.0), "pipe_bend": Vector3(1.0, 1.0, 1.0), "cable_bundle": Vector3(3.0, 0.15, 0.6),
	"wall_lamp": Vector3(0.4, 0.3, 0.25), "ceiling_lamp": Vector3(0.6, 0.4, 0.6), "fallen_beam": Vector3(4.0, 0.6, 0.6),
	"debris_pile": Vector3(2.5, 1.0, 2.0), "security_gate": Vector3(6.4, 5.0, 0.8), "turret_broken": Vector3(1.0, 1.3, 1.0),
	"comms_console": Vector3(2.0, 1.4, 1.0), "reactor_core": Vector3(6.0, 16.0, 6.0), "cargo_lift": Vector3(6.0, 0.6, 6.0),
	"medkit": Vector3(0.4, 0.25, 0.3), "ammo_pistol": Vector3(0.25, 0.15, 0.15), "ammo_rifle": Vector3(0.35, 0.18, 0.2),
	"datapad": Vector3(0.25, 0.03, 0.18), "keycard": Vector3(0.09, 0.01, 0.06),
	"the_spire": Vector3(14.0, 60.0, 14.0), "crystal_cluster_a": Vector3(2.0, 2.5, 2.0), "crystal_cluster_b": Vector3(3.0, 4.0, 3.0),
	"crystal_cluster_c": Vector3(1.4, 1.6, 1.4), "alien_plant_a": Vector3(1.2, 1.5, 1.2), "alien_plant_b": Vector3(0.8, 2.0, 0.8),
	"alien_plant_c": Vector3(1.5, 0.8, 1.5), "alien_rock_a": Vector3(6.0, 4.0, 5.0), "alien_rock_b": Vector3(4.0, 6.0, 4.0),
	"alien_rock_c": Vector3(10.0, 5.0, 8.0), "alien_rock_d": Vector3(3.0, 2.0, 3.0), "satellite_dish": Vector3(10.0, 10.0, 10.0),
	"landing_pad": Vector3(32.0, 0.6, 32.0), "shuttle": Vector3(9.0, 5.0, 16.0), "habitat_module": Vector3(12.0, 6.0, 10.0),
	"antenna_mast": Vector3(1.0, 14.0, 1.0), "cargo_containers": Vector3(6.0, 2.6, 2.5), "kit_pillar": Vector3(0.8, 4.0, 0.8),
	"corpse_sitting": Vector3(0.8, 1.0, 1.0), "corpse_prone": Vector3(0.8, 0.4, 1.9), "crystal_figure": Vector3(1.6, 2.4, 1.6),
}
## Hand-fitted collision for props whose bounding box would be wrong (towers, open frames, round decks).
## Each entry: ["box", size, centre] or ["cyl", Vector2(radius, height), centre], in Godot model space.
const CUSTOM := {
	"landing_pad": [["cyl", Vector2(16.0, 0.4), Vector3(0, 0.2, 0)], ["box", Vector3(2.0, 5.2, 2.0), Vector3(0, 2.6, -16.6)]],
	"cargo_lift": [["box", Vector3(0.5, 8.4, 0.5), Vector3(-3.3, 4.2, -3.3)], ["box", Vector3(0.5, 8.4, 0.5), Vector3(3.3, 4.2, -3.3)],
		["box", Vector3(0.5, 8.4, 0.5), Vector3(-3.3, 4.2, 3.3)], ["box", Vector3(0.5, 8.4, 0.5), Vector3(3.3, 4.2, 3.3)]],
	"security_gate": [["box", Vector3(0.8, 5.0, 1.0), Vector3(-2.6, 2.5, 0)], ["box", Vector3(0.8, 5.0, 1.0), Vector3(2.6, 2.5, 0)], ["box", Vector3(6.0, 1.1, 1.0), Vector3(0, 4.45, 0)]],
	"habitat_module": [["box", Vector3(6.4, 6.0, 14.0), Vector3(0, 5.0, -3.0)], ["box", Vector3(5.2, 4.6, 4.6), Vector3(0, 2.3, 10.8)]],
	"shuttle": [["box", Vector3(5.0, 3.6, 15.0), Vector3(0, 3.4, 0)], ["box", Vector3(0.5, 2.0, 0.5), Vector3(3.25, 1.0, 3.0)],
		["box", Vector3(0.5, 2.0, 0.5), Vector3(-3.25, 1.0, 3.0)], ["box", Vector3(0.5, 2.0, 0.5), Vector3(0, 0.9, -5.55)]],
	"satellite_dish": [["box", Vector3(10.0, 0.6, 7.0), Vector3(0, 0.3, 1.5)], ["box", Vector3(3.0, 9.0, 3.0), Vector3(0, 4.5, 0)]],
	"the_spire": [["cyl", Vector2(9.0, 60.0), Vector3(0, 30.0, 0)]],
	"reactor_core": [["cyl", Vector2(3.4, 18.0), Vector3(0, 9.0, 0)]],
	"containment_tube": [["cyl", Vector2(0.7, 3.0), Vector3(0, 1.5, 0)]],
	"containment_tube_broken": [["cyl", Vector2(0.75, 1.2), Vector3(0, 0.6, 0)]],
	"cryo_pod": [["box", Vector3(1.4, 2.8, 1.4), Vector3(0, 1.4, 0)]],
	# M2 collision pass (no walking through anything solid): organic props get trimmed colliders, so the
	# invisible edge sits on the visible mass instead of the bounding box's empty corners.
	"alien_plant_a": [["cyl", Vector2(0.35, 2.0), Vector3(0, 1.0, 0)]],
	"alien_plant_b": [["cyl", Vector2(0.6, 0.7), Vector3(0, 0.35, 0)]],
	"alien_plant_c": [["cyl", Vector2(0.55, 3.0), Vector3(0, 1.5, 0)]],
	"crystal_cluster_a": [["box", Vector3(3.6, 4.0, 2.0), Vector3(0, 2.0, 0)]],
	"crystal_cluster_b": [["box", Vector3(1.3, 2.0, 1.1), Vector3(0, 1.0, 0)]],
	"crystal_cluster_c": [["box", Vector3(0.7, 0.9, 0.65), Vector3(0, 0.45, 0)]],
	"debris_pile": [["box", Vector3(1.5, 0.6, 1.4), Vector3(0, 0.3, 0)]],
	"corpse_sitting": [["box", Vector3(0.7, 0.85, 0.75), Vector3(0, 0.42, 0)]],
	"corpse_prone": [["box", Vector3(0.7, 0.4, 1.8), Vector3(0, 0.2, 0)]],
}
const NO_COLLIDE := ["medkit", "ammo_pistol", "ammo_rifle", "datapad", "keycard", "cable_bundle", "wall_lamp", "ceiling_lamp"]

static var _scenes := {}

static func model_path(name: String) -> String:
	var p := DIR + name + ".glb"
	if ResourceLoader.exists(p):
		return p
	p = "res://assets/models/" + name + ".glb"
	if ResourceLoader.exists(p):
		return p
	return ""

static func instance(name: String) -> Node3D:
	var path := model_path(name)
	if path != "":
		if not _scenes.has(path):
			_scenes[path] = load(path)
		var ps: PackedScene = _scenes[path]
		if ps:
			return ps.instantiate()
	return stand_in(name)

static func stand_in(name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var s: Vector3 = SIZES.get(name, Vector3.ONE)
	bm.size = s
	mi.mesh = bm
	mi.position.y = s.y * 0.5
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.47, 0.5)
	m.roughness = 0.7
	m.metallic = 0.3
	mi.material_override = m
	n.add_child(mi)
	return n

## Wraps the model in a StaticBody3D whose box shape fits the model's bounds.
static func make(name: String, collide: bool = true) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var inst := instance(name)
	root.add_child(inst)
	detail(inst)
	# small clutter (under ~0.9 m across) casts no shadow: dozens of tiny casters per room were drawn again in
	# every shadow pass of every light (Post-PRD Phase 10 draw-call pass); big props still ground themselves.
	var small := bounds(inst).size.length() < 0.9
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if small else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if collide and CUSTOM.has(name):
		var sb2 := StaticBody3D.new()
		sb2.collision_layer = 1
		sb2.add_to_group("nav_source")
		for c in CUSTOM[name]:
			var cs2 := CollisionShape3D.new()
			if c[0] == "cyl":
				var cy := CylinderShape3D.new()
				cy.radius = (c[1] as Vector2).x
				cy.height = (c[1] as Vector2).y
				cs2.shape = cy
			else:
				var bx := BoxShape3D.new()
				bx.size = c[1]
				cs2.shape = bx
			cs2.position = c[2]
			sb2.add_child(cs2)
		root.add_child(sb2)
	elif collide and not name in NO_COLLIDE:
		var aabb := bounds(inst)
		if aabb.size.length() > 0.05:
			var sb := StaticBody3D.new()
			sb.collision_layer = 1
			sb.add_to_group("nav_source")
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = aabb.size.max(Vector3(0.05, 0.05, 0.05))
			cs.shape = bs
			cs.position = aabb.get_center()
			sb.add_child(cs)
			root.add_child(sb)
	return root

static func bounds(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi_node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_node as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != null and cur != n:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		xf = n.transform * xf
		var a := xf * mi.mesh.get_aabb()
		if first:
			out = a
			first = false
		else:
			out = out.merge(a)
	return out

## Find a named child node in a prop (e.g. "Lid", "Fan", "Door", "LeafL").
static func part(root: Node, name: String) -> Node3D:
	return root.find_child(name, true, false) as Node3D


## Surface detail for props (M2 visual pass): the env helper's props carry flat role-named PBR constants
## (Panel, Trim, Dark, Metal, Accent...). Each role gets the matching texture set's normal + roughness (+AO)
## at 1 UV = 1 m, keeping the prop's own designed colour, so crates, consoles and machines stop reading as
## flat plastic. Materials are cached per source material, so instances share them.
const DETAIL_ROLES := {
	"Panel": ["panel_white", 0.5], "PanelAlt": ["panel_scifi", 0.5], "Trim": ["metal_dark", 0.5],
	"Dark": ["metal_dark", 0.5], "Metal": ["scratched_metal", 0.5], "Accent": ["scratched_metal", 0.5],
	"Hazard": ["hazard_clean", 0.5], "Rubber": ["rubber", 0.5], "Cable": ["rubber", 1.0], "CableColor": ["rubber", 1.0],
	"Concrete": ["concrete", 0.35], "Rock": ["rock_alien", 0.25], "Fabric": ["fabric", 1.0], "Hull": ["panel_white", 0.35],
	"HullDark": ["metal_dark", 0.35], "Plastic": ["panel_white", 0.5], "Floor": ["diamond_plate", 0.5],
	"ContainerBlue": ["scratched_metal", 0.4], "Insulation": ["fabric", 1.0], "Mattress": ["fabric", 1.0],
}
static var _detail_cache := {}

static func detail(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for i in m.mesh.get_surface_count():
			var src := m.mesh.surface_get_material(i)
			if src == null or not (src is StandardMaterial3D):
				continue
			var key := src.get_instance_id()
			if not _detail_cache.has(key):
				_detail_cache[key] = _detailed(src as StandardMaterial3D)
			if _detail_cache[key] != null:
				m.set_surface_override_material(i, _detail_cache[key])

static func _detailed(src: StandardMaterial3D) -> Material:
	var nm := src.resource_name
	var role := ""
	for r in DETAIL_ROLES.keys():
		if nm == r or nm.begins_with(r + ".") or nm.begins_with(r + "_"):
			role = r
			break
	if role == "" or src.emission_enabled or src.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or src.normal_texture != null:
		return null
	var d: Array = DETAIL_ROLES[role]
	var base := "res://assets/textures/" + str(d[0])
	var m := src.duplicate() as StandardMaterial3D
	var nt := Themes.tex(base + "_normal.jpg")
	if nt:
		m.normal_enabled = true
		m.normal_texture = nt
		m.normal_scale = 0.8
	var rt := Themes.tex(base + "_rough.jpg")
	if rt:
		m.roughness_texture = rt
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.roughness = clampf(src.roughness * 1.15, 0.2, 1.0)
	var ao := Themes.tex(base + "_ao.jpg")
	if ao:
		m.ao_enabled = true
		m.ao_texture = ao
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.ao_light_affect = 0.3
	# bright sets also lend their albedo detail (panel seams, stains); brighten the tint so the mean stays put
	if str(d[0]) in ["panel_white", "concrete"]:
		var at := Themes.tex(base + "_albedo.jpg")
		if at:
			m.albedo_texture = at
			var k := 1.18 if str(d[0]) == "panel_white" else 1.5
			m.albedo_color = Color(minf(src.albedo_color.r * k, 1.0), minf(src.albedo_color.g * k, 1.0), minf(src.albedo_color.b * k, 1.0), src.albedo_color.a)
	var uv: float = d[1]
	m.uv1_scale = Vector3(uv, uv, uv)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m
