extends Node
## v1.1.0 stage 4 tests: the phone frame guard (decision and cap; the trigger itself runs only on Android).  --driver=stage4
var passed := 0
var failed := 0

func check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, "  ", extra)

func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["touch"] = "off"
	Game.apply_settings()
	await GameMode.load_area("cryo", "cryo_hub", true)
	await get_tree().process_frame
	_decision()
	await _cap()
	_desktop_unchanged()
	print("STAGE4 %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)

func _decision() -> void:
	check("guard: fine frame rate keeps the scale", is_equal_approx(Game.phone_guard_next_scale(60.0, 1.0), 1.0))
	check("guard: exactly 28 fps is fine", is_equal_approx(Game.phone_guard_next_scale(28.0, 1.0), 1.0))
	check("guard: 27.9 fps steps down to 0.9", is_equal_approx(Game.phone_guard_next_scale(27.9, 1.0), 0.9), str(Game.phone_guard_next_scale(27.9, 1.0)))
	check("guard: steps down from 0.8 to 0.7", is_equal_approx(Game.phone_guard_next_scale(20.0, 0.8), 0.7), str(Game.phone_guard_next_scale(20.0, 0.8)))
	check("guard: never below 0.6", is_equal_approx(Game.phone_guard_next_scale(20.0, 0.7), 0.6), str(Game.phone_guard_next_scale(20.0, 0.7)))
	check("guard: stays at the floor", is_equal_approx(Game.phone_guard_next_scale(5.0, 0.6), 0.6))

func _cap() -> void:
	var vp := get_viewport()
	Game.phone_render_cap = 0.7
	Game.settings["render_scale"] = 1.0
	Game.apply_settings()
	check("cap: applied to the 3D scale", absf(vp.scaling_3d_scale - 0.7) < 0.001, str(vp.scaling_3d_scale))
	Game.phone_render_cap = 1.0
	Game.apply_settings()
	check("cap: 1.0 leaves the player's scale", absf(vp.scaling_3d_scale - 1.0) < 0.001, str(vp.scaling_3d_scale))

func _desktop_unchanged() -> void:
	Game.phone_render_cap = 1.0
	Game.phone_steps = 0
	for i in 40:
		Game.phone_sample(1.0)
	check("desktop: the phone guard never acts", Game.phone_steps == 0 and Game.phone_render_cap == 1.0)
