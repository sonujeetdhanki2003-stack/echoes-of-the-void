extends Node
## Performance probe (Post-PRD Phase 10): per area, at its main checkpoint, average frame time and the renderer's
## own counters (draw calls, objects, primitives, video memory) over 4 s, with occlusion culling on or off.
##   xvfb-run godot --rendering-method forward_plus --resolution 1280x720 -- --driver=perf [--occ=0]
func _ready() -> void:
	await get_tree().process_frame
	get_viewport().use_occlusion_culling = Game.arg("occ", "1") == "1"
	# --quality=mobile measures the phone preset (the Android default) on this renderer
	if Game.arg("quality", "") != "":
		Game.settings["quality"] = Game.arg("quality", "")
	print("PERF renderer %s quality %s" % [RenderingServer.get_current_rendering_method(), Game.settings["quality"]])
	var cps := {"cryo": "cryo_hub", "research": "research_atrium", "security": "security_corr", "reactor": "reactor_control", "exterior": "exterior_start", "extraction": "extraction_pad"}
	for a in Game.arg("areas", "cryo,research,security,reactor,exterior,extraction").split(","):
		Game.new_state()
		Game.state["flags"]["cine.wake"] = true
		Game.state["mission"] = 3 if a in ["exterior", "extraction"] else (2 if a == "reactor" else 1)
		var t0 := Time.get_ticks_msec()
		await GameMode.load_area(a, cps[a], true)
		var load_ms := Time.get_ticks_msec() - t0
		for e in get_tree().get_nodes_in_group("enemy"):
			e.set_physics_process(false)
		await get_tree().create_timer(2.0).timeout
		var n := 0
		var ft := 0.0
		var dc := 0
		var ob := 0
		var pr := 0
		var t1 := Time.get_ticks_usec()
		while n < 6:
			await get_tree().process_frame
			n += 1
			dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			ob += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			pr += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		ft = float(Time.get_ticks_usec() - t1) / 1000.0 / n
		print("PERF %-10s occ=%s load %5d ms  frame %7.1f ms  draws %5d  objects %5d  prims %8d  vram %5.0f MB  static %4.0f MB" % [a, Game.arg("occ", "1"), load_ms, ft, dc / n, ob / n, pr / n,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0, OS.get_static_memory_usage() / 1048576.0])
	get_tree().quit()
