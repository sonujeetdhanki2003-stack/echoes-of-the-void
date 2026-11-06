extends Node
## v1.8.0 screenshots for the gallery (not pass/fail): --driver=s9shots --out=<dir>
## main menu, slot picker, THE HOLLOWS (the basin), the three new weapon models in hand, and a melee stagger.
func _ready() -> void:
	var out := Game.arg("out", "/tmp")
	await get_tree().process_frame
	Game.SAVE_PATH = "user://s9shots.json"
	Game.delete_save()
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["touch"] = "off"
	Game.settings["subtitles"] = true
	get_window().size = Vector2i(1280, 720)
	Game.apply_settings()
	Game.new_state()
	Game.save_game()
	GameMode.ui.show_menu()
	await get_tree().create_timer(3.0, true, false, true).timeout
	await _frames(30)
	await _save(out + "/main-menu.png")
	GameMode.ui._slots_menu()
	await get_tree().create_timer(2.0, true, false, true).timeout
	await _frames(30)
	await _save(out + "/load-slots.png")
	GameMode.ui._close_to_game() if GameMode.ui.has_method("_close_to_game") else null
	await GameMode.load_area("hollows", "hollows_start", true)
	await _frames(40)
	var p: Player = GameMode.player
	p.global_position = Vector3(12.0, p.global_position.y, -88.0)
	await _frames(30)
	await _save(out + "/hollows-basin.png")
	await GameMode.load_area("security", "security_start", true)
	await _frames(20)
	p = GameMode.player
	for id in ["shotgun", "precision", "breach"]:
		p.combat.give(id, true)
		await _frames(30)
		await _save(out + "/held-" + id + ".png")
	Game.delete_save()
	get_tree().quit(0)

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame

func _save(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("SAVED ", path)
