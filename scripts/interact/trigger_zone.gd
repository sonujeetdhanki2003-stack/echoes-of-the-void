class_name TriggerZone
extends Area3D
## A volume that fires once (saved by stable ID) when the player enters: story beats, MIRA lines, encounters.

signal entered(player: Player)

@export var stable_id := ""
@export var size := Vector3(4, 3, 4)
@export var once := true
@export var requires_flag := ""
var fired := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	monitorable = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	add_child(cs)
	if once and stable_id != "" and Game.flag("trig." + stable_id):
		fired = true
	body_entered.connect(_on_body)

func _on_body(b: Node) -> void:
	if not (b is Player) or fired:
		return
	# an area being unloaded can still report an overlap this frame: its callbacks capture nodes that are going away
	if not is_inside_tree() or _dying():
		return
	if requires_flag != "" and not Game.flag(requires_flag):
		return
	if (b as Player).dead:
		return
	if once:
		fired = true
		if stable_id != "":
			Game.set_flag("trig." + stable_id)
	entered.emit(b as Player)

func _dying() -> bool:
	var n: Node = self
	while n:
		if n.is_queued_for_deletion():
			return true
		n = n.get_parent()
	return false

## Re-check (e.g. after a required flag gets set while the player already stands inside).
func recheck() -> void:
	if fired:
		return
	for b in get_overlapping_bodies():
		_on_body(b)
