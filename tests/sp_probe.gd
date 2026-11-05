extends Node
func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.state["mission"] = 3
	await GameMode.load_area("extraction", "extraction_pad", true)
	print("SP ", GameMode.area.shuttle.global_position, " ", GameMode.area.shuttle.rotation_degrees)
	get_tree().quit()
