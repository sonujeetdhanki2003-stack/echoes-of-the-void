extends CanvasLayer
## All player-facing UI (PRD Phase 10): HUD, main menu, settings, pause, journal/objectives, death, loading,
## cinematic letterbox and subtitles, puzzle overlays (keypad, conduit board) and touch controls.

const K := preload("res://scripts/ui/ui_kit.gd")

var main: Node
var hud: Control
var host: Control           # full-screen panels (menus, overlays)
var fade: ColorRect
var post: ColorRect
var post_mat: ShaderMaterial
var touch: Control
var letterbox_top: ColorRect
var letterbox_bot: ColorRect
var current := ""           # name of the open panel ("" = gameplay)
var _back_stack: Array = []

# HUD widgets
var hp_bar: ProgressBar
var st_bar: ProgressBar
var hp_lbl: Label
var ammo_lbl: Label
var reserve_lbl: Label
var weapon_lbl: Label
var med_lbl: Label
var obj_title: Label
var obj_lbl: Label
var fps_lbl: Label
var _fps_t := 0.0
var prompt_lbl: Label
var prompt_box: PanelContainer
var sub_lbl: Label
var sub_speaker: Label
var sub_box: PanelContainer
var sub_inner: VBoxContainer
var _sub_pad := 0.0
var toast_lbl: Label
var crosshair: Control
var banner: VBoxContainer
var boss_box: VBoxContainer
var boss_bar: ProgressBar
var boss_lbl: Label
var save_icon: Label
var loading_box: VBoxContainer
var loading_lbl: Label
var skip_lbl: Label
var dmg_dirs: Array = []
var _toast_t := 0.0
var _toast_tw: Tween
var _sub_t := 0.0
var _hit_t := 0.0
var _hit_crit := false
var _hit_kill := false
var _dmg_flash := 0.0
var _low_hp := 0.0
var _banner_t := 0.0
var _save_t := 0.0
var _skip_hold := 0.0
var _keypad_entry := ""
var _keypad_target: Keypad
var _keypad_disp: Label
var _conduit_target: ConduitConsole
var _conduit_canvas: Control
var menu_backdrop: Node3D

func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var post_layer := CanvasLayer.new()
	post_layer.layer = 1
	add_child(post_layer)
	post = ColorRect.new()
	post.set_anchors_preset(Control.PRESET_FULL_RECT)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = load("res://shaders/post.gdshader")
	post.material = post_mat
	post_layer.add_child(post)
	_build_hud()
	relayout_hud()
	touch = load("res://scripts/ui/touch.gd").new()
	touch.ui = self
	touch.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch.visible = false
	add_child(touch)
	host = Control.new()
	host.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(host)
	letterbox_top = _bar_rect(true)
	letterbox_bot = _bar_rect(false)
	skip_lbl = K.mono("", 20, K.DIM)
	skip_lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_lbl.position = Vector2(-420, -60)
	add_child(skip_lbl)
	loading_box = K.vbox(8)
	loading_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	loading_box.position = Vector2(90, -170)
	loading_lbl = K.label("", 44, K.WHITE, "Rajdhani-Bold")
	loading_box.add_child(loading_lbl)
	loading_box.add_child(K.mono("LOADING…", 20, K.CYAN))
	loading_box.visible = false
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 1)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	add_child(loading_box)
	_connect_events()
	hud.visible = false

func _bar_rect(top: bool) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0, 0, 0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.anchor_left = 0.0
	r.anchor_right = 1.0
	if top:
		r.anchor_top = 0.0
		r.anchor_bottom = 0.0
	else:
		r.anchor_top = 1.0
		r.anchor_bottom = 1.0
	r.offset_top = 0.0
	r.offset_bottom = 0.0
	add_child(r)
	return r

func _connect_events() -> void:
	Events.message.connect(toast)
	Events.subtitle.connect(_on_subtitle)
	Events.interact_focus.connect(_on_prompt)
	Events.objective_changed.connect(func(t): obj_lbl.text = t)
	Events.mission_changed.connect(_on_mission)
	Events.hit_confirmed.connect(func(c, k):
		_hit_t = 0.25
		_hit_crit = c
		_hit_kill = k)
	Events.player_damaged.connect(_on_damaged)
	Events.boss_health.connect(_on_boss)
	Events.cinematic_state.connect(_on_cinematic)
	Events.checkpoint_reached.connect(func(_id): _save_t = 2.0)

# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	hud = Control.new()
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hud)
	crosshair = load("res://scripts/ui/crosshair.gd").new()
	crosshair.ui = self
	crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(crosshair)
	# performance readout (Settings > Show FPS): lets the player measure real frame rates on their own PC / phone
	fps_lbl = K.mono("", 16, Color(0.75, 1.0, 0.8, 0.9))
	fps_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fps_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	fps_lbl.position = Vector2(-300, 2)
	fps_lbl.custom_minimum_size = Vector2(600, 20)
	fps_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fps_lbl.visible = false
	add_child(fps_lbl)
	# vitals, bottom-left
	var vit := K.vbox(6)
	hud_vit = vit
	var row := K.hbox(12)
	hp_lbl = K.mono("100", 30, K.WHITE)
	row.add_child(K.mono("VITALS", 18, K.CYAN))
	row.add_child(hp_lbl)
	vit.add_child(row)
	hp_bar = K.bar(340, 12, Color(0.85, 0.95, 1.0))
	vit.add_child(hp_bar)
	st_bar = K.bar(340, 5, Color(0.42, 0.86, 1.0, 0.8))
	vit.add_child(st_bar)
	med_lbl = K.mono("MEDKITS 0", 18, K.DIM)
	vit.add_child(med_lbl)
	hud.add_child(vit)
	# ammo, bottom-right
	var am := K.vbox(0)
	hud_am = am
	am.alignment = BoxContainer.ALIGNMENT_END
	weapon_lbl = K.mono("", 20, K.CYAN)
	weapon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	weapon_lbl.custom_minimum_size.x = 260
	am.add_child(weapon_lbl)
	var arow := K.hbox(10)
	arow.alignment = BoxContainer.ALIGNMENT_END
	ammo_lbl = K.label("", 72, K.WHITE, "Rajdhani-Bold")
	reserve_lbl = K.mono("", 28, K.DIM)
	arow.add_child(ammo_lbl)
	arow.add_child(reserve_lbl)
	arow.custom_minimum_size.x = 260
	am.add_child(arow)
	hud.add_child(am)
	# objective, top-left
	var ob := K.vbox(2)
	hud_ob = ob
	obj_title = K.mono("", 18, K.CYAN)
	obj_lbl = K.wrap(K.label("", 28, K.WHITE), 620)
	ob.add_child(obj_title)
	ob.add_child(obj_lbl)
	hud.add_child(ob)
	# interaction prompt
	prompt_box = PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0, 0.03, 0.05, 0.6)
	ps.border_color = K.CYAN
	ps.border_width_left = 3
	ps.content_margin_left = 16
	ps.content_margin_right = 16
	ps.content_margin_top = 6
	ps.content_margin_bottom = 6
	prompt_box.add_theme_stylebox_override("panel", ps)
	prompt_lbl = K.label("", 28, K.WHITE)
	prompt_box.add_child(prompt_lbl)
	prompt_box.set_anchors_preset(Control.PRESET_CENTER)
	prompt_box.position = Vector2(-10, 90)
	prompt_box.visible = false
	hud.add_child(prompt_box)
	# subtitles
	sub_box = PanelContainer.new()
	sub_inner = K.vbox(2)
	sub_box.add_child(sub_inner)
	sub_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sub_box.position = Vector2(-560, -260)
	sub_box.custom_minimum_size = Vector2(1120, 0)
	sub_speaker = K.mono("", 20, K.CYAN)
	sub_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl = K.wrap(K.label("", 30, K.WHITE), 1120)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_inner.add_child(sub_speaker)
	sub_inner.add_child(sub_lbl)
	sub_box.visible = false
	add_child(sub_box)
	_style_sub()
	# toast
	toast_lbl = K.label("", 28, K.WHITE)
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.position = Vector2(-500, 150)
	toast_lbl.custom_minimum_size.x = 1000
	toast_lbl.modulate.a = 0.0
	hud.add_child(toast_lbl)
	# mission banner
	banner = K.vbox(4)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.position = Vector2(-600, -250)
	banner.custom_minimum_size.x = 1200
	banner.modulate.a = 0.0
	add_child(banner)
	# boss bar
	boss_box = K.vbox(4)
	boss_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	boss_box.position = Vector2(-450, 70)
	boss_lbl = K.label("", 28, K.WHITE, "Rajdhani-Bold")
	boss_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_lbl.custom_minimum_size.x = 900
	boss_bar = K.bar(900, 14, Color(0.75, 0.35, 1.0))
	boss_box.add_child(boss_lbl)
	boss_box.add_child(boss_bar)
	boss_box.visible = false
	hud.add_child(boss_box)
	save_icon = K.mono("◈ SAVING", 20, K.CYAN)
	save_icon.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	save_icon.position = Vector2(-200, 50)
	save_icon.modulate.a = 0.0
	hud.add_child(save_icon)

var hud_vit: Control
var hud_am: Control
var hud_ob: Control
## HUD layout. Desktop: objective top-left, vitals bottom-left, ammo bottom-right. Touch: the thumbs own the
## bottom corners (stick + buttons), so vitals and objective stack top-left and ammo sits top-right under the
## LAMP / LOGS / pause row, clear of every touch button.
func relayout_hud() -> void:
	if hud_vit == null:
		return
	var t := Game.touch_enabled()
	var vw := get_viewport().get_visible_rect().size.x
	if t:
		_place(hud_vit, Control.PRESET_TOP_LEFT, Vector2(56, 30))
		_place(hud_ob, Control.PRESET_TOP_LEFT, Vector2(56, 150))
		_place(hud_am, Control.PRESET_TOP_RIGHT, Vector2(-330, 120))
		# subtitles: left of the button cluster, right of the RUN button
		# between the RUN button (left) and the button cluster (right)
		_sub_w = clampf(vw - 560.0, 420.0, 880.0)
		_sub_x = 140.0 - vw * 0.5
		_sub_bottom = -95.0
	else:
		_place(hud_ob, Control.PRESET_TOP_LEFT, Vector2(64, 50))
		_place(hud_vit, Control.PRESET_BOTTOM_LEFT, Vector2(64, -150))
		_place(hud_am, Control.PRESET_BOTTOM_RIGHT, Vector2(-330, -175))
		_sub_w = minf(1120.0, vw - 120.0)
		_sub_x = -_sub_w * 0.5
		_sub_bottom = -195.0
	_place_sub()
	# v1.0.1 layout audit: the transient widgets (prompt, toast, boss bar, saving icon) are placed per mode so they never
	# land on the always-visible HUD or the touch buttons (measured by tests/ui_layout2.gd at 20:9, 16:9 and 4:3)
	if t:
		var bw := clampf(vw - 880.0, 420.0, 900.0)       # between the vitals (left) and the LAMP/LOGS/pause buttons (right)
		_center_top(boss_box, 70.0, bw)
		_center_top(toast_lbl, 24.0, 1000.0)
		_place(save_icon, Control.PRESET_TOP_LEFT, Vector2(56, 124))
		_prompt_y = -40.0   # 1.9.2: lifted clear of the subtitle box that sits low on touch screens
	else:
		_center_top(boss_box, 165.0, minf(900.0, vw - 160.0))
		_center_top(toast_lbl, 225.0, 1000.0)
		_place(save_icon, Control.PRESET_TOP_RIGHT, Vector2(-200, 50))
		_prompt_y = 90.0
	boss_bar.custom_minimum_size.x = boss_box.offset_right - boss_box.offset_left
	boss_lbl.custom_minimum_size.x = boss_bar.custom_minimum_size.x
	_place_prompt()

var _prompt_y := 90.0
func _center_top(c: Control, y: float, w: float) -> void:
	c.set_anchors_preset(Control.PRESET_CENTER_TOP)
	var h := maxf(c.get_combined_minimum_size().y, c.size.y)
	c.offset_left = -w * 0.5
	c.offset_right = w * 0.5
	c.offset_top = y
	c.offset_bottom = y + h

## the interaction prompt sits on the centre line, centred on its own text (a long prompt used to run into the USE button)
func _place_prompt() -> void:
	if prompt_box == null:
		return
	prompt_box.set_anchors_preset(Control.PRESET_CENTER)
	var sz := prompt_box.get_combined_minimum_size()
	prompt_box.offset_left = -sz.x * 0.5
	prompt_box.offset_right = sz.x * 0.5
	prompt_box.offset_top = _prompt_y
	prompt_box.offset_bottom = _prompt_y + sz.y

var _sub_x := -560.0
var _sub_w := 1120.0
var _sub_bottom := -125.0
var _cine_on := false

## Subtitles keep their BOTTOM edge fixed and grow upward, so a long 3-line subtitle never runs under the
## cinematic letterbox or the touch buttons.
func _place_sub() -> void:
	if sub_box == null:
		return
	sub_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	sub_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	var bottom := -150.0 if _cine_on else _sub_bottom
	var w := _sub_w
	if Game.touch_enabled() and not _cine_on and touch:
		# fit between the SPRINT button (left) and the right-hand button cluster, measured from the live layout
		var vr := get_viewport().get_visible_rect().size
		var left := 140.0
		var right := vr.x - 420.0
		for b in touch.find_children("Touch_*", "Control", true, false):
			var r: Rect2 = (b as Control).get_global_rect()
			if r.size.x <= 0.0 or r.position.y < vr.y * 0.45:
				continue
			if r.get_center().x < vr.x * 0.5:
				left = maxf(left, r.end.x + 24.0)
			else:
				right = minf(right, r.position.x - 24.0)
		w = clampf(right - left, 360.0, 880.0)
		_sub_x = left - vr.x * 0.5
	if _cine_on:     # HUD and touch buttons are hidden: centre it, as wide as the screen allows
		w = minf(1120.0, get_viewport().get_visible_rect().size.x - 120.0)
	sub_box.custom_minimum_size = Vector2(w, 0)
	sub_lbl.custom_minimum_size.x = w - _sub_pad * 2.0
	sub_box.offset_left = _sub_x if not _cine_on else -w * 0.5
	sub_box.offset_right = sub_box.offset_left + w
	sub_box.offset_bottom = bottom
	sub_box.offset_top = bottom

const SUB_FONT := {"small": [24, 17], "medium": [30, 20], "large": [38, 26]}   # text size, speaker size

## v1.1.0: subtitle size, and an optional dark backing behind the text (accessibility, PRD 11.5)
func _style_sub() -> void:
	if sub_box == null or sub_lbl == null:
		return
	var sz: Array = SUB_FONT.get(str(Game.settings.get("subtitle_size", "medium")), SUB_FONT["medium"])
	sub_lbl.add_theme_font_size_override("font_size", sz[0])
	sub_speaker.add_theme_font_size_override("font_size", sz[1])
	if bool(Game.settings.get("subtitle_bg", false)):
		var f := StyleBoxFlat.new()
		f.bg_color = Color(0.0, 0.0, 0.0, 0.62)
		f.set_corner_radius_all(4)
		f.content_margin_left = 16.0
		f.content_margin_right = 16.0
		f.content_margin_top = 8.0
		f.content_margin_bottom = 8.0
		sub_box.add_theme_stylebox_override("panel", f)
		_sub_pad = 16.0
	else:
		sub_box.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		_sub_pad = 0.0

## anchor `c` to a preset and put its top-left at `off` from that anchor (works before and after layout)
func _place(c: Control, preset: int, off: Vector2) -> void:
	c.set_anchors_preset(preset)
	var sz := c.get_combined_minimum_size()
	c.offset_left = off.x
	c.offset_top = off.y
	c.offset_right = off.x + sz.x
	c.offset_bottom = off.y + sz.y

func hud_visible(on: bool) -> void:
	hud.visible = on
	touch.visible = on and Game.touch_enabled()
	relayout_hud()
	if not on:
		prompt_box.visible = false

func toast(text: String, secs: float = 2.0) -> void:
	toast_lbl.text = text
	if _toast_tw and _toast_tw.is_valid():
		_toast_tw.kill()      # v1.0.1: a fade still running from the previous toast must not hide this one
	toast_lbl.modulate.a = 1.0
	_toast_t = secs

func _on_subtitle(speaker: String, text: String, secs: float) -> void:
	if text == "" or not Game.settings["subtitles"]:
		sub_box.visible = false
		return
	_style_sub()
	sub_speaker.text = speaker
	sub_lbl.text = text
	_place_sub()
	sub_box.visible = true
	_sub_t = secs

func _on_prompt(text: String) -> void:
	prompt_box.visible = text != "" and current == ""
	if text != "":
		var key := "USE" if Game.touch_enabled() else "[%s]" % Game.key_name("interact")
		prompt_lbl.text = "%s  %s" % [key, text]
		prompt_box.reset_size()
		_place_prompt()

func _on_mission(_i: int, title: String) -> void:
	for c in banner.get_children():
		c.queue_free()
	var t := K.label(title, 64, K.WHITE, "Rajdhani-Bold")
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size.x = 1200
	banner.add_child(t)
	var m := Missions.current_mission()
	var s := K.mono(str(m.get("subtitle", "")).to_upper(), 22, K.CYAN)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.custom_minimum_size.x = 1200
	banner.add_child(s)
	_banner_t = 5.0
	obj_title.text = title
	Sfx.sting("sting_discovery", -6.0)

func show_mission_banner() -> void:
	_on_mission(Game.state["mission"], Missions.mission_title(Game.state["mission"]))

func _on_damaged(amount: float, dir: Vector3) -> void:
	_dmg_flash = clampf(_dmg_flash + amount / 40.0, 0.0, 1.0)
	var p: Player = GameMode.player
	if p:
		# angle of the hit relative to the camera, for the directional indicator
		var cam_f: Vector3 = -p.controller.cam.global_transform.basis.z
		cam_f.y = 0.0
		var a := cam_f.normalized().signed_angle_to(dir, Vector3.UP)
		dmg_dirs.append([a, 1.0])
		crosshair.queue_redraw()

func _on_boss(n: String, f: float, vis: bool) -> void:
	boss_box.visible = vis
	boss_lbl.text = n
	boss_bar.value = f * 100.0

func _on_cinematic(playing: bool) -> void:
	_cine_on = playing
	_skip_touch = false      # v1.0.1: the SKIP button is freed with the cinematic; its button_up never fires
	_skip_hold = 0.0
	_place_sub()
	var h := 130.0 if playing else 0.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(letterbox_top, "offset_bottom", h, 0.6)
	tw.tween_property(letterbox_bot, "offset_top", -h, 0.6)
	hud.visible = not playing and GameMode.in_game
	touch.visible = not playing and GameMode.in_game and Game.touch_enabled()
	skip_lbl.text = ("Hold SKIP to skip" if Game.touch_enabled() else "Hold ENTER / SPACE to skip") if playing else ""
	if playing:
		_add_skip_button()
	else:
		var sb := get_node_or_null("SkipButton")
		if sb:
			sb.queue_free()

func _add_skip_button() -> void:
	if not Game.touch_enabled() or get_node_or_null("SkipButton"):
		return
	var b := K.button("SKIP ▶▶", func(): pass, 24, 180)
	b.name = "SkipButton"
	b.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	b.position = Vector2(-220, 30)
	b.button_down.connect(func(): _skip_touch = true)
	b.button_up.connect(func(): _skip_touch = false)
	add_child(b)

var _skip_touch := false

func skip_held() -> bool:
	return Input.is_action_pressed("skip") or Input.is_action_pressed("jump") or _skip_touch

func _process(delta: float) -> void:
	var p: Player = GameMode.player
	_update_fps(delta)
	if _toast_t > 0.0:
		_toast_t -= delta
		if _toast_t <= 0.0:
			_toast_tw = create_tween()
			_toast_tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.4)
	if _sub_t > 0.0:
		_sub_t -= delta
		if _sub_t <= 0.0:
			sub_box.visible = false
	if _banner_t > 0.0:
		_banner_t -= delta
		banner.modulate.a = clampf(minf(_banner_t, 5.0 - _banner_t) * 1.5, 0.0, 1.0)
	if _save_t > 0.0:
		_save_t -= delta
		save_icon.modulate.a = clampf(_save_t, 0.0, 1.0) * (0.6 + 0.4 * sin(_save_t * 12.0))
	_hit_t = maxf(0.0, _hit_t - delta)
	_dmg_flash = maxf(0.0, _dmg_flash - delta * 1.4)
	for d in dmg_dirs:
		d[1] -= delta * 0.9
	dmg_dirs = dmg_dirs.filter(func(d): return d[1] > 0.0)
	if p and is_instance_valid(p) and hud.visible:
		hp_bar.value = p.health.frac() * 100.0
		hp_lbl.text = str(int(ceil(p.health.hp)))
		hp_lbl.add_theme_color_override("font_color", K.RED if p.health.frac() < 0.3 else K.WHITE)
		st_bar.value = p.stamina
		st_bar.modulate = Color(1, 0.4, 0.3) if p.exhausted else Color.WHITE
		med_lbl.text = "MEDKITS %d   ·   %s" % [p.inventory.medkits, "MED" if Game.touch_enabled() else "%s to heal" % Game.key_name("medkit")] if p.inventory.medkits > 0 else "MEDKITS 0"
		if p.combat.current:
			var w := p.combat.current
			weapon_lbl.text = w.data.display_name + ("   RELOADING" if w.reloading else "")
			ammo_lbl.text = str(w.mag)
			ammo_lbl.add_theme_color_override("font_color", K.RED if w.mag <= int(w.data.mag_size * 0.25) else K.WHITE)
			reserve_lbl.text = "/ %d" % int(p.inventory.reserve.get(w.data.ammo_type, 0))
		else:
			weapon_lbl.text = ""
			ammo_lbl.text = ""
			reserve_lbl.text = ""
		_low_hp = lerpf(_low_hp, clampf(1.0 - p.health.frac() / 0.35, 0.0, 1.0) if not p.dead else 1.0, 1.0 - exp(-3.0 * delta))
		Sfx.loop("heartbeat", "heartbeat", _low_hp > 0.35 and not p.dead and GameMode.in_game, -6.0)
	else:
		_low_hp = lerpf(_low_hp, 0.0, 1.0 - exp(-3.0 * delta))
	post_mat.set_shader_parameter("damage", _dmg_flash)
	post_mat.set_shader_parameter("low_health", _low_hp)
	crosshair.queue_redraw()
	# cinematic skip
	if GameMode.cinematic_playing:
		if skip_held():
			_skip_hold += delta
			skip_lbl.text = "Skipping… %d%%" % int(clampf(_skip_hold / 0.8, 0.0, 1.0) * 100.0)
			if _skip_hold >= 0.8:
				_skip_hold = 0.0
				var c: Node = get_tree().get_first_node_in_group("cinematic")
				if c and c.has_method("skip"):
					c.skip()
		else:
			_skip_hold = 0.0

func fade_to(a: float, secs: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", a, secs)
	await tw.finished

func show_loading(area_name: String) -> void:
	loading_lbl.text = area_name
	loading_box.visible = true
	_clear_host()
	current = ""
	hud_visible(false)

func hide_loading() -> void:
	loading_box.visible = false

func on_area_loaded(_id: String) -> void:
	_clear_host()
	current = ""
	_free_backdrop()
	hud_visible(true)
	obj_title.text = Missions.mission_title(Game.state["mission"])
	obj_lbl.text = Missions.objective_text()
	touch.release_all()

# ---------------------------------------------------------------- panels
func is_blocking() -> bool:
	return current != "" or GameMode.loading

func is_open() -> bool:
	return current != ""

func _clear_host() -> void:
	for c in host.get_children():
		c.queue_free()
	host.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _open(name: String) -> void:
	_clear_host()
	current = name
	host.mouse_filter = Control.MOUSE_FILTER_STOP
	prompt_box.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if touch:
		touch.release_all()

func _close_to_game() -> void:
	_clear_host()
	current = ""
	get_tree().paused = false
	if GameMode.in_game and not Game.touch_enabled() and Game.test_mode == "":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3 and (OS.is_debug_build() or Game.has_arg("ai_debug")):
		EnemyBase.debug_ai = not EnemyBase.debug_ai
		Events.message.emit("AI debug " + ("on" if EnemyBase.debug_ai else "off"), 1.2)
	if event.is_action_pressed("pause"):
		back_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("journal") and GameMode.in_game and not GameMode.cinematic_playing:
		if current == "":
			open_journal()
		elif current == "journal":
			_close_to_game()
		get_viewport().set_input_as_handled()

## Esc / Android back: close the open panel, or pause during play. Never quits.
func back_pressed() -> void:
	match current:
		"":
			if GameMode.in_game and not GameMode.cinematic_playing:
				pause()
		"pause":
			_close_to_game()
		"settings_pause", "journal_pause", "confirm_pause", "howto_pause":
			pause()
		"journal", "keypad", "conduits", "bench":
			_close_to_game()
		"settings_menu", "credits", "newgame", "howto", "slots":
			show_menu()
		"bindings":
			if _rebind_action == "":
				open_settings(_rebind_back)
		"menu", "death", "end_credits":
			pass

func pause() -> void:
	if not GameMode.in_game:
		return
	get_tree().paused = true
	_open("pause")
	Sfx.ui("ui_back", -6.0)
	var v := K.vbox(10)
	v.add_child(K.label("PAUSED", 64, K.WHITE, "Rajdhani-Bold"))
	v.add_child(K.mono(Missions.mission_title(Game.state["mission"]) + "  ·  " + Missions.objective_text(), 20, K.CYAN))
	v.add_child(K.spacer(20))
	var resume := K.button("Resume", _close_to_game)
	v.add_child(resume)
	v.add_child(K.button("Inventory & logs", func(): open_journal(true)))
	var why := GameMode.can_manual_save()
	var sv := K.button("Save game" if why == "" else "Save game  (%s)" % why, _do_save)
	sv.disabled = why != ""
	v.add_child(sv)
	v.add_child(K.button("How to play", func(): open_howto(true)))
	v.add_child(K.button("Settings", func(): open_settings("settings_pause")))
	v.add_child(K.button("Restart checkpoint", func(): _confirm("Restart from the last checkpoint? Progress since then will be lost.", func():
		_close_to_game()
		GameMode.restart_checkpoint(), "confirm_pause")))
	v.add_child(K.button("Main menu", func(): _confirm("Return to the main menu? Unsaved progress will be lost.", func():
		_close_to_game()
		GameMode.to_menu(), "confirm_pause")))
	var p := K.panel()
	p.add_child(v)
	host.add_child(K.center(p))
	resume.grab_focus()

func _do_save() -> void:
	if GameMode.manual_save():
		toast("Game saved", 1.6)
		_save_t = 2.0
		Sfx.ui("checkpoint", -6.0)
	else:
		toast(GameMode.can_manual_save(), 1.6)
	pause()

func _confirm(text: String, yes: Callable, name: String = "confirm") -> void:
	var back := current
	_open(name)
	var v := K.vbox(16)
	v.add_child(K.wrap(K.label(text, 30, K.WHITE), 700))
	var h := K.hbox(16)
	var y := K.button("Yes", yes, 28, 200)
	h.add_child(y)
	h.add_child(K.button("No", func():
		if back == "pause":
			pause()
		elif back == "menu":
			show_menu()
		else:
			pause(), 28, 200))
	v.add_child(h)
	var p := K.panel()
	p.add_child(v)
	host.add_child(K.center(p))
	y.grab_focus()

# ---------------------------------------------------------------- main menu
func show_menu() -> void:
	GameMode.in_game = false
	get_tree().paused = false
	hud_visible(false)
	_open("menu")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if menu_backdrop == null:
		_make_backdrop()
	Sfx.set_music_mode("menu")
	Sfx.ambience("amb_exterior", -8.0)
	var shade := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.85))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	shade.texture = gt
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(shade)
	# fit the title block and buttons to the visible height (phones at 1.35x UI have ~800 virtual px)
	var vps := get_viewport().get_visible_rect().size
	var compact := vps.y < 950.0
	var v := K.vbox(6 if compact else 10)
	v.position = Vector2(110 if compact else 130, clampf(vps.y * 0.08, 36.0, 170.0) if compact else 170.0)
	var t1 := K.label("ECHOES", 104 if compact else 132, K.WHITE, "Rajdhani-Bold")
	var t2 := K.label("OF THE VOID", 44 if compact else 54, Color(0.75, 0.88, 1.0), "Rajdhani-Bold")
	t1.add_theme_constant_override("line_spacing", -30)
	v.add_child(t1)
	v.add_child(t2)
	v.add_child(K.mono("NYX-7  ·  ORPHEUS RESEARCH STATION  ·  DAY 153", 20, K.CYAN))
	v.add_child(K.spacer(14 if compact else 40))
	var first: Button = null
	if Game.has_save():
		# v1.5.0: with one save this continues it; with more, the same button opens the three-slot picker
		var many := Game.used_slot_count() > 1
		first = K.button("Load game" if many else "Continue", _slots_menu if many else func(): Game.active_slot = Game.latest_slot(); _continue())
		v.add_child(first)
		v.add_child(K.mono("    " + Game.save_info(), 18, K.DIM))
	var ng := K.button("New Game", _new_game_menu)
	v.add_child(ng)
	if first == null:
		first = ng
	v.add_child(K.button("How to play", func(): open_howto(false)))
	v.add_child(K.button("Settings", func(): open_settings("settings_menu")))
	v.add_child(K.button("Credits", _credits))
	if not Game.is_web and not Game.is_mobile:
		v.add_child(K.button("Exit", func(): get_tree().quit()))
	host.add_child(v)
	var foot := K.mono("v%s  ·  A game by Sonujeet Dhanki  ·  Made in India  ·  headphones recommended" % Game.VERSION, 18, K.DIM)
	foot.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	foot.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	foot.grow_vertical = Control.GROW_DIRECTION_BEGIN
	foot.offset_right = -40
	foot.offset_bottom = -24
	host.add_child(foot)
	first.grab_focus()

func _make_backdrop() -> void:
	if GameMode.world_root == null:
		return
	menu_backdrop = load("res://scripts/ui/menu_backdrop.gd").new()
	GameMode.world_root.add_child(menu_backdrop)

func _free_backdrop() -> void:
	if menu_backdrop and is_instance_valid(menu_backdrop):
		menu_backdrop.queue_free()
	menu_backdrop = null

func _continue() -> void:
	_clear_host()
	current = ""
	var ok: bool = await GameMode.continue_game()
	if not ok:
		toast("Save could not be loaded", 2.0)
		show_menu()

func _new_game_menu(slot: int = 0) -> void:
	_open("newgame")
	if slot <= 0:
		slot = Game.first_empty_slot()
	var v := K.vbox(12)
	v.add_child(K.label("NEW GAME", 56, K.WHITE, "Rajdhani-Bold"))
	# v1.5.0: which save slot the new game goes into
	v.add_child(K.mono("SAVE TO", 20, K.CYAN))
	var srow := K.hbox(10)
	for s in range(1, Game.SLOT_COUNT + 1):
		var txt := "Slot %d%s" % [s, " · replaces" if Game.slot_used(s) else " · empty"]
		if s == slot:
			txt = "[ " + txt + " ]"
		srow.add_child(K.button(txt, _new_game_menu.bind(s), 20, 240))
	v.add_child(srow)
	if Game.slot_used(slot):
		v.add_child(K.wrap(K.label("Slot %d's saved progress is replaced when you start." % slot, 24, K.AMBER), 640))
	v.add_child(K.mono("CHOOSE DIFFICULTY", 20, K.CYAN))
	var first: Button = null
	for d in [["story", "Story", "Enemies hit softer. For the narrative."], ["normal", "Normal", "The intended experience."], ["hard", "Hard", "Tougher enemies, scarcer cells."]]:
		var b := K.button(d[1] + "   —   " + d[2], func():
			Game.settings["difficulty"] = d[0]
			Game.save_settings()
			Game.active_slot = slot
			_start_new(), 26, 640)
		v.add_child(b)
		if d[0] == Game.settings["difficulty"]:
			first = b
	v.add_child(K.spacer(10))
	v.add_child(K.button("Back", show_menu, 26, 200))
	var p := K.panel()
	p.add_child(v)
	host.add_child(K.center(p))
	if first:
		first.grab_focus()

## v1.5.0: the load picker. Each slot shows its own progress; an empty slot cannot be picked.
func _slots_menu() -> void:
	_open("slots")
	var v := K.vbox(12)
	v.add_child(K.label("LOAD GAME", 56, K.WHITE, "Rajdhani-Bold"))
	v.add_child(K.mono("Three save slots, each with its own progress.", 20, K.DIM))
	var first: Button = null
	for s in range(1, Game.SLOT_COUNT + 1):
		var info := Game.slot_info(s)
		var b: Button
		if info == "":
			b = K.button("Slot %d   —   empty" % s, func(): pass, 26, 640)
			b.disabled = true
		else:
			b = K.button("Slot %d   —   %s" % [s, info], _load_slot.bind(s), 22, 800)
			if first == null:
				first = b
		v.add_child(b)
	v.add_child(K.spacer(10))
	v.add_child(K.button("Back", show_menu, 26, 200))
	var p := K.panel()
	p.add_child(v)
	host.add_child(K.center(p))
	if first:
		first.grab_focus()

func _load_slot(s: int) -> void:
	Game.active_slot = s
	_continue()

func _start_new() -> void:
	_clear_host()
	current = ""
	_free_backdrop()
	await GameMode.new_game()

func _credits() -> void:
	_open("credits")
	var v := K.vbox(10)
	v.add_child(K.label("CREDITS", 56, K.WHITE, "Rajdhani-Bold"))
	var txt := "ECHOES OF THE VOID — a game by Sonujeet Dhanki (Mumbai, India), built with AI.\n\n" \
		+ "Engine: Godot Engine %s (MIT licence).\n" % Engine.get_version_info()["string"].split(" ")[0] \
		+ "Characters, creatures, weapons and the facility kit: modelled and animated in Blender for this game.\n" \
		+ "Surface textures: ambientCG (CC0). Fonts: Rajdhani and Share Tech Mono (SIL Open Font Licence).\n" \
		+ "Voices, sound effects, ambience and music: generated and mastered for this game.\n\n" \
		+ "The crew of ORPHEUS Station — Kabir Rao, Leela Iyer, Marcus Hale, Tomasz Wren, Nadia Okoye, Sam Ortega — are fictional.\n" \
		+ "Full asset list: CREDITS.md."
	v.add_child(K.wrap(K.label(txt, 26, K.WHITE), 1100))
	v.add_child(K.button("Back", show_menu, 26, 200))
	var p := K.panel()
	p.add_child(v)
	host.add_child(K.center(p))


# ---------------------------------------------------------------- how to play
const HOWTO := {
	"GOAL": "You are Specialist Kabir Rao. You wake from cryosleep on ORPHEUS Research Station, on the alien world NYX-7. The crew is gone and something is broadcasting from the black Spire outside.\n\n• Follow the OBJECTIVE at the top left. It always tells you what to do next.\n• Explore 6 areas: Cryo Chamber, Research Wing, Security Sector, Reactor Core, the Alien Exterior and the Extraction Zone.\n• Solve 3 puzzles: restart the generators in the right order, find the security code, and rotate the conduits to route power.\n• Explore The Hollows, a crystal basin west of the canyon, where the signal leads.\n• Survive the Echo, reach the shuttle and defeat the Herald to escape.\n\nUPGRADE BENCH: spend the parts you find to improve your weapons and suit.\nSAVE SLOTS: there are three. Pick one from the main menu to start or continue.\nThe game saves at every checkpoint (you will see the save icon). You can also save from the pause menu.",
	"TOUCH": "LEFT SIDE: drag anywhere to move (a stick appears under your thumb). Push it far to walk faster.\nRIGHT SIDE: drag to look around.\n\nFIRE (big button): shoot. MELEE (button): a short strike at close range, and a finishing move on a staggered enemy. Hold for the rifle's automatic fire, and slide your thumb on it to keep aiming while you shoot.\nAIM: tap to aim over the shoulder (tap again to lower). Aiming is more accurate.\nRELOAD · JUMP · CROUCH: as named. Crouch to sneak past enemies and under low beams.\nUSE: open doors, press panels, read logs, pick things up (shown when you are close).\nSWAP: switch between the Pulse Rifle and the Energy Pistol.\nMED: use a medkit.  RUN: toggle sprint.\nTop right: LAMP (helmet lights), LOGS (objectives and research logs), II (pause).\n\nAndroid back button = pause. Aim assist helps on touch and can be changed in Settings.",
	"KEYBOARD": "KEYBOARD & MOUSE\n{move} move · Mouse look · {sprint} sprint · {jump} jump · {crouch} crouch\nRight mouse aim · Left mouse fire · {reload} reload · {w1} / {w2} or mouse wheel: weapons\n{use} use · {med} medkit · {lamp} helmet lamp · {shoulder} swap shoulder · {logs} logs · Esc pause\n{melee} melee strike (close range, and finishes a staggered enemy)\n{closer} / {farther}, Ctrl + wheel or pinch: camera distance\nHold Enter to skip a cutscene.\n\nGAMEPAD\nLeft stick move · Right stick look · LT aim · RT fire · RB reload\nA jump · B crouch · X use · Y switch weapon · LB medkit\nClick left stick sprint · D-pad up lamp · View logs · Menu pause",
	"HUD": "TOP LEFT: your current mission and objective.\nBOTTOM LEFT: VITALS (health, red) and STAMINA (blue). Sprinting uses stamina; it refills when you slow down. When health is low the screen pulses red: use a medkit.\nBOTTOM RIGHT: weapon name, ammo in the magazine / reserve ammo, and medkits.\nCENTRE: the crosshair. It flashes on a hit and turns red on a weak-point hit.\nRed marks at the screen edge show where damage came from.\nBOTTOM CENTRE: subtitles for voices and logs, and the USE prompt when you can interact.\nTOP CENTRE in the final battle: the Herald's health.",
	"ENEMIES": "STALKER: fast four-legged hunter. It screeches, then lunges. Back off or side-step when it crouches, then shoot. Its glowing head is the weak point.\n\nSENTINEL: an infected security trooper with a crystal cannon arm. It hides at range and fires charged bolts. Watch for the violet glow as it charges and get behind cover. Shoot the glowing chest core.\n\nBRUTE: huge and slow, but it hits very hard. It raises both arms before a ground slam and roars before it charges. Dodge sideways, then shoot the glowing crystals on its BACK (weak point).\n\nTHE HERALD: the final boss. Destroy its 3 glowing cyan nodes. Its attacks show a warning first: SLAM draws a red ring on the ground, so leave the ring before it lands. SWEEP shows a glowing maw, so sidestep or break line of sight before the beam fires. Shard rain marks the ground in purple first.",
	"TIPS": "• Read the logs. They hold the clues for the puzzles (the generator order and the security code).\n• Aim for glowing weak points: they take much more damage.\n• Ammo stations and pickups refill you. The pistol is accurate and has more reserve ammo; save rifle ammo for big fights.\n• Melee is short range and cheap on ammo. Stagger an enemy, then finish it up close.\n• Crouching makes you quieter. Enemies can hear running and gunfire.\n• Too hard? Switch to STORY difficulty in Settings at any time.\n• Things too small or too big? Change the Interface size in Settings.\n• Play with headphones for the full atmosphere.",
}

## A How to Play page with the CURRENT key bindings filled in (they follow Settings > Change keys).
func howto_text(page: String) -> String:
	var t: String = HOWTO[page]
	return t.format({"move": Game.move_keys(), "sprint": Game.key_name("sprint"), "jump": Game.key_name("jump"),
		"crouch": Game.key_name("crouch"), "reload": Game.key_name("reload"), "w1": Game.key_name("weapon_1"),
		"w2": Game.key_name("weapon_2"), "use": Game.key_name("interact"), "med": Game.key_name("medkit"),
		"lamp": Game.key_name("lamp"), "shoulder": Game.key_name("shoulder_swap"), "logs": Game.key_name("journal"),
		"closer": Game.key_name("cam_closer"), "farther": Game.key_name("cam_farther"), "melee": Game.key_name("melee")})

func open_howto(from_pause: bool = false, page: String = "GOAL") -> void:
	_open("howto_pause" if from_pause else "howto")
	var vps := get_viewport().get_visible_rect().size
	var w := minf(1500.0, vps.x - 140.0)
	var v := K.vbox(14)
	v.add_child(K.label("HOW TO PLAY", 52, K.WHITE, "Rajdhani-Bold"))
	var tabs := K.hbox(10)
	var pages := ["GOAL", "TOUCH", "KEYBOARD", "HUD", "ENEMIES", "TIPS"]
	if Game.touch_enabled():
		pass
	var first: Button = null
	for pg in pages:
		var b := K.button(("KEYS / PAD" if pg == "KEYBOARD" else pg), func(): open_howto(from_pause, pg), 28, minf(200.0, (w - 60.0) / pages.size()))
		if pg == page:
			b.add_theme_color_override("font_color", K.CYAN)
			first = b
		tabs.add_child(b)
	v.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(w, clampf(vps.y - 330.0, 260.0, 640.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var body := K.wrap(K.label(howto_text(page), 30, K.WHITE), w - 40.0)
	scroll.add_child(body)
	v.add_child(scroll)
	var back := K.button("Back", func():
		if from_pause:
			pause()
		else:
			show_menu(), 28, 220)
	v.add_child(back)
	var p := K.panel()
	p.add_child(v)
	host.add_child(K.center(p))
	if first:
		first.grab_focus()

# ---------------------------------------------------------------- settings
func open_settings(name: String) -> void:
	_open(name)
	var s := Game.settings
	var root := K.vbox(10)
	root.add_child(K.label("SETTINGS", 52, K.WHITE, "Rajdhani-Bold"))
	var scroll := ScrollContainer.new()
	var vps := get_viewport().get_visible_rect().size
	scroll.custom_minimum_size = Vector2(minf(1000.0, vps.x - 120.0), clampf(vps.y - 300.0, 300.0, 620.0))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 40)
	g.add_theme_constant_override("v_separation", 14)
	scroll.add_child(g)
	root.add_child(scroll)
	_section(g, "GRAPHICS")
	var qopts := ["low", "medium", "high", "ultra"] if not Game.is_mobile else ["mobile", "low", "medium"]
	if Game.is_web and not Game.is_mobile:
		qopts = ["low", "web", "high"]
	_option(g, "Quality", qopts, s["quality"], func(v):
		s["quality"] = v
		_apply())
	_slider_row(g, "Render scale", s["render_scale"], 0.5, 1.0, 0.05, func(v):
		s["render_scale"] = v
		_apply())
	_option(g, "Interface size", ["auto", "normal", "large", "x-large", "huge"], s.get("ui_size", "auto"), func(v):
		s["ui_size"] = v
		_apply()
		open_settings(name))
	_slider_row(g, "Field of view", s["fov"], 55.0, 95.0, 1.0, func(v):
		s["fov"] = v
		_apply())
	if not Game.is_mobile and not Game.is_web:
		_toggle(g, "Fullscreen", s["fullscreen"], func(v):
			s["fullscreen"] = v
			_apply())
		_toggle(g, "V-Sync", s["vsync"], func(v):
			s["vsync"] = v
			_apply())
		_option(g, "Resolution (windowed)", Game.RESOLUTIONS, s.get("resolution", "1600x900"), func(v):
			s["resolution"] = v
			_apply())
	_section(g, "AUDIO")
	for k in [["master", "Master volume"], ["music", "Music"], ["sfx", "Effects"], ["voice", "Voices"]]:
		var key: String = k[0]
		_slider_row(g, k[1], s[key], 0.0, 1.0, 0.05, func(v):
			s[key] = v
			_apply())
	_section(g, "CONTROLS")
	_slider_row(g, "Look sensitivity", s["sensitivity"], 0.2, 3.0, 0.05, func(v):
		s["sensitivity"] = v
		_apply())
	_toggle(g, "Invert look Y", s["invert_y"], func(v):
		s["invert_y"] = v
		_apply())
	_toggle(g, "Aim assist (touch/controller)", s["aim_assist"], func(v):
		s["aim_assist"] = v
		_apply())
	_option(g, "Touch controls", ["auto", "on", "off"], s["touch"], func(v):
		s["touch"] = v
		_apply()
		touch.visible = GameMode.in_game and Game.touch_enabled()
		relayout_hud())
	_slider_row(g, "Camera distance", s.get("cam_distance", 1.0), 0.7, 1.5, 0.05, func(v):
		s["cam_distance"] = v
		_apply())
	_slider_row(g, "Camera shake", s["camera_shake"], 0.0, 1.0, 0.1, func(v):
		s["camera_shake"] = v
		_apply())
	if not Game.is_mobile:
		g.add_child(K.label("Key bindings", 26))
		g.add_child(K.button("Change keys…", func(): open_bindings(name), 22, 260))
	_section(g, "GAMEPLAY")
	_option(g, "Difficulty", ["story", "normal", "hard"], s["difficulty"], func(v):
		s["difficulty"] = v
		_apply()
		if GameMode.player:
			GameMode.player.health.dmg_mult = Game.diff("dmg_taken"))
	_toggle(g, "Subtitles", s["subtitles"], func(v):
		s["subtitles"] = v
		_apply())
	_option(g, "Subtitle size", ["small", "medium", "large"], str(s.get("subtitle_size", "medium")), func(v):
		s["subtitle_size"] = v
		_apply())
	_toggle(g, "Subtitle background", bool(s.get("subtitle_bg", false)), func(v):
		s["subtitle_bg"] = v
		_apply())
	_toggle(g, "Reduce motion (less shake, no hit slow-motion)", bool(s.get("reduce_motion", false)), func(v):
		s["reduce_motion"] = v
		_apply())
	_toggle(g, "Vibration (phone and controller)", bool(s.get("vibration", true)), func(v):
		s["vibration"] = v
		_apply())
	_option(g, "Frame rate cap", ["30", "60", "120", "unlimited"], "unlimited" if int(s.get("frame_cap", 0)) == 0 else str(int(s.get("frame_cap", 0))), func(v):
		s["frame_cap"] = 0 if v == "unlimited" else int(v)
		_apply())
	_toggle(g, "Show FPS", bool(s.get("show_fps", false)), func(v):
		s["show_fps"] = v
		_apply())
	if not Game.is_mobile:
		root.add_child(K.wrap(K.mono(Game.keys_line(), 16, K.DIM), minf(1000.0, vps.x - 160.0)))
	var back := K.button("Back", func():
		if name == "settings_pause":
			pause()
		else:
			show_menu(), 26, 200)
	root.add_child(back)
	var p := K.panel()
	p.add_child(root)
	host.add_child(K.center(p))
	back.grab_focus()

## FPS / frame time / GPU / preset, refreshed twice a second while Settings > Show FPS is on.
func _update_fps(delta: float) -> void:
	if fps_lbl == null:
		return
	fps_lbl.visible = bool(Game.settings.get("show_fps", false))
	if not fps_lbl.visible:
		return
	_fps_t -= delta
	if _fps_t > 0.0:
		return
	_fps_t = 0.5
	var fps := Engine.get_frames_per_second()
	fps_lbl.text = "%d FPS  ·  %.1f ms  ·  %s  ·  %s  ·  %s" % [fps, 1000.0 / maxf(fps, 1.0),
		RenderingServer.get_video_adapter_name(), RenderingServer.get_current_rendering_method(), str(Game.settings["quality"]).to_upper()]

func _apply() -> void:
	Game.apply_settings()
	Game.save_settings()

# ---------------------------------------------------------------- key bindings
var _rebind_action := ""
var _rebind_back := ""
func open_bindings(back_to: String) -> void:
	_open("bindings")
	_rebind_back = back_to
	var root := K.vbox(10)
	root.add_child(K.label("KEY BINDINGS", 52, K.WHITE, "Rajdhani-Bold"))
	root.add_child(K.mono("Click an action, then press the new key. Esc cancels. Mouse: LMB fire · RMB aim · wheel switches weapons.", 18, K.DIM))
	var scroll := ScrollContainer.new()
	var vps := get_viewport().get_visible_rect().size
	scroll.custom_minimum_size = Vector2(minf(820.0, vps.x - 120.0), clampf(vps.y - 330.0, 260.0, 600.0))
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 40)
	g.add_theme_constant_override("v_separation", 8)
	scroll.add_child(g)
	root.add_child(scroll)
	var first: Button = null
	for pair in Game.REBINDABLE:
		var action: String = pair[0]
		g.add_child(K.label(pair[1], 24))
		var label := "[ press a key ]" if _rebind_action == action else OS.get_keycode_string(Game.binding_of(action))
		var b := K.button(label, func():
			_rebind_action = action
			open_bindings(back_to), 22, 240)
		g.add_child(b)
		if first == null or _rebind_action == action:
			first = b
	var row := K.hbox(16)
	row.add_child(K.button("Reset to defaults", func():
		_rebind_action = ""
		Game.reset_bindings()
		open_bindings(back_to), 22, 260))
	var back := K.button("Back", func():
		_rebind_action = ""
		open_settings(back_to), 24, 200)
	row.add_child(back)
	root.add_child(row)
	var p := K.panel()
	p.add_child(root)
	host.add_child(K.center(p))
	(first if first else back).grab_focus()

func _input(event: InputEvent) -> void:
	if _rebind_action == "" or current != "bindings":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		var k: int = (event as InputEventKey).physical_keycode
		var action := _rebind_action
		_rebind_action = ""
		if k != KEY_ESCAPE and k != 0:
			Game.set_binding(action, k)
		open_bindings(_rebind_back)

func _section(g: GridContainer, title: String) -> void:
	g.add_child(K.mono(title, 20, K.CYAN))
	g.add_child(K.spacer(1))

func _slider_row(g: GridContainer, title: String, value: float, mn: float, mx: float, step: float, cb: Callable) -> void:
	g.add_child(K.label(title, 26))
	var h := K.hbox(10)
	var val := K.mono(_fmt(value, step), 20, K.WHITE)
	var sl := K.slider(value, mn, mx, step, func(v):
		val.text = _fmt(v, step)
		cb.call(v))
	h.add_child(sl)
	h.add_child(val)
	g.add_child(h)

func _fmt(v: float, step: float) -> String:
	return str(int(v)) if step >= 1.0 else "%d%%" % int(round(v * 100.0)) if step < 0.2 else "%.1f" % v

func _toggle(g: GridContainer, title: String, value: bool, cb: Callable) -> void:
	g.add_child(K.label(title, 26))
	var c := CheckButton.new()
	c.button_pressed = value
	c.toggled.connect(cb)
	c.custom_minimum_size = Vector2(80, 40)
	g.add_child(c)

func _option(g: GridContainer, title: String, opts: Array, value: String, cb: Callable) -> void:
	g.add_child(K.label(title, 26))
	var o := OptionButton.new()
	for i in opts.size():
		o.add_item(str(opts[i]).capitalize(), i)
		if opts[i] == value:
			o.select(i)
	o.add_theme_font_size_override("font_size", 24)
	o.custom_minimum_size = Vector2(260, 44)
	o.item_selected.connect(func(i): cb.call(opts[i]))
	g.add_child(o)

# ---------------------------------------------------------------- journal
func open_journal(from_pause: bool = false) -> void:
	if not from_pause:
		get_tree().paused = true
	else:
		get_tree().paused = true
	_open("journal_pause" if from_pause else "journal")
	var root := K.vbox(10)
	root.add_child(K.label(Missions.mission_title(Game.state["mission"]), 44, K.WHITE, "Rajdhani-Bold"))
	root.add_child(K.label("▸ " + Missions.objective_text(), 28, K.CYAN))
	root.add_child(_inventory_block())
	root.add_child(K.mono("RESEARCH LOGS  %d / %d" % [Game.state["logs"].size(), GameData.logs().size()], 20, K.DIM))
	var h := K.hbox(30)
	var list := K.vbox(6)
	var ls := ScrollContainer.new()
	ls.custom_minimum_size = Vector2(460, clampf(get_viewport().get_visible_rect().size.y - 560.0, 180.0, 420.0))
	ls.add_child(list)
	h.add_child(ls)
	var right := K.vbox(10)
	var title := K.label("", 32, K.WHITE, "Rajdhani-Bold")
	var who := K.mono("", 20, K.CYAN)
	var body := K.wrap(K.label("Select a log.", 26, K.WHITE), 720)
	right.add_child(title)
	right.add_child(who)
	right.add_child(body)
	var play := K.button("▶  Play recording", func(): pass, 24, 300)
	play.visible = false
	right.add_child(play)
	h.add_child(right)
	root.add_child(h)
	var first: Button = null
	for id in Game.state["logs"]:
		var info := GameData.log_info(int(id))
		var b := K.button("%02d  %s" % [int(id), info.get("title", "")], func():
			title.text = info.get("title", "")
			who.text = str(info.get("name", ""))
			body.text = info.get("text", "")
			play.visible = true
			for c in play.pressed.get_connections():
				play.pressed.disconnect(c["callable"])
			play.pressed.connect(func(): Sfx.say("log%02d" % int(id), true)), 22, 440)
		list.add_child(b)
		if first == null:
			first = b
	if Game.state["logs"].is_empty():
		list.add_child(K.mono("No logs found yet.", 20, K.DIM))
	var close := K.button("Back", func():
		if from_pause:
			pause()
		else:
			_close_to_game(), 24, 200)
	root.add_child(close)
	var p := K.panel()
	p.add_child(root)
	host.add_child(K.center(p))
	if first:
		first.grab_focus()
	else:
		close.grab_focus()

## Inventory (Post-PRD 4.5): resources, key items and mission objects, read live from the player and the story flags.
func _inventory_block() -> Control:
	var h := K.hbox(48)
	var p: Player = GameMode.player
	var inv: InventoryComponent = p.inventory if p else null
	# v1.5.0: four categories (was three): WEAPONS (with upgrade levels), SUPPLIES (cells, medkits, upgrade parts),
	# KEY ITEMS, MISSION OBJECTS
	var cols := [["WEAPONS", []], ["SUPPLIES", []], ["KEY ITEMS", []], ["MISSION OBJECTS", []]]
	if inv:
		var labels := {"rifle": "Pulse rifle", "pistol": "Energy pistol", "shotgun": "Scatter shotgun", "precision": "Precision rifle", "breach": "Breach cannon"}
		for w in ["rifle", "pistol", "shotgun", "precision", "breach"]:
			if inv.has_weapon(w):
				var mag := 0
				if p.combat.weapons.has(w):
					mag = int(p.combat.weapons[w].mag)
				var ammo_key: String = {"shotgun": "pistol", "precision": "rifle", "breach": "rifle"}.get(w, w)     # shared cells
				cols[0][1].append("%s   %d + %d" % [labels[w], mag, int(inv.reserve.get(ammo_key, 0))])
				var lv := Upgrades.levels(w)
				cols[0][1].append("   dmg %d/3 · reload %d/3 · mag %d/3 · acc %d/3" % [lv["damage"], lv["reload"], lv["magazine"], lv["accuracy"]])
		cols[1][1].append("Cells   %d pistol · %d rifle" % [int(inv.reserve.get("pistol", 0)), int(inv.reserve.get("rifle", 0))])
		cols[1][1].append("Medkits   %d / %d" % [inv.medkits, InventoryComponent.MAX_MEDKITS])
		cols[1][1].append("Upgrade parts   %d" % inv.parts)
		for w in inv.weapons:
			if w == "pistol" or w == "rifle":
				cols[2][1].append("M7 Pulse Rifle" if w == "rifle" else "EP-2 Energy Pistol")
		for k in inv.keycards:
			cols[2][1].append("Keycard: " + str(k).capitalize())
		cols[2][1].append("Suit lamp")
	var objs := [["used.log.5", "Dr. Iyer's research data"], ["puzzle.generators", "Emergency power restored"],
		["puzzle.security_code", "Security override code 0417"], ["comms.restored", "Comms uplink online"],
		["puzzle.conduits", "Reactor stabilized"], ["transmission.sent", "Warning transmitted"]]
	for o in objs:
		if Game.flag(o[0]):
			cols[3][1].append(o[1])
	for c in cols:
		var v := K.vbox(4)
		v.add_child(K.mono(c[0], 18, K.CYAN))
		if (c[1] as Array).is_empty():
			v.add_child(K.mono("—", 18, K.DIM))
		for line in c[1]:
			if (line as String).begins_with("   "):
				v.add_child(K.mono(line, 16, K.DIM))
			else:
				v.add_child(K.label(line, 22, K.WHITE))
		h.add_child(v)
	return h

# ---------------------------------------------------------------- v1.5.0: upgrade bench
var _bench_player: Player = null
const _WEAPON_NAMES := {"rifle": "Pulse rifle", "pistol": "Energy pistol", "shotgun": "Scatter shotgun", "precision": "Precision rifle", "breach": "Breach cannon"}

func open_bench(p: Player) -> void:
	_bench_player = p
	_bench_draw()

func _bench_draw() -> void:
	var p := _bench_player
	_open("bench")
	var v := K.vbox(10)
	v.add_child(K.label("UPGRADE BENCH", 48, K.WHITE, "Rajdhani-Bold"))
	v.add_child(K.mono("UPGRADE PARTS   %d" % p.inventory.parts, 22, K.AMBER))
	v.add_child(K.mono("One part per level, three levels per stat.", 18, K.DIM))
	var first: Button = null
	for w in ["pistol", "rifle", "shotgun", "precision", "breach"]:
		if not p.inventory.has_weapon(w):
			continue
		v.add_child(K.mono(str(_WEAPON_NAMES[w]), 22, K.CYAN))
		var row := K.hbox(8)
		for stat in Upgrades.STATS:
			var lv := Upgrades.level(w, stat)
			var b := K.button("%s %d/3%s" % [str(stat).capitalize(), lv, "" if lv >= Upgrades.MAX_LEVEL else "  +1"], _bench_buy.bind(w, stat), 18, 170)
			b.disabled = lv >= Upgrades.MAX_LEVEL or p.inventory.parts < Upgrades.COST
			row.add_child(b)
			if first == null and not b.disabled:
				first = b
		v.add_child(row)
	v.add_child(K.button("Close", _close_to_game, 22, 380))
	var pnl := K.panel()
	pnl.add_child(v)
	host.add_child(K.center(pnl))
	if first:
		first.grab_focus()

func _bench_buy(w: String, stat: String) -> void:
	var p := _bench_player
	if p == null:
		return
	if Upgrades.buy(p.inventory, w, stat):
		p.combat.refresh_upgrades(w)
		Sfx.play("item_pickup", -4.0)
		Events.message.emit("%s upgraded: %s" % [_WEAPON_NAMES[w], stat], 1.6)
	else:
		Events.message.emit("Needs an upgrade part", 1.4)
	_bench_draw()

# ---------------------------------------------------------------- death
func show_death() -> void:
	_open("death")
	Sfx.sting("sting_death", -2.0)
	var v := K.vbox(14)
	v.add_child(K.label("SIGNAL LOST", 84, K.RED, "Rajdhani-Bold"))
	v.add_child(K.mono("SPECIALIST RAO — VITALS FLATLINED", 22, K.DIM))
	v.add_child(K.spacer(20))
	var r := K.button("Retry from checkpoint", func():
		_clear_host()
		current = ""
		GameMode.restart_checkpoint())
	v.add_child(r)
	v.add_child(K.button("Main menu", func():
		_clear_host()
		current = ""
		GameMode.to_menu()))
	var p := K.panel()
	p.add_child(v)
	host.add_child(K.center(p))
	r.grab_focus()

# ---------------------------------------------------------------- keypad
func open_keypad(k: Keypad) -> void:
	_keypad_target = k
	_keypad_entry = ""
	_open("keypad")
	var v := K.vbox(12)
	v.add_child(K.mono("SECURITY SECTOR — LOCKDOWN", 22, K.AMBER))
	v.add_child(K.mono(k.hint, 20, K.DIM))
	_keypad_disp = K.label("_ _ _ _", 72, K.WHITE, "ShareTechMono-Regular")
	_keypad_disp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_keypad_disp)
	var g := GridContainer.new()
	g.columns = 3
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	var first: Button = null
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "CLR", "0", "OK"]:
		var b := K.button(key, func(): _keypad_press(key), 34, 120)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.name = "Key_" + key
		g.add_child(b)
		if first == null:
			first = b
	v.add_child(g)
	v.add_child(K.button("Close", _close_to_game, 22, 380))
	var p := K.panel()
	p.add_child(v)
	host.add_child(K.center(p))
	first.grab_focus()

func _keypad_press(key: String) -> void:
	if _keypad_target == null:
		return
	Sfx.ui("keypad_beep", -6.0)
	if key == "CLR":
		_keypad_entry = ""
	elif key == "OK":
		if _keypad_entry.length() == 4:
			if _keypad_target.submit(_keypad_entry):
				_keypad_disp.text = "ACCEPTED"
				_keypad_disp.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
				await get_tree().create_timer(0.8, true).timeout
				_close_to_game()
				return
			else:
				_keypad_disp.text = "DENIED"
				_keypad_disp.add_theme_color_override("font_color", K.RED)
				_keypad_entry = ""
				await get_tree().create_timer(0.7, true).timeout
				_keypad_disp.add_theme_color_override("font_color", K.WHITE)
	elif _keypad_entry.length() < 4:
		_keypad_entry += key
	var shown := ""
	for i in 4:
		shown += (_keypad_entry[i] if i < _keypad_entry.length() else "_") + (" " if i < 3 else "")
	if current == "keypad":
		_keypad_disp.text = shown

## Test hook: type a code into an open keypad.
func keypad_type(code: String) -> void:
	for c in code:
		_keypad_press(c)
	_keypad_press("OK")

# ---------------------------------------------------------------- conduit board
func open_conduits(c: ConduitConsole) -> void:
	_conduit_target = c
	_open("conduits")
	var v := K.vbox(12)
	v.add_child(K.label("REACTOR POWER ROUTING", 40, K.AMBER, "Rajdhani-Bold"))
	v.add_child(K.wrap(K.mono("Tap a conduit to rotate it. Route power from the CORE to the UPLINK. Keep the SPIRE FEED outlets dark.", 20, K.DIM), 900))
	_conduit_canvas = load("res://scripts/ui/conduit_view.gd").new()
	_conduit_canvas.board = c.board
	_conduit_canvas.custom_minimum_size = Vector2(900, 560)
	_conduit_canvas.solved.connect(func():
		c.on_board_solved()
		await get_tree().create_timer(1.2, true).timeout
		if current == "conduits":
			_close_to_game())
	v.add_child(_conduit_canvas)
	var h := K.hbox(12)
	h.add_child(K.button("Reset", func():
		c.board.scramble(7)
		_conduit_canvas.queue_redraw(), 22, 200))
	h.add_child(K.button("Close", _close_to_game, 22, 200))
	v.add_child(h)
	var p := K.panel()
	p.add_child(v)
	host.add_child(K.center(p))

# ---------------------------------------------------------------- title card & end credits
func show_title(lines: Array, secs: float = 5.0) -> void:
	var v := K.vbox(6)
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-600, -80)
	v.custom_minimum_size.x = 1200
	for i in lines.size():
		var l := K.label(str(lines[i]), 64 if i == 0 else 28, K.WHITE if i == 0 else K.CYAN, "Rajdhani-Bold" if i == 0 else "ShareTechMono-Regular")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size.x = 1200
		v.add_child(l)
	v.modulate.a = 0.0
	add_child(v)
	var tw := create_tween()
	tw.tween_property(v, "modulate:a", 1.0, 1.2)
	tw.tween_interval(maxf(0.5, secs - 2.4))
	tw.tween_property(v, "modulate:a", 0.0, 1.2)
	tw.tween_callback(v.queue_free)

func show_end_credits() -> void:
	GameMode.in_game = false
	hud_visible(false)
	_open("end_credits")
	Sfx.set_music_mode("ending")
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(bg)
	fade.color.a = 0.0
	var st: Dictionary = Game.state["stats"]
	var t := int(st.get("time", 0.0))
	var lines := [
		["ECHOES OF THE VOID", 96, K.WHITE], ["", 30, K.WHITE],
		["Specialist Kabir Rao's warning reached the Earth relay.", 30, K.DIM],
		["Nobody answered.", 30, K.DIM], ["", 60, K.WHITE],
		["TIME  %d:%02d   ·   KILLS  %d   ·   LOGS  %d / %d   ·   DEATHS  %d" % [t / 60, t % 60, int(st.get("kills", 0)), Game.state["logs"].size(), GameData.logs().size(), int(st.get("deaths", 0))], 26, K.CYAN],
		["", 80, K.WHITE],
		["A GAME BY", 24, K.CYAN], ["Sonujeet Dhanki", 44, K.WHITE], ["Mumbai, India", 26, K.DIM], ["", 50, K.WHITE],
		["DESIGN DOCUMENT", 24, K.CYAN], ["Sonujeet Dhanki", 34, K.WHITE], ["", 40, K.WHITE],
		["BUILT WITH", 24, K.CYAN], ["Tab — design, code, levels, art, animation, audio", 30, K.WHITE], ["", 40, K.WHITE],
		["ENGINE", 24, K.CYAN], ["Godot Engine (MIT licence)", 30, K.WHITE], ["", 40, K.WHITE],
		["3D MODELS & ANIMATION", 24, K.CYAN], ["made in Blender for this game", 30, K.WHITE], ["", 40, K.WHITE],
		["MUSIC · VOICES · SOUND", 24, K.CYAN], ["generated and mastered for this game", 30, K.WHITE], ["", 40, K.WHITE],
		["TEXTURES", 24, K.CYAN], ["ambientCG (CC0)", 30, K.WHITE], ["", 40, K.WHITE],
		["FONTS", 24, K.CYAN], ["Rajdhani · Share Tech Mono (SIL OFL)", 30, K.WHITE], ["", 40, K.WHITE],
		["THE CREW OF ORPHEUS STATION", 24, K.CYAN],
		["Kabir Rao · Leela Iyer · Marcus Hale · Tomasz Wren · Nadia Okoye · Sam Ortega", 28, K.WHITE], ["", 40, K.WHITE],
		["MIRA", 24, K.CYAN], ["kept the lights on", 30, K.WHITE], ["", 120, K.WHITE],
		["Thank you for playing.", 40, K.WHITE],
	]
	var v := K.vbox(4)
	for l in lines:
		var lab := K.label(l[0], l[1], l[2], "Rajdhani-Bold" if l[1] >= 40 else "Rajdhani-SemiBold")
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.custom_minimum_size = Vector2(1600, l[1] + 6)
		v.add_child(lab)
	host.add_child(v)
	var vp := get_viewport().get_visible_rect().size
	v.position = Vector2((vp.x - 1600) * 0.5, vp.y)
	await get_tree().process_frame
	if not is_instance_valid(v):
		return
	var h := v.size.y
	var dur := 48.0 if Game.test_mode == "" else 2.0
	var tw := create_tween()
	tw.tween_property(v, "position:y", vp.y * 0.5 - h + 60.0, dur)
	await tw.finished
	if current != "end_credits":
		return
	var b := K.button("Main menu", func():
		_free_backdrop()
		GameMode.to_menu(), 28, 260)
	b.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	b.position = Vector2(-130, -140)
	host.add_child(b)
	b.grab_focus()
