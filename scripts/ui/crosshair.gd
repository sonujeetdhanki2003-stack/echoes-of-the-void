extends Control
## Dynamic crosshair (spread), hit markers, and directional damage indicators.

var ui: Node

func _draw() -> void:
	var p: Player = GameMode.player
	var c := size * 0.5
	if ui == null or not ui.hud.visible:
		return
	# damage direction arcs
	for d in ui.dmg_dirs:
		var a: float = -d[0] - PI * 0.5
		var alpha: float = clampf(d[1], 0.0, 1.0)
		draw_arc(c, 230.0, a - 0.35, a + 0.35, 24, Color(1.0, 0.2, 0.15, 0.7 * alpha), 10.0)
	if p == null or p.combat.current == null or p.locked or p.dead:
		if p and not p.locked:
			draw_circle(c, 2.5, Color(1, 1, 1, 0.6))
		return
	var w := p.combat.current
	var spread_deg := w.current_spread()
	var cam: Camera3D = p.controller.cam
	var px := tan(deg_to_rad(spread_deg)) / tan(deg_to_rad(cam.fov * 0.5)) * size.y * 0.5
	var gap := 6.0 + px
	var col := Color(1, 1, 1, 0.85)
	if w.reloading:
		col = Color(1.0, 0.75, 0.3, 0.8)
		draw_arc(c, 22.0, -PI * 0.5, -PI * 0.5 + TAU * w.reload_progress(), 32, col, 3.0)
	var len := 10.0
	for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
		draw_line(c + dir * gap, c + dir * (gap + len), Color(0, 0, 0, 0.5), 4.0)
		draw_line(c + dir * gap, c + dir * (gap + len), col, 2.0)
	draw_circle(c, 1.6, col)
	if ui._hit_t > 0.0:
		var hc := Color(1.0, 0.3, 0.25) if ui._hit_kill else (Color(1.0, 0.85, 0.3) if ui._hit_crit else Color(1, 1, 1))
		hc.a = ui._hit_t * 4.0
		var s := 9.0 + (4.0 if ui._hit_kill else 0.0)
		for dv in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_line(c + dv * s, c + dv * (s + 9.0), hc, 3.0)
