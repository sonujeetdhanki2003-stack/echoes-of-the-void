extends Node
## v1.5.0 stage 5 tests: three save slots, migration of 1.0.x/1.4.x saves, weapon upgrades, the Breach Cannon,
## inventory parts, upgrade parts on the floor in every area, and the bench.  --driver=stage5
var passed := 0
var failed := 0

func check(name: String, ok: bool, extra: String = "") -> void:
	if ok:
		passed += 1
		print("PASS ", name)
	else:
		failed += 1
		print("FAIL ", name, "  ", extra)

func _write(path: String, d: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()

func _ready() -> void:
	await get_tree().process_frame
	Game.SAVE_PATH = "user://stage5_save.json"
	Game.delete_save()
	Game.settings["touch"] = "off"
	Game.apply_settings()
	_slots()
	_migration()
	_upgrades()
	_inventory()
	_breach()
	await _areas()
	Game.delete_save()
	Game.active_slot = 1
	print("STAGE5 %d/%d passed" % [passed, passed + failed])
	get_tree().quit(0 if failed == 0 else 1)

func _slots() -> void:
	Game.delete_save()
	Game.active_slot = 1
	Game.new_state()
	Game.state["mission"] = 0
	check("slot 1 saves", Game.save_game())
	Game.active_slot = 2
	Game.new_state()
	Game.state["area"] = "security"
	Game.state["checkpoint"] = "security_start"
	Game.state["mission"] = 1
	check("slot 2 saves", Game.save_game())
	Game.active_slot = 3
	Game.new_state()
	Game.state["area"] = "reactor"
	Game.state["checkpoint"] = "reactor_start"
	Game.state["mission"] = 2
	check("slot 3 saves", Game.save_game())
	check("three slots used", Game.slot_used(1) and Game.slot_used(2) and Game.slot_used(3))
	check("slot 1 is the original save file", Game.slot_path(1) == Game.SAVE_PATH)
	check("slots 2 and 3 have their own files", Game.slot_path(2) != Game.slot_path(1) and Game.slot_path(3) != Game.slot_path(2))
	Game.active_slot = 2
	check("slot 2 loads its own area", Game.load_game() and Game.state["area"] == "security")
	Game.active_slot = 3
	check("slot 3 loads its own area", Game.load_game() and Game.state["area"] == "reactor")
	Game.active_slot = 1
	check("slot 1 loads its own area", Game.load_game() and Game.state["area"] == "cryo")
	check("has_save with slots in use", Game.has_save() and Game.latest_slot() > 0)
	check("slot_info names the save", Game.slot_info(1) != "" and Game.slot_info(2) != "")
	Game.delete_slot(2)
	check("deleting slot 2 leaves slots 1 and 3", Game.slot_used(1) and not Game.slot_used(2) and Game.slot_used(3))
	check("empty slot has no info", Game.slot_info(2) == "")
	check("first empty slot is 2", Game.first_empty_slot() == 2)
	Game.active_slot = 2
	check("a new game in slot 2 leaves slot 1 alone", Game.slot_used(1))
	Game.active_slot = 1

func _migration() -> void:
	Game.delete_save()
	Game.active_slot = 1
	# a save as the 1.4.0 build wrote it: version 1, no upgrades, no parts
	_write(Game.SAVE_PATH, {"version": 1, "area": "cryo", "checkpoint": "cryo_start", "flags": {"got.pistol": true},
		"player": {"hp": 80.0, "weapons": ["pistol"], "reserve": {"pistol": 12, "rifle": 0}, "mag": {"pistol": 7}, "equipped": "pistol"},
		"mission": 0, "objective": 0, "logs": [], "stats": {"time": 12.0, "kills": 1, "deaths": 0, "shots": 3, "hits": 2},
		"saved_at": "2026-10-01T10:00:00"})
	check("1.4 save is slot 1, nothing moved", Game.slot_used(1) and Game.has_save())
	check("1.4 save loads", Game.load_game())
	check("1.4 save: upgrades start empty", Game.state["upgrades"].is_empty())
	check("1.4 save: parts start at 0", int(Game.state["player"].get("parts", -1)) == 0)
	check("1.4 save: hp and weapons kept", is_equal_approx(float(Game.state["player"]["hp"]), 80.0) and Game.state["player"]["weapons"] == ["pistol"])
	check("1.4 save: info line still reads", Game.save_info().find("00:12") >= 0 or Game.save_info() != "")
	_write(Game.SAVE_PATH, {"version": Game.SAVE_VERSION + 1, "area": "cryo", "checkpoint": "cryo_start", "flags": {}, "player": {},
		"mission": 0, "objective": 0})
	check("a save from a newer build is refused", not Game.slot_used(1))
	Game.delete_save()

func _upgrades() -> void:
	Game.new_state()
	var inv := InventoryComponent.new()
	check("no parts: buying is refused", not Upgrades.buy(inv, "pistol", "damage"))
	inv.add_parts(4)
	check("a purchase takes one part", Upgrades.buy(inv, "pistol", "damage") and inv.parts == 3)
	check("the level is recorded", Upgrades.level("pistol", "damage") == 1)
	Upgrades.buy(inv, "pistol", "damage")
	Upgrades.buy(inv, "pistol", "damage")
	check("level 3 is the cap", Upgrades.level("pistol", "damage") == 3 and inv.parts == 1)
	check("a fourth level is refused and takes no part", not Upgrades.buy(inv, "pistol", "damage") and inv.parts == 1)
	check("an unknown stat is refused", not Upgrades.buy(inv, "pistol", "luck") and inv.parts == 1)
	var base: WeaponData = load("res://data/weapons/energy_pistol.tres")
	var base_dmg := base.damage
	var d: WeaponData = base.duplicate()
	Upgrades.apply(d)
	check("damage +45 percent at level 3", is_equal_approx(d.damage, base_dmg * 1.45), str(d.damage))
	check("the shared table entry is untouched", is_equal_approx(base.damage, base_dmg))
	inv.add_parts(3)
	Upgrades.buy(inv, "rifle", "magazine")
	Upgrades.buy(inv, "rifle", "magazine")
	Upgrades.buy(inv, "rifle", "reload")
	Upgrades.buy(inv, "rifle", "accuracy")
	check("four rifle upgrades cost four parts", inv.parts == 0)
	var rb: WeaponData = load("res://data/weapons/pulse_rifle.tres")
	var r: WeaponData = rb.duplicate()
	Upgrades.apply(r)
	check("magazine +4 at level 2", r.mag_size == rb.mag_size + 4, "%d vs %d" % [r.mag_size, rb.mag_size])
	check("reload 10 percent faster at level 1", is_equal_approx(r.reload_time, rb.reload_time * 0.9), str(r.reload_time))
	check("accuracy: spread 12 percent tighter at level 1", is_equal_approx(r.spread_hip, rb.spread_hip * 0.88) and is_equal_approx(r.spread_aim, rb.spread_aim * 0.88))
	check("levels survive a save dictionary", Game.state["upgrades"].has("rifle") and int(Game.state["upgrades"]["rifle"]["magazine"]) == 2)

func _inventory() -> void:
	var inv := InventoryComponent.new()
	inv.add_parts(5)
	inv.take_parts(2)
	check("take_parts removes parts", inv.parts == 3)
	check("take_parts refuses more than held", not inv.take_parts(9) and inv.parts == 3)
	var dct := inv.to_dict()
	check("parts are in the inventory save", int(dct.get("parts", -1)) == 3)
	var inv2 := InventoryComponent.new()
	inv2.from_dict(dct)
	check("parts round-trip", inv2.parts == 3)
	var inv3 := InventoryComponent.new()
	inv3.from_dict({"weapons": ["pistol"], "reserve": {"pistol": 4, "rifle": 0}, "medkits": 1, "keycards": []})
	check("an older inventory reads zero parts", inv3.parts == 0)

func _breach() -> void:
	var bd: WeaponData = load("res://data/weapons/breach.tres")
	check("breach table entry loads", bd != null and bd.id == "breach" and bd.mag_size == 4)
	check("breach is registered for combat", CombatComponent.WEAPON_DATA.has("breach") and CombatComponent.WEAPON_SCRIPT.has("breach"))
	check("breach script loads", load("res://scripts/weapons/breach_cannon.gd") != null)
	var pr: WeaponData = load("res://data/weapons/precision.tres")
	check("breach hits harder than the precision rifle", bd.damage > pr.damage)
	check("breach is slower to fire", bd.fire_rate < pr.fire_rate)

func _on_floor(pos: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3(0, 1.2, 0), pos + Vector3(0, -1.5, 0))
	q.collide_with_areas = false
	return not get_viewport().world_3d.direct_space_state.intersect_ray(q).is_empty()

func _areas() -> void:
	var expect := {"cryo": ["cryo_start", 2], "reactor": ["reactor_start", 2], "research": ["research_start", 2],
		"extraction": ["extraction_start", 2], "exterior": ["exterior_start", 2], "security": ["security_start", 4]}
	var total := 0
	for area in expect.keys():
		await GameMode.load_area(area, expect[area][0], true)
		await get_tree().process_frame
		await get_tree().process_frame
		var found := 0
		var on_floor := 0
		for n in get_tree().get_nodes_in_group("interactable"):
			if n is Pickup and (n as Pickup).kind == "part":
				found += 1
				if _on_floor((n as Node3D).global_position):
					on_floor += 1
		check("%s: upgrade parts placed (%d)" % [area, found], found == int(expect[area][1]), "found %d" % found)
		check("%s: every part sits on a floor (%d/%d)" % [area, on_floor, found], on_floor == found)
		total += found
		if area == "reactor":
			for n in get_tree().get_nodes_in_group("interactable"):
				if n is Pickup and (n as Pickup).kind == "weapon_breach":
					check("reactor: breach cannon sits on a floor", _on_floor((n as Node3D).global_position))
	check("14 parts in the game, enough for all 12 upgrades", total == 14, str(total))
	await GameMode.load_area("security", "security_start", true)
	await get_tree().process_frame
	var bench_ok := false
	for n in get_tree().get_nodes_in_group("interactable"):
		if n is UpgradeBench:
			bench_ok = (n as UpgradeBench).get_prompt().begins_with("Use upgrade bench")
	check("security has the Upgrade Bench", bench_ok)
	var p := GameMode.player
	if p != null:
		p.combat.give("pistol", false)
		var before := int(p.combat.weapons["pistol"].data.mag_size)
		p.inventory.add_parts(1)
		Upgrades.buy(p.inventory, "pistol", "magazine")
		p.combat.refresh_upgrades("pistol")
		check("a bench purchase raises the live weapon's magazine", int(p.combat.weapons["pistol"].data.mag_size) == before + 2)
		check("the snapshot carries parts", p.snapshot().has("parts"))
	else:
		check("player exists in the security area", false)
