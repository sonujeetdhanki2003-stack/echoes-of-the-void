extends Node
## Prints each interior area's dressing counts (models + decals) after a real load, and checks the damaged wall
## variant: 1-3 per interior area, none beside a door, its torn plates blocked by collision, its crystal pulsing
## and its strip light flickering.  --driver=dress_probe
var passed := 0
var total := 0
func check(ok: bool, what: String) -> void:
	total += 1
	if ok:
		passed += 1
	print(("PASS " if ok else "FAIL ") + what)

func _solid(ar: Node3D, p: Vector3) -> bool:
	var q := PhysicsPointQueryParameters3D.new()
	q.position = p
	q.collision_mask = 1
	return not ar.get_world_3d().direct_space_state.intersect_point(q, 4).is_empty()

func _ready() -> void:
	await get_tree().process_frame
	for a in ["cryo", "research", "security", "reactor"]:
		Game.new_state()
		Game.state["flags"]["cine.wake"] = true
		Game.state["mission"] = 2 if a == "reactor" else 1
		await GameMode.load_area(a, a + "_start", true)
		await get_tree().physics_frame
		var ar = GameMode.area
		var dmg := 0
		for mm in ar.find_children("MM_kit_wall_damaged*", "MultiMeshInstance3D", true, false):
			dmg += (mm as MultiMeshInstance3D).multimesh.instance_count
		print("DAMAGED %-9s %d walls" % [a, dmg])
		check(dmg >= 1 and dmg <= 3, "%s: 1-3 damaged walls (%d)" % [a, dmg])
		var beside := 0
		var blocked := 0
		var free_beside := 0
		var n := 0
		for w in ar.B.wall_edges:
			if w["piece"] != "kit_wall_damaged":
				continue
			n += 1
			var pos: Vector3 = w["pos"]
			var inn: Vector3 = w["in"]
			var al: Vector3 = w["along"]
			for d in ar.B.door_edges:
				var dp: Vector3 = d["pos"]
				if absf(inn.dot((d["in"] as Vector3))) > 0.9 and absf((dp - pos).dot(inn)) < 0.3 and Vector2(dp.x - pos.x, dp.z - pos.z).length() < LevelBuilder.CELL + 0.2:
					beside += 1
			# inside the torn plates (0.45 m out from the wall line, centre of the tear) must be solid;
			# the intact left part of the same wall at the same depth must not be
			if _solid(ar, pos + inn * 0.45 + al * 0.475 + Vector3.UP * 1.9):
				blocked += 1
			if not _solid(ar, pos + inn * 0.45 + al * -1.4 + Vector3.UP * 1.0):
				free_beside += 1
		check(beside == 0, "%s: no damaged wall beside a door (%d)" % [a, beside])
		# the detector itself must see walls that DO sit beside doors (else the check above proves nothing)
		var any_beside := 0
		for w in ar.B.wall_edges:
			for d in ar.B.door_edges:
				var dp2: Vector3 = d["pos"]
				var p2: Vector3 = w["pos"]
				if absf((w["in"] as Vector3).dot((d["in"] as Vector3))) > 0.9 and absf((dp2 - p2).dot(w["in"])) < 0.3 and Vector2(dp2.x - p2.x, dp2.z - p2.z).length() < LevelBuilder.CELL + 0.2:
					any_beside += 1
		check(any_beside > 0, "%s: beside-door detector finds walls next to doors (%d)" % [a, any_beside])
		check(blocked == n, "%s: torn plates blocked by collision (%d/%d)" % [a, blocked, n])
		check(free_beside == n, "%s: intact part of the wall stays walkable (%d/%d)" % [a, free_beside, n])
		var anims := ar.find_children("DamagedWallEmissive*", "Node", true, false)
		if dmg > 0:
			var e: Array = (anims[0]._mats if anims.size() > 0 else [])
			var seen := {"pulse": [], "flicker": []}
			for f in 180:
				await get_tree().process_frame
				for x in e:
					seen[x["mode"]].append((x["mat"] as BaseMaterial3D).emission_energy_multiplier)
			var pr: Array = seen["pulse"]
			var fl: Array = seen["flicker"]
			check(pr.size() > 0 and pr.max() - pr.min() > 0.1 * pr.max(), "%s: crystal emission pulses" % a)
			check(fl.size() > 0 and fl.min() < 0.5 * fl.max(), "%s: broken strip light flickers" % a)
		print("DRESS %-9s walls %3d doors %2d models %3d decals %3d" % [a, ar.B.wall_edges.size(), ar.B.door_edges.size(), ar.dress_stats.get("models", 0), ar.dress_stats.get("decals", 0)])
	print("DMGTEST %d/%d passed" % [passed, total])
	get_tree().quit()
