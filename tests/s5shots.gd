extends Node
## v1.5.0 screenshots for the gallery (not pass/fail): --driver=s5shots --out=<dir>
func _ready() -> void:
	var out := Game.arg("out", "/tmp")
	await get_tree().process_frame
	Game.SAVE_PATH = "user://s5shots.json"
	Game.delete_save()
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["touch"] = "off"
	Game.settings["subtitles"] = false
	get_window().size = Vector2i(1600, 900)
	Game.apply_settings()
	await GameMode.load_area("security", "security_start", true)
	for i in 10:
		await get_tree().process_frame
	var p: Player = GameMode.player
	p.combat.give("rifle", false)
	p.combat.give("precision", false)
	p.combat.give("breach", false)
	p.inventory.add_ammo("rifle", 40)
	p.inventory.add_parts(5)
	Upgrades.buy(p.inventory, "precision", "damage")
	Upgrades.buy(p.inventory, "precision", "accuracy")
	Upgrades.buy(p.inventory, "rifle", "magazine")
	p.combat.refresh_upgrades("precision")
	p.combat.refresh_upgrades("rifle")
	GameMode.ui.open_bench(p)
	for i in 20:
		await get_tree().process_frame
	_save(out + "/bench-upgrades.png")
	GameMode.ui._close_to_game()
	GameMode.ui.open_journal(false)
	for i in 20:
		await get_tree().process_frame
	_save(out + "/inventory-categories.png")
	GameMode.ui._close_to_game()
	GameMode.ui.show_menu()
	for i in 20:
		await get_tree().process_frame
	Game.new_state()
	Game.save_game()
	GameMode.ui.show_menu()
	for i in 20:
		await get_tree().process_frame
	_save(out + "/main-menu.png")
	GameMode.ui._slots_menu()
	for i in 20:
		await get_tree().process_frame
	_save(out + "/load-slots.png")
	Game.delete_save()
	get_tree().quit(0)

func _save(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path)
