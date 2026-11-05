class_name CombatComponent
extends Node
## PRD BP_EOT_CombatComponent: owns firing, aiming, ammunition, reload and weapon switching.

signal weapon_changed(id: String)

const WEAPON_DATA := {
	"pistol": "res://data/weapons/energy_pistol.tres",
	"rifle": "res://data/weapons/pulse_rifle.tres",
	"shotgun": "res://data/weapons/shotgun.tres",     # v1.1.0 stage 3
	"precision": "res://data/weapons/precision.tres",
	"breach": "res://data/weapons/breach.tres",     # v1.5.0 heavy weapon
}
const WEAPON_SCRIPT := {
	"pistol": "res://scripts/weapons/energy_pistol.gd",
	"rifle": "res://scripts/weapons/pulse_rifle.gd",
	"shotgun": "res://scripts/weapons/scatter_shotgun.gd",
	"precision": "res://scripts/weapons/precision_rifle.gd",
	"breach": "res://scripts/weapons/breach_cannon.gd",
}

var player: Player
var weapons := {}            # id -> WeaponBase
var current: WeaponBase
var touch_fire := false
var _equip_t := 0.0
var _trigger_was := false
var _empty_click_t := 0.0
var _semi_ready := true

func setup(p: Player) -> void:
	player = p

func current_id() -> String:
	return current.data.id if current else ""

func has_weapon_out() -> bool:
	return current != null

func firing_held() -> bool:
	return current != null and player.controller.fire_held

func reloading_blocks_sprint() -> bool:
	return false

func aim_fov(base: float) -> float:
	if current == null:
		return base
	return base - (70.0 - current.data.aim_fov)

func mags() -> Dictionary:
	var m := {"pistol": 0, "rifle": 0}
	for id in weapons.keys():
		m[id] = (weapons[id] as WeaponBase).mag
	return m

## v1.5.0: a bench purchase re-reads the weapon's upgraded numbers.
func refresh_upgrades(id: String) -> void:
	if weapons.has(id):
		(weapons[id] as WeaponBase).refresh_upgrades()
		_emit_ammo()

func _make(id: String) -> WeaponBase:
	var d: WeaponData = load(WEAPON_DATA[id])
	var w: WeaponBase = load(WEAPON_SCRIPT[id]).new()
	w.setup(d, player)
	player.anim.attach_weapon(w)
	w.visible = false
	w.reloaded.connect(_emit_ammo)
	weapons[id] = w
	return w

## Pickup: give a weapon with a full magazine and equip it.
func give(id: String, equip_now: bool = true) -> void:
	player.inventory.add_weapon(id)
	if not weapons.has(id):
		_make(id)
	if equip_now:
		equip(id, true)

func restore(m: Dictionary, equipped: String) -> void:
	for id in player.inventory.weapons:
		if not weapons.has(id) and WEAPON_DATA.has(id):
			_make(id)
		if weapons.has(id):
			(weapons[id] as WeaponBase).mag = int(m.get(id, (weapons[id] as WeaponBase).data.mag_size))
	if equipped != "" and weapons.has(equipped):
		equip(equipped, true)
	elif player.inventory.weapons.size() > 0:
		equip(player.inventory.weapons[-1], true)

func equip(id: String, instant: bool = false) -> void:
	if not weapons.has(id) or (current and current.data.id == id) or player.dead:
		return
	if current:
		current.cancel_reload()
		current.visible = false
	current = weapons[id]
	current.visible = true
	_equip_t = 0.0 if instant else current.data.equip_time
	player.anim.set_weapon(id, instant)
	if not instant:
		Sfx.play("weapon_switch", -8.0)
	weapon_changed.emit(id)
	Events.weapon_changed.emit(id)
	_emit_ammo()

func cycle() -> void:
	var owned := player.inventory.weapons
	if owned.size() < 2 or current == null:
		return
	var i := owned.find(current.data.id)
	equip(owned[(i + 1) % owned.size()])

func reload() -> void:
	if current == null or player.dead:
		return
	if current.start_reload(int(player.inventory.reserve.get(current.data.ammo_type, 0))):
		player.anim.reload(current.data.id, current.data.reload_time)
	elif current.mag < current.data.mag_size and int(player.inventory.reserve.get(current.data.ammo_type, 0)) <= 0:
		Events.message.emit("No %s cells left" % ("rifle" if current.data.ammo_type == "rifle" else "pistol"), 1.4)

func cancel_reload() -> void:
	if current and current.reloading:
		current.cancel_reload()
		player.anim.cancel_reload()

func _process(delta: float) -> void:
	if current == null or player == null:
		return
	_empty_click_t -= delta
	if _equip_t > 0.0:
		_equip_t -= delta
	var trig := player.controller.fire_held and not player.locked and not player.dead and not GameMode.ui_blocking()
	if trig and _equip_t <= 0.0 and not player.anim.busy_full():
		if player.sprinting:
			player.sprinting = false
		player.face_camera_for(0.7)
		var auto: bool = current.data.automatic
		if current.mag <= 0 and not current.reloading:
			if int(player.inventory.reserve.get(current.data.ammo_type, 0)) > 0:
				reload()
			elif _empty_click_t <= 0.0 and (not _trigger_was):
				Sfx.play("dry_fire", -6.0)
				_empty_click_t = 0.3
				_try_switch_when_dry()
		elif auto or _semi_ready:
			# fire only once the body has turned toward the aim, so shots don't leave sideways
			var fwd := player.forward()
			var cam_f: Vector3 = -player.controller.cam.global_transform.basis.z
			cam_f.y = 0.0
			if fwd.angle_to(cam_f.normalized()) < deg_to_rad(50.0) or player.aiming:
				if current.fire():
					player.anim.fire(current.data.id)
					_semi_ready = false
					_emit_ammo()
	if not trig:
		_semi_ready = true
	_trigger_was = trig

func _try_switch_when_dry() -> void:
	for id in player.inventory.weapons:
		if id != current.data.id and weapons.has(id):
			var w: WeaponBase = weapons[id]
			if w.mag > 0 or int(player.inventory.reserve.get(w.data.ammo_type, 0)) > 0:
				Events.message.emit("Out of ammo — switching weapon", 1.4)
				equip(id)
				return

func _emit_ammo() -> void:
	if current:
		Events.ammo_changed.emit(current.mag, int(player.inventory.reserve.get(current.data.ammo_type, 0)))

func ammo_text() -> Array:
	if current == null:
		return [0, 0]
	return [current.mag, int(player.inventory.reserve.get(current.data.ammo_type, 0))]

func _ready() -> void:
	set_process(true)
	await get_tree().process_frame
	if player:
		player.inventory.changed.connect(_emit_ammo)
