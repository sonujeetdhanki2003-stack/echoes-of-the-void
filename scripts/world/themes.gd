class_name Themes
extends RefCounted
## Per-area look: kit materials by slot name, light colour, and environment (fog, ambient, grading).

static var _tex := {}

static func tex(path: String) -> Texture2D:
	if _tex.has(path):
		return _tex[path]
	var t: Texture2D = load(path) if ResourceLoader.exists(path) else null
	_tex[path] = t
	return t

## A PBR material from a texture set in assets/textures (name_albedo/normal/rough/ao/metal).
static func pbr(set_name: String, tint: Color = Color.WHITE, uv: float = 0.5, rough: float = 1.0, metal: float = -1.0, extra: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.resource_name = set_name
	var base := "res://assets/textures/" + set_name
	var a := tex(base + "_albedo.jpg")
	if a:
		m.albedo_texture = a
	m.albedo_color = tint
	var n := tex(base + "_normal.jpg")
	if n:
		m.normal_enabled = true
		m.normal_texture = n
		m.normal_scale = float(extra.get("normal", 1.0))
	var r := tex(base + "_rough.jpg")
	if r:
		m.roughness_texture = r
		m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.roughness = rough
	var mt := tex(base + "_metal.jpg")
	if metal >= 0.0:
		m.metallic = metal
		if mt and extra.get("metal_tex", true):
			m.metallic_texture = mt
			m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	var ao := tex(base + "_ao.jpg")
	if ao and extra.get("ao", true):
		m.ao_enabled = true
		m.ao_texture = ao
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
		m.ao_light_affect = 0.4
	m.uv1_scale = Vector3(uv, uv, uv)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if extra.get("triplanar", false):
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
	return m

static func emit(c: Color, energy: float = 3.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c.darkened(0.3)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	return m

static func glass(c: Color = Color(0.6, 0.75, 0.85, 0.18)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	# 1.9.2 (bug 4, 14): a depth pre-pass stops the front and back faces of one pane from fighting (the flicker)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	m.albedo_color = c
	m.metallic = 0.2
	m.roughness = 0.06
	m.metallic_specular = 0.8
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func screen(c: Color, energy: float = 1.6) -> StandardMaterial3D:
	var m := emit(c, energy)
	m.albedo_color = Color(0.02, 0.03, 0.04)
	return m

static func get_theme(id: String) -> Dictionary:
	var t := {}
	match id:
		"cryo":
			t = {
				"grime": 0.6, "damaged": 0.08, "grime_tint": Color(0.6, 0.6, 0.62),
				"light_color": Color(0.62, 0.8, 1.0), "light_energy": 1.3,
				"materials": {
					"Panel": pbr("panel_white", Color(0.78, 0.86, 0.95), 0.5, 0.85, 0.15),
					"PanelAlt": pbr("panel_scifi", Color(0.7, 0.8, 0.9), 0.5, 0.8, 0.3),
					"Trim": pbr("metal_dark", Color(0.55, 0.62, 0.7), 0.5, 0.7, 0.8),
					"Floor": pbr("floor_tiles", Color(0.62, 0.7, 0.78), 0.5, 0.75, 0.2),
					"Dark": pbr("metal_dark", Color(0.25, 0.3, 0.36), 0.5, 0.75, 0.7),
					"Metal": pbr("scratched_metal", Color(0.75, 0.82, 0.9), 0.5, 0.6, 0.9),
					"Accent": emit(Color(0.35, 0.75, 1.0), 1.2),
					"Hazard": pbr("hazard_clean", Color(0.85, 0.9, 1.0), 0.5, 0.7, 0.2),
					"Rubber": pbr("rubber", Color(0.2, 0.22, 0.25), 0.5, 0.9, 0.0),
					"Grate": pbr("grate", Color(0.6, 0.66, 0.72), 0.5, 0.6, 0.85),
					"Glass": glass(Color(0.7, 0.85, 1.0, 0.22)),
					"Screen": screen(Color(0.3, 0.7, 1.0)),
					"EmitLight": emit(Color(0.7, 0.88, 1.0), 4.0),
					"EmitDoor": emit(Color(0.3, 0.75, 1.0), 3.0),
				},
				"env": {"bg": Color(0.0, 0.01, 0.02), "ambient": Color(0.38, 0.52, 0.72), "ambient_energy": 0.45,
					"fog_color": Color(0.5, 0.7, 0.95), "fog_density": 0.035, "fog_emission": Color(0.04, 0.07, 0.12),
					"contrast": 1.08, "saturation": 0.82, "exposure": 1.0, "glow": 0.9, "tint": Color(0.92, 0.97, 1.05)},
				"reverb": [0.45, 0.16], "music": "music_explore", "amb": "amb_cryo",
			}
		"research":
			t = {
				"grime": 0.65, "damaged": 0.14, "grime_tint": Color(0.6, 0.57, 0.52),
				"light_color": Color(1.0, 0.98, 0.95), "light_energy": 1.5,
				"materials": {
					"Panel": pbr("panel_white", Color(0.95, 0.95, 0.94), 0.5, 0.8, 0.1),
					"PanelAlt": pbr("panel_white", Color(0.82, 0.86, 0.88), 0.5, 0.8, 0.1),
					"Trim": pbr("scratched_metal", Color(0.75, 0.77, 0.8), 0.5, 0.55, 0.85),
					"Floor": pbr("floor_rubber", Color(0.72, 0.74, 0.76), 0.5, 0.8, 0.0),
					"Dark": pbr("metal_dark", Color(0.35, 0.37, 0.4), 0.5, 0.7, 0.6),
					"Metal": pbr("scratched_metal", Color(0.85, 0.87, 0.9), 0.5, 0.5, 0.9),
					"Accent": emit(Color(0.4, 0.95, 0.85), 1.0),
					"Hazard": pbr("hazard_clean", Color.WHITE, 0.5, 0.7, 0.2),
					"Rubber": pbr("rubber", Color(0.18, 0.18, 0.2), 0.5, 0.9, 0.0),
					"Grate": pbr("grate", Color(0.75, 0.77, 0.8), 0.5, 0.6, 0.85),
					"Glass": glass(Color(0.75, 0.9, 0.95, 0.16)),
					"Screen": screen(Color(0.45, 0.95, 0.85)),
					"EmitLight": emit(Color(1.0, 0.98, 0.94), 4.5),
					"EmitDoor": emit(Color(0.4, 1.0, 0.8), 3.0),
				},
				"env": {"bg": Color(0.01, 0.01, 0.012), "ambient": Color(0.75, 0.78, 0.8), "ambient_energy": 0.35,
					"fog_color": Color(0.85, 0.88, 0.9), "fog_density": 0.018, "fog_emission": Color(0.05, 0.05, 0.055),
					"contrast": 1.05, "saturation": 0.78, "exposure": 1.0, "glow": 0.7, "tint": Color(1.0, 1.0, 1.0)},
				"reverb": [0.4, 0.13], "music": "music_explore", "amb": "amb_research",
			}
		"security":
			t = {
				"grime": 0.9, "damaged": 0.07, "grime_tint": Color(0.58, 0.55, 0.5),
				"light_color": Color(1.0, 0.68, 0.38), "light_energy": 1.5,
				"materials": {
					"Panel": pbr("metal_dark", Color(0.56, 0.58, 0.6), 0.5, 0.72, 0.55),
					"PanelAlt": pbr("panel_scifi", Color(0.55, 0.56, 0.58), 0.5, 0.72, 0.45),
					"Trim": pbr("diamond_plate", Color(0.55, 0.55, 0.55), 0.5, 0.6, 0.85),
					"Floor": pbr("diamond_plate", Color(0.62, 0.6, 0.58), 0.5, 0.6, 0.75),
					"Dark": pbr("metal_dark", Color(0.2, 0.21, 0.22), 0.5, 0.8, 0.6),
					"Metal": pbr("scratched_metal", Color(0.6, 0.6, 0.6), 0.5, 0.55, 0.9),
					"Accent": emit(Color(1.0, 0.5, 0.15), 1.4),
					"Hazard": pbr("hazard_stripes", Color.WHITE, 0.5, 0.75, 0.4),
					"Rubber": pbr("rubber", Color(0.15, 0.15, 0.15), 0.5, 0.9, 0.0),
					"Grate": pbr("grate", Color(0.5, 0.5, 0.5), 0.5, 0.6, 0.85),
					"Glass": glass(Color(0.8, 0.7, 0.5, 0.2)),
					"Screen": screen(Color(1.0, 0.55, 0.2)),
					"EmitLight": emit(Color(1.0, 0.72, 0.42), 3.0),
					"EmitDoor": emit(Color(1.0, 0.45, 0.1), 3.0),
				},
				"env": {"bg": Color(0.005, 0.004, 0.003), "ambient": Color(0.55, 0.45, 0.36), "ambient_energy": 0.4,
					"fog_color": Color(0.6, 0.45, 0.3), "fog_density": 0.03, "fog_emission": Color(0.04, 0.025, 0.012),
					"contrast": 1.12, "saturation": 0.85, "exposure": 1.0, "glow": 1.0, "tint": Color(1.05, 0.98, 0.92)},
				"reverb": [0.6, 0.18], "music": "music_tension", "amb": "amb_security",
			}
		"reactor":
			t = {
				"grime": 0.95, "damaged": 0.26, "grime_tint": Color(0.55, 0.47, 0.4),
				"light_color": Color(1.0, 0.55, 0.22), "light_energy": 1.5,
				"materials": {
					"Panel": pbr("metal_dark", Color(0.48, 0.45, 0.43), 0.5, 0.68, 0.65),
					"PanelAlt": pbr("panel_scifi", Color(0.52, 0.47, 0.42), 0.5, 0.68, 0.55),
					"Trim": pbr("scratched_metal", Color(0.55, 0.5, 0.45), 0.5, 0.55, 0.9),
					"Floor": pbr("grate", Color(0.45, 0.42, 0.4), 0.5, 0.6, 0.85),
					"Dark": pbr("metal_dark", Color(0.18, 0.17, 0.16), 0.5, 0.8, 0.6),
					"Metal": pbr("scratched_metal", Color(0.6, 0.55, 0.5), 0.5, 0.5, 0.9),
					"Accent": emit(Color(1.0, 0.45, 0.1), 2.0),
					"Hazard": pbr("hazard_stripes", Color.WHITE, 0.5, 0.75, 0.4),
					"Rubber": pbr("rubber", Color(0.14, 0.13, 0.12), 0.5, 0.9, 0.0),
					"Grate": pbr("grate", Color(0.5, 0.46, 0.42), 0.5, 0.6, 0.85),
					"Glass": glass(Color(1.0, 0.7, 0.4, 0.2)),
					"Screen": screen(Color(1.0, 0.5, 0.15)),
					"EmitLight": emit(Color(1.0, 0.6, 0.3), 3.0),
					"EmitDoor": emit(Color(1.0, 0.4, 0.1), 3.0),
				},
				"env": {"bg": Color(0.01, 0.004, 0.002), "ambient": Color(0.65, 0.4, 0.22), "ambient_energy": 0.42,
					"fog_color": Color(1.0, 0.55, 0.25), "fog_density": 0.03, "fog_emission": Color(0.12, 0.045, 0.012),
					"contrast": 1.12, "saturation": 0.95, "exposure": 1.0, "glow": 1.25, "tint": Color(1.06, 0.97, 0.9)},
				"reverb": [0.85, 0.22], "music": "music_tension", "amb": "amb_reactor",
			}
		"exterior":
			t = {
				"light_color": Color(0.8, 0.7, 1.0), "light_energy": 1.0,
				"materials": {
					"Panel": pbr("panel_white", Color(0.6, 0.6, 0.66), 0.5, 0.8, 0.2),
					"Trim": pbr("metal_dark", Color(0.4, 0.4, 0.45), 0.5, 0.7, 0.8),
					"Floor": pbr("concrete", Color(0.5, 0.5, 0.55), 0.5, 0.9, 0.0),
					"Dark": pbr("metal_dark", Color(0.2, 0.2, 0.24), 0.5, 0.8, 0.6),
					"Rock": pbr("rock_alien", Color(0.42, 0.38, 0.5), 0.25, 0.95, 0.0, {"triplanar": true}),
					"Ground": pbr("ground_alien", Color(0.5, 0.45, 0.55), 0.25, 0.95, 0.0),
					"EmitLight": emit(Color(0.85, 0.85, 1.0), 3.0),
				},
				"env": {"bg": Color(0.1, 0.06, 0.16), "ambient": Color(0.45, 0.38, 0.6), "ambient_energy": 0.55,
					"fog_color": Color(0.5, 0.4, 0.72), "fog_density": 0.007, "fog_emission": Color(0.06, 0.035, 0.09),
					"contrast": 1.06, "saturation": 1.0, "exposure": 1.0, "glow": 1.0, "tint": Color(1.0, 0.98, 1.04)},
				"reverb": [0.95, 0.05], "music": "music_explore", "amb": "amb_exterior",
			}
		"extraction":
			t = {
				"light_color": Color(1.0, 0.22, 0.15), "light_energy": 1.4,
				"materials": {
					"Panel": pbr("metal_dark", Color(0.4, 0.38, 0.4), 0.5, 0.75, 0.6),
					"Trim": pbr("scratched_metal", Color(0.55, 0.52, 0.52), 0.5, 0.55, 0.9),
					"Floor": pbr("concrete", Color(0.42, 0.4, 0.42), 0.5, 0.9, 0.0),
					"Dark": pbr("metal_dark", Color(0.18, 0.16, 0.17), 0.5, 0.8, 0.6),
					"Hazard": pbr("hazard_stripes", Color.WHITE, 0.5, 0.75, 0.4),
					"Rock": pbr("rock_alien", Color(0.35, 0.3, 0.38), 0.25, 0.95, 0.0, {"triplanar": true}),
					"Ground": pbr("ground_alien", Color(0.42, 0.36, 0.42), 0.25, 0.95, 0.0),
					"EmitLight": emit(Color(1.0, 0.2, 0.12), 4.0),
				},
				"env": {"bg": Color(0.08, 0.03, 0.06), "ambient": Color(0.5, 0.25, 0.3), "ambient_energy": 0.45,
					"fog_color": Color(0.6, 0.28, 0.3), "fog_density": 0.008, "fog_emission": Color(0.09, 0.025, 0.03),
					"contrast": 1.1, "saturation": 0.95, "exposure": 1.0, "glow": 1.15, "tint": Color(1.06, 0.95, 0.95)},
				"reverb": [0.95, 0.06], "music": "music_tension", "amb": "amb_extraction",
			}
		_:
			t = get_theme("research")
	return t
