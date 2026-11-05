extends Node
## Still-frame renderer for visual checks and the press kit.
##   godot -- --shots --out=<dir> --name=<file> --area=<id> [--cp=<checkpoint>] [--flags=a,b] [--mission=N]
##        [--cam=x,y,z --look=x,y,z --fov=50] [--frames=N] [--q=high] [--menu]
## Without --cam the gameplay camera at the checkpoint is used.

func _ready() -> void:
	var out := Game.arg("out", "/tmp")
	var nm := Game.arg("name", "shot")
	Game.settings["quality"] = Game.arg("q", "high")
	Game.settings["subtitles"] = not Game.has_arg("nosubs")
	if Game.has_arg("touch"):
		Game.settings["touch"] = "on"
	if Game.arg("ui") != "":
		Game.settings["ui_size"] = Game.arg("ui")
	Game.apply_settings()
	await get_tree().process_frame
	var ui = GameMode.ui
	var tk := Timer.new()
	tk.wait_time = 5.0
	tk.autostart = true
	tk.process_mode = Node.PROCESS_MODE_ALWAYS
	tk.timeout.connect(func(): print("tick t=", Time.get_ticks_msec(), " frames=", Engine.get_frames_drawn(), " loading=", GameMode.loading))
	add_child(tk)
	if Game.has_arg("menu"):
		ui.show_menu()
		ui.fade.color.a = 0.0
		match Game.arg("page"):
			"howto": ui.open_howto(false, Game.arg("tab", "GOAL"))
			"settings": ui.open_settings("settings_menu")
			"credits": ui._credits()
	else:
		Game.new_state()
		Game.state["mission"] = int(Game.arg("mission", "0"))
		for f in Game.arg("flags", "").split(",", false):
			Game.state["flags"][f] = true
		Game.state["flags"]["cine.wake"] = true
		await GameMode.load_area(Game.arg("area", "cryo"), Game.arg("cp", Game.arg("area", "cryo") + "_start"), true)
		ui.fade.color.a = 0.0
		if Game.arg("cam") != "":
			var c := Camera3D.new()
			c.fov = float(Game.arg("fov", "55"))
			c.far = 900.0
			GameMode.area.add_child(c)
			c.global_position = _v(Game.arg("cam"))
			c.look_at(_v(Game.arg("look", "0,0,0")), Vector3.UP)
			c.make_current()
			ui.hud_visible(Game.has_arg("hud"))
		if Game.arg("weapon") != "" and GameMode.player:
			GameMode.player.combat.give(Game.arg("weapon"))
			GameMode.player.inventory.add_ammo(Game.arg("weapon"), 100)
	# --spawn=kind:dx:dz:yaw;kind2:... places enemies relative to the player (dx right, dz forward), dormant,
	# optionally posed with --anim=clip (for model/lighting checks)
	if Game.arg("spawn") != "" and GameMode.player:
		var pl: Node3D = GameMode.player
		var fwd := -pl.global_transform.basis.z
		var right := pl.global_transform.basis.x
		var k := 0
		for sp in Game.arg("spawn").split(",", false):
			var f := sp.split(":")
			var pos := pl.global_position + right * float(f[1]) + fwd * float(f[2])
			var e = GameMode.area.enemy(f[0], "shot_%d" % k, pos, rad_to_deg(pl.rotation.y) + float(f[3]) if f.size() > 3 else 0.0, {})
			k += 1
			if e:
				await get_tree().process_frame
				e.set_physics_process(false)
				e.perception.enabled = false
				if Game.arg("anim") != "":
					e.play_anim(Game.arg("anim"), 0.0)
	# --boss: the Herald already risen (idle) for a look at it, optionally posed with --banim=clip at --bt=secs
	if Game.has_arg("boss") and GameMode.area.get("herald"):
		var h = GameMode.area.herald
		h.visible = true
		var hap: AnimationPlayer = h.ap
		if hap:
			var clip := Game.arg("banim", "idle")
			hap.play(clip)
			hap.seek(float(Game.arg("bt", "0.5")), true)
			hap.pause()
	if Game.has_arg("aim") and GameMode.player:
		GameMode.player.controller.aim_toggle = true
	if Game.arg("yaw") != "" and GameMode.player:
		GameMode.player.controller.yaw = float(Game.arg("yaw"))
		GameMode.player.rotation.y = deg_to_rad(float(Game.arg("yaw")))
	# --pcam=right,up,forward: a camera placed relative to the player, looking at the chest (--plook=height)
	if Game.arg("pcam") != "" and GameMode.player:
		var pl3: Node3D = GameMode.player
		var o := _v(Game.arg("pcam"))
		var c2 := Camera3D.new()
		c2.fov = float(Game.arg("fov", "40"))
		GameMode.area.add_child(c2)
		# the astronaut faces its VisualRoot's -Z (measured: +Z showed the backpack)
		var vr: Node3D = pl3.get_node_or_null("VisualRoot")
		var fz: Vector3 = (-vr.global_basis.z if vr else -pl3.global_basis.z).normalized()
		var rx := Vector3.UP.cross(fz).normalized()
		c2.global_position = pl3.global_position - rx * o.x + Vector3.UP * o.y + fz * o.z
		c2.look_at(pl3.global_position + Vector3.UP * float(Game.arg("plook", "1.25")), Vector3.UP)
		c2.make_current()
		ui.hud_visible(false)
	# --subtest: a long 3-line subtitle (in a cinematic with --cine) to check it clears the letterbox / buttons
	if Game.has_arg("subtest"):
		if Game.has_arg("cine"):
			Events.cinematic_state.emit(true)
		Events.subtitle.emit("KABIR", "This is the Orpheus relay. If anyone can hear this, the signal is still going out. Whatever happened down there, we're coming. Hold on. Hold on just a little longer, we are almost in range of the station.", 20.0)
	if Game.has_arg("nohud"):
		ui.hud_visible(false)
	if Game.arg("hidep") != "" and GameMode.player:
		GameMode.player.visible = false
	var frames := int(Game.arg("frames", "8"))
	print("LOADED at ", Time.get_ticks_msec())
	for i in frames:
		await get_tree().process_frame
		print("frame ", i, " t=", Time.get_ticks_msec(), " objs=", Performance.get_monitor(Performance.OBJECT_COUNT),
			" res=", Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT), " nodes=", Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
			" draws=", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), " vmem=", int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576), "MB static=", int(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576), "MB")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := out.path_join(nm + ".png")
	img.save_png(path)
	print("SHOT ", path, " fps=", Engine.get_frames_per_second())
	get_tree().quit()

func _v(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
