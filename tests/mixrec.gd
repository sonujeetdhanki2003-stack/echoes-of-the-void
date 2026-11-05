extends Node
## Mix recorder: a scripted 32 s slice of play (combat music, rifle bursts, live enemies, MIRA, a research log,
## pickups) with every bus muted except --stem (music|sfx|voice|amb|ui|all). Run under --write-movie to capture
## the in-engine mix; compare the stems' loudness offline.
func _ready() -> void:
	get_window().size = Vector2i(160, 90)
	get_window().content_scale_size = Vector2i(160, 90)
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.state["mission"] = 1
	await GameMode.load_area("security", "security_corr", true)
	GameMode.ui.fade.color.a = 0.0
	for b in ["Master", "Music", "SFX", "Voice", "Amb"]:
		var i := AudioServer.get_bus_index(b)
		var cap := AudioEffectCapture.new()
		cap.buffer_length = 2.0
		AudioServer.add_bus_effect(i, cap)
		_caps[b] = cap
		_data[b] = PackedVector2Array()
	var p: Player = GameMode.player
	p.health.dmg_mult = 0.0
	p.combat.give("rifle")
	p.inventory.add_ammo("rifle", 400)
	Sfx.set_music_mode("combat")
	p.controller.aim_toggle = true
	await _t(3.0)
	Sfx.say("mira_door", true)
	for i in 6:
		p.combat.touch_fire = true
		await _t(0.9)
		if i == 0:
			print("MIXDBG fire_held=", p.controller.fire_held, " busy=", p.anim.busy_full(), " equip_t=", p.combat._equip_t, " cur=", p.combat.current, " ctrl_enabled=", p.controller.enabled, " dead=", p.dead, " can_fire=", p.combat.current.can_fire(), " aiming=", p.aiming, " out=", p.combat.has_weapon_out(), " cd=", p.combat.current._cooldown, " reloading=", p.combat.current.reloading)
		p.combat.touch_fire = false
		await _t(0.8)
	Sfx.play("ammo_pickup", -4.0)
	await _t(1.0)
	Sfx.say("log03", true)
	await _t(4.0)
	for i in 4:
		p.combat.touch_fire = true
		await _t(0.7)
		p.combat.touch_fire = false
		await _t(1.0)
	Sfx.set_music_mode("explore")
	await _t(6.0)
	var out := Game.arg("out", "/tmp/mix")
	for b in _data.keys():
		_wav(out + "_" + b.to_lower() + ".wav", _data[b])
	print("MIXREC done ", AudioServer.get_mix_rate(), " mag ", p.combat.current.mag, " reserve ", p.inventory.reserve, " blocking ", GameMode.ui_blocking(), " locked ", p.locked)
	get_tree().quit()

var _caps := {}
var _data := {}
func _process(_d: float) -> void:
	for b in _caps.keys():
		var c: AudioEffectCapture = _caps[b]
		var n := c.get_frames_available()
		if n > 0:
			_data[b].append_array(c.get_buffer(n))

func _wav(path: String, frames: PackedVector2Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	var rate := int(AudioServer.get_mix_rate())
	var n := frames.size()
	f.store_buffer("RIFF".to_ascii_buffer())
	f.store_32(36 + n * 4)
	f.store_buffer("WAVEfmt ".to_ascii_buffer())
	f.store_32(16)
	f.store_16(1)
	f.store_16(2)
	f.store_32(rate)
	f.store_32(rate * 4)
	f.store_16(4)
	f.store_16(16)
	f.store_buffer("data".to_ascii_buffer())
	f.store_32(n * 4)
	var buf := PackedByteArray()
	buf.resize(n * 4)
	for i in n:
		buf.encode_s16(i * 4, int(clampf(frames[i].x, -1.0, 1.0) * 32767.0))
		buf.encode_s16(i * 4 + 2, int(clampf(frames[i].y, -1.0, 1.0) * 32767.0))
	f.store_buffer(buf)
	f.close()

func _t(s: float) -> void:
	await get_tree().create_timer(s, false, false, true).timeout
