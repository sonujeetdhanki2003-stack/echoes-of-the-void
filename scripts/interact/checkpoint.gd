class_name Checkpoint
extends TriggerZone
## Autosave checkpoint (PRD checkpoints with stable IDs). Entering saves the game once per playthrough.

func _ready() -> void:
	super._ready()
	entered.connect(func(_p): Events.checkpoint_reached.emit(stable_id))

func _on_body(b: Node) -> void:
	if not (b is Player) or fired or (b as Player).dead:
		return
	if Game.flag("cp." + stable_id):
		fired = true
		return
	fired = true
	Game.set_flag("cp." + stable_id)
	entered.emit(b as Player)
