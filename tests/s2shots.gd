extends Node
## v1.1.0 stage 2 screenshots for the release gallery (not a pass/fail test): --driver=s2shots --out=<dir>
func _ready() -> void:
	var out := Game.arg("out", "/tmp")
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["touch"] = "off"
	Game.settings["subtitles"] = false
	get_window().size = Vector2i(1600, 900)
	Game.apply_settings()
	await GameMode.load_area("cryo", "cryo_hub", true)
	for i in 10:
		await get_tree().process_frame
	var p: Player = GameMode.player
	var fwd := -p.global_transform.basis.z
	var h: EnemyBase = GameMode.area.enemy("hunter", "shot_h", p.global_position + fwd * 5.0 + Vector3(-1.4, 0, 0), 0.0)
	var e: Experimental = GameMode.area.enemy("experimental", "shot_e", p.global_position + fwd * 7.5 + Vector3(1.6, 0, 0), 0.0)
	for i in 30:
		await get_tree().physics_frame
	for en in [h, e]:
		en.set_state(EnemyBase.State.IDLE)
		en.perception.enabled = false
	for i in 20:
		await get_tree().process_frame
	_save(out + "/hunter-and-experimental.png")
	e.release_spores()
	for i in 10:
		await get_tree().process_frame
	_save(out + "/spore-cloud.png")
	get_tree().quit(0)

func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path)
