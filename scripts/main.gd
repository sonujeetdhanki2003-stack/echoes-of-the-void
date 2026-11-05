extends Node
## Entry scene: owns the world root and the UI, registers them with GameMode, and starts the main menu,
## a direct area load (--area=<id> [--cp=<id>]), or a test driver (--autotest / --qa / --shots ...).

var world_root: Node3D
var ui: CanvasLayer

func _ready() -> void:
	world_root = Node3D.new()
	world_root.name = "WorldRoot"
	add_child(world_root)
	ui = load("res://scripts/ui/ui.gd").new()
	ui.name = "UI"
	add_child(ui)
	ui.main = self
	GameMode.register_main(self, ui, world_root)
	Game.apply_settings()
	await get_tree().process_frame
	var driver := Game.arg("driver")
	if Game.test_mode != "" or driver != "":
		var path := "res://tests/%s.gd" % (driver if driver != "" else Game.test_mode)
		if ResourceLoader.exists(path):
			var d: Node = load(path).new()
			d.name = "TestDriver"
			add_child(d)
			return
	var area := Game.arg("area", Game.boot_area)
	if area != "" and Missions.area_exists(area):
		Game.new_state()
		Game.state["mission"] = int(Game.arg("mission", str(Game.boot_mission)))
		ui.fade_to(1.0, 0.0)
		await GameMode.load_area(area, Game.arg("cp", area + "_start"), true)
		return
	ui.show_menu()
	ui.fade_to(0.0, 1.2)
