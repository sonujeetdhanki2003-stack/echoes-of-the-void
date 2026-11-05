extends Node
## Checks the reactor reveal figure: which way it faces and that turn_head lifts the head.  --driver=fig_probe
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.state["mission"] = 2
	await GameMode.load_area("reactor", "reactor_start", true)
	var f: Node3D = GameMode.area.iyer_fig
	var s: Skeleton3D = f.find_children("*", "Skeleton3D", true, false)[0]
	var hi := s.find_bone("head")
	var ni := s.find_bone("neck")
	GameMode.area._fig_turn(f)
	for k in 7:
		var hp := s.global_transform * s.get_bone_global_pose(hi).origin
		var np := s.global_transform * s.get_bone_global_pose(ni).origin
		var hb: Basis = (s.global_transform.basis * s.get_bone_global_pose(hi).basis).orthonormalized()
		var fwd := f.global_basis.z
		print("FIG t=%.1f head_y=%.3f head_off_fwd=%.3f head_axes_dot_fwd y=%.2f z=%.2f" % [k * 0.5, hp.y, (hp - np).dot(fwd), hb.y.dot(fwd), hb.z.dot(fwd)])
		await get_tree().create_timer(0.5).timeout
	var hb2: Basis = (s.global_transform.basis * s.get_bone_global_pose(hi).basis).orthonormalized()
	print("FIGTEST ", "PASS" if hb2.z.dot(f.global_basis.z) > 0.9 else "FAIL", " (head faces the figure's +Z after turn_head; the reveal turns +Z to the camera)")
	get_tree().quit()
