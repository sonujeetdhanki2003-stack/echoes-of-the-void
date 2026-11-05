extends Node
## Save -> quit -> relaunch -> continue, across two real processes (the release builds run it under wine / on the box):
##   godot -- --driver=save_xproc --phase=write   (loads security, changes state, manual-saves, quits)
##   godot -- --driver=save_xproc --phase=read    (a NEW process: Continue, then checks area, position, player, flags)
## Uses its own save file (user://xproc_save.json), never the player's save.
const EXPECT := "user://xproc_expect.json"
var passed := 0
var total := 0
func check(ok: bool, what: String) -> void:
	total += 1
	if ok:
		passed += 1
	print(("PASS " if ok else "FAIL ") + what)

func _ready() -> void:
	Game.SAVE_PATH = "user://xproc_save.json"
	await get_tree().process_frame
	if Game.arg("phase", "write") == "write":
		await _write()
	else:
		await _read()
	get_tree().quit()

func _write() -> void:
	Game.delete_save()
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.state["mission"] = 1
	# a real mid-game loadout, so the round trip has something to lose
	Game.state["player"].merge({"weapons": ["pistol", "rifle"], "equipped": "rifle", "medkits": 2,
		"mag": {"pistol": 7, "rifle": 19}, "reserve": {"pistol": 21, "rifle": 60}, "keycards": ["kc_test"]}, true)
	await GameMode.load_area("security", "security_armory", true)
	for i in 90:
		await get_tree().physics_frame
	var pl = GameMode.player
	# walk off the checkpoint spot so the position check means something
	pl.global_position += Vector3(1.6, 0.3, 1.1)
	for i in 40:
		await get_tree().physics_frame
	pl.health.hp = 63.0
	Game.set_flag("xproc.marker", 4242)
	Game.add_log(3)
	Game.state["stats"]["time"] = 754.0
	for i in 10:
		await get_tree().physics_frame
	var ok: bool = GameMode.manual_save()
	var p: Vector3 = pl.global_position
	var exp := {"pos": [p.x, p.y, p.z], "player": pl.snapshot(), "mission": Game.state["mission"], "objective": Game.state["objective"]}
	var f := FileAccess.open(EXPECT, FileAccess.WRITE)
	f.store_string(JSON.stringify(exp))
	f.close()
	print("XPROC WRITE %s at %s hp %.0f save %s" % ["ok" if ok else "FAILED", p, pl.health.hp, ProjectSettings.globalize_path(Game.SAVE_PATH)])

func _read() -> void:
	var exp: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(EXPECT))
	check(Game.has_save(), "a save from the previous process is found")
	check(Game.save_info().find("12:34") >= 0, "menu save line shows the play time (%s)" % Game.save_info())
	var ok: bool = await GameMode.continue_game()
	check(ok, "Continue loads it")
	for i in 30:
		await get_tree().physics_frame
	check(GameMode.area != null and str(Game.state["area"]) == "security", "back in the same area (%s)" % str(Game.state["area"]))
	var pl = GameMode.player
	var want := Vector3(exp["pos"][0], exp["pos"][1], exp["pos"][2])
	var d: float = pl.global_position.distance_to(want) if pl else 999.0
	check(d < 0.6, "player at the saved spot (%.2f m off)" % d)
	check(int(Game.flag_value("xproc.marker", 0)) == 4242, "story flag kept")
	check(3 in Game.state["logs"], "found log kept")
	check(int(Game.state["mission"]) == int(exp["mission"]) and int(Game.state["objective"]) == int(exp["objective"]), "mission and objective kept")
	var a: Dictionary = exp["player"]
	var b: Dictionary = pl.snapshot()
	for k in ["hp", "medkits", "weapons", "equipped", "reserve", "mag", "keycards"]:
		check(_norm(a[k]) == _norm(b[k]), "player %s kept (%s)" % [k, JSON.stringify(b[k])])
	print("XPROC %d/%d passed" % [passed, total])
	Game.delete_save()

## JSON turns every number into a float: compare numbers by value
func _norm(v: Variant) -> String:
	if v is int or v is float:
		return "%.3f" % float(v)
	if v is Array:
		return "[" + ",".join((v as Array).map(func(x): return _norm(x))) + "]"
	if v is Dictionary:
		var ks: Array = (v as Dictionary).keys()
		ks.sort()
		return "{" + ",".join(ks.map(func(k): return str(k) + ":" + _norm(v[k]))) + "}"
	return str(v)
