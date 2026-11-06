extends Node
## v1.9.0 menu screenshot attempt (not pass/fail): --driver=menushots --out=<dir>
func _ready() -> void:
	var out := Game.arg("out", "/tmp")
	await get_tree().process_frame
	Game.SAVE_PATH = "user://menushots.json"
	Game.delete_save()
	Game.settings["touch"] = "off"
	get_window().size = Vector2i(1280, 720)
	Game.apply_settings()
	GameMode.ui.show_menu()
	GameMode.ui.fade_to(0.0, 0.3)
	for i in 240:
		await get_tree().process_frame
	await _save(out + "/menu_viewport.png")
	await RenderingServer.frame_post_draw
	DisplayServer.screen_get_image(0).save_png(out + "/menu_screen.png")
	print("MENU_SAVED")
	GameMode.ui._slots_menu()
	GameMode.ui.fade_to(0.0, 0.3)
	for i in 120:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	DisplayServer.screen_get_image(0).save_png(out + "/slots_screen.png")
	print("SLOTS_SAVED")
	Game.delete_save()
	get_tree().quit(0)

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("SAVED ", path)
