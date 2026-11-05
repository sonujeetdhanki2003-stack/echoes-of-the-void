extends Node
## UI layout audit (v1.0.1): measures control rects at phone sizes. --driver=ui_layout2
## HUD pieces and touch buttons must not overlap each other and must stay on screen; every menu panel must fit.
var bad := 0
var checks := 0

func _ready() -> void:
	await get_tree().process_frame
	Game.new_state()
	Game.state["flags"]["cine.wake"] = true
	Game.settings["touch"] = "on"
	Game.apply_settings()
	await GameMode.load_area("cryo", "cryo_hub", true)
	var ui = GameMode.ui
	# NOTE: the UI scales with canvas_items stretch from a 1920x1080 base, so only the ASPECT RATIO changes the layout:
	# 2400x1080 and 1600x720 (20:9 phones) are the same logical layout. Sizes below are one per aspect; every one is
	# measured after the viewport actually changed (the visible rect is printed).
	var sizes := [Vector2i(2400, 1080), Vector2i(1600, 720), Vector2i(1920, 1080), Vector2i(1024, 768), Vector2i(2340, 1080)]
	for t in ["on", "off"]:
		Game.settings["touch"] = t
		for sz in sizes:
			get_window().size = sz
			Game.apply_settings()
			for i in 4:
				await get_tree().process_frame
			print("SIZE ", sz, " touch=", t, " visible ", _vr(ui).size)
			await _hud(ui, sz, t)
			await _panels(ui, sz, t)
	print("UILAYOUT2 %d checks, %d problems" % [checks, bad])
	get_tree().quit(0 if bad == 0 else 1)

func _vr(ui) -> Rect2:
	return ui.get_viewport().get_visible_rect()

func _prob(msg: String) -> void:
	bad += 1
	print("  PROBLEM ", msg)

func _hud(ui, sz: Vector2i, mode: String) -> void:
	ui.hud_visible(true)
	ui.relayout_hud()
	ui.fps_lbl.visible = false
	# a worst-case HUD: long objective, interaction prompt, toast, boss bar, saving icon, subtitle
	ui.obj_title.text = "04 — FINAL EXTRACTION"
	ui.obj_lbl.text = "Security access: find the override code and use the gate terminal"
	ui.prompt_box.visible = true
	ui.prompt_lbl.text = "USE  Open the weapons locker"
	ui.toast_lbl.text = "Progress saved"
	ui.toast_lbl.modulate.a = 1.0
	ui.boss_box.visible = true
	ui.boss_lbl.text = "THE HERALD"
	ui.save_icon.modulate.a = 1.0
	Events.subtitle.emit("MIRA", "This is the Orpheus relay. If anyone can hear this, the signal is still going out. Whatever happened down there, we're coming. Hold on, we are almost in range.", 30.0)
	for i in 6:
		await get_tree().process_frame
	var vr := _vr(ui)
	var tag := "%s touch=%s" % [str(sz), mode]
	var items := {}
	items["vitals"] = ui.hud_vit.get_global_rect()
	items["objective"] = ui.hud_ob.get_global_rect()
	items["ammo"] = ui.hud_am.get_global_rect()
	items["prompt"] = ui.prompt_box.get_global_rect()
	items["toast"] = _text_rect(ui.toast_lbl)
	items["boss"] = ui.boss_box.get_global_rect()
	items["saving"] = ui.save_icon.get_global_rect()
	items["subtitle"] = ui.sub_box.get_global_rect()
	if mode == "on":
		for b in ui.touch.find_children("Touch_*", "Control", true, false):
			if (b as Control).visible:
				items[b.name] = (b as Control).get_global_rect()
	var names := items.keys()
	for n in names:
		var r: Rect2 = items[n]
		checks += 1
		if not vr.grow(1.0).encloses(r):
			_prob("%s: %s %s is off screen (viewport %s)" % [tag, n, r, vr.size])
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Rect2 = items[names[i]]
			var b: Rect2 = items[names[j]]
			checks += 1
			# the interaction prompt / toast / boss bar / saving icon / subtitles are transient and centred: they must
			# still keep clear of everything that is always there
			if a.grow(-2.0).intersects(b.grow(-2.0)):
				_prob("%s: %s %s overlaps %s %s" % [tag, names[i], a, names[j], b])
	Events.subtitle.emit("", "", 0.0)
	ui.prompt_box.visible = false
	ui.boss_box.visible = false
	ui.save_icon.modulate.a = 0.0
	ui.toast_lbl.modulate.a = 0.0

func _text_rect(l: Label) -> Rect2:
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var w := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var r := l.get_global_rect()
	var cx := r.position.x + r.size.x * 0.5
	return Rect2(cx - w * 0.5, r.position.y, w, r.size.y)

func _panels(ui, sz: Vector2i, mode: String) -> void:
	var tag := "%s touch=%s" % [str(sz), mode]
	var vr := _vr(ui)
	var opens := {
		"pause": func(): ui.pause(),
		"settings(pause)": func(): ui.open_settings("settings_pause"),
		"howto": func(): ui.open_howto(true),
		"journal": func(): ui.open_journal(true),
		"death": func(): ui.show_death(),
		"credits": func(): ui._credits(),
		"menu": func(): GameMode.in_game = false; ui.show_menu(),
	}
	for k in opens.keys():
		GameMode.in_game = true
		get_tree().paused = false
		opens[k].call()
		for i in 8:
			await get_tree().process_frame
		var n_bad := 0
		for c in ui.host.find_children("*", "Control", true, false):
			var ctl: Control = c
			if not ctl.is_visible_in_tree() or ctl.size.x < 2.0 or ctl.size.y < 2.0:
				continue
			# anything inside a scroll container is clipped by it and reached by scrolling
			var inside_scroll := false
			var p := ctl.get_parent()
			while p and p != ui.host:
				if p is ScrollContainer:
					inside_scroll = true
					break
				p = p.get_parent()
			var r := ctl.get_global_rect()
			if inside_scroll:
				continue
			if ctl is Button or ctl is Label or ctl is ScrollContainer or ctl is PanelContainer:
				checks += 1
				if not vr.grow(2.0).encloses(r) and r.size.x < vr.size.x * 1.5 and ctl.get_class() != "ColorRect":
					n_bad += 1
					if n_bad <= 3:
						_prob("%s panel '%s': %s '%s' %s outside viewport %s" % [tag, k, ctl.get_class(), (ctl.get("text") if ctl.get("text") != null else ctl.name), r, vr.size])
		# buttons must be big enough to hit with a thumb on touch (>= 44 px tall at the device's scale)
		if mode == "on":
			var scale: float = get_window().content_scale_factor
			for c in ui.host.find_children("*", "Button", true, false):
				var bt: Button = c
				if bt.is_visible_in_tree() and bt.size.y * scale < 44.0:
					checks += 1
					_prob("%s panel '%s': button '%s' only %.0f px tall on screen" % [tag, k, bt.text, bt.size.y * scale])
		ui._clear_host()
		ui.current = ""
		get_tree().paused = false
