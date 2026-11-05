class_name PlayerAnim
extends Node
## Animation driver for the astronaut: builds an AnimationTree in code (locomotion blend spaces, an upper-body
## aim/weapon layer filtered to the spine and above, and one-shot layers for fire/reload/equip/actions).
## Falls back to a simple procedural placeholder if the model is missing.

const MODEL := "res://assets/models/astronaut.glb"
const UPPER_BONES := ["spine1", "chest", "neck", "head", "shoulder.L", "upper_arm.L", "forearm.L", "hand.L", "fingers.L", "thumb.L", "shoulder.R", "upper_arm.R", "forearm.R", "hand.R", "fingers.R", "thumb.R", "prop.R"]

var player: Player
var model: Node3D
var ap: AnimationPlayer
var tree: AnimationTree
var skel: Skeleton3D
var hand_attach: Node3D
var weapon_id := ""
var placeholder := false
var _busy_full := 0.0
var _dead := false
var _speeds := {"walk": 1.9, "run": 4.1, "sprint": 6.3, "crouch": 1.6}
var _lamp_mats: Array = []
var _ph_body: Node3D
var _t := 0.0
var _loco_scale := 1.0

func setup(p: Player) -> void:
	player = p
	if ResourceLoader.exists(MODEL):
		var ps: PackedScene = load(MODEL)
		model = ps.instantiate()
		model.rotation.y = PI
		p.model_root.add_child(model)
		ap = model.find_child("AnimationPlayer", true, false)
		skel = model.find_child("Skeleton3D", true, false) as Skeleton3D
		_read_manifest()
		for mi in model.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			for i in m.get_surface_override_material_count():
				var mat := m.mesh.surface_get_material(i)
				if mat and mat.resource_name.begins_with("EmitLamp"):
					var dup := mat.duplicate() as BaseMaterial3D
					m.set_surface_override_material(i, dup)
					_lamp_mats.append(dup)
		set_char_layer(model)
		if ap and skel:
			_build_tree()
		else:
			push_warning("astronaut.glb has no AnimationPlayer/Skeleton3D")
	else:
		_build_placeholder()
	if skel and skel.find_bone("prop.R") != -1:
		var ba := BoneAttachment3D.new()
		ba.bone_name = "prop.R"
		skel.add_child(ba)
		hand_attach = ba
	elif hand_attach == null:
		hand_attach = Node3D.new()
		hand_attach.position = Vector3(0.22, 1.12, -0.35)
		p.model_root.add_child(hand_attach)

func _read_manifest() -> void:
	var path := MODEL.get_basename() + ".json"
	if not FileAccess.file_exists(path):
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(path)) != OK or not (j.data is Dictionary):
		return
	for c in (j.data as Dictionary).get("clips", []):
		if c is Dictionary and c.has("ground_speed_mps"):
			var n: String = c.get("name", "")
			var sp := float(c["ground_speed_mps"])
			if sp > 0.1:
				_speeds[n] = sp

func _spd(clip: String, def: float) -> float:
	return float(_speeds.get(clip, def))

func _has(clip: String) -> bool:
	return ap != null and ap.has_animation(clip)

func _clip(name: String, fallback: String = "") -> String:
	if _has(name):
		return name
	if fallback != "" and _has(fallback):
		return fallback
	return ""

func _anim_node(clip: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = clip
	return n

func _set_loops() -> void:
	var loops := ["idle", "walk", "run", "crouch_idle", "crouch_walk", "fall", "rifle_idle", "rifle_walk", "rifle_walk_back",
		"rifle_strafe_l", "rifle_strafe_r", "rifle_run", "rifle_sprint", "rifle_crouch_idle", "rifle_crouch_walk", "rifle_aim",
		"pistol_idle", "pistol_aim"]
	for lib_name in ap.get_animation_library_list():
		var lib := ap.get_animation_library(lib_name)
		for an in lib.get_animation_list():
			var a := lib.get_animation(an)
			a.loop_mode = Animation.LOOP_LINEAR if an in loops else Animation.LOOP_NONE

func _build_tree() -> void:
	_set_loops()
	tree = AnimationTree.new()
	tree.name = "AnimTree"
	model.add_child(tree)
	tree.anim_player = tree.get_path_to(ap)
	tree.root_node = tree.get_path_to(ap.get_node(ap.root_node))
	var bt := AnimationNodeBlendTree.new()
	# unarmed locomotion
	var lu := AnimationNodeBlendSpace1D.new()
	lu.min_space = 0.0
	lu.max_space = 7.0
	lu.add_blend_point(_anim_node(_clip("idle")), 0.0, -1, &"idle")
	lu.add_blend_point(_anim_node(_clip("walk")), _spd("walk", 1.9), -1, &"walk")
	lu.add_blend_point(_anim_node(_clip("run")), _spd("run", 4.1), -1, &"run")
	bt.add_node("loco_u", lu, Vector2(0, 0))
	# armed locomotion: local velocity (x = right, y = forward) in m/s
	var la := AnimationNodeBlendSpace2D.new()
	la.min_space = Vector2(-4, -4)
	la.max_space = Vector2(4, 7)
	la.add_blend_point(_anim_node(_clip("rifle_idle", "idle")), Vector2.ZERO, -1, &"rifle_idle")
	la.add_blend_point(_anim_node(_clip("rifle_walk", "walk")), Vector2(0, _spd("rifle_walk", 1.9)), -1, &"rifle_walk")
	la.add_blend_point(_anim_node(_clip("rifle_run", "run")), Vector2(0, _spd("rifle_run", 4.1)), -1, &"rifle_run")
	la.add_blend_point(_anim_node(_clip("rifle_sprint", "run")), Vector2(0, _spd("rifle_sprint", 6.3)), -1, &"rifle_sprint")
	la.add_blend_point(_anim_node(_clip("rifle_walk_back", "walk")), Vector2(0, -_spd("rifle_walk_back", 1.9)), -1, &"rifle_walk_back")
	la.add_blend_point(_anim_node(_clip("rifle_strafe_l", "walk")), Vector2(-_spd("rifle_strafe_l", 1.9), 0), -1, &"rifle_strafe_l")
	la.add_blend_point(_anim_node(_clip("rifle_strafe_r", "walk")), Vector2(_spd("rifle_strafe_r", 1.9), 0), -1, &"rifle_strafe_r")
	bt.add_node("loco_a", la, Vector2(0, 200))
	var cu := AnimationNodeBlendSpace1D.new()
	cu.max_space = 3.0
	cu.add_blend_point(_anim_node(_clip("crouch_idle", "idle")), 0.0, -1, &"crouch_idle")
	cu.add_blend_point(_anim_node(_clip("crouch_walk", "walk")), _spd("crouch_walk", 1.5), -1, &"crouch_walk")
	bt.add_node("crouch_u", cu, Vector2(0, 400))
	var ca := AnimationNodeBlendSpace1D.new()
	ca.max_space = 3.0
	ca.add_blend_point(_anim_node(_clip("rifle_crouch_idle", "crouch_idle")), 0.0, -1, &"rifle_crouch_idle")
	ca.add_blend_point(_anim_node(_clip("rifle_crouch_walk", "crouch_walk")), _spd("rifle_crouch_walk", 1.5), -1, &"rifle_crouch_walk")
	bt.add_node("crouch_a", ca, Vector2(0, 600))
	bt.add_node("fall", _anim_node(_clip("fall", "idle")), Vector2(0, 800))
	bt.add_node("dead", _anim_node(_clip("death", "idle")), Vector2(0, 1000))
	bt.add_node("wake", _anim_node(_clip("wake_up", "idle")), Vector2(0, 1200))
	var st := AnimationNodeTransition.new()
	st.xfade_time = 0.2
	state_node = st
	for i in ["unarmed", "armed", "crouch_u", "crouch_a", "air", "dead", "wake"]:
		st.add_input(i)
	bt.add_node("state", st, Vector2(300, 400))
	bt.connect_node("state", 0, "loco_u")
	bt.connect_node("state", 1, "loco_a")
	bt.connect_node("state", 2, "crouch_u")
	bt.connect_node("state", 3, "crouch_a")
	bt.connect_node("state", 4, "fall")
	bt.connect_node("state", 5, "dead")
	bt.connect_node("state", 6, "wake")
	var ts := AnimationNodeTimeScale.new()
	bt.add_node("loco_speed", ts, Vector2(450, 400))
	bt.connect_node("loco_speed", 0, "state")
	# upper body layer
	var us := AnimationNodeTransition.new()
	us.xfade_time = 0.15
	for i in ["rifle_aim", "pistol_idle", "pistol_aim"]:
		us.add_input(i)
	bt.add_node("upper_sel", us, Vector2(300, 1400))
	bt.add_node("u_rifle_aim", _anim_node(_clip("rifle_aim", "rifle_idle")), Vector2(0, 1400))
	bt.add_node("u_pistol_idle", _anim_node(_clip("pistol_idle", "rifle_idle")), Vector2(0, 1500))
	bt.add_node("u_pistol_aim", _anim_node(_clip("pistol_aim", "rifle_aim")), Vector2(0, 1600))
	bt.connect_node("upper_sel", 0, "u_rifle_aim")
	bt.connect_node("upper_sel", 1, "u_pistol_idle")
	bt.connect_node("upper_sel", 2, "u_pistol_aim")
	var ub := AnimationNodeBlend2.new()
	ub.filter_enabled = true
	_apply_filter(ub)
	bt.add_node("upper", ub, Vector2(600, 400))
	bt.connect_node("upper", 0, "loco_speed")
	bt.connect_node("upper", 1, "upper_sel")
	# one-shot layers (upper body): equip, reload, fire
	var prev := "upper"
	var x := 800
	for layer in ["equip", "reload", "fire"]:
		var sel := AnimationNodeTransition.new()
		sel.xfade_time = 0.0
		sel.add_input("rifle")
		sel.add_input("pistol")
		bt.add_node(layer + "_sel", sel, Vector2(x, 1700))
		bt.add_node(layer + "_r", _anim_node(_clip("rifle_" + layer, "rifle_idle")), Vector2(x - 150, 1800))
		bt.add_node(layer + "_p", _anim_node(_clip("pistol_" + layer, "pistol_idle")), Vector2(x - 150, 1900))
		bt.connect_node(layer + "_sel", 0, layer + "_r")
		bt.connect_node(layer + "_sel", 1, layer + "_p")
		var os := AnimationNodeOneShot.new()
		os.filter_enabled = true
		_apply_filter(os)
		os.fadein_time = 0.04 if layer == "fire" else 0.12
		os.fadeout_time = 0.08 if layer == "fire" else 0.2
		bt.add_node(layer, os, Vector2(x, 400))
		bt.connect_node(layer, 0, prev)
		if layer == "reload":
			bt.add_node("reload_ts", AnimationNodeTimeScale.new(), Vector2(x, 1600))
			bt.connect_node("reload_ts", 0, "reload_sel")
			bt.connect_node(layer, 1, "reload_ts")
		else:
			bt.connect_node(layer, 1, layer + "_sel")
		prev = layer
		x += 200
	# full-body actions
	var asel := AnimationNodeTransition.new()
	asel.xfade_time = 0.0
	for i in ["hit", "interact", "heal", "jump", "land"]:
		asel.add_input(i)
	bt.add_node("action_sel", asel, Vector2(x, 1700))
	var ai := 0
	for pair in [["hit", "hit"], ["interact", "interact"], ["heal", "heal"], ["jump", "jump_start"], ["land", "land"]]:
		bt.add_node("a_" + pair[0], _anim_node(_clip(pair[1], "idle")), Vector2(x - 150, 1800 + ai * 100))
		bt.connect_node("action_sel", ai, "a_" + pair[0])
		ai += 1
	var aos := AnimationNodeOneShot.new()
	aos.fadein_time = 0.1
	aos.fadeout_time = 0.2
	bt.add_node("action", aos, Vector2(x, 400))
	bt.connect_node("action", 0, prev)
	bt.connect_node("action", 1, "action_sel")
	bt.connect_node("output", 0, "action")
	tree.tree_root = bt
	tree.active = true
	tree.set("parameters/upper/blend_amount", 0.0)

func _apply_filter(node: AnimationNode) -> void:
	# tracks are addressed by the path the animations use, e.g. "Armature/Skeleton3D:spine1"
	var skel_path := String(ap.get_node(ap.root_node).get_path_to(skel))
	for b in UPPER_BONES:
		if skel.find_bone(b) != -1:
			node.set_filter_path(NodePath(skel_path + ":" + b), true)

func _build_placeholder() -> void:
	placeholder = true
	var body := Node3D.new()
	body.name = "PlaceholderAstronaut"
	var suit := StandardMaterial3D.new()
	suit.albedo_color = Color(0.86, 0.86, 0.84)
	suit.roughness = 0.6
	var orange := StandardMaterial3D.new()
	orange.albedo_color = Color(0.95, 0.45, 0.12)
	var torso := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.1
	torso.mesh = cm
	torso.position.y = 1.05
	torso.material_override = suit
	body.add_child(torso)
	var helm := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	helm.mesh = sm
	helm.position.y = 1.68
	helm.material_override = suit
	body.add_child(helm)
	var visor := MeshInstance3D.new()
	var vm := SphereMesh.new()
	vm.radius = 0.15
	vm.height = 0.22
	visor.mesh = vm
	visor.position = Vector3(0, 1.68, -0.1)
	var vmat := StandardMaterial3D.new()
	vmat.albedo_color = Color(0.7, 0.55, 0.2)
	vmat.metallic = 1.0
	vmat.roughness = 0.1
	visor.material_override = vmat
	body.add_child(visor)
	var pack := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.45, 0.6, 0.25)
	pack.mesh = bm
	pack.position = Vector3(0, 1.2, 0.3)
	pack.material_override = orange
	body.add_child(pack)
	for side in [-1.0, 1.0]:
		var leg := MeshInstance3D.new()
		var lm := CapsuleMesh.new()
		lm.radius = 0.12
		lm.height = 0.85
		leg.mesh = lm
		leg.position = Vector3(0.14 * side, 0.42, 0)
		leg.material_override = suit
		leg.name = "Leg" + ("L" if side < 0 else "R")
		body.add_child(leg)
	player.model_root.add_child(body)
	_ph_body = body
	model = body

func attach_weapon(w: WeaponBase) -> void:
	if hand_attach:
		hand_attach.add_child(w)
		var xf := _weapon_offset(w.data.id)
		w.transform = xf
		set_char_layer(w)

func _weapon_offset(id: String) -> Transform3D:
	var path := MODEL.get_basename() + ".json"
	if FileAccess.file_exists(path):
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string(path)) == OK and j.data is Dictionary:
			var att: Dictionary = (j.data as Dictionary).get("weapon_attach", {}).get(id, {})
			if att.has("position"):
				var pos: Array = att["position"]
				var rot: Array = att.get("rotation_deg", [0, 0, 0])
				var b := Basis.from_euler(Vector3(deg_to_rad(rot[0]), deg_to_rad(rot[1]), deg_to_rad(rot[2])))
				return Transform3D(b, Vector3(pos[0], pos[1], pos[2]))
	return Transform3D.IDENTITY

func set_weapon(id: String, _instant: bool) -> void:
	weapon_id = id
	if tree and not _instant:
		_oneshot("equip", 1 if id == "pistol" else 0)

func _oneshot(layer: String, sel: int) -> void:
	if tree == null:
		return
	tree.set("parameters/%s_sel/transition_request" % layer, ["rifle", "pistol"][sel] if layer != "action" else ["hit", "interact", "heal", "jump", "land"][sel])
	tree.set("parameters/%s/request" % layer, AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func fire(id: String) -> void:
	_oneshot("fire", 1 if id == "pistol" else 0)

func reload(id: String, secs: float) -> void:
	if tree:
		var clip := ("pistol_reload" if id == "pistol" else "rifle_reload")
		if _has(clip):
			var len := ap.get_animation(clip).length
			# scale the clip to the weapon's reload time
			tree.set("parameters/reload_ts/scale", len / maxf(0.1, secs))
		_oneshot("reload", 1 if id == "pistol" else 0)

func cancel_reload() -> void:
	if tree:
		tree.set("parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FADE_OUT)

func _action(i: int, busy: float) -> void:
	_busy_full = busy
	if tree:
		tree.set("parameters/action_sel/transition_request", ["hit", "interact", "heal", "jump", "land"][i])
		tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

func melee() -> void:
	_action(0, 0.0)

func hit() -> void:
	_action(0, 0.0)

func interact() -> void:
	_action(1, 0.5)

func heal() -> void:
	_action(2, 0.9)

func jump() -> void:
	_action(3, 0.0)

func land(speed: float) -> void:
	if speed > 6.0:
		_action(4, 0.25)

func die() -> void:
	_dead = true
	if tree:
		tree.set("parameters/action/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		tree.set("parameters/fire/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		tree.set("parameters/reload/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
		tree.set("parameters/upper/blend_amount", 0.0)
		tree.set("parameters/state/transition_request", "dead")
	elif _ph_body:
		var tw := _ph_body.create_tween()
		tw.tween_property(_ph_body, "rotation:x", -PI * 0.5, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

func revive() -> void:
	_dead = false
	if _ph_body:
		_ph_body.rotation = Vector3.ZERO

var wake_mode := false
var state_node: AnimationNodeTransition

func play_wake() -> void:
	wake_mode = true
	if tree:
		state_node.xfade_time = 0.0
		tree.set("parameters/state/transition_request", "wake")
	var secs := ap.get_animation(_clip("wake_up", "idle")).length if ap else 5.0
	await get_tree().create_timer(maxf(0.5, secs - 0.25), false).timeout
	# hand back to locomotion with a soft blend
	if tree:
		state_node.xfade_time = 0.35
	wake_mode = false
	await get_tree().create_timer(0.4, false).timeout
	if tree:
		state_node.xfade_time = 0.2

func busy_full() -> bool:
	return _busy_full > 0.0

func set_lamp(on: bool) -> void:
	for m in _lamp_mats:
		(m as BaseMaterial3D).emission_energy_multiplier = 4.0 if on else 0.3

func _process(delta: float) -> void:
	_busy_full = maxf(0.0, _busy_full - delta)
	if player == null:
		return
	var v := player.velocity
	var local := player.global_transform.basis.inverse() * Vector3(v.x, 0, v.z)
	var lv := Vector2(local.x, -local.z)
	var spd := lv.length()
	var armed := weapon_id != ""
	if tree:
		if _dead:
			return
		if wake_mode:
			return
		var state := "unarmed"
		if not player.is_on_floor() and absf(v.y) > 1.5:
			state = "air"
		elif player.crouching:
			state = "crouch_a" if armed else "crouch_u"
		else:
			state = "armed" if armed else "unarmed"
		tree.set("parameters/state/transition_request", state)
		tree.set("parameters/loco_u/blend_position", spd)
		tree.set("parameters/loco_a/blend_position", lv)
		tree.set("parameters/crouch_u/blend_position", spd)
		tree.set("parameters/crouch_a/blend_position", spd)
		# keep feet honest: play cycles a bit faster/slower when the speed is between blend points
		var scale := 1.0
		if state == "unarmed" and spd > _spd("run", 4.1) + 0.2:
			scale = spd / _spd("run", 4.1)
		tree.set("parameters/loco_speed/scale", clampf(scale, 0.8, 1.6))
		var upper := 0.0
		if armed:
			if weapon_id == "pistol":
				upper = 1.0
				tree.set("parameters/upper_sel/transition_request", "pistol_aim" if player.aiming else "pistol_idle")
			elif player.aiming or player.combat.firing_held():
				upper = 1.0
				tree.set("parameters/upper_sel/transition_request", "rifle_aim")
			if player.sprinting and weapon_id == "rifle":
				upper = 0.0
		var cur := float(tree.get("parameters/upper/blend_amount"))
		tree.set("parameters/upper/blend_amount", lerpf(cur, upper, 1.0 - exp(-14.0 * delta)))
	elif _ph_body and not _dead:
		_t += delta * (2.0 + spd * 1.6)
		var bob := sin(_t * 2.0) * 0.03 * clampf(spd, 0.0, 1.0)
		_ph_body.position.y = bob - (0.35 if player.crouching else 0.0)
		for leg_name in ["LegL", "LegR"]:
			var leg := _ph_body.get_node_or_null(leg_name) as Node3D
			if leg:
				var s := 1.0 if leg_name == "LegL" else -1.0
				leg.rotation.x = sin(_t) * 0.5 * clampf(spd / 4.0, 0.0, 1.0) * s


## Put every mesh under `n` on visual layer 2 as well, so the camera-side character lights reach it.
func set_char_layer(n: Node) -> void:
	for mi in n.find_children("*", "VisualInstance3D", true, false):
		(mi as VisualInstance3D).layers |= 2
	if n is VisualInstance3D:
		(n as VisualInstance3D).layers |= 2
