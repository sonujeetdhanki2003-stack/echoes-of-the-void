extends Node
## v1.1.0 feel and comfort tests: hit-stop, haptics gating, Reduce motion, subtitle size and background,
## frame-rate cap, settings migration from 1.0.1 files.  --driver=feedback
var passed := 0
var failed := 0

func check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, "  ", extra)

func _wait_real(secs: float) -> void:
	await get_tree().create_timer(secs, true, false, true).timeout

func _ready() -> void:
	await get_tree().process_frame
	var saved_settings: Dictionary = Game.settings.duplicate(true)
	var saved_path: String = Game.SETTINGS_PATH
	Feedback.force_on = false
	await _defaults()
	await _pulses()
	await _gating()
	await _hitstop()
	await _frame_cap()
	await _migration()
	await _subtitles()
	Feedback.force_on = false
	Engine.time_scale = 1.0
	Game.SETTINGS_PATH = saved_path
	Game.settings = saved_settings
	Game.apply_settings()
	print("FEEDBACK %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)

func _defaults() -> void:
	check("default: reduce motion off", not bool(Game.settings["reduce_motion"]))
	check("default: vibration on", bool(Game.settings["vibration"]))
	check("default: subtitle size medium", str(Game.settings["subtitle_size"]) == "medium")
	check("default: subtitle background off", not bool(Game.settings["subtitle_bg"]))
	check("default: frame cap unlimited on desktop", int(Game.settings["frame_cap"]) == 0 or Game.is_mobile)

func _pulses() -> void:
	check("pulse: kill", Feedback.pulse_for(Feedback.Kind.KILL) == [90, 0.8])
	check("pulse: weak point", Feedback.pulse_for(Feedback.Kind.WEAKPOINT) == [35, 0.5])
	check("pulse: death", Feedback.pulse_for(Feedback.Kind.DEATH) == [400, 1.0])
	var lo: Array = Feedback.pulse_for(Feedback.Kind.HURT, 2.0)
	var hi: Array = Feedback.pulse_for(Feedback.Kind.HURT, 500.0)
	check("pulse: hurt amplitude floor 0.3", is_equal_approx(float(lo[1]), 0.3), str(lo))
	check("pulse: hurt amplitude cap 1.0", is_equal_approx(float(hi[1]), 1.0), str(hi))
	check("pulse: hurt length 60 ms", int(hi[0]) == 60)

func _gating() -> void:
	# inside a test driver (or any test mode) nothing vibrates and no hit-stop runs unless forced
	check("gate: driver run is not live", not Feedback.vibration_allowed() and not Feedback.hitstop_allowed())
	Feedback.force_on = true
	Game.settings["vibration"] = true
	check("gate: forced and vibration on", Feedback.vibration_allowed())
	Game.settings["vibration"] = false
	check("gate: vibration off blocks pulses", not Feedback.vibration_allowed())
	Game.settings["vibration"] = true
	Game.settings["reduce_motion"] = true
	check("gate: reduce motion blocks hit-stop", not Feedback.hitstop_allowed())
	Game.settings["reduce_motion"] = false
	check("gate: hit-stop allowed when forced", Feedback.hitstop_allowed())

func _hitstop() -> void:
	Feedback.force_on = true
	Game.settings["reduce_motion"] = false
	Engine.time_scale = 1.0
	Feedback.hit_stop(0.12)
	check("hitstop: slows time", is_equal_approx(Engine.time_scale, Feedback.HITSTOP_SCALE), str(Engine.time_scale))
	await _wait_real(0.25)
	check("hitstop: restores time after real-time timeout", is_equal_approx(Engine.time_scale, 1.0), str(Engine.time_scale))
	check("hitstop: not active after restore", not Feedback.stop_active())
	# overlapping stops: the later one owns the restore, and the restored scale is the one from before the first stop
	Feedback.hit_stop(0.05)
	await _wait_real(0.02)
	Feedback.hit_stop(0.2)
	await _wait_real(0.1)
	check("hitstop: overlap keeps the later stop running", is_equal_approx(Engine.time_scale, Feedback.HITSTOP_SCALE))
	await _wait_real(0.25)
	check("hitstop: overlap restores once to 1.0", is_equal_approx(Engine.time_scale, 1.0), str(Engine.time_scale))
	# reduce motion: a kill does nothing to time
	Game.settings["reduce_motion"] = true
	Feedback.on_hit_confirmed(true, true)
	check("hitstop: reduce motion keeps time at 1.0", is_equal_approx(Engine.time_scale, 1.0))
	Game.settings["reduce_motion"] = false
	Feedback.on_hit_confirmed(false, false)
	check("hitstop: plain body hit does not stop time", not Feedback.stop_active())
	Feedback.on_hit_confirmed(false, true)
	check("hitstop: kill stops time", Feedback.stop_active())
	await _wait_real(0.2)
	check("hitstop: kill stop ends", not Feedback.stop_active() and is_equal_approx(Engine.time_scale, 1.0))
	Feedback.on_hit_confirmed(true, false)
	check("hitstop: weak point stops time", Feedback.stop_active())
	await _wait_real(0.15)
	check("hitstop: weak point stop ends", not Feedback.stop_active() and is_equal_approx(Engine.time_scale, 1.0))
	Feedback.force_on = false

func _frame_cap() -> void:
	Game.settings["frame_cap"] = 30
	Game.apply_settings()
	check("frame cap: 30 applied", Engine.max_fps == 30, str(Engine.max_fps))
	Game.settings["frame_cap"] = 120
	Game.apply_settings()
	check("frame cap: 120 applied", Engine.max_fps == 120, str(Engine.max_fps))
	Game.settings["frame_cap"] = 0
	Game.apply_settings()
	check("frame cap: unlimited is 0", Engine.max_fps == 0, str(Engine.max_fps))

func _cfg(path: String, lines: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(lines)
	f.close()

func _migration() -> void:
	var p := "user://feedback_test_settings.cfg"
	Game.SETTINGS_PATH = p
	# a 1.0.1 settings file: none of the new keys present
	_cfg(ProjectSettings.globalize_path(p), "[settings]\nmaster=0.5\nsubtitles=false\ncamera_shake=0.4\nshow_fps=true\nquality=\"high\"\n")
	Game.settings = Game.settings.duplicate(true)
	Game.settings["reduce_motion"] = false
	Game.load_settings()
	check("migrate: old master volume kept", is_equal_approx(float(Game.settings["master"]), 0.5))
	check("migrate: old subtitles off kept", not bool(Game.settings["subtitles"]))
	check("migrate: old camera shake kept", is_equal_approx(float(Game.settings["camera_shake"]), 0.4))
	check("migrate: old show fps kept", bool(Game.settings["show_fps"]))
	check("migrate: new keys take defaults", not bool(Game.settings["reduce_motion"]) and bool(Game.settings["vibration"]) and str(Game.settings["subtitle_size"]) == "medium" and not bool(Game.settings["subtitle_bg"]))
	# bad values from a hand edit: wrong type ignored, unknown words and numbers fall back to defaults
	_cfg(ProjectSettings.globalize_path(p), "[settings]\nvibration=\"yes\"\nsubtitle_size=\"huge\"\nframe_cap=7\nreduce_motion=1\n")
	Game.load_settings()
	check("migrate: wrong type for vibration ignored", bool(Game.settings["vibration"]))
	check("migrate: unknown subtitle size falls back to medium", str(Game.settings["subtitle_size"]) == "medium", str(Game.settings["subtitle_size"]))
	check("migrate: frame cap 7 falls back to default", int(Game.settings["frame_cap"]) == (60 if Game.is_mobile else 0), str(Game.settings["frame_cap"]))
	check("migrate: reduce motion int ignored (type bool kept)", typeof(Game.settings["reduce_motion"]) == TYPE_BOOL)
	# round trip: what we save, we load
	Game.settings["subtitle_size"] = "large"
	Game.settings["frame_cap"] = 120
	Game.settings["reduce_motion"] = true
	Game.save_settings()
	Game.settings["subtitle_size"] = "medium"
	Game.settings["frame_cap"] = 0
	Game.settings["reduce_motion"] = false
	Game.load_settings()
	check("migrate: round trip large subtitles", str(Game.settings["subtitle_size"]) == "large")
	check("migrate: round trip frame cap 120", int(Game.settings["frame_cap"]) == 120)
	check("migrate: round trip reduce motion", bool(Game.settings["reduce_motion"]))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func _subtitles() -> void:
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["subtitles"] = true
	Game.settings["subtitle_size"] = "large"
	Game.settings["subtitle_bg"] = true
	Game.apply_settings()
	await GameMode.load_area("cryo", "cryo_hub", true)
	await get_tree().process_frame
	var ui = GameMode.ui
	Events.subtitle.emit("MIRA", "Hold on, we are almost in range.", 30.0)
	for i in 4:
		await get_tree().process_frame
	check("subtitles: large font size 38", ui.sub_lbl.get_theme_font_size("font_size") == 38, str(ui.sub_lbl.get_theme_font_size("font_size")))
	check("subtitles: speaker font 26", ui.sub_speaker.get_theme_font_size("font_size") == 26)
	check("subtitles: background panel is a flat box", ui.sub_box.get_theme_stylebox("panel") is StyleBoxFlat)
	check("subtitles: visible", ui.sub_box.visible)
	var vr: Rect2 = ui.get_viewport().get_visible_rect()
	var r: Rect2 = ui.sub_box.get_global_rect()
	check("subtitles: large box stays on screen", r.position.x >= 0.0 and r.end.x <= vr.size.x + 0.5 and r.end.y <= vr.size.y + 0.5, "%s in %s" % [r, vr])
	Game.settings["subtitle_size"] = "small"
	Game.settings["subtitle_bg"] = false
	Events.subtitle.emit("MIRA", "Short line.", 3.0)
	for i in 3:
		await get_tree().process_frame
	check("subtitles: small font size 24", ui.sub_lbl.get_theme_font_size("font_size") == 24)
	check("subtitles: background off is an empty box", ui.sub_box.get_theme_stylebox("panel") is StyleBoxEmpty)
	Game.settings["subtitles"] = false
	Events.subtitle.emit("MIRA", "Should not show.", 3.0)
	await get_tree().process_frame
	check("subtitles: off hides the box", not ui.sub_box.visible)
	Game.settings["subtitles"] = true
