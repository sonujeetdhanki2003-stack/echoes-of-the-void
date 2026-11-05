class_name Feedback
extends RefCounted
## v1.1.0 feel and comfort: hit-stop (a few real milliseconds of slow motion on a kill or a weak-point hit) and
## haptics (phone vibration, controller rumble). Both respect the "Reduce motion" and "Vibration" settings.
## Both are off while a test driver runs (Game.test_mode), so the fixed-step regression suites keep their timing;
## the feedback test switches them on with force_on.

const HITSTOP_KILL_SECS := 0.07       # real time (ignores time_scale)
const HITSTOP_WEAK_SECS := 0.045
const HITSTOP_SCALE := 0.12

enum Kind { HURT, KILL, WEAKPOINT, DEATH }

static var force_on := false          # test hook: lets the feedback test run inside a test driver
static var _restore_scale := 1.0
static var _stop_gen := 0

static func reduce_motion() -> bool:
	return bool(Game.settings.get("reduce_motion", false))

static func vibration_setting() -> bool:
	return bool(Game.settings.get("vibration", true))

static func _live_game() -> bool:
	# any test mode or test driver (--driver=...) keeps the fixed-step timing: off unless the test forces it
	return (Game.test_mode == "" and Game.arg("driver") == "") or force_on

## true when a hit-stop may run now
static func hitstop_allowed() -> bool:
	return _live_game() and not reduce_motion()

## true when a vibration pulse may go out now
static func vibration_allowed() -> bool:
	return _live_game() and vibration_setting()

## pulse table: [duration_ms, amplitude 0..1] per kind; amplitude is scaled by the hit size for HURT
static func pulse_for(kind: int, amount: float = 0.0) -> Array:
	match kind:
		Kind.HURT:
			return [60, clampf(amount / 30.0, 0.3, 1.0)]
		Kind.KILL:
			return [90, 0.8]
		Kind.WEAKPOINT:
			return [35, 0.5]
		Kind.DEATH:
			return [400, 1.0]
	return [40, 0.5]

static func vibrate(kind: int, amount: float = 0.0) -> void:
	if not vibration_allowed():
		return
	var p := pulse_for(kind, amount)
	var ms: int = p[0]
	var amp: float = p[1]
	if Game.is_mobile:
		Input.vibrate_handheld(ms, amp)
	for pad in Input.get_connected_joypads():
		Input.start_joy_vibration(pad, amp, amp * 0.6, ms / 1000.0)

## freeze-frame style slow motion in real time. A later stop extends the current one; the old scale comes back once.
static func hit_stop(secs: float) -> void:
	if not hitstop_allowed():
		return
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	if _stop_gen == 0:
		_restore_scale = Engine.time_scale
	_stop_gen += 1
	var gen := _stop_gen
	Engine.time_scale = HITSTOP_SCALE
	var t := tree.create_timer(secs, true, false, true)
	t.timeout.connect(func() -> void: _end_stop(gen))

static func _end_stop(gen: int) -> void:
	if gen != _stop_gen:
		return                         # a later stop owns the restore
	Engine.time_scale = _restore_scale
	_stop_gen = 0

static func stop_active() -> bool:
	return _stop_gen != 0

## called by Game for every confirmed hit on a target
static func on_hit_confirmed(critical: bool, killed: bool) -> void:
	if killed:
		hit_stop(HITSTOP_KILL_SECS)
		vibrate(Kind.KILL)
	elif critical:
		hit_stop(HITSTOP_WEAK_SECS)
		vibrate(Kind.WEAKPOINT)

static func on_player_damaged(amount: float) -> void:
	vibrate(Kind.HURT, amount)

static func on_player_died() -> void:
	vibrate(Kind.DEATH)
