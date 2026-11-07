extends Control
## Draws and drives the conduit rotation board. Tap/click a tile to rotate it 90°.

signal solved

var board: ConduitBoard
var _solved := false
var _flash := 0.0
var _last_rot_frame := -1

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_solved = board.is_solved()

func _tile_rect(x: int, y: int) -> Rect2:
	var margin := Vector2(120, 20)
	var cell := minf((size.x - margin.x * 2.0) / board.w, (size.y - margin.y * 2.0) / board.h)
	var origin := Vector2((size.x - cell * board.w) * 0.5, (size.y - cell * board.h) * 0.5)
	return Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))

func _gui_input(event: InputEvent) -> void:
	if _solved:
		return
	var pos := Vector2.INF
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		pos = (event as InputEventMouseButton).position
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		pos = (event as InputEventScreenTouch).position
	if pos == Vector2.INF:
		return
	# 1.9.2 (bug 7): a touch can arrive as a screen touch and as an emulated mouse press in the same frame; rotate once
	var fr := Engine.get_process_frames()
	if fr == _last_rot_frame:
		accept_event()
		return
	for y in board.h:
		for x in board.w:
			if _tile_rect(x, y).has_point(pos):
				_last_rot_frame = fr
				rotate_tile(x, y)
				accept_event()
				return

func rotate_tile(x: int, y: int) -> void:
	board.rotate_tile(x, y)
	Sfx.ui("conduit_rotate", -4.0)
	queue_redraw()
	if board.is_solved() and not _solved:
		_solved = true
		_flash = 1.0
		solved.emit()

func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta)
	queue_redraw()

func _draw() -> void:
	var pw := board.powered()
	var cells: Dictionary = pw["cells"]
	var t := Time.get_ticks_msec() * 0.001
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.03, 0.04, 0.9))
	var font := UIKit.font("ShareTechMono-Regular")
	for y in board.h:
		for x in board.w:
			var r := _tile_rect(x, y)
			draw_rect(r.grow(-4), Color(0.06, 0.08, 0.1), true)
			draw_rect(r.grow(-4), Color(0.25, 0.35, 0.42, 0.6), false, 2.0)
			var m := board.mask(x, y)
			var lit := cells.has(Vector2i(x, y))
			var col := Color(1.0, 0.6, 0.2) if lit else Color(0.35, 0.42, 0.48)
			if lit:
				col = col.lerp(Color(1.0, 0.9, 0.6), 0.3 + 0.3 * sin(t * 6.0 + x + y))
			var c := r.get_center()
			var half := r.size.x * 0.5 - 4.0
			var wdt := r.size.x * 0.16
			for d in [[ConduitBoard.N, Vector2.UP], [ConduitBoard.E, Vector2.RIGHT], [ConduitBoard.S, Vector2.DOWN], [ConduitBoard.W, Vector2.LEFT]]:
				if m & int(d[0]):
					draw_line(c, c + (d[1] as Vector2) * half, col, wdt)
			draw_circle(c, wdt * 0.7, col)
	# terminals
	var src := _tile_rect(0, board.source_row)
	_terminal(Vector2(src.position.x - 60, src.get_center().y), "CORE", Color(1.0, 0.55, 0.15), true, font)
	var up := _tile_rect(board.w - 1, board.uplink_row)
	_terminal(Vector2(up.end.x + 60, up.get_center().y), "UPLINK", Color(0.35, 1.0, 0.55) if pw["uplink"] else Color(0.3, 0.45, 0.4), pw["uplink"], font)
	for fr in [board.feed_row, board.feed2_row]:
		var f := _tile_rect(board.w - 1, fr)
		_terminal(Vector2(f.end.x + 60, f.get_center().y), "SPIRE", Color(1.0, 0.25, 0.6) if pw["feed"] else Color(0.4, 0.25, 0.35), pw["feed"], font)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.8, 0.4, _flash * 0.3))

func _terminal(p: Vector2, label: String, col: Color, on: bool, font: Font) -> void:
	draw_circle(p, 26.0, col if on else col * 0.6)
	draw_string(font, p + Vector2(-34, 52), label, HORIZONTAL_ALIGNMENT_CENTER, 68, 18, col)
