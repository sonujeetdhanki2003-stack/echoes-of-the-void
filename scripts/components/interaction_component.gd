class_name InteractionComponent
extends Node
## PRD BP_EOT_InteractionComponent: finds the best interactable in front of the player and uses it.
## Anything in the "interactable" group that implements the Interactable contract (PRD BPI_Interactable):
##   get_prompt() -> String, can_interact(player) -> bool, interact(player), interact_range() -> float

var player: Player
var focus: Node = null
var _t := 0.0
var _hold := 0.0

func setup(p: Player) -> void:
	player = p

func _physics_process(delta: float) -> void:
	if player == null or player.dead:
		_set_focus(null)
		return
	_t -= delta
	if _t <= 0.0:
		_t = 0.08
		_set_focus(null if player.locked else _find())
	# hold-to-use interactables (manual door cranks)
	if focus and focus.has_method("hold_time") and float(focus.hold_time()) > 0.0:
		if Input.is_action_pressed("interact"):
			_hold += delta
			if focus.has_method("set_hold_progress"):
				focus.set_hold_progress(_hold / float(focus.hold_time()))
			if _hold >= float(focus.hold_time()):
				_hold = 0.0
				focus.interact(player)
		else:
			if _hold > 0.0 and focus.has_method("set_hold_progress"):
				focus.set_hold_progress(0.0)
			_hold = 0.0

func _find() -> Node:
	var best: Node = null
	var best_score := INF
	var from := player.chest()
	if not player.controller.cam.is_inside_tree():
		return null
	var cam_f: Vector3 = -player.controller.cam.global_transform.basis.z
	for n in player.get_tree().get_nodes_in_group("interactable"):
		if not (n is Node3D) or not n.is_inside_tree() or not n.has_method("interact"):
			continue
		if n.has_method("can_focus") and not n.can_focus(player):
			continue
		var p: Vector3 = n.focus_point() if n.has_method("focus_point") else (n as Node3D).global_position
		var rng: float = n.interact_range() if n.has_method("interact_range") else 2.2
		var d := from.distance_to(p)
		if d > rng:
			continue
		var to := (p - from).normalized()
		var flat_f := player.forward()
		var ang := minf(cam_f.angle_to(to), flat_f.angle_to(to))
		if ang > deg_to_rad(75.0) and d > 1.1:
			continue
		var q := PhysicsRayQueryParameters3D.create(from, p, 1)
		q.exclude = [player.get_rid()]
		var hit := player.get_world_3d().direct_space_state.intersect_ray(q)
		if hit and hit["position"].distance_to(p) > 0.45:
			var c: Object = hit["collider"]
			if not (c is Node and ((c as Node) == n or (n as Node).is_ancestor_of(c as Node))):
				continue
		var score := d + ang * 1.5
		if score < best_score:
			best_score = score
			best = n
	return best

func _set_focus(n: Node) -> void:
	if n == focus:
		if focus:
			var pr: String = focus.get_prompt()
			if pr != _last_prompt:
				_last_prompt = pr
				Events.interact_focus.emit(pr)
		return
	if focus and is_instance_valid(focus) and focus.has_method("set_highlight"):
		focus.set_highlight(false)
	focus = n
	_hold = 0.0
	if focus and focus.has_method("set_highlight"):
		focus.set_highlight(true)
	_last_prompt = focus.get_prompt() if focus else ""
	Events.interact_focus.emit(_last_prompt)

var _last_prompt := ""

func interact() -> void:
	if focus == null or not is_instance_valid(focus) or player.locked:
		return
	if focus.has_method("hold_time") and float(focus.hold_time()) > 0.0:
		return
	if focus.has_method("can_interact") and not focus.can_interact(player):
		if focus.has_method("denied"):
			focus.denied(player)
		return
	focus.interact(player)
	_t = 0.0
