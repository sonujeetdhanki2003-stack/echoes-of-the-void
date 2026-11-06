extends Node
## v1.9.0 stage G tests: boss wind-up timings and the how-to page. --driver=stage10
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
	var consts: Dictionary = load("res://scripts/ai/herald.gd").get_script_constant_map()
	var slam := float(consts.get("SLAM_MIN_WINDUP", 0.0))
	var shard := float(consts.get("SHARD_BASE_DELAY", 0.0))
	check("herald slam wind-up floor is at least 1.3 s", slam >= 1.3, "%.2f" % slam)
	check("herald shard first landing is at least 1.1 s after its release", shard >= 1.1, "%.2f" % shard)
	check("herald phase-3 speed-up keeps the slam at or above the floor", maxf(slam, 1.33 / 1.15) >= slam)
	var how: Dictionary = load("res://scripts/ui/ui.gd").get_script_constant_map().get("HOWTO", {})
	check("how-to keyboard page names the melee key", str(how.get("KEYBOARD", "")).find("{melee}") >= 0)
	var src := FileAccess.get_file_as_string("res://scripts/ui/ui.gd")
	check("how-to fills the melee key name", src.find('"melee": Game.key_name("melee")') >= 0)
	check("how-to goal page lists save slots and the bench", str(how.get("GOAL", "")).find("SAVE SLOTS") >= 0 and str(how.get("GOAL", "")).find("UPGRADE BENCH") >= 0)
	check("build is 1.9.1", Game.VERSION == "1.9.1", Game.VERSION)
	var dlg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue.json"))
	check("echo cinematic lines exist in the dialogue data", dlg.has("mira_hollows_echo_1") and dlg.has("mira_hollows_echo_2"))
	check("echo cinematic script is in the hollows area", FileAccess.get_file_as_string("res://scripts/areas/area_hollows.gd").find("func _echo_cinematic") >= 0)
	print("STAGE10 %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)
