extends Node
## v1.1.0 stage 3 screenshots for the release gallery (not a pass/fail test): --driver=s3shots --out=<dir>
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
	p.combat.give("shotgun", false)
	p.combat.give("precision", false)
	p.inventory.add_ammo("pistol", 12)
	p.inventory.add_ammo("rifle", 24)
	p.combat.equip("shotgun", true)
	for i in 30:
		await get_tree().process_frame
	_save(out + "/shotgun-in-hand.png")
	p.combat.equip("precision", true)
	for i in 30:
		await get_tree().process_frame
	_save(out + "/precision-in-hand.png")
	get_tree().quit(0)

func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path)
