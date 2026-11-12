extends Node
## Diagnostic 1.9.5 (bug 9): the walk cycle's real planted-foot speed. The body stands still, the walk clip plays
## alone at playback scale 1 (its authored ground speed), and the planted foot's world speed is measured.
##   godot --headless --fixed-fps 60 -- --driver=walkclip
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	await GameMode.load_area("cryo", "cryo_hub", true)
	await frames(60)
	var p: Player = GameMode.player
	p.health.dmg_mult = 0.0
	var sk: Skeleton3D = null
	for s in p.find_children("*", "Skeleton3D", true, false):
		sk = s
	var lf := sk.find_bone("foot.L")
	var rf := sk.find_bone("foot.R")
	var hub := GameMode.area.checkpoint_xform("cryo_hub")
	p.place(Transform3D(Basis(Vector3.UP, deg_to_rad(180.0)), hub.origin + Vector3(0, 0.1, 0)))
	p.controller.yaw = 180.0
	p.controller.snap_to(deg_to_rad(180.0))
	p.anim.set_process(false)
	var tree: AnimationTree = p.anim.tree
	tree.set("parameters/state/transition_request", "unarmed")
	for pos in [1.9, 4.1]:
		tree.set("parameters/loco_u/blend_position", pos)
		tree.set("parameters/loco_speed/scale", 1.0)
		await frames(60)
		var samples := []
		for i in 240:
			await get_tree().physics_frame
			var rows := {}
			for b in [["L", lf], ["R", rf]]:
				rows[b[0]] = sk.global_transform * sk.get_bone_global_pose(b[1]).origin
			samples.append(rows)
		var floor_y := 1e9
		for s2 in samples:
			for k in ["L", "R"]:
				floor_y = minf(floor_y, (s2[k] as Vector3).y)
		var sums := {"L": [0.0, 0], "R": [0.0, 0]}
		var all := {"L": [], "R": []}
		for i in range(1, samples.size()):
			for k in ["L", "R"]:
				var fa: Vector3 = samples[i - 1][k]
				var fb: Vector3 = samples[i][k]
				var v := Vector2(fb.x - fa.x, fb.z - fa.z).length() * 60.0
				all[k].append([fb.y - floor_y, v])
		for k in ["L", "R"]:
			var lows := []
			for e in all[k]:
				if e[0] < 0.05:
					lows.append(e[1])
			var t := 0.0
			for v in lows:
				t += v
			print("WALKCLIP pos=%.2f foot=%s stance_frames=%d stance_world_mps=%.3f all_frames_mps=%.3f" % [pos, k, lows.size(), t / maxf(1.0, lows.size()), (all[k].reduce(func(a, e): return a + e[1], 0.0)) / all[k].size()])
		var ymin := 1e9
		var ymax := -1e9
		for s2 in samples:
			ymin = minf(ymin, (s2["L"] as Vector3).y)
			ymax = maxf(ymax, (s2["L"] as Vector3).y)
		print("WALKCLIP_AMP left_foot_y %.3f..%.3f" % [ymin, ymax])
	get_tree().quit(0)

func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame
	await get_tree().process_frame
