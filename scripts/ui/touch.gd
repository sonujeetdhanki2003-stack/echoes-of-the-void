extends Control
## On-screen controls for phones and tablets (adapted from THE DEEP v1.0.1): a floating move stick,
## drag-to-look on the right half, and action buttons. Every finger is tracked by its own touch index, so
## moving, looking and firing work at the same time. The FIRE button also steers the camera while held.

const STICK_R := 120.0
const DEAD := 0.14

var ui: Node
var stick_center := Vector2.ZERO
var stick_vec := Vector2.ZERO
var stick_idx := -1
var look_idx := -1
var pinch_idx := -1           # a second finger on the look side = pinch to change camera distance
var pinch_pos := {}
var look_last := Vector2.ZERO
var buttons: Array = []          # [Button, id, hold]
var _btn_touch := {}             # touch index -> button entry index
var _btn_last := {}              # touch index -> last position (for FIRE look-drag)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var big := Vector2(150, 124)
	var defs := [
		["FIRE", "fire", Vector2(-230, -330), true, Vector2(190, 190)],
		["AIM", "aim", Vector2(-430, -250), false, big],
		["JUMP", "jump", Vector2(-200, -470), false, Vector2(130, 110)],
		["RELOAD", "reload", Vector2(-430, -400), false, big],
		["CROUCH", "crouch", Vector2(-600, -180), false, Vector2(140, 110)],
		["USE", "interact", Vector2(-620, -330), false, big],
		["SWAP", "weapon_next", Vector2(-380, -560), false, Vector2(130, 100)],
		["MED", "medkit", Vector2(-560, -500), false, Vector2(130, 100)],
		["RUN", "sprint", Vector2(40, -160), false, Vector2(130, 100)],
		["MELEE", "melee", Vector2(-400, -110), false, Vector2(130, 110)],
		["LAMP", "lamp", Vector2(-400, 24), false, Vector2(110, 84)],
		["LOGS", "journal", Vector2(-270, 24), false, Vector2(110, 84)],
		["II", "pause", Vector2(-140, 24), false, Vector2(110, 84)],
	]
	for d in defs:
		var b := Button.new()
		b.text = d[0]
		b.add_theme_font_override("font", UIKit.font("Rajdhani-Bold"))
		b.add_theme_font_size_override("font_size", 28)
		var top: bool = d[1] in ["pause", "journal", "lamp"]
		var left: bool = d[1] == "sprint"
		b.custom_minimum_size = d[4]
		b.set_anchors_preset(Control.PRESET_TOP_RIGHT if top else (Control.PRESET_BOTTOM_LEFT if left else Control.PRESET_BOTTOM_RIGHT))
		var off: Vector2 = d[2]
		b.offset_left = off.x
		b.offset_top = off.y
		b.offset_right = off.x + b.custom_minimum_size.x
		b.offset_bottom = off.y + b.custom_minimum_size.y
		b.modulate.a = 0.72
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.toggle_mode = true
		b.name = "Touch_" + str(d[1])
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.02, 0.06, 0.08, 0.45)
		sb.border_color = Color(0.42, 0.86, 1.0, 0.6)
		sb.set_border_width_all(2)
		sb.set_corner_radius_all(int(minf(b.custom_minimum_size.x, b.custom_minimum_size.y) * 0.5))
		var sp := sb.duplicate() as StyleBoxFlat
		sp.bg_color = Color(0.3, 0.7, 0.9, 0.55)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sp)
		b.add_theme_stylebox_override("hover_pressed", sp)
		add_child(b)
		buttons.append([b, str(d[1]), bool(d[3])])

func _player() -> Player:
	return GameMode.player

func _button_at(p: Vector2) -> int:
	for i in buttons.size():
		var b: Button = buttons[i][0]
		if b.visible and b.get_global_rect().grow(10.0).has_point(p):
			return i
	return -1

func _tap(action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	var ev2 := InputEventAction.new()
	ev2.action = action
	ev2.pressed = false
	Input.parse_input_event(ev2)

func _press(i: int, on: bool) -> void:
	var e: Array = buttons[i]
	var id: String = e[1]
	(e[0] as Button).set_pressed_no_signal(on)
	var p := _player()
	match id:
		"fire":
			if p:
				p.combat.touch_fire = on
		"aim":
			if on and p:
				p.controller.aim_toggle = not p.controller.aim_toggle
		"sprint":
			if on and p:
				p.controller.sprint_toggle = not p.controller.sprint_toggle
		_:
			if on:
				_tap(id)

func release_all() -> void:
	for idx in _btn_touch.keys():
		var i: int = _btn_touch[idx]
		if buttons[i][1] == "fire":
			_press(i, false)
	_btn_touch.clear()
	_btn_last.clear()
	for e in buttons:
		(e[0] as Button).set_pressed_no_signal(false)
	stick_idx = -1
	look_idx = -1
	stick_vec = Vector2.ZERO
	var pl := _player()
	if pl and is_instance_valid(pl):
		pl.touch_move = Vector2.ZERO
		pl.combat.touch_fire = false
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		release_all()

func _look(delta_px: Vector2) -> void:
	var p := _player()
	if p:
		var s := 0.11 * float(Game.settings["sensitivity"]) * (0.55 if p.aiming else 1.0)
		p.controller.look(delta_px * s)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	if ui and ui.is_blocking():
		if not _btn_touch.is_empty() or stick_idx != -1 or look_idx != -1:
			release_all()
		return
	var vp := get_viewport_rect().size
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var bi := _button_at(e.position)
			if bi != -1:
				_btn_touch[e.index] = bi
				_btn_last[e.index] = e.position
				_press(bi, true)
				get_viewport().set_input_as_handled()
			elif e.position.x < vp.x * 0.4 and e.position.y > vp.y * 0.28 and stick_idx == -1:
				stick_idx = e.index
				stick_center = e.position
				stick_vec = Vector2.ZERO
			elif e.position.x >= vp.x * 0.4 and look_idx == -1:
				look_idx = e.index
				look_last = e.position
			elif e.position.x >= vp.x * 0.4 and look_idx != -1 and pinch_idx == -1:
				pinch_idx = e.index
				pinch_pos = {look_idx: look_last, pinch_idx: e.position}
		else:
			if _btn_touch.has(e.index):
				var i: int = _btn_touch[e.index]
				if buttons[i][1] == "fire":
					_press(i, false)
				else:
					(buttons[i][0] as Button).set_pressed_no_signal(false)
				_btn_touch.erase(e.index)
				_btn_last.erase(e.index)
			if e.index == stick_idx:
				stick_idx = -1
				stick_vec = Vector2.ZERO
			if e.index == look_idx:
				look_idx = -1
				pinch_idx = -1
			if e.index == pinch_idx:
				pinch_idx = -1
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == stick_idx:
			var raw := (d.position - stick_center) / STICK_R
			var l := raw.length()
			if l > 1.0:
				stick_center += (d.position - stick_center).normalized() * (l - 1.0) * STICK_R
				raw = raw / l
				l = 1.0
			stick_vec = Vector2.ZERO if l < DEAD else raw.normalized() * ((l - DEAD) / (1.0 - DEAD))
		elif pinch_idx != -1 and (d.index == look_idx or d.index == pinch_idx):
			var before: float = (pinch_pos[look_idx] as Vector2).distance_to(pinch_pos[pinch_idx])
			pinch_pos[d.index] = d.position
			if d.index == look_idx:
				look_last = d.position
			var after: float = (pinch_pos[look_idx] as Vector2).distance_to(pinch_pos[pinch_idx])
			var pl0 := _player()
			if pl0 and before > 1.0:
				pl0.controller.zoom_camera((before - after) * 0.004)
		elif d.index == look_idx:
			_look(d.position - look_last)
			look_last = d.position
		elif _btn_touch.has(d.index) and buttons[_btn_touch[d.index]][1] == "fire":
			_look(d.position - (_btn_last[d.index] as Vector2))
			_btn_last[d.index] = d.position
	var pl := _player()
	if pl:
		pl.touch_move = Vector2(stick_vec.x, -stick_vec.y)
	queue_redraw()

func _process(_d: float) -> void:
	var p := _player()
	if p == null or not visible:
		return
	for e in buttons:
		var b: Button = e[0]
		match e[1]:
			"aim":
				b.set_pressed_no_signal(p.controller.aim_toggle)
			"sprint":
				b.set_pressed_no_signal(p.controller.sprint_toggle)
			"medkit":
				b.visible = p.inventory.medkits > 0
			"weapon_next":
				b.visible = p.combat.weapons.size() > 1
			"fire", "aim", "reload":
				b.visible = p.combat.current != null
	var use_btn: Button = buttons[5][0]
	use_btn.modulate.a = 0.95 if p.interaction.focus != null else 0.45

func _draw() -> void:
	if stick_idx != -1:
		draw_circle(stick_center, STICK_R, Color(0.4, 0.9, 1.0, 0.1))
		draw_arc(stick_center, STICK_R, 0, TAU, 48, Color(0.4, 0.9, 1.0, 0.5), 3.0)
		draw_circle(stick_center + stick_vec * STICK_R, 46.0, Color(0.4, 0.9, 1.0, 0.45))
	else:
		var vp := get_viewport_rect().size
		var c := Vector2(260, vp.y - 380)
		draw_arc(c, STICK_R, 0, TAU, 48, Color(0.4, 0.9, 1.0, 0.22), 3.0)
		draw_string(UIKit.font("Rajdhani-Bold"), c + Vector2(-34, 8), "MOVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.6, 0.9, 1.0, 0.4))
