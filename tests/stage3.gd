extends Node
## v1.1.0 stage 3 tests: the scatter shotgun and the new weapon wiring.  --driver=stage3
var passed := 0
var failed := 0

func check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, "  ", extra)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["touch"] = "off"
	Game.apply_settings()
	await GameMode.load_area("cryo", "cryo_hub", true)
	await frames(10)
	_data()
	_pellets()
	await _wiring()
	await _precision()
	_keys()
	print("STAGE3 %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)

func _data() -> void:
	var d: WeaponData = load("res://data/weapons/shotgun.tres")
	check("data: shotgun id", d.id == "shotgun")
	check("data: shotgun uses energy cells", d.ammo_type == "pistol")
	check("data: seven pellets", d.pellets == 7)
	check("data: not automatic", not d.automatic)
	var r: WeaponData = load("res://data/weapons/pulse_rifle.tres")
	check("data: normal weapons keep one pellet", r.pellets == 1)
	check("data: shotgun close-range damage per trigger is high", d.damage * d.pellets >= 60.0, str(d.damage * d.pellets))

func _pellets() -> void:
	var fwd := Vector3(0, 0, -1)
	var dirs: Array = ScatterShotgun.pellet_dirs(fwd, 7, 5.0)
	check("pellets: count is seven", dirs.size() == 7, str(dirs.size()))
	check("pellets: first pellet on the aim line", (dirs[0] as Vector3).is_equal_approx(fwd))
	var cone_ok := true
	var widest := 0.0
	for i in range(1, dirs.size()):
		var a := rad_to_deg(acos(clampf((dirs[i] as Vector3).dot(fwd), -1.0, 1.0)))
		widest = maxf(widest, a)
		if a > 5.0 + 0.1 or a < 0.5:
			cone_ok = false
	check("pellets: each inside the 5 degree cone", cone_ok, "widest %.2f" % widest)
	check("pellets: they spread (not all the same line)", widest > 2.0, "widest %.2f" % widest)
	var unit := true
	for d in dirs:
		if absf((d as Vector3).length() - 1.0) > 0.001:
			unit = false
	check("pellets: unit directions", unit)
	var one: Array = ScatterShotgun.pellet_dirs(fwd, 1, 5.0)
	check("pellets: one pellet is the plain shot", one.size() == 1)
	var side: Array = ScatterShotgun.pellet_dirs(Vector3(1, 0, 0), 7, 4.0)
	check("pellets: works for any aim direction", side.size() == 7 and (side[0] as Vector3).is_equal_approx(Vector3(1, 0, 0)))

func _wiring() -> void:
	var p: Player = GameMode.player
	check("wiring: starts without the shotgun", not p.inventory.has_weapon("shotgun"))
	p.combat.give("shotgun", false)
	check("wiring: give adds it to the inventory", p.inventory.has_weapon("shotgun"))
	check("wiring: give builds the weapon", p.combat.weapons.has("shotgun") and p.combat.weapons["shotgun"] is ScatterShotgun)
	p.inventory.add_ammo("pistol", 12)
	var w: ScatterShotgun = p.combat.weapons["shotgun"]
	w.mag = w.data.mag_size
	p.combat.equip("shotgun", true)
	check("wiring: equip makes it current", p.combat.current_id() == "shotgun")
	var before := w.mag
	var shots0: int = int(Game.state["stats"]["shots"])
	var ok := w.fire()
	check("fire: one trigger uses one round", ok and w.mag == before - 1, "mag %d -> %d" % [before, w.mag])
	check("fire: counts one shot in the stats", int(Game.state["stats"]["shots"]) == shots0 + 1)
	check("fire: cooldown blocks an immediate second trigger", not w.can_fire())
	await frames(60)
	var m: Dictionary = p.combat.mags()
	check("save: magazine state includes the shotgun", m.has("shotgun") and int(m["shotgun"]) == w.mag)
	p.combat.restore(m, "shotgun")
	check("save: restore keeps the shotgun equipped", p.combat.current_id() == "shotgun")
	check("save: restore keeps its magazine", int(p.combat.weapons["shotgun"].mag) == w.mag)
	check("ammo: the energy-cell reserve is shared (pistol pool exists)", p.inventory.reserve.has("pistol"))
	p.combat.equip("pistol", true)

func _precision() -> void:
	var d: WeaponData = load("res://data/weapons/precision.tres")
	check("precision: id and rifle cells", d.id == "precision" and d.ammo_type == "rifle")
	check("precision: one pellet, not automatic", d.pellets == 1 and not d.automatic)
	check("precision: hits much harder than a rifle shot", d.damage >= 3.0 * float(load("res://data/weapons/pulse_rifle.tres").damage))
	check("precision: slower than the rifle", d.fire_rate < float(load("res://data/weapons/pulse_rifle.tres").fire_rate))
	var p: Player = GameMode.player
	p.combat.give("precision", false)
	check("precision: given to the player", p.inventory.has_weapon("precision") and p.combat.weapons.has("precision"))
	p.combat.equip("precision", true)
	check("precision: equips", p.combat.current_id() == "precision")
	var w: PrecisionRifle = p.combat.weapons["precision"]
	w.mag = w.data.mag_size
	var before := w.mag
	check("precision: one trigger, one round", w.fire() and w.mag == before - 1)
	check("precision: cooldown after the shot", not w.can_fire())
	var m: Dictionary = p.combat.mags()
	check("precision: magazine saved", m.has("precision") and int(m["precision"]) == w.mag)
	p.combat.equip("pistol", true)

func _keys() -> void:
	check("keys: weapon 4 action exists", InputMap.has_action("weapon_4"))
	check("keys: weapon 4 defaults to key 4", Game.DEFAULT_KEYS.has("weapon_4") and Game.DEFAULT_KEYS["weapon_4"].has(KEY_4))
	check("keys: weapon 3 action exists", InputMap.has_action("weapon_3"))
	check("keys: weapon 3 defaults to key 3", Game.DEFAULT_KEYS.has("weapon_3") and Game.DEFAULT_KEYS["weapon_3"].has(KEY_3))
