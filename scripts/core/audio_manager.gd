extends Node
## AudioManager (PRD BP_EOT_AudioManager): music with dynamic layers, ambience, positional SFX, voice-over with
## subtitles. Autoloaded as "Sfx". Buses are built in code so the project needs no bus layout file.

const LINES_PATH := "res://data/dialogue.json"

var _cache: Dictionary = {}
var _variants: Dictionary = {}
var _loops: Dictionary = {}
var music_a: AudioStreamPlayer
var music_b: AudioStreamPlayer
var _music_cur: AudioStreamPlayer
var _music_name := ""
var _music_tween: Tween
var amb: AudioStreamPlayer
var _amb_name := ""
var voice: AudioStreamPlayer
var _voice_queue: Array = []
var _voice_id := ""
var lines: Dictionary = {}
var music_mode := ""
var area_music := "music_explore"
var reverb: AudioEffectReverb
var _duck := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_buses()
	music_a = _mk_player("Music")
	music_b = _mk_player("Music")
	_music_cur = music_a
	amb = _mk_player("Amb")
	voice = _mk_player("Voice")
	voice.finished.connect(_voice_done)
	_load_lines()
	apply_volumes()

func _mk_player(bus: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p

func _build_buses() -> void:
	for b in ["Music", "SFX", "Voice", "Amb", "UI"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	var sfx := AudioServer.get_bus_index("SFX")
	reverb = AudioEffectReverb.new()
	reverb.room_size = 0.55
	reverb.damping = 0.55
	reverb.wet = 0.14
	reverb.dry = 0.92
	reverb.predelay_msec = 30.0
	AudioServer.add_bus_effect(sfx, reverb)
	# M2 mix pass (measured in-engine with tests/mixrec.gd): the old -14 dB / 3:1 compressor held gunfire
	# ~10 dB under the voices. Gentler glue + makeup gain puts weapons level with dialogue, music under both.
	var comp := AudioEffectCompressor.new()
	comp.threshold = -9.0
	comp.ratio = 2.2
	comp.attack_us = 800.0
	comp.release_ms = 120.0
	comp.gain = 4.0
	AudioServer.add_bus_effect(sfx, comp)
	AudioServer.add_bus_effect(0, AudioEffectLimiter.new())

## Areas set their acoustic space: small rooms vs the reactor hall vs the open exterior.
func set_space(room: float, wet: float) -> void:
	if reverb:
		reverb.room_size = room
		reverb.wet = wet

func apply_volumes() -> void:
	if AudioServer.get_bus_index("Voice") == -1 or not has_node("/root/Game"):
		return
	var s: Dictionary = Game.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, float(s["master"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, float(s["music"]))) - _duck)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(s["sfx"]))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), linear_to_db(maxf(0.0001, float(s["sfx"]))) - 4.0)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Amb"), linear_to_db(maxf(0.0001, float(s["sfx"]) * 0.85)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(maxf(0.0001, float(s["voice"]))))

func _load_lines() -> void:
	if not FileAccess.file_exists(LINES_PATH):
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(LINES_PATH)) == OK and j.data is Dictionary:
		lines = j.data

func stream(path: String) -> AudioStream:
	if _cache.has(path):
		return _cache[path]
	var full := "res://assets/audio/%s.ogg" % path
	var st: AudioStream = null
	if ResourceLoader.exists(full):
		st = load(full)
	_cache[path] = st
	return st

## "rifle_fire" resolves to rifle_fire.ogg, or a random pick of rifle_fire_1..N.
func _sfx(name: String) -> AudioStream:
	var st := stream("sfx/" + name)
	if st:
		return st
	if not _variants.has(name):
		var v: Array = []
		for i in range(1, 7):
			var s2 := stream("sfx/%s_%d" % [name, i])
			if s2 == null:
				break
			v.append(s2)
		_variants[name] = v
	var arr: Array = _variants[name]
	return null if arr.is_empty() else arr[randi() % arr.size()]

func play(snd: String, vol_db: float = 0.0, pitch: float = 1.0) -> AudioStreamPlayer:
	var st := _sfx(snd)
	if st == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = "SFX"
	p.volume_db = vol_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
	return p

func ui(snd: String, vol_db: float = 0.0) -> void:
	var st := _sfx(snd)
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = "UI"
	p.volume_db = vol_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

func play_at(snd: String, pos: Vector3, vol_db: float = 0.0, max_dist: float = 50.0, pitch: float = 1.0) -> AudioStreamPlayer3D:
	var st := _sfx(snd)
	if st == null:
		return null
	var tree := get_tree()
	if tree == null or tree.current_scene == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = "SFX"
	p.volume_db = vol_db
	p.max_distance = max_dist
	p.unit_size = 7.0
	p.pitch_scale = pitch * randf_range(0.96, 1.04)
	p.attenuation_filter_cutoff_hz = 6000.0
	p.attenuation_filter_db = -12.0
	tree.current_scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)
	return p

## A positional looping emitter that lives under `parent` (machines, enemy hums).
func emitter(snd: String, parent: Node3D, vol_db: float = 0.0, max_dist: float = 25.0) -> AudioStreamPlayer3D:
	var st := _sfx(snd)
	if st == null:
		return null
	if st is AudioStreamOggVorbis:
		st = st.duplicate()
		(st as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer3D.new()
	p.stream = st
	p.bus = "SFX"
	p.volume_db = vol_db
	p.max_distance = max_dist
	p.unit_size = 5.0
	p.autoplay = true
	parent.add_child(p)
	return p

func loop(key: String, snd: String, on: bool, vol_db: float = 0.0) -> void:
	if on:
		if _loops.has(key) and is_instance_valid(_loops[key]):
			(_loops[key] as AudioStreamPlayer).volume_db = vol_db
			return
		var st := _sfx(snd)
		if st == null:
			return
		if st is AudioStreamOggVorbis:
			st = st.duplicate()
			(st as AudioStreamOggVorbis).loop = true
		var p := AudioStreamPlayer.new()
		p.stream = st
		p.bus = "SFX"
		p.volume_db = vol_db
		p.process_mode = Node.PROCESS_MODE_PAUSABLE
		add_child(p)
		p.play()
		_loops[key] = p
	elif _loops.has(key):
		if is_instance_valid(_loops[key]):
			(_loops[key] as AudioStreamPlayer).queue_free()
		_loops.erase(key)

func stop_all_loops() -> void:
	for k in _loops.keys():
		loop(k, "", false)

# ---------------------------------------------------------------- music
func music(snd: String, fade: float = 2.0, vol_db: float = 0.0) -> void:
	if snd == _music_name:
		return
	_music_name = snd
	var old := _music_cur
	var nw := music_b if _music_cur == music_a else music_a
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	if old.playing:
		_music_tween = create_tween()
		_music_tween.tween_property(old, "volume_db", -60.0, fade)
		_music_tween.tween_callback(old.stop)
	if snd != "":
		var st := stream("music/" + snd)
		if st:
			if st is AudioStreamOggVorbis and not snd.begins_with("sting"):
				(st as AudioStreamOggVorbis).loop = true
			nw.stream = st
			nw.volume_db = -50.0
			nw.play()
			var t2 := create_tween()
			t2.tween_property(nw, "volume_db", vol_db, fade * 0.8)
	_music_cur = nw

func sting(snd: String, vol_db: float = 0.0) -> void:
	var st := stream("music/" + snd)
	if st == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = st
	p.bus = "Music"
	p.volume_db = vol_db
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)

## Dynamic score: GameMode tells us whether enemies are hunting the player.
func set_music_mode(mode: String) -> void:
	if mode == music_mode:
		return
	music_mode = mode
	match mode:
		"explore": music(area_music, 4.0, -6.0)
		"tension": music("music_tension", 2.5, -4.0)
		"combat": music("music_combat", 1.2, -3.0)
		"boss": music("music_boss", 1.5, -2.0)
		"menu": music("music_menu", 2.0, -2.0)
		"ending": music("music_ending", 2.0, -1.0)
		_: music("", 3.0)

func ambience(snd: String, vol_db: float = 0.0) -> void:
	if snd == _amb_name:
		return
	_amb_name = snd
	var st := stream("amb/" + snd) if snd != "" else null
	if st == null:
		amb.stop()
		return
	if st is AudioStreamOggVorbis:
		(st as AudioStreamOggVorbis).loop = true
	amb.stream = st
	amb.volume_db = -40.0
	amb.play()
	create_tween().tween_property(amb, "volume_db", vol_db, 3.0)

# ---------------------------------------------------------------- voice
func line_text(id: String) -> Dictionary:
	return lines.get(id, {})

## Speak a voice line with a subtitle. Lines queue; `interrupt` cuts the current one (cinematics).
func say(id: String, interrupt: bool = false) -> float:
	var info := line_text(id)
	if interrupt:
		_voice_queue.clear()
		voice.stop()
		_voice_id = ""
	if voice.playing or _voice_id != "":
		if not id in _voice_queue and id != _voice_id:
			_voice_queue.append(id)
		return 0.0
	return _start_voice(id, info)

func _start_voice(id: String, info: Dictionary) -> float:
	_voice_id = id
	var st := stream("vo/" + id)
	var secs := 0.0
	var txt: String = info.get("text", "")
	if st:
		voice.stream = st
		voice.play()
		secs = st.get_length()
	else:
		secs = clampf(txt.split(" ").size() * 0.36 + 0.8, 1.5, 30.0)
		get_tree().create_timer(secs, true).timeout.connect(func():
			if _voice_id == id:
				_voice_done())
	if txt != "":
		Events.subtitle.emit(str(info.get("speaker", "")), txt, secs + 0.3)
	_set_duck(6.0)
	return secs

func _voice_done() -> void:
	_voice_id = ""
	if _voice_queue.size() > 0:
		var nx: String = _voice_queue.pop_front()
		_start_voice(nx, line_text(nx))
	else:
		_set_duck(0.0)

func voice_busy() -> bool:
	return _voice_id != "" or voice.playing

func stop_voice() -> void:
	_voice_queue.clear()
	voice.stop()
	_voice_id = ""
	_set_duck(0.0)
	Events.subtitle.emit("", "", 0.0)

func _set_duck(db: float) -> void:
	_duck = db
	apply_volumes()
