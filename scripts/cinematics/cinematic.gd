class_name Cinematic
extends Node3D
## In-engine cinematic (PRD "Cinematics"): a sequence of camera shots baked into an AnimationPlayer
## animation (position, rotation and FOV tracks plus a method track for story events and voice lines).
## Letterboxed, skippable by holding a button; essential events still run when skipped.

signal finished

var cam: Camera3D
var ap: AnimationPlayer
var shots: Array = []        # [from_pos, from_look, to_pos, to_look, dur, fov_a, fov_b, ease_kind]
var events: Array = []       # [time, Callable, essential]
var length := 0.0
var _fired := {}
var _done := false
var hide_player := true
var shake := 0.0

func _ready() -> void:
	add_to_group("cinematic")

func shot(from_pos: Vector3, from_look: Vector3, to_pos: Vector3, to_look: Vector3, dur: float, fov_a: float = 50.0, fov_b: float = -1.0, ease_kind: String = "inout") -> Cinematic:
	shots.append([from_pos, from_look, to_pos, to_look, dur, fov_a, fov_a if fov_b < 0.0 else fov_b, ease_kind])
	return self

func at(t: float, cb: Callable, essential: bool = false) -> Cinematic:
	events.append([t, cb, essential])
	return self

func say(t: float, line_id: String) -> Cinematic:
	return at(t, func(): Sfx.say(line_id, true))

func _ease(x: float, kind: String) -> float:
	match kind:
		"in": return x * x
		"out": return 1.0 - (1.0 - x) * (1.0 - x)
		"linear": return x
	return x * x * (3.0 - 2.0 * x)

func _build() -> void:
	cam = Camera3D.new()
	cam.near = 0.05
	cam.far = 900.0
	add_child(cam)
	ap = AnimationPlayer.new()
	add_child(ap)
	var anim := Animation.new()
	var tp := anim.add_track(Animation.TYPE_POSITION_3D)
	var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
	var tf := anim.add_track(Animation.TYPE_VALUE)
	var tm := anim.add_track(Animation.TYPE_METHOD)
	var cam_path := NodePath(String(get_path_to(cam)))
	anim.track_set_path(tp, cam_path)
	anim.track_set_path(tr, cam_path)
	anim.track_set_path(tf, NodePath(String(get_path_to(cam)) + ":fov"))
	anim.track_set_path(tm, NodePath("."))
	anim.track_set_interpolation_type(tf, Animation.INTERPOLATION_LINEAR)
	anim.value_track_set_update_mode(tf, Animation.UPDATE_CONTINUOUS)
	var t := 0.0
	for s in shots:
		var dur: float = s[4]
		var n := maxi(2, int(dur * 12.0))
		for i in n + 1:
			var x := float(i) / float(n)
			var e := _ease(x, s[7])
			var pos: Vector3 = (s[0] as Vector3).lerp(s[2], e)
			var look: Vector3 = (s[1] as Vector3).lerp(s[3], e)
			var b := Basis.looking_at(look - pos, Vector3.UP) if (look - pos).length() > 0.01 else Basis()
			# a cut is a key 1 ms after the previous shot's last key
			var kt := t + x * dur + (0.001 if i == 0 and t > 0.0 else 0.0)
			anim.position_track_insert_key(tp, kt, pos)
			anim.rotation_track_insert_key(tr, kt, b.get_rotation_quaternion())
			anim.track_insert_key(tf, kt, lerpf(s[5], s[6], e))
		t += dur
	length = t
	for i in events.size():
		anim.track_insert_key(tm, minf(events[i][0], length - 0.01), {"method": "_event", "args": [i]})
	anim.length = length
	var lib := AnimationLibrary.new()
	lib.add_animation("shot", anim)
	ap.add_animation_library("", lib)
	ap.animation_finished.connect(func(_n): _finish())

func _event(i: int) -> void:
	if _fired.has(i):
		return
	_fired[i] = true
	(events[i][1] as Callable).call()

func play() -> void:
	_build()
	GameMode.cinematic_playing = true
	Events.cinematic_state.emit(true)
	var p: Player = GameMode.player
	if p:
		p.locked = true
		p.velocity = Vector3.ZERO
		if hide_player:
			p.visible = false
	cam.make_current()
	ap.play("shot")
	# test runs fast-forward cinematics
	if Game.test_mode != "":
		ap.speed_scale = 6.0
	await finished

func _process(_d: float) -> void:
	if shake > 0.0 and cam:
		cam.h_offset = randf_range(-1, 1) * shake * 0.05
		cam.v_offset = randf_range(-1, 1) * shake * 0.05

## Skip to the end: every essential event still fires (story state can never be skipped past).
func skip() -> void:
	if _done:
		return
	Sfx.stop_voice()
	for i in events.size():
		if events[i][2]:
			_event(i)
	_finish()

func _finish() -> void:
	if _done:
		return
	_done = true
	if ap:
		ap.stop()
	GameMode.cinematic_playing = false
	Events.cinematic_state.emit(false)
	var p: Player = GameMode.player
	if p and is_instance_valid(p):
		p.locked = false
		p.visible = true
		p.controller.make_current()
	finished.emit()
	queue_free()
