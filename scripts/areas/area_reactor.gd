extends Area
## A4 — REACTOR CORE (Mission 3, CONTAINMENT FAILURE). A sixteen-metre chamber around the reactor column, Iyer's
## experiment lab, the CONDUIT ROTATION puzzle, THE EXPERIMENT reveal, and a 90-second survival encounter
## before the surface lift unlocks.

const SURVIVE_SECS := 90.0

var core: Node3D
var core_parts: Array = []
var core_light: OmniLight3D
var iyer_fig: Node3D
var surviving := false
var survive_left := 0.0
var _wave_t := 0.0
var _wave_i := 0
var _spawned := 0
var waves := [
	[0.0, "stalker", Vector2(2.6, 0.6)], [0.0, "stalker", Vector2(7.4, 0.6)],
	[12.0, "sentinel", Vector2(2.6, 5.4)], [18.0, "stalker", Vector2(7.4, 3.0)],
	[30.0, "stalker", Vector2(2.6, 3.0)], [36.0, "stalker", Vector2(5.0, 0.6)],
	[48.0, "brute", Vector2(5.0, 0.8)], [62.0, "stalker", Vector2(7.4, 5.4)], [70.0, "sentinel", Vector2(7.4, 0.8)],
]

func build() -> void:
	setup_theme("reactor", 404)
	B.room("lift_in", 0, 2, 2, 2, {"light_energy": 0.6})
	B.room("ring", 2, 0, 6, 6, {"h": 4, "floor": "grate", "light_energy": 0.5})
	B.room("lab", 8, 1, 3, 2, {"light_energy": 0.7})
	B.room("control", 3, 6, 4, 2, {"light_energy": 0.8})
	B.room("lift_out", 8, 4, 2, 2, {"h": 2, "light_energy": 0.6})
	B.open(Vector2i(1, 2), "e", "open")
	B.open(Vector2i(1, 3), "e", "open")
	door("lab", Vector2i(7, 1), "e")
	for x in [3, 4, 5, 6]:
		B.open(Vector2i(x, 5), "s", "open")
	door("lift_out", Vector2i(7, 4), "e", {"lock": "enc.reactor_survive", "text": "Lift sealed — the core is in lockdown"})
	B.build()
	_props()
	_lighting()
	_story()
	checkpoint("reactor_start", at(0.6, 3.0), -90.0)
	checkpoint("reactor_lab", at(8.5, 2.0), -90.0)
	checkpoint("reactor_control", at(5.0, 6.8), 0.0)
	checkpoint("reactor_lift", at(9.0, 5.0), -90.0)

func _props() -> void:
	core = Props.instance("reactor_core")
	add_child(core)
	core.global_position = at(5.0, 3.0)
	for n in ["Core", "Ring1", "Ring2"]:
		var p := Props.part(core, n)
		if p:
			core_parts.append(p)
	# the core's base is solid
	B.box_collider(at(5.0, 3.0) + Vector3(0, 2.0, 0), Vector3(5.6, 4.0, 5.6))
	# safety railing blocks and machinery around the core give cover in the survival fight
	for a in 8:
		var ang := TAU * a / 8.0
		var p := at(5.0, 3.0) + Vector3(cos(ang), 0, sin(ang)) * 6.2
		var nm := "crate_large" if a % 2 == 0 else "barrel"
		prop(nm, p, rad_to_deg(ang))
		cover_point(p + Vector3(cos(ang), 0, sin(ang)) * 1.4)
	prop("kit_pillar", at(2.3, 0.3), 0.0)
	prop("kit_pillar", at(7.7, 0.3), 0.0)
	prop("kit_pillar", at(2.3, 5.7), 0.0)
	prop("kit_pillar", at(7.7, 5.7), 0.0)
	# fused crew around the core
	for f in [[3.6, 1.4, 40.0, 0.92], [6.6, 4.8, 220.0, 1.04], [3.4, 4.6, 140.0, 0.97]]:
		var other := prop("crystal_figure", at(f[0], f[1]), f[2], true, f[3])
		_fig_hold(other, 0.0)      # the other fused crew: heads bowed and turned away, frozen in the crystal
	iyer_fig = prop("crystal_figure", at(6.4, 1.5), -40.0)   # the figure faces its local +Z (crystal_figure.json)
	_fig_hold(iyer_fig, 0.0)
	prop("crystal_cluster_b", at(4.0, 4.4), 0.0, true, 0.8)
	prop("crystal_cluster_a", at(6.2, 2.0), 0.0, true, 0.8)
	# lab
	prop("lab_table_clutter", at(9.5, 1.4), 0.0)
	prop("containment_tube_broken", at(10.6, 1.3), 0.0)
	prop("containment_tube", at(10.6, 2.6), 180.0)
	prop("lab_equipment", at(9.0, 2.7), 180.0)
	prop("terminal", at(8.4, 1.3), 90.0)
	prop("crystal_cluster_c", at(10.0, 2.2), 0.0, true, 0.9)
	prop("corpse_prone", at(9.6, 2.2), 30.0, true)
	# control room
	prop("console_large", at(4.0, 7.5), 180.0)
	prop("server_rack", at(6.6, 7.6), 180.0)
	prop("chair", at(4.2, 7.0), 0.0)
	# lift out
	var lift := Props.instance("cargo_lift")
	add_child(lift)
	lift.global_position = at(9.0, 5.0)
	Props.add_slab(lift, Vector3(6.1, 0.3, 6.1), Vector3(0, -0.15, 0), false)   # 1.9.2 bug 6: the lift floor is solid
	label3d("SURFACE LIFT", at(9.0, 5.95) + Vector3(0, 4.2, 0), 180.0, 72, Color(1.0, 0.75, 0.3))
	# pickups and stations (no softlocks in the survival fight)
	pickup("ammo_rifle", "rea_r1", at(0.6, 2.4), 48)
	pickup("medkit", "rea_m1", at(9.0, 1.2))
	pickup("ammo_pistol", "rea_a1", at(10.0, 1.2), 24)
	pickup("weapon_breach", "rea_breach", at(9.0, 2.0) + Vector3(0, 0.3, 0))   # v1.5.0 heavy weapon
	pickup("part", "rea_p1", at(6.2, 5.0) + Vector3(0, 0.3, 0))              # v1.5.0 upgrade parts
	pickup("part", "rea_p2", at(10.0, 3.0) + Vector3(0, 0.3, 0))
	for pos in [at(2.2, 3.0), at(7.8, 3.0)]:
		var st := AmmoStation.new()
		st.give_medkit = true
		st.recharge = 30.0
		add_child(st)
		st.global_position = pos
		st.rotation.y = PI * 0.5 if pos.x < 20.0 else -PI * 0.5
	_hazards()
	log_at(10, at(9.4, 1.4) + Vector3(0, 0.95, 0))
	log_at(11, at(8.5, 1.3) + Vector3(0, 0.0, 0.4))
	log_at(12, at(6.0, 1.9))

## Environmental hazards (Post-PRD Ph6): two ruptured coolant vents and a torn power feed in the ring, beside the
## route and away from the survival spawns, staggered so there is always a safe moment to pass.
var hazards: Array = []
func _hazards() -> void:
	for h in [["steam", Vector2(3.9, 1.5), 0.0], ["steam", Vector2(4.2, 5.3), 2.1], ["arc", Vector2(6.1, 4.6), 3.7]]:
		var hz := HazardZone.new()
		hz.kind = h[0]
		hz.phase_offset = h[2]
		var v: Vector2 = h[1]
		add_child(hz)
		hz.global_position = at(v.x, v.y)
		hazards.append(hz)
		if h[0] == "steam":
			var vent := Props.make("kit_vent_cover", false)
			add_child(vent)
			vent.global_position = hz.global_position + Vector3(0, 0.02, 0)
		else:
			var cab := Props.make("cable_bundle", false)
			add_child(cab)
			cab.global_position = hz.global_position + Vector3(0, 0.0, 0)
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 1.0
		tm.outer_radius = 1.08
		ring.mesh = tm
		ring.material_override = Fx.glow_mat(Color(1.0, 0.55, 0.1), 1.2, "hazard_ring")
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.global_position = hz.global_position + Vector3(0, 0.03, 0)
		ring.scale = Vector3(1.0, 0.2, 1.0)

func _lighting() -> void:
	room_lights("lift_in", 2, 0.6)
	room_lights("lab", 2, 0.8, true, 0.3)
	room_lights("control", 2, 0.8)
	room_lights("lift_out", 2, 0.6)
	core_light = omni(at(5.0, 3.0) + Vector3(0, 6.0, 0), Color(1.0, 0.5, 0.15), 6.0, 26.0, true)
	omni(at(5.0, 3.0) + Vector3(0, 13.0, 0), Color(1.0, 0.4, 0.1), 3.0, 20.0)
	for c in [Vector2(2.4, 0.4), Vector2(7.6, 0.4), Vector2(2.4, 5.6), Vector2(7.6, 5.6)]:
		omni(at(c.x, c.y) + Vector3(0, 3.5, 0), Color(1.0, 0.65, 0.3), 1.0, 9.0)
	omni(at(6.4, 1.5) + Vector3(0, 1.6, 0), Color(0.6, 0.3, 1.0), 1.2, 4.0)

func _story() -> void:
	trigger("rea_enter", at(1.0, 3.0), Vector3(4, 3, 6), func(_p): beat("reactor_enter", "mira_reactor", 1.0))
	trigger("rea_lab", at(8.6, 2.0), Vector3(3, 3, 6), func(_p): Game.set_flag("seen.iyer_lab"))
	enemy("stalker", "rea_s1", at(3.0, 1.0), 90.0, {"patrol": [at(3.0, 1.0), at(7.0, 1.0), at(7.0, 5.0), at(3.0, 5.0)]})
	enemy("sentinel", "rea_t1", at(7.2, 5.2), -135.0)
	var cc := ConduitConsole.new()
	cc.stable_id = "conduits"
	add_child(cc)
	cc.global_position = at(5.0, 7.8)
	cc.rotation.y = 0.0
	cc.solved.connect(_on_rerouted)
	trigger("rea_control", at(5.0, 6.6), Vector3(10, 3, 3), func(_p):
		if not Game.flag("puzzle.conduits"):
			beat("conduit", "mira_conduit"))
	console("lift_out_controls", at(9.0, 4.3), 180.0, "Ascend to the surface", func(_p): _ascend(),
		{"model": "terminal", "requires": "enc.reactor_survive", "requires_text": "Lift locked", "one_shot": false})
	if Game.flag("puzzle.conduits") and iyer_fig:
		# the reveal already happened: Iyer is awake and watching
		var ap := _fig_ap(iyer_fig)
		if ap and ap.has_animation("idle"):
			ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
			ap.play("idle")
	if Game.flag("puzzle.conduits") and not Game.flag("enc.reactor_survive"):
		# reloaded mid-encounter: start the fight again
		call_deferred("_start_survival")

func _on_rerouted() -> void:
	await get_tree().create_timer(1.4, true).timeout
	Sfx.say("mira_rerouted", true)
	await get_tree().create_timer(4.5, false).timeout
	await _reveal()
	GameMode.save_checkpoint("reactor_control")
	_start_survival()

func _reveal() -> void:
	var c := Cinematic.new()
	add_child(c)
	var cp := at(5.0, 3.0)
	var fig := iyer_fig.global_position if iyer_fig else at(6.4, 1.5)
	c.shot(cp + Vector3(-9, 2.0, 9), cp + Vector3(0, 6, 0), cp + Vector3(-7, 9.0, 7), cp + Vector3(0, 10, 0), 6.0, 55.0, 50.0)
	c.shot(fig + Vector3(1.0, 1.75, 2.4), fig + Vector3(0, 1.58, 0), fig + Vector3(0.5, 1.72, 1.4), fig + Vector3(0, 1.64, 0), 6.0, 36.0, 28.0)
	c.shot(cp + Vector3(0, 1.5, 10), cp + Vector3(0, 4, 0), cp + Vector3(0, 1.2, 8), cp + Vector3(0, 5, 0), 4.0, 60.0, 70.0)
	c.at(0.2, func(): Sfx.sting("sting_reveal", -2.0))
	if iyer_fig:
		# face the close-up camera so her head turn ends looking straight into the lens
		var cam_end := fig + Vector3(0.5, 1.72, 1.4)
		iyer_fig.rotation.y = atan2(cam_end.x - fig.x, cam_end.z - fig.z)   # the figure faces local +Z
	c.at(6.0, func(): _fig_turn(iyer_fig))
	c.say(7.4, "echo_came")
	c.at(12.2, func():
		Sfx.play("brute_roar", 4.0)
		Events.camera_shake.emit(0.8, 1.5)
		c.shake = 1.0)
	c.at(15.8, func(): pass, true)
	await c.play()

func _start_survival() -> void:
	if surviving or Game.flag("enc.reactor_survive"):
		return
	surviving = true
	tension = true
	survive_left = SURVIVE_SECS
	_wave_t = 0.0
	_wave_i = 0
	Sfx.say("mira_survive", true)
	Sfx.play("alarm_loop", -10.0)
	if core_light:
		core_light.light_color = Color(1.0, 0.2, 0.1)

func _process(delta: float) -> void:
	super._process(delta)
	for i in core_parts.size():
		var p: Node3D = core_parts[i]
		p.rotate_y(delta * (0.3 if i == 0 else (0.6 if i == 1 else -0.45)) * (3.0 if surviving else 1.0))
	if core_light:
		core_light.light_energy = (6.0 if not surviving else 8.0) + sin(_t * (2.0 if not surviving else 6.0)) * 1.5
	if not surviving:
		return
	_wave_t += delta
	survive_left -= delta
	while _wave_i < waves.size() and _wave_t >= float(waves[_wave_i][0]):
		var w: Array = waves[_wave_i]
		var v: Vector2 = w[2]
		var e := enemy(w[1], "rea_wave_%d_%d" % [_wave_i, _spawned], at(v.x, v.y), 0.0, {"alerted": true})
		if e:
			Fx.burst(e.global_position + Vector3.UP, Color(0.8, 0.4, 1.0), 0.9, 30)
			Sfx.play_at("crystal_spawn", e.global_position, 0.0, 40.0)
		_spawned += 1
		_wave_i += 1
	Events.objective_changed.emit("Survive until MIRA unlocks the lift — %d:%02d" % [int(survive_left) / 60, int(survive_left) % 60])
	if survive_left <= 0.0:
		surviving = false
		tension = false
		Game.set_flag("enc.reactor_survive")
		Sfx.say("mira_lift", true)
		GameMode.save_checkpoint("reactor_control")

func _ascend() -> void:
	var p: Player = GameMode.player
	if p == null:
		return
	p.locked = true
	Sfx.play("lift_start", 0.0)
	Events.camera_shake.emit(0.3, 2.5)
	await get_tree().create_timer(2.2, false).timeout
	p.locked = false
	GameMode.travel("exterior", "exterior_start")

func on_enter(fresh: bool) -> void:
	super.on_enter(fresh)
	tension = true


## crystal_figure clips (helper 1ca9c5ee): turn_head 2.5 s (head bowed and away -> eyes meet the camera at 2.2 s),
## then idle (4 s loop that starts where turn_head ends).
func _fig_ap(n: Node) -> AnimationPlayer:
	return n.find_child("AnimationPlayer", true, false) as AnimationPlayer if n else null

func _fig_hold(n: Node, t: float) -> void:
	var ap := _fig_ap(n)
	if ap and ap.has_animation("turn_head"):
		ap.play("turn_head")
		ap.seek(t, true)
		ap.pause()

func _fig_turn(n: Node) -> void:
	var ap := _fig_ap(n)
	if ap == null or not ap.has_animation("turn_head"):
		return
	ap.play("turn_head")
	if ap.has_animation("idle"):
		ap.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		ap.queue("idle")
