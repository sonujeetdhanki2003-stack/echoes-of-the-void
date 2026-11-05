extends Node
## Doc 03 named level scenes (cryo_chamber.tscn, …): each boots the game straight into its area, exactly as the
## main scene does after "New Game" / a checkpoint load. Areas are built by scripts/areas/area_<id>.gd.
@export var area_id := "cryo"
@export var mission := 0

func _ready() -> void:
	Game.boot_area = area_id
	Game.boot_mission = mission
	var main: Node = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child.call_deferred(main)
	Events.area_loaded.connect(func(a): print("LEVEL BOOT loaded area ", a, " with player ", GameMode.player != null))
	if Game.arg("quit_after") != "":
		await get_tree().create_timer(float(Game.arg("quit_after"))).timeout
		get_tree().quit()
