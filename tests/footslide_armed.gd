extends Node
## Diagnostic 1.9.4 (bug 9): foot slide. Walks the player at several stick speeds on the cryo bay floor and measures,
## for each foot, the horizontal ground speed of the foot bone while the foot is planted (lowest part of the stride).
## A planted foot should not move over the ground; the slide is its ground speed in planted frames.
##   godot --headless --fixed-fps 60 -- --driver=footslide
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("cryo", "cryo_hub", true)
	await frames(60)
	var p: Player = GameMode.player
	p.health.dmg_mult = 0.0
	p.combat.give("rifle")
	p.combat.equip("rifle")
	await frames(20)
	
	var sk: Skeleton3D = null
	for s in p.find_children("*", "Skeleton3D", true, false):
		sk = s
	if sk == null:
		print("FOOT no skeleton")
		get_tree().quit(1)
		return
	var lf := sk.find_bone("foot.L")
	var rf := sk.find_bone("foot.R")
	print("FOOT bones ", lf, " ", rf)
	for spd in [0.35, 0.6, 1.0]:
		var hub := GameMode.area.checkpoint_xform("cryo_hub")
		p.place(Transform3D(Basis(Vector3.UP, deg_to_rad(180.0)), hub.origin + Vector3(0, 0.1, 0)))
		p.controller.yaw = 180.0
		p.controller.snap_to(deg_to_rad(180.0))
		await frames(30)
		p.touch_move = Vector2(0, -spd)
		await frames(90)
		var samples := []
		var vel_sum := 0.0
		var vel_n := 0
		var prev := {}
		for i in 240:
			await get_tree().physics_frame
			var rows := {}
			for b in [["L", lf], ["R", rf]]:
				var gp := sk.global_transform * sk.get_bone_global_pose(b[1]).origin
				rows[b[0]] = gp
			samples.append([p.global_position, rows])
			vel_sum += Vector2(p.velocity.x, p.velocity.z).length()
			vel_n += 1
		print("FOOT_VEL stick=%.2f mean_velocity_mps=%.3f" % [spd, vel_sum / maxf(1.0, vel_n)])
		p.touch_move = Vector2.ZERO
		await frames(60)
		# per frame, the planted foot: lower than 0.12 m above the lowest point seen in the window
		var floor_y := 1e9
		for s2 in samples:
			for k in ["L", "R"]:
				floor_y = minf(floor_y, (s2[1][k] as Vector3).y)
		var slide := {"L": [], "R": []}
		var body := []
		for i in range(1, samples.size()):
			var a: Array = samples[i - 1]
			var b: Array = samples[i]
			var body_v: float = Vector2(b[0].x - a[0].x, b[0].z - a[0].z).length() * 60.0
			body.append(body_v)
			for k in ["L", "R"]:
				var fa: Vector3 = a[1][k]
				var fb: Vector3 = b[1][k]
				if fb.y - floor_y < 0.08 and fa.y - floor_y < 0.08:
					slide[k].append(Vector2(fb.x - fa.x, fb.z - fa.z).length() * 60.0)
		var ms := func(arr: Array) -> float:
			if arr.is_empty():
				return -1.0
			var t := 0.0
			for v in arr:
				t += float(v)
			return t / arr.size()
		var at: AnimationTree = p.anim.tree
		print("FOOT_TREE wake=%s dead=%s tree=%s loco_u=%s scale=%s active=%s tr=%s" % [str(p.anim.wake_mode), str(p.anim._dead), str(p.anim.tree != null), str(at.get("parameters/loco_u/blend_position")), str(at.get("parameters/loco_speed/scale")), str(at.active), str(at.get("parameters/state/transition_request"))])
		var ymin := 1e9
		var ymax := -1e9
		for s2 in samples:
			ymin = minf(ymin, (s2[1]["L"] as Vector3).y)
			ymax = maxf(ymax, (s2[1]["L"] as Vector3).y)
		print("FOOT_AMP stick=%.2f left_foot_y %.3f..%.3f" % [spd, ymin, ymax])
		# relative to the body: a planted foot moves backward at the body speed, so the mean of (foot - body) along
		# the body's forward axis over planted frames should be -body speed (tests the cycle rate, not the blend)
		var rel := {"L": [], "R": []}
		for i in range(1, samples.size()):
			var a2: Array = samples[i - 1]
			var b2: Array = samples[i]
			var bv := Vector3(b2[0].x - a2[0].x, 0, b2[0].z - a2[0].z) * 60.0
			for k in ["L", "R"]:
				var fa2: Vector3 = a2[1][k]
				var fb2: Vector3 = b2[1][k]
				if fb2.y - floor_y < 0.08 and fa2.y - floor_y < 0.08:
					var fv := Vector3(fb2.x - fa2.x, 0, fb2.z - fa2.z) * 60.0
					var fwd := Vector3(sin(p.rotation.y), 0, cos(p.rotation.y))
					rel[k].append((fv - bv).dot(fwd))
		var drift := {"L": 0.0, "R": 0.0}
		for k2 in ["L", "R"]:
			var f0: Vector3 = samples[0][1][k2]
			var f1: Vector3 = samples[samples.size() - 1][1][k2]
			var fwd2 := Vector3(sin(p.rotation.y), 0, cos(p.rotation.y))
			drift[k2] = (Vector3(f1.x - f0.x, 0, f1.z - f0.z) * 60.0 / (samples.size() - 1)).dot(fwd2)
		var bdisp: Vector3 = samples[samples.size() - 1][0] - samples[0][0]
		var bvel := Vector3(bdisp.x, 0, bdisp.z).dot(Vector3(sin(p.rotation.y), 0, cos(p.rotation.y))) * 60.0 / (samples.size() - 1)
		print("FOOT_PACE stick=%.2f body_fwd=%.3f foot_L=%.3f foot_R=%.3f (over %d frames)" % [spd, bvel, drift["L"], drift["R"], samples.size()])
		print("FOOT_REL stick=%.2f rel_L=%.3f rel_R=%.3f (expect %.3f)" % [spd, ms.call(rel["L"]), ms.call(rel["R"]), -spd * 1.0])
		var body_avg: float = ms.call(body)
		print("FOOT stick=%.2f body_mps=%.2f planted_samples L=%d R=%d slide_L_mps=%.3f slide_R_mps=%.3f" % [spd, body_avg, slide["L"].size(), slide["R"].size(), ms.call(slide["L"]), ms.call(slide["R"])])
	get_tree().quit(0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
