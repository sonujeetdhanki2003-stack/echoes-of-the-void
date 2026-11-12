extends Node
## 1.9.5 tests: bug 8 (the fallen beam's light strip is hidden), bug 10 (no cable bundle under the arc hazard), the
## VIEW toggle and the view key.  --driver=bugs195
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
	await get_tree().process_frame

func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("cryo", "cryo_start", true)
	await frames(20)
	# bug 8: the strip is hidden, either as a hidden transparent node or as an invisible EmitLight surface override
	var shown := 0
	var hidden_n := 0
	for mi in get_tree().root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.get_parent() == null or not str(m.get_parent().name).begins_with("fallen_beam"):
			continue
		for s in m.mesh.get_surface_count():
			var ov := m.get_surface_override_material(s) as BaseMaterial3D
			var act := m.get_active_material(s)
			if ov != null and ov.albedo_color.a == 0.0:
				hidden_n += 1
			elif act and act.resource_name == "EmitLight":
				shown += 1
	check("bug 8: the fallen beam's floating light strip is hidden", hidden_n == 1 and shown == 0, "hidden %d shown %d" % [hidden_n, shown])

	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("reactor", "reactor_start", true)
	await frames(20)
	var arcs := []
	for hz in get_tree().root.find_children("*", "HazardZone", true, false):
		if str(hz.get("kind")) == "arc":
			arcs.append(hz)
	check("the arc hazard is still placed", arcs.size() == 1, "arcs %d" % arcs.size())
	var cable_near := 0
	for c in get_tree().root.find_children("cable_bundle*", "Node3D", true, false):
		for a in arcs:
			if (c as Node3D).global_position.distance_to((a as Node3D).global_position) < 1.5:
				cable_near += 1
	check("bug 10: no cable bundle under the arc hazard", cable_near == 0, "cables near %d" % cable_near)

	var p: Player = GameMode.player
	var fp0: bool = p.controller.first_person
	p.controller.toggle_first_person()
	var fp1: bool = p.controller.first_person
	var vis1: bool = p.model_root.visible
	p.controller.toggle_first_person()
	var fp2: bool = p.controller.first_person
	var vis2: bool = p.model_root.visible
	check("VIEW toggles first and third person (and the model follows)", fp1 != fp0 and fp2 == fp0 and vis1 != vis2 and vis2 == true, "%s %s %s vis %s %s" % [fp0, fp1, fp2, vis1, vis2])
	check("the view key is bound", InputMap.has_action("view") and InputMap.action_get_events("view").size() > 0)
	print("BUGS195 %d/%d passed" % [passed, passed + failed])
	get_tree().quit(1 if failed > 0 else 0)
