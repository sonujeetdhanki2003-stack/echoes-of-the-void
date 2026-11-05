class_name Pickup
extends Interactable
## Items: medkits and ammo are collected by walking over them (if there is room); weapons and keycards are
## picked up with Use. Collected pickups are remembered by stable ID.

@export var kind := "medkit"      # medkit | ammo_pistol | ammo_rifle | weapon_pistol | weapon_rifle | keycard
@export var amount := 1
@export var keycard_id := ""
@export var label := ""
var model: Node3D
var _bob := 0.0
var _auto: Area3D
var _glow: OmniLight3D
var _base_y := 0.0

func _ready() -> void:
	super._ready()
	if stable_id != "" and Game.flag("got." + stable_id):
		queue_free()
		return
	range_m = 2.0
	focus_offset = Vector3(0, 0.35, 0)
	var mname: String = {"medkit": "medkit", "ammo_pistol": "ammo_pistol", "ammo_rifle": "ammo_rifle", "keycard": "keycard"}.get(kind, "")
	if kind == "weapon_pistol":
		model = _weapon_model("res://assets/models/energy_pistol.glb", Vector3(0.07, 0.12, 0.28))
	elif kind == "weapon_rifle":
		model = _weapon_model("res://assets/models/pulse_rifle.glb", Vector3(0.08, 0.16, 0.85))
	else:
		model = Props.instance(mname)
		if kind == "keycard":
			model.scale = Vector3.ONE * 2.0
	add_child(model)
	model.position.y = 0.25
	_base_y = 0.25
	_glow = OmniLight3D.new()
	_glow.light_color = _color()
	_glow.light_energy = 0.7
	_glow.omni_range = 1.8
	_glow.position.y = 0.5
	add_child(_glow)
	if _is_auto():
		_auto = Area3D.new()
		_auto.collision_layer = 0
		_auto.collision_mask = 2
		var cs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.0
		cs.shape = sp
		cs.position.y = 0.5
		_auto.add_child(cs)
		add_child(_auto)
		_auto.body_entered.connect(func(b): if b is Player: _try_take(b as Player, true))

func _weapon_model(path: String, size: Vector3) -> Node3D:
	if ResourceLoader.exists(path):
		var n: Node3D = (load(path) as PackedScene).instantiate()
		n.rotation = Vector3(0, PI * 0.5, PI * 0.5)
		return n
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.22, 0.25)
	m.metallic = 0.7
	mi.material_override = m
	var n2 := Node3D.new()
	n2.add_child(mi)
	n2.rotation.x = PI * 0.5
	return n2

func _color() -> Color:
	match kind:
		"medkit": return Color(0.3, 1.0, 0.5)
		"ammo_pistol": return Color(1.0, 0.65, 0.25)
		"ammo_rifle": return Color(0.35, 0.8, 1.0)
		"keycard": return Color(1.0, 0.85, 0.3)
	return Color(0.6, 0.9, 1.0)

func _is_auto() -> bool:
	return kind in ["medkit", "ammo_pistol", "ammo_rifle"]

func get_prompt() -> String:
	match kind:
		"weapon_pistol": return "Take Energy Pistol"
		"weapon_rifle": return "Take Pulse Rifle"
		"keycard": return "Take " + (label if label != "" else "keycard")
		"medkit": return "Take medkit"
		"ammo_pistol": return "Take pistol cells"
		"ammo_rifle": return "Take rifle cells"
	return "Take"

func interact(p: Player) -> void:
	_try_take(p, false)

func _try_take(p: Player, auto: bool) -> void:
	if p.dead:
		return
	var ok := false
	var msg := ""
	match kind:
		"medkit":
			ok = p.inventory.add_medkit()
			msg = "Medkit (%d/%d)" % [p.inventory.medkits, InventoryComponent.MAX_MEDKITS] if ok else "Can't carry more medkits"
			if ok:
				Sfx.play("medkit_pickup", -4.0)
		"ammo_pistol", "ammo_rifle":
			var t := "pistol" if kind == "ammo_pistol" else "rifle"
			var n := int(round(amount * Game.diff("ammo")))
			var got := p.inventory.add_ammo(t, n)
			ok = got > 0
			msg = ("+%d %s cells" % [got, t]) if ok else ("%s cells full" % t.capitalize())
			if ok:
				Sfx.play("ammo_pickup", -4.0)
		"weapon_pistol":
			p.combat.give("pistol")
			p.inventory.add_ammo("pistol", 24)
			ok = true
			msg = "Energy Pistol"
			Game.set_flag("got.pistol")
			Sfx.play("item_pickup", -2.0)
		"weapon_rifle":
			p.combat.give("rifle")
			p.inventory.add_ammo("rifle", 64)
			ok = true
			msg = "Pulse Rifle"
			Game.set_flag("got.rifle")
			Sfx.play("item_pickup", -2.0)
		"keycard":
			p.inventory.add_keycard(keycard_id)
			ok = true
			msg = label if label != "" else "Keycard"
			Game.set_flag("keycard." + keycard_id)
			Sfx.play("keycard_pickup", -2.0)
	if ok:
		if stable_id != "":
			Game.set_flag("got." + stable_id)
		Events.pickup.emit(kind, amount)
		Events.message.emit(msg, 1.8)
		queue_free()
	elif not auto:
		Events.message.emit(msg, 1.4)

func _process(delta: float) -> void:
	_bob += delta
	if model:
		model.position.y = _base_y + sin(_bob * 2.2) * 0.04
		model.rotation.y += delta * 0.8
