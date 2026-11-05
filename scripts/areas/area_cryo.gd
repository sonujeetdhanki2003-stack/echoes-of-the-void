extends Area
## A1 — CRYO CHAMBER (Mission 1, AWAKENING). Opening cinematic, movement tutorial (crouch, jump, door panel),
## the medbay sidearm, the first Stalker, and the generator-sequence puzzle that powers the Research bulkhead.

var gen_puzzle: GeneratorPuzzle
var vent_stalker: EnemyBase
var bulkhead: Door
var power_lights: Array = []

func build() -> void:
	setup_theme("cryo", 101)
	tension = false
	# ---- layout (cells are 4 m) ----
	B.room("bay", 0, 0, 3, 3, {"h": 2})
	B.room("decon", 3, 1, 4, 1, {"floor": "none", "light_energy": 0.5, "variants": ["kit_wall", "kit_wall_pipes"]})
	B.room("hub", 7, 0, 2, 4)
	B.room("medbay", 9, 0, 3, 2)
	B.room("quarters", 9, 2, 2, 2, {"light_energy": 0.6})
	B.room("aux", 6, 4, 4, 3, {"light_energy": 0.35, "variants": ["kit_wall_pipes", "kit_wall", "kit_wall_vent"]})
	B.room("bulk", 7, -2, 2, 2, {"light_energy": 0.5})
	B.open(Vector2i(2, 1), "e", "open")
	door("cryo_bay", Vector2i(6, 1), "e", {"lock": "power.bay_panel", "text": "Door locked — use the panel"})
	door("medbay", Vector2i(8, 0), "e")
	door("quarters", Vector2i(8, 3), "e")
	door("aux", Vector2i(7, 3), "s", {"lock": "got.pistol", "text": "Sealed — find a weapon first"})
	bulkhead = door("research_bulkhead", Vector2i(7, 0), "n", {"lock": "puzzle.generators", "text": "Bulkhead sealed — no power"})
	B.open(Vector2i(10, 1), "s", "window")
	B.open(Vector2i(1, 2), "s", "window")
	B.build()
	_decon_floor()
	_props()
	_lighting()
	_story()
	checkpoint("cryo_start", at(0.9, 1.5), -90.0)
	checkpoint("cryo_hub", at(7.5, 1.5), 180.0, Vector3(6, 3, 3))
	checkpoint("cryo_armed", at(10.5, 1.2), 90.0)
	checkpoint("cryo_power", at(8.0, 4.6), 0.0)
	exit_zone("to_research", at(8.0, -1.6), Vector3(7, 3, 2.5), "research", "research_start", "puzzle.generators")
	var s := Sfx.emitter("vent_hum", self, -14.0, 12.0)
	if s:
		s.global_position = at(1.5, 0.3) + Vector3.UP * 7.0

## The decontamination corridor: a collapsed beam to crouch under and a missing floor section to jump.
func _decon_floor() -> void:
	var y := 0.0
	# floor slabs with a 1.8 m gap (x 19.0 .. 20.8); the trench below is shallow and resets the player
	B.box(Vector3(15.5, y - 0.25, 6.0), Vector3(7.0, 0.5, 4.0), "Floor")
	B.box(Vector3(24.4, y - 0.25, 6.0), Vector3(7.2, 0.5, 4.0), "Floor")
	B.box(Vector3(19.9, y - 3.25, 6.0), Vector3(1.8, 0.5, 4.0), "Dark")
	for side in [-1.0, 1.0]:
		B.box(Vector3(19.9 + side * 0.9, y - 1.6, 6.0), Vector3(0.05, 3.0, 4.0), "Dark", false)
	var mist := omni(Vector3(19.9, -2.2, 6.0), Color(0.3, 0.7, 1.0), 2.0, 5.0)
	mist.light_volumetric_fog_energy = 4.0
	var t := trigger("decon_fall", Vector3(19.9, -3.0, 6.0), Vector3(1.8, 1.4, 4.0), func(p: Player):
		p.place(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(17.6, 0.1, 6.0)))
		p.controller.snap_to(p.rotation.y)
		Events.message.emit("Sprint and jump across the gap" if not Game.touch_enabled() else "RUN, then JUMP across the gap", 2.5), false)
	t.once = false
	# collapsed beam: a 0.6 m slab with its underside at 1.3 m — crouch height clears it, standing doesn't
	var beam := prop("fallen_beam", Vector3(16.0, 1.3, 6.0), 90.0, false)
	beam.rotation.z = deg_to_rad(4.0)
	B.box_collider(Vector3(16.0, 1.65, 6.0), Vector3(0.7, 0.7, 4.0))
	B.box(Vector3(16.0, 2.9, 6.0), Vector3(0.5, 1.9, 4.0), "Dark")
	prop("debris_pile", Vector3(16.6, 0.0, 4.8), 30.0, true, 0.5)
	prop("cable_bundle", Vector3(14.0, 0.02, 6.6), 80.0, false)

func _props() -> void:
	# cryo pods along the west wall and the north wall; the player's pod is the open one in the middle
	for z in [2.2, 6.0, 9.8]:
		var pod := prop("cryo_pod", Vector3(0.95, 0.0, z), 90.0)
		if absf(z - 6.0) < 0.1:
			pod.name = "PlayerPod"
	for x in [4.0, 8.0]:
		prop("cryo_pod", Vector3(x, 0.0, 0.95), 0.0)
	for x in [4.0, 8.0]:
		prop("cryo_pod", Vector3(x, 0.0, 11.05), 180.0)
	prop("console_large", Vector3(6.0, 0.0, 6.0), 0.0)
	prop("server_rack", Vector3(11.4, 0.0, 1.0), -90.0)
	prop("server_rack", Vector3(11.4, 0.0, 10.9), -90.0)
	prop("corpse_sitting", Vector3(10.6, 0.0, 9.8), -120.0, true)
	prop("crate_small", Vector3(10.8, 0.0, 2.6), 15.0)
	prop("pipe_straight", Vector3(0.4, 7.0, 6.0), 0.0, false)
	# decon
	prop("locker", Vector3(13.0, 0.0, 4.4), 0.0)
	prop("barrel", Vector3(26.8, 0.0, 7.4), 0.0)
	# hub
	prop("crate_large", Vector3(34.6, 0.0, 14.4), 10.0)
	prop("crate_small", Vector3(33.4, 0.0, 14.9), -20.0)
	prop("terminal", Vector3(29.0, 0.0, 9.0), 90.0)
	prop("kit_vent_cover", Vector3(35.75, 2.4, 6.0), -90.0, false)
	prop("chair", Vector3(30.2, 0.0, 9.6), 140.0)
	# medbay
	for x in [39.0, 43.0]:
		prop("med_bed", Vector3(x, 0.0, 2.0), 0.0)
	prop("med_cabinet", Vector3(47.6, 0.0, 2.5), -90.0)
	prop("med_cabinet", Vector3(47.6, 0.0, 5.5), -90.0)
	prop("lab_table_clutter", Vector3(41.0, 0.0, 6.9), 180.0)
	prop("locker", Vector3(46.8, 0.0, 7.4), 180.0)
	prop("locker", Vector3(45.9, 0.0, 7.4), 180.0)
	prop("corpse_prone", Vector3(44.6, 0.0, 4.6), 70.0, true)
	# quarters
	prop("desk", Vector3(42.4, 0.0, 9.0), 180.0)
	prop("monitor", Vector3(42.4, 0.8, 9.0), 180.0, false)
	prop("chair", Vector3(42.2, 0.0, 10.0), 10.0)
	prop("locker", Vector3(43.5, 0.0, 15.4), 180.0)
	prop("crate_small", Vector3(37.0, 0.0, 15.0), 0.0)
	# aux power
	prop("pipe_straight", Vector3(24.5, 3.4, 22.0), 0.0, false)
	prop("pipe_straight", Vector3(39.5, 3.4, 22.0), 0.0, false)
	prop("server_rack", Vector3(25.0, 0.0, 17.0), 90.0)
	prop("barrel", Vector3(38.9, 0.0, 17.2), 0.0)
	prop("barrel", Vector3(38.2, 0.0, 17.6), 0.0)
	# bulkhead corridor
	prop("crate_large", Vector3(29.4, 0.0, -6.4), 0.0)
	# pickups
	pickup("medkit", "cryo_med1", Vector3(42.6, 0.95, 6.9))
	pickup("medkit", "cryo_med2", Vector3(25.6, 0.0, 26.8))
	pickup("weapon_pistol", "pistol", Vector3(46.3, 0.0, 6.6))
	pickup("ammo_pistol", "cryo_a1", Vector3(42.5, 0.82, 9.0), 12)
	pickup("ammo_pistol", "cryo_a2", Vector3(30.0, 0.0, 14.6), 12)
	pickup("ammo_pistol", "cryo_a3", Vector3(37.4, 0.0, 26.6), 12)
	pickup("part", "cryo_p1", Vector3(40.0, 0.3, 12.0))   # v1.5.0 upgrade parts
	pickup("part", "cryo_p2", Vector3(33.0, 0.3, 20.0))
	# logs
	log_at(1, Vector3(40.6, 0.95, 6.8))
	log_at(2, Vector3(29.2, 0.0, 15.2))
	log_at(3, Vector3(38.6, 0.82, 9.2))

func _lighting() -> void:
	room_lights("bay", 2, 0.8, true, 0.25)
	room_lights("hub", 2, 0.9)
	room_lights("medbay", 2, 1.0)
	room_lights("quarters", 2, 0.6, true, 0.4)
	room_lights("bulk", 2, 0.5)
	# the bay: cold key light through the frost from above the pods, a red alarm beacon by the exit
	spot(Vector3(6.0, 7.6, 6.0), Vector3(1.0, 0.0, 6.0), Color(0.55, 0.8, 1.0), 4.0, 14.0, 55.0, true)
	omni(Vector3(11.0, 3.4, 6.0), Color(1.0, 0.15, 0.1), 1.2, 7.0, false, 0.6)
	# decon: dim emergency red with one flickering white strip
	omni(Vector3(14.0, 3.5, 6.0), Color(1.0, 0.2, 0.12), 1.5, 9.0)
	omni(Vector3(22.0, 3.5, 6.0), Color(0.8, 0.9, 1.0), 1.6, 9.0, true, 0.7)
	omni(Vector3(27.0, 2.8, 4.6), Color(1.0, 0.6, 0.2), 0.8, 4.0)
	# aux power room: dark until the generators run
	for p in [Vector3(28, 3.6, 20), Vector3(36, 3.6, 20), Vector3(28, 3.6, 26), Vector3(36, 3.6, 26)]:
		var l := omni(p, Color(1.0, 0.85, 0.6), 0.0, 10.0, p.x < 30.0 and p.z < 22.0)
		power_lights.append(l)
	omni(Vector3(32, 3.5, 22), Color(1.0, 0.25, 0.1), 1.0, 12.0, false, 0.3)

func _story() -> void:
	# door panel next to the bay exit (tutorial: interact)
	console("bay_panel", Vector3(27.65, 1.15, 4.35), -90.0, "Open door", func(_p):
		Game.set_flag("power.bay_panel")
		Sfx.say("mira_power"), {"model": "door_panel", "focus": Vector3(0, 0.2, 0.15)})
	trigger("tut_crouch", Vector3(14.0, 0.0, 6.0), Vector3(2.0, 3.0, 4.0), func(_p):
		Sfx.say("mira_crouch")
		_hint("Hold %s to crouch" % Game.key_name("crouch"), "Tap CROUCH to duck under"))
	trigger("tut_jump", Vector3(17.8, 0.0, 6.0), Vector3(1.5, 3.0, 4.0), func(_p):
		Sfx.say("mira_jump")
		_hint("%s to sprint, %s to jump" % [Game.key_name("sprint"), Game.key_name("jump")], "RUN, then JUMP"))
	trigger("tut_door", Vector3(25.5, 0.0, 6.0), Vector3(3.0, 3.0, 4.0), func(_p):
		Sfx.say("mira_door")
		_hint("Look at the panel and press %s" % Game.key_name("interact"), "Look at the panel and tap USE"))
	trigger("hub_weapon", Vector3(31.0, 0.0, 6.0), Vector3(5.0, 3.0, 4.0), func(_p):
		if not Game.flag("got.pistol"):
			Sfx.say("mira_weapon"))
	trigger("medbay_enter", Vector3(39.0, 0.0, 4.0), Vector3(4.0, 3.0, 8.0), func(p: Player):
		if p.inventory.medkits == 0:
			_hint("Medkits heal you: %s" % Game.key_name("medkit"), "Medkits heal you: MED"))
	# the first Stalker waits in the hub vent until the player is armed
	if not Game.flag("enc.cryo_first"):
		vent_stalker = enemy("stalker", "cryo_vent_stalker", Vector3(34.5, 0.0, 6.0), 90.0, {"dormant": true})
		if vent_stalker:
			vent_stalker.health.died.connect(func(_i): _on_first_kill())
		var t := trigger("cryo_vent", Vector3(33.0, 0.0, 9.0), Vector3(7.5, 3.0, 9.0), func(_p): _vent_burst())
		t.requires_flag = "got.pistol"
		var tid := t.get_instance_id()
		Events.flag_set.connect(func(f):
			if f == "got.pistol" and is_instance_id_valid(tid):
				GameMode.save_checkpoint("cryo_armed", false)
				_hint("Hold RMB to aim, LMB to fire, %s to reload" % Game.key_name("reload"), "AIM, then hold FIRE — drag FIRE to steer"))
	# generator puzzle
	gen_puzzle = GeneratorPuzzle.new()
	add_child(gen_puzzle)
	var gens := [["A", "MAIN", Vector3(28.0, 0.0, 25.4)], ["B", "COOLANT", Vector3(32.0, 0.0, 25.4)], ["C", "REGULATOR", Vector3(36.0, 0.0, 25.4)]]
	for g in gens:
		var gen := Generator.new()
		gen.gen_id = g[0]
		gen.label = g[1]
		gen.stable_id = "gen_" + str(g[0]).to_lower()
		add_child(gen)
		gen.global_position = g[2]
		gen.rotation.y = PI
		gen_puzzle.register(gen)
	gen_puzzle.solved_signal.connect(_on_power)
	# the wall schematic (second source of the order besides Wren's note)
	label3d("AUX POWER — COLD START", Vector3(32.0, 2.9, 16.3), 0.0, 56, Color(1.0, 0.8, 0.4))
	label3d("COOLANT (B)  ▸  REGULATOR (C)  ▸  MAIN (A)", Vector3(32.0, 2.45, 16.3), 0.0, 44)
	label3d("Never start MAIN cold.  — T.W.", Vector3(32.0, 2.05, 16.3), 0.0, 32, Color(0.7, 0.8, 0.9))
	trigger("aux_enter", Vector3(32.0, 0.0, 18.0), Vector3(8.0, 3.0, 3.0), func(_p):
		if not Game.flag("puzzle.generators"):
			Events.message.emit("Start the generators in the right order", 3.0))
	if Game.flag("puzzle.generators"):
		_power_visuals(false)

func _hint(kb: String, touch_text: String) -> void:
	Events.message.emit(touch_text if Game.touch_enabled() else kb, 3.5)

func _vent_burst() -> void:
	if vent_stalker == null or not is_instance_valid(vent_stalker):
		return
	tension = true
	Sfx.say("mira_contact", true)
	await get_tree().create_timer(1.6, false).timeout
	var vp := Vector3(35.6, 2.4, 6.0)
	Sfx.play_at("vent_burst", vp, 2.0, 40.0)
	Fx.burst(vp, Color(0.7, 0.8, 0.9), 0.8, 30)
	Events.camera_shake.emit(0.35, 0.4)
	var vc := find_child("kit_vent_cover", true, false) as Node3D
	if vc:
		var tw := create_tween()
		tw.tween_property(vc, "position", vc.position + Vector3(-2.5, -2.4, 0.6), 0.5).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(vc, "rotation", Vector3(1.2, 0.0, 0.9), 0.5)
	vent_stalker.global_position = Vector3(34.4, 0.0, 6.0)
	vent_stalker.awaken(true)

func _on_first_kill() -> void:
	tension = false
	Game.set_flag("enc.cryo_first")
	await get_tree().create_timer(2.0, false).timeout
	Sfx.say("mira_power")
	GameMode.save_checkpoint("cryo_hub")

func _on_power() -> void:
	_power_visuals(true)
	Sfx.say("mira_gen_ok", true)
	GameMode.save_checkpoint("cryo_power")

func _power_visuals(animate: bool) -> void:
	for l in power_lights:
		if animate:
			create_tween().tween_property(l, "light_energy", 1.6, 1.5)
		else:
			(l as OmniLight3D).light_energy = 1.6

func on_enter(fresh: bool) -> void:
	super.on_enter(fresh)
	if not Game.flag("cine.wake"):
		Game.set_flag("cine.wake")
		_wake_cinematic()

func _wake_cinematic() -> void:
	var p: Player = GameMode.player
	var c := Cinematic.new()
	c.hide_player = false
	add_child(c)
	var pod := Vector3(0.95, 1.4, 6.0)
	c.shot(Vector3(9.5, 6.5, 10.5), Vector3(2.0, 1.0, 6.0), Vector3(8.0, 5.0, 9.0), Vector3(1.5, 1.2, 6.0), 5.5, 48.0, 44.0)
	c.shot(Vector3(4.3, 1.55, 8.6), Vector3(1.4, 1.1, 6.0), Vector3(3.6, 1.45, 8.0), Vector3(1.6, 1.0, 6.0), 4.5, 40.0, 36.0)
	c.shot(Vector3(5.5, 2.0, 4.0), Vector3(2.8, 1.4, 6.0), Vector3(5.2, 1.9, 6.6), Vector3(9.0, 1.4, 6.0), 3.0, 55.0, 60.0)
	c.at(0.4, func(): GameMode.ui.show_title(["NYX-7", "ORPHEUS RESEARCH STATION  ·  DAY 153"], 5.0))
	c.at(6.0, func():
		Sfx.play("pod_open", -2.0)
		var lid := Props.part(find_child("PlayerPod", true, false), "Lid")
		if lid:
			create_tween().tween_property(lid, "rotation:y", lid.rotation.y - 1.4, 1.6).set_trans(Tween.TRANS_SINE))
	c.say(0.6, "mira_wake")
	# Kabir is still in the pod for the opening shots; he spills out when the lid opens (wake_up starts kneeling)
	if p:
		# out of the pod's door, facing into the room (+X)
		p.global_position = Vector3(2.0, p.global_position.y, 6.0)
		p.rotation.y = deg_to_rad(-90.0)
		if p.controller:
			p.controller.yaw = -90.0
	if p and p.anim and p.anim.model:
		p.anim.model.visible = false
	c.at(6.3, func():
		if p and p.anim:
			if p.anim.model:
				p.anim.model.visible = true
			p.anim.play_wake())
	c.say(10.4, "kabir_wake")
	c.at(12.9, func(): pass, true)
	await c.play()
	# hand over clear of the pod: right beside it the follow camera's spring arm hits the pod and the wall and
	# collapses into Kabir's helmet (found in the wake reshoot). The last shot looks away down the bay, so the move is
	# hidden by the cut to the gameplay camera.
	if p and is_instance_valid(p):
		p.place(Transform3D(Basis(Vector3.UP, deg_to_rad(-90.0)), Vector3(5.2, p.global_position.y, 6.0)))
		if p.controller:
			p.controller.snap_to(p.rotation.y)
	await get_tree().create_timer(0.6, false).timeout
	Sfx.say("mira_move")
	_hint("%s to move · mouse to look · %s to sprint" % [Game.move_keys(), Game.key_name("sprint")], "Left thumb moves · right thumb looks")
