class_name Fx
extends RefCounted
## Shared visual effects: muzzle flashes, tracers, impacts, scorch decals, explosions. Cheap, pooled where
## it matters, and scaled by the quality preset.

static var _mats := {}
static var _decals: Array = []
static var _sparks_mesh: Mesh
static var particle_scale := 1.0

static func root() -> Node:
	var t := Engine.get_main_loop() as SceneTree
	if t == null:
		return null
	var w := t.get_first_node_in_group("area")
	return w if w else t.current_scene

static func glow_mat(c: Color, energy: float = 4.0, key: String = "") -> StandardMaterial3D:
	var k := key if key != "" else "glow_%s_%s" % [c.to_html(), energy]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(c.r * energy, c.g * energy, c.b * energy, c.a)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.no_depth_test = false
	m.disable_receive_shadows = true
	_mats[k] = m
	return m

static func _flash_tex() -> Texture2D:
	if _mats.has("flash_tex"):
		return _mats["flash_tex"]
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.25, Color(1, 1, 1, 0.8))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 64
	t.height = 64
	_mats["flash_tex"] = t
	return t

## Soft, noisy puff for steam and smoke (no bright core, so a cloud of them reads as vapour, not a ball).
static func _smoke_tex() -> Texture2D:
	if _mats.has("smoke_tex"):
		return _mats["smoke_tex"]
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var n := FastNoiseLite.new()
	n.frequency = 0.09
	n.seed = 7
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
			var fall := clampf(1.0 - d, 0.0, 1.0)
			fall = fall * fall * (3.0 - 2.0 * fall)
			var a := fall * (0.55 + 0.45 * (n.get_noise_2d(x, y) * 0.5 + 0.5)) * 0.8
			img.set_pixel(x, y, Color(1, 1, 1, a))
	var t := ImageTexture.create_from_image(img)
	_mats["smoke_tex"] = t
	return t

static func sprite_mat(c: Color, energy: float = 3.0) -> StandardMaterial3D:
	var k := "spr_%s_%s" % [c.to_html(), energy]
	if _mats.has(k):
		return _mats[k]
	var m := glow_mat(c, energy, k + "_base").duplicate() as StandardMaterial3D
	m.albedo_texture = _flash_tex()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mats[k] = m
	return m

static func _free_after(n: Node, secs: float) -> void:
	var t := n.get_tree()
	if t:
		# a bound method, not a lambda: the connection dies with `n` if the area unloads first
		t.create_timer(secs, false).timeout.connect(n.queue_free)

static func muzzle_flash(pos: Vector3, dir: Vector3, c: Color, big: bool = false) -> void:
	var r := root()
	if r == null:
		return
	var n := Node3D.new()
	r.add_child(n)
	n.global_position = pos
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	var sz := 0.42 if big else 0.3
	qm.size = Vector2(sz, sz)
	q.mesh = qm
	q.material_override = sprite_mat(c, 5.0)
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	q.rotation.z = randf() * TAU
	n.add_child(q)
	# a stretched core along the barrel
	var core := MeshInstance3D.new()
	var cm := QuadMesh.new()
	cm.size = Vector2(0.12, 0.5 if big else 0.34)
	core.mesh = cm
	core.material_override = glow_mat(c, 6.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(core)
	if dir.length() > 0.01:
		var up := Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		core.look_at_from_position(pos + dir.normalized() * 0.15, pos + dir.normalized(), up)
		core.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 3.5 if big else 2.4
	l.omni_range = 6.0
	l.shadow_enabled = false
	n.add_child(l)
	_free_after(n, 0.055)

static func tracer(from: Vector3, to: Vector3, c: Color, width: float = 0.025) -> void:
	var r := root()
	if r == null or from.distance_to(to) < 0.5:
		return
	var m := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = width
	cyl.bottom_radius = width * 0.4
	cyl.height = 1.0
	cyl.radial_segments = 5
	cyl.rings = 1
	m.mesh = cyl
	m.material_override = glow_mat(c, 3.0, "tracer_%s" % c.to_html()).duplicate()
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(m)
	var start := from.lerp(to, 0.08)
	var len := start.distance_to(to)
	var mid := start.lerp(to, 0.5)
	var dir := (to - start).normalized()
	var up := Vector3.UP if absf(dir.dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	m.global_transform = Transform3D(Basis.looking_at(dir, up), mid)
	m.rotate_object_local(Vector3.RIGHT, PI * 0.5)
	m.scale = Vector3(1.0, len, 1.0)
	var mat := m.material_override as StandardMaterial3D
	var tw := m.create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.09)
	tw.tween_callback(m.queue_free)

static func impact(pos: Vector3, normal: Vector3, surface: String = "metal", scale: float = 1.0) -> void:
	var r := root()
	if r == null:
		return
	var col := Color(1.0, 0.75, 0.4)
	var count := 14
	match surface:
		"flesh":
			col = Color(0.7, 0.3, 1.0)
		"crystal":
			col = Color(0.4, 0.9, 1.0)
		"rock":
			col = Color(0.9, 0.8, 0.7)
			count = 10
		"armor":
			col = Color(1.0, 0.85, 0.6)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = maxi(4, int(count * scale * particle_scale))
	p.lifetime = 0.45
	p.explosiveness = 0.95
	p.direction = normal if normal.length() > 0.1 else Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = 2.5 * scale
	p.initial_velocity_max = 7.0 * scale
	p.gravity = Vector3(0, -9.0, 0)
	p.scale_amount_min = 0.025
	p.scale_amount_max = 0.06
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	p.mesh = qm
	p.material_override = sprite_mat(col, 4.0)
	r.add_child(p)
	p.global_position = pos + normal * 0.03
	p.emitting = true
	_free_after(p, 1.0)
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.2 * scale
	l.omni_range = 2.5 * scale
	r.add_child(l)
	l.global_position = pos + normal * 0.2
	_free_after(l, 0.05)
	if surface in ["metal", "rock", "armor"]:
		scorch(pos, normal)

static func scorch(pos: Vector3, normal: Vector3) -> void:
	var r := root()
	if r == null:
		return
	var d: Decal = null
	_decals = _decals.filter(func(x): return is_instance_valid(x))
	if _decals.size() >= 48:
		var old: Variant = _decals.pop_front()
		if is_instance_valid(old):
			d = old
	if d == null:
		d = Decal.new()
		d.size = Vector3(0.22, 0.3, 0.22)
		d.texture_albedo = _scorch_tex()
		d.modulate = Color(0.08, 0.07, 0.06, 0.85)
		d.emission_energy = 0.0
		d.cull_mask = 1
		d.upper_fade = 0.2
		d.lower_fade = 0.2
		r.add_child(d)
	_decals.append(d)
	var up := normal.normalized() if normal.length() > 0.1 else Vector3.UP
	var side := Vector3.RIGHT if absf(up.dot(Vector3.RIGHT)) < 0.9 else Vector3.FORWARD
	var b := Basis(side.cross(up).normalized(), up, up.cross(side.cross(up).normalized()))
	d.global_transform = Transform3D(b.rotated(up, randf() * TAU), pos)

static func _scorch_tex() -> Texture2D:
	if _mats.has("scorch"):
		return _mats["scorch"]
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 1))
	g.add_point(0.35, Color(0, 0, 0, 0.7))
	g.set_color(1, Color(0, 0, 0, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	_mats["scorch"] = t
	return t

static func burst(pos: Vector3, c: Color, size: float = 1.0, count: int = 40) -> void:
	var r := root()
	if r == null:
		return
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = maxi(6, int(count * particle_scale))
	p.lifetime = 1.1
	p.explosiveness = 0.9
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 2.0 * size
	p.initial_velocity_max = 7.0 * size
	p.gravity = Vector3(0, -6.0, 0)
	p.scale_amount_min = 0.04 * size
	p.scale_amount_max = 0.14 * size
	var qm := QuadMesh.new()
	p.mesh = qm
	p.material_override = sprite_mat(c, 4.0)
	r.add_child(p)
	p.global_position = pos
	p.emitting = true
	_free_after(p, 1.6)
	var l := OmniLight3D.new()
	l.light_color = c
	l.light_energy = 4.0 * size
	l.omni_range = 7.0 * size
	r.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)

## A ground telegraph ring that grows over `secs` (Brute slam, Herald slams, shard rain).
static func telegraph(pos: Vector3, radius: float, secs: float, c: Color = Color(1.0, 0.15, 0.1)) -> Node3D:
	var r := root()
	if r == null:
		return null
	var n := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.04
	cyl.radial_segments = 40
	n.mesh = cyl
	var m := glow_mat(c, 1.6, "tele_%s" % c.to_html()).duplicate() as StandardMaterial3D
	m.albedo_color.a = 0.35
	n.material_override = m
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.add_child(n)
	n.global_position = pos + Vector3.UP * 0.05
	n.scale = Vector3(radius * 0.15, 1.0, radius * 0.15)
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3(radius, 1.0, radius), secs).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.75, secs)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(n.queue_free)
	return n


## Engine exhaust attached to a moving node (shuttle launch): a hot core sprite stream, a long soft smoke
## trail and an orange light that washes the pad.
static func thruster(parent: Node3D, local_pos: Vector3, dir_local: Vector3 = Vector3.DOWN, size: float = 1.0) -> Node3D:
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.position = local_pos
	for layer in [["core", Color(1.0, 0.75, 0.45), 6.0, 0.35, 90, 0.35, 16.0], ["smoke", Color(0.55, 0.5, 0.48), 0.0, 3.2, 70, 1.6, 6.0]]:
		var gp := GPUParticles3D.new()
		gp.amount = int(layer[4])
		gp.lifetime = float(layer[3])
		gp.local_coords = false
		gp.draw_order = GPUParticles3D.DRAW_ORDER_VIEW_DEPTH
		var pm := ParticleProcessMaterial.new()
		pm.direction = dir_local.normalized()
		pm.spread = 8.0 if layer[0] == "core" else 22.0
		pm.initial_velocity_min = float(layer[6]) * 0.8
		pm.initial_velocity_max = float(layer[6]) * 1.2
		pm.gravity = Vector3.ZERO
		pm.damping_min = 0.5 if layer[0] == "core" else 2.5
		pm.damping_max = pm.damping_min
		pm.scale_min = float(layer[5]) * size
		pm.scale_max = float(layer[5]) * size * 1.6
		var sc := Curve.new()
		sc.add_point(Vector2(0, 0.6))
		sc.add_point(Vector2(1, 1.0 if layer[0] == "core" else 2.6))
		var sct := CurveTexture.new()
		sct.curve = sc
		pm.scale_curve = sct
		var grad := Gradient.new()
		grad.set_color(0, Color(layer[1], 0.9))
		grad.set_color(1, Color(layer[1], 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = grad
		pm.color_ramp = gt
		gp.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(1, 1)
		var m := sprite_mat(layer[1], float(layer[2])) if layer[0] == "core" else sprite_mat(layer[1], 0.0)
		m.vertex_color_use_as_albedo = true
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		q.material = m
		gp.draw_pass_1 = q
		gp.visibility_aabb = AABB(Vector3(-30, -60, -30), Vector3(60, 90, 60))
		holder.add_child(gp)
		gp.emitting = true
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 8.0 * size
	l.omni_range = 18.0 * size
	l.shadow_enabled = false
	holder.add_child(l)
	return holder
