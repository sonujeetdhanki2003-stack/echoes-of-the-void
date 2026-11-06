extends Node
## GameInstance (PRD BP_EOT_GameInstance): persistent session data, settings, input map, and the
## SaveManager role (PRD BP_EOT_SaveManager): JSON saves keyed by stable IDs. Autoloaded as "Game".

const VERSION := "1.9.1"
const SAVE_VERSION := 3   # v1.6.0: 3 adds THE HOLLOWS steps in the final mission; 1.0.x to 1.5.x saves still load (objective shift)

# Paths are vars so automated tests use their own files and never touch a player's save.
var SAVE_PATH := "user://echoes_save.json"
var SETTINGS_PATH := "user://echoes_settings.cfg"

var is_web := OS.has_feature("web")
var is_mobile := OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios")
var boot_area := ""           # set by the named level scenes (scenes/levels/*.tscn)
var boot_mission := 0
var test_mode := ""          # "autotest", "qa", ... set from the command line
var user_args := PackedStringArray()

var settings := {
	"master": 0.9, "music": 0.7, "sfx": 0.9, "voice": 1.0,
	"sensitivity": 1.0, "invert_y": false, "fov": 70.0,
	"quality": "high", "fullscreen": false, "vsync": true,
	"subtitles": true, "difficulty": "normal", "touch": "auto",
	"aim_assist": true, "camera_shake": 1.0, "render_scale": 1.0, "ui_size": "auto",
	"resolution": "1600x900", "bindings": {}, "cam_distance": 1.0, "show_fps": false,
	"web_default": false,
	"reduce_motion": false, "vibration": true, "subtitle_size": "medium", "subtitle_bg": false, "frame_cap": 0,
}

## The live game state. Everything that must survive a save lives here, keyed by stable string IDs.
var state: Dictionary = {}

const DIFFICULTY := {
	"story": {"dmg_taken": 0.5, "enemy_hp": 0.75, "ammo": 1.4},
	"normal": {"dmg_taken": 1.0, "enemy_hp": 1.0, "ammo": 1.0},
	"hard": {"dmg_taken": 1.45, "enemy_hp": 1.25, "ammo": 0.8},
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	user_args = OS.get_cmdline_user_args()
	for a in user_args:
		if a.begins_with("--") and a.length() > 2 and test_mode == "":
			var n := a.substr(2)
			if n in ["autotest", "qa", "shots", "trailer", "prof", "soak", "fps", "probe"]:
				test_mode = n
	if test_mode != "":
		# per-process files: two test runs at once (lead + auditor) must not share a save
		SAVE_PATH = "user://test_%s_%d_save.json" % [test_mode, OS.get_process_id()]
		SETTINGS_PATH = "user://test_%s_%d_settings.cfg" % [test_mode, OS.get_process_id()]
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH + ".bak"))
	if is_mobile:
		settings["quality"] = "mobile"
		settings["fov"] = 72.0
		settings["frame_cap"] = 60     # v1.1.0: phones default to 60 fps (less heat); PC and web stay unlimited
	elif is_web:
		settings["quality"] = "web"       # v1.0.1: desktop browsers get the "web" look (was "low": flat, no shadows, no grime)
	_setup_input()
	if has_arg("ai_debug"):
		EnemyBase.debug_ai = true
	load_settings()
	apply_bindings()
	apply_settings()
	# v1.1.0 feel: hit-stop and haptics listen to the event bus (see scripts/core/feedback.gd)
	Events.hit_confirmed.connect(Feedback.on_hit_confirmed)
	Events.player_damaged.connect(func(amount: float, _from: Vector3) -> void: Feedback.on_player_damaged(amount))
	Events.player_died.connect(Feedback.on_player_died)
	new_state()

func arg(name: String, def: String = "") -> String:
	for a in user_args:
		if a.begins_with("--" + name + "="):
			return a.split("=", true, 1)[1]
	return def

func has_arg(name: String) -> bool:
	return ("--" + name) in user_args

func touch_enabled() -> bool:
	var t: String = settings["touch"]
	if t == "on":
		return true
	if t == "off":
		return false
	return is_mobile or DisplayServer.is_touchscreen_available() and is_web

func diff(key: String) -> float:
	var d: Dictionary = DIFFICULTY.get(settings["difficulty"], DIFFICULTY["normal"])
	return float(d[key])

# ---------------------------------------------------------------- state
func new_state() -> void:
	state = {
		"version": SAVE_VERSION,
		"mission": 0,                 # index into Missions.MISSIONS
		"objective": 0,               # index into that mission's objectives
		"area": "cryo",
		"checkpoint": "cryo_start",
		"pos": null,                  # manual-save position [x,y,z,yaw] or null = checkpoint transform
		"player": default_player(),
		"flags": {},                  # stable id -> true/value (doors, puzzles, pickups, dead enemies, triggers)
		"logs": [],                   # research log ids found, in order
		"upgrades": {},               # v1.5.0: weapon id -> {damage, reload, magazine, accuracy} levels (0-3)
		"stats": {"time": 0.0, "kills": 0, "deaths": 0, "shots": 0, "hits": 0},
		"saved_at": "",
	}

func default_player() -> Dictionary:
	return {
		"hp": 100.0, "max_hp": 100.0, "stamina": 100.0, "medkits": 0,
		"weapons": [], "equipped": "",
		"mag": {"pistol": 0, "rifle": 0}, "reserve": {"pistol": 0, "rifle": 0},
		"keycards": [], "lamp": false, "parts": 0,
	}

func flag(id: String) -> bool:
	return bool(state["flags"].get(id, false))

func flag_value(id: String, def: Variant = null) -> Variant:
	return state["flags"].get(id, def)

func set_flag(id: String, value: Variant = true) -> void:
	var had: bool = state["flags"].has(id)
	state["flags"][id] = value
	if not had or value is bool:
		Events.flag_set.emit(id)

func add_log(id: int) -> bool:
	if id in state["logs"]:
		return false
	state["logs"].append(id)
	Events.log_found.emit(id)
	return true

# ---------------------------------------------------------------- save / load
## v1.5.0: three save slots. Slot 1 is the file every 1.0.x and 1.4.x build wrote (SAVE_PATH), so an old save is
## slot 1 with nothing to move. Slots 2 and 3 sit beside it (..._s2.json, ..._s3.json), each with its own .bak.
const SLOT_COUNT := 3
var active_slot := 1      # the slot the current game reads and writes (chosen in the menu, not saved)

func slot_path(s: int, bak: bool = false) -> String:
	var p := SAVE_PATH if s <= 1 else SAVE_PATH.trim_suffix(".json") + "_s%d.json" % s
	return p + ".bak" if bak else p

## v1.0.1: only a save that load_game() would accept counts (a damaged or too-new file used to show "Continue"
## and then fail with "Save could not be loaded").
func _usable_slot(s: int) -> Variant:
	for p in [slot_path(s), slot_path(s, true)]:
		var d: Variant = _read_json(p)
		if d != null and _valid(d):
			return d
	return null

func _usable_save() -> Variant:
	return _usable_slot(active_slot)

func slot_used(s: int) -> bool:
	return _usable_slot(s) != null

func slot_info(s: int) -> String:
	var d: Variant = _usable_slot(s)
	if d == null:
		return ""
	var m := int(d.get("mission", 0))
	var title: String = Missions.mission_title(m)
	var t := int(float(d.get("stats", {}).get("time", 0.0)))
	return "%s  ·  %d:%02d played  ·  %s" % [title, t / 60, t % 60, str(d.get("saved_at", ""))]

## The slot whose save is the newest (0 when no slot holds a usable save).
func latest_slot() -> int:
	var best := 0
	var best_at := ""
	for s in range(1, SLOT_COUNT + 1):
		var d: Variant = _usable_slot(s)
		if d != null and str(d.get("saved_at", "")) >= best_at:
			best = s
			best_at = str(d.get("saved_at", ""))
	return best

func first_empty_slot() -> int:
	for s in range(1, SLOT_COUNT + 1):
		if not slot_used(s):
			return s
	return 1

func has_save() -> bool:
	return latest_slot() > 0

func used_slot_count() -> int:
	var n := 0
	for s in range(1, SLOT_COUNT + 1):
		if slot_used(s):
			n += 1
	return n

func save_info() -> String:
	var s := latest_slot()
	return slot_info(s) if s > 0 else ""

## Atomic save: write a temp file, read it back and parse it, keep the previous save as .bak, then swap.
## A crash or power loss mid-write can never leave the player with no usable save.
func save_game(snapshot: Dictionary = {}) -> bool:
	var data: Dictionary = (state if snapshot.is_empty() else snapshot).duplicate(true)
	data["version"] = SAVE_VERSION
	data["game_version"] = VERSION
	data["saved_at"] = Time.get_datetime_string_from_system(false, true)
	state["saved_at"] = data["saved_at"]
	var path := slot_path(active_slot)
	var txt := JSON.stringify(data, "\t")
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save: cannot open %s (%s)" % [tmp, error_string(FileAccess.get_open_error())])
		return false
	f.store_string(txt)
	f.flush()
	f.close()
	if _read_json(tmp) == null:
		push_warning("save: verification of the temp save failed")
		return false
	var abs_save := ProjectSettings.globalize_path(path)
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(abs_save + ".bak")
		DirAccess.rename_absolute(abs_save, abs_save + ".bak")
	var err := DirAccess.rename_absolute(abs_tmp, abs_save)
	if err != OK:
		push_warning("save: rename failed (%s)" % error_string(err))
		return false
	return true

func load_game() -> bool:
	var path := slot_path(active_slot)
	var d: Variant = _read_json(path)
	if d == null or not _valid(d):
		d = _read_json(path + ".bak")
		if d == null or not _valid(d):
			return false
	new_state()
	# merge so saves from older versions get any new keys with defaults
	for k in d.keys():
		state[k] = d[k]
	var p := default_player()
	for k in state["player"].keys():
		p[k] = state["player"][k]
	state["player"] = p
	state["mission"] = int(state["mission"])
	state["objective"] = int(state["objective"])
	# v1.6.0: THE HOLLOWS adds two steps at the front of the final mission (mission index 3). A save from before
	# (1.0.x to 1.5.x) keeps its place: its objective index moves past the two new steps.
	if int(d.get("version", 0)) < 3 and state["mission"] == 3:
		state["objective"] = int(state["objective"]) + 2
	var logs: Array = []
	for l in state["logs"]:
		logs.append(int(l))
	state["logs"] = logs
	return true

## Deletes every slot (tests and a full reset). A new game deletes only its own slot, see delete_slot().
func delete_save() -> void:
	for s in range(1, SLOT_COUNT + 1):
		delete_slot(s)

func delete_slot(s: int) -> void:
	var path := slot_path(s)
	for p in [path, path + ".bak", path + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## Save validation (Post-PRD 4.6): structure, types and ranges are checked before a save is trusted; a file that
## fails falls back to the .bak copy written by the previous save, and a version newer than this build is refused.
func _valid(d: Variant) -> bool:
	if not (d is Dictionary):
		return false
	for k in ["area", "checkpoint", "flags", "player", "mission", "objective"]:
		if not d.has(k):
			return false
	if not (d["flags"] is Dictionary and d["player"] is Dictionary):
		return false
	if int(d.get("version", 0)) > SAVE_VERSION or int(d.get("version", 0)) < 1:
		return false
	if not Missions.area_exists(str(d["area"])):
		return false
	var m := int(d["mission"])
	if m < 0 or m > Missions.mission_count():
		return false
	if d.has("logs") and not (d["logs"] is Array):
		return false
	return true

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var txt := f.get_as_text()
	f.close()
	if txt.strip_edges() == "":
		return null
	var j := JSON.new()
	if j.parse(txt) != OK:
		return null
	return j.data if j.data is Dictionary else null

# ---------------------------------------------------------------- settings
func load_settings() -> void:
	var c := ConfigFile.new()
	if c.load(SETTINGS_PATH) != OK:
		return
	for k in settings.keys():
		if c.has_section_key("settings", k):
			var v: Variant = c.get_value("settings", k)
			if typeof(v) == typeof(settings[k]) or (settings[k] is float and v is int):
				settings[k] = v
	# v1.1.0: a hand-edited or damaged value falls back to its default (the type check above keeps the rest)
	if not (str(settings["subtitle_size"]) in ["small", "medium", "large"]):
		settings["subtitle_size"] = "medium"
	if not ([0, 30, 60, 120] as Array).has(int(settings["frame_cap"])):
		settings["frame_cap"] = 60 if is_mobile else 0
	if is_mobile and settings["quality"] in ["high", "ultra"]:
		settings["quality"] = "mobile"
	# v1.0.1: a v1.0.0 web player who ever opened Settings has "low" saved: move them to the new web look once
	if is_web and not is_mobile and not bool(settings["web_default"]):
		settings["web_default"] = true
		if settings["quality"] == "low":
			settings["quality"] = "web"
		save_settings()

func save_settings() -> void:
	var c := ConfigFile.new()
	for k in settings.keys():
		c.set_value("settings", k, settings[k])
	c.save(SETTINGS_PATH)

func apply_settings() -> void:
	Engine.max_fps = int(settings["frame_cap"])     # v1.1.0: 0 = unlimited
	if not is_mobile and not is_web and DisplayServer.get_name() != "headless":
		var want := DisplayServer.WINDOW_MODE_FULLSCREEN if settings["fullscreen"] else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != want and not (want == DisplayServer.WINDOW_MODE_WINDOWED and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_MAXIMIZED):
			DisplayServer.window_set_mode(want)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if settings["vsync"] else DisplayServer.VSYNC_DISABLED)
		if want == DisplayServer.WINDOW_MODE_WINDOWED and test_mode == "" and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			var parts: PackedStringArray = str(settings.get("resolution", "1600x900")).split("x")
			if parts.size() == 2:
				var sz := Vector2i(int(parts[0]), int(parts[1]))
				var scr := DisplayServer.screen_get_usable_rect().size
				sz = Vector2i(mini(sz.x, scr.x), mini(sz.y, scr.y))
				if DisplayServer.window_get_size() != sz and sz.x >= 640:
					DisplayServer.window_set_size(sz)
					DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect().position + (scr - sz) / 2)
	var vp := get_viewport()
	if vp:
		(vp as Window).content_scale_factor = ui_scale() if vp is Window else 1.0
		var rs := float(settings["render_scale"])
		if settings["quality"] == "mobile":
			rs = minf(rs, 0.8)
		elif settings["quality"] == "low":
			rs = minf(rs, 0.85)
		rs = minf(rs, phone_render_cap)     # v1.1.0 stage 4: the phone guard's session cap (1.0 when not used)
		vp.scaling_3d_scale = clampf(rs, 0.5, 1.0)
		vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if (is_mobile or is_web or rs >= 0.99) else Viewport.SCALING_3D_MODE_FSR
		# FXAA exists only in Forward+ / Mobile; the Compatibility renderer (web, GL fallback) warns on every set
		if RenderingServer.get_current_rendering_method() != "gl_compatibility":
			vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
		vp.use_taa = settings["quality"] == "ultra" and not is_mobile and not is_web
		# the web build has no FXAA/TAA (Compatibility renderer): desktop browsers get 2x MSAA instead of bare jagged edges
		vp.msaa_3d = Viewport.MSAA_2X if (is_web and not is_mobile and settings["quality"] != "low") else Viewport.MSAA_DISABLED
	if has_node("/root/Sfx"):
		get_node("/root/Sfx").apply_volumes()
	if has_node("/root/GameMode"):
		get_node("/root/GameMode").apply_quality()

## UI scale (Sonujeet's THE DEEP feedback: everything on the phone must be big). "auto" = 1.35x on touch
## devices, 1.0x on desktop. The whole canvas is scaled, so every menu, HUD element and touch button grows together.
const UI_SIZES := {"small": 0.9, "normal": 1.0, "large": 1.2, "x-large": 1.35, "huge": 1.55}
func ui_scale() -> float:
	var k: String = settings.get("ui_size", "auto")
	if UI_SIZES.has(k):
		return UI_SIZES[k]
	return 1.35 if (is_mobile or touch_enabled()) else 1.1

## Quality presets. Each area's WorldEnvironment is passed through here, so a settings change applies live.
func quality_profile() -> Dictionary:
	var q: String = settings["quality"]
	var rm := RenderingServer.get_current_rendering_method()
	var fwd := rm == "forward_plus"
	var p := {
		"sdfgi": false, "ssao": false, "ssil": false, "ssr": false, "vol_fog": false, "glow": true,
		"shadow_size": 2048, "shadows": true, "lights_shadow": true, "particles": 1.0, "lod_bias": 1.0,
		"far": 220.0,
	}
	match q:
		"ultra":
			p.merge({"sdfgi": fwd, "ssao": fwd, "ssil": fwd, "ssr": fwd, "vol_fog": fwd, "shadow_size": 4096, "lod_bias": 1.5, "far": 400.0}, true)
		"high":
			p.merge({"sdfgi": fwd, "ssao": fwd, "vol_fog": fwd, "shadow_size": 4096, "far": 320.0}, true)
		"medium":
			p.merge({"ssao": fwd, "vol_fog": fwd, "shadow_size": 2048, "far": 260.0, "particles": 0.8}, true)
		"web":
			# desktop browsers (Compatibility renderer): no SDFGI / SSAO / volumetric fog, so everything it CAN do is on
			p.merge({"glow": true, "shadow_size": 2048, "lights_shadow": false, "particles": 0.8, "lod_bias": 1.0, "far": 260.0,
				"probes": false, "ambient_boost": 1.4}, true)
		"low":
			p.merge({"glow": true, "shadow_size": 1024, "lights_shadow": false, "particles": 0.6, "lod_bias": 0.75, "far": 200.0, "splits": 2, "shadow_dist": 34.0}, true)
		"mobile":
			p.merge({"glow": true, "shadow_size": 1024, "lights_shadow": false, "particles": 0.5, "lod_bias": 0.6, "far": 180.0, "splits": 2, "shadow_dist": 30.0}, true)
	if has_arg("qo"):   # debugging: --qo=key=val;key=val
		for kv in arg("qo").split(";", false):
			var a := kv.split("=")
			p[a[0]] = float(a[1]) if a[1].is_valid_float() else (a[1] == "true")
	return p

# ---------------------------------------------------------------- phone guard (v1.1.0 stage 4)
## On an Android phone, if the game holds under PHONE_GUARD_FPS for 6 s (after a warm-up, in the game only), the 3D
## render scale steps down by 0.1 (never below PHONE_GUARD_MIN_SCALE), once per step, and the player is told once.
## It is a session cap: it is not saved, so the next launch starts at the player's own setting again.
const PHONE_GUARD_FPS := 28.0
const PHONE_GUARD_MIN_SCALE := 0.6
var phone_render_cap := 1.0
var phone_steps := 0
var _phone_t := 0.0
var _phone_n := 0
var _phone_warm := 4.0

## the render-scale cap after one guard decision: unchanged when the frame rate is fine, one step down otherwise
static func phone_guard_next_scale(fps: float, rs: float) -> float:
	if fps >= PHONE_GUARD_FPS:
		return rs
	return maxf(PHONE_GUARD_MIN_SCALE, snappedf(rs - 0.1, 0.01))

func phone_sample(delta: float) -> void:
	if not is_mobile or is_web or get_tree().paused:
		return
	if not get_node("/root/GameMode").in_game or delta > 0.5:
		return
	if _phone_warm > 0.0:
		_phone_warm -= delta
		return
	_phone_t += delta
	_phone_n += 1
	if _phone_t < 6.0:
		return
	var fps := float(_phone_n) / _phone_t
	var rs := float(settings["render_scale"])
	var cur := minf(rs, phone_render_cap)
	var next := phone_guard_next_scale(fps, cur)
	if next < cur - 0.001:
		phone_render_cap = next
		phone_steps += 1
		apply_settings()
		var ui = get_node("/root/GameMode").ui
		if ui:
			ui.toast("Running slowly - lowered the resolution a little", 3.0)
	_phone_t = 0.0
	_phone_n = 0

# ---------------------------------------------------------------- web performance guard (v1.0.1)
## The "web" look costs roughly twice the draw calls of "low" (grime overlay). If a browser can't hold ~30 fps on it
## the game drops itself to "low" once, tells the player, and remembers it.
var _perf_t := 0.0
var _perf_n := 0
var _perf_warm := 3.0
var perf_dropped := false
func _process(delta: float) -> void:
	perf_sample(delta)
	phone_sample(delta)

func perf_sample(delta: float) -> void:
	if not is_web or is_mobile or settings["quality"] != "web" or perf_dropped or get_tree().paused:
		return
	if not get_node("/root/GameMode").in_game or delta > 0.5:
		return                       # menus, loads and long hitches (tab switches) are not the game's frame rate
	if _perf_warm > 0.0:
		_perf_warm -= delta          # shader compiles / first frames
		return
	_perf_t += delta
	_perf_n += 1
	if _perf_t >= 6.0:
		var fps := float(_perf_n) / _perf_t
		if fps < 28.0:
			perf_dropped = true
			settings["quality"] = "low"
			save_settings()
			apply_settings()
			var ui = get_node("/root/GameMode").ui
			if ui:
				ui.toast("Running slowly - switched to Low graphics (Settings > Quality to change)", 4.0)
		_perf_t = 0.0
		_perf_n = 0

# ---------------------------------------------------------------- input
const DEFAULT_KEYS := {
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"sprint": [KEY_SHIFT], "jump": [KEY_SPACE], "crouch": [KEY_C, KEY_CTRL],
	"interact": [KEY_E], "reload": [KEY_R], "medkit": [KEY_Q, KEY_H],
	"weapon_1": [KEY_1], "weapon_2": [KEY_2], "weapon_3": [KEY_3], "weapon_4": [KEY_4], "weapon_5": [KEY_5], "weapon_next": [], "weapon_prev": [],
	"melee": [KEY_G], "lamp": [KEY_F], "journal": [KEY_TAB, KEY_J], "pause": [KEY_ESCAPE, KEY_P],
	"shoulder_swap": [KEY_V], "fire": [], "aim": [], "skip": [KEY_ENTER],
	"cam_closer": [KEY_PAGEDOWN], "cam_farther": [KEY_PAGEUP],
}
## Key rebinding (Post-PRD Phase 9): the primary key of these actions can be changed in Settings; the choice is
## stored in settings["bindings"] (action -> physical keycode) and persists with the other settings.
const REBINDABLE := [["move_forward", "Move forward"], ["move_back", "Move back"], ["move_left", "Move left"],
	["move_right", "Move right"], ["sprint", "Sprint"], ["jump", "Jump"], ["crouch", "Crouch"], ["interact", "Use / interact"],
	["reload", "Reload"], ["medkit", "Use medkit"], ["weapon_1", "Energy pistol"], ["weapon_2", "Pulse rifle"], ["weapon_3", "Scatter shotgun"], ["weapon_4", "Precision rifle"], ["weapon_5", "Breach cannon"],
	["melee", "Melee strike"], ["lamp", "Suit lamp"], ["journal", "Inventory & logs"], ["shoulder_swap", "Swap shoulder"],
	["cam_closer", "Camera closer"], ["cam_farther", "Camera farther"]]
const RESOLUTIONS := ["1280x720", "1366x768", "1600x900", "1920x1080", "2560x1440"]

func binding_of(action: String) -> int:
	var b: Dictionary = settings.get("bindings", {})
	if b.has(action):
		return int(b[action])
	var d: Array = DEFAULT_KEYS.get(action, [])
	return int(d[0]) if d.size() > 0 else 0

## The key currently bound to `action`, as the player would read it on the keycap ("W", "Shift", "Space").
## Every on-screen keyboard hint is built from this, so the hints follow a rebinding.
func key_name(action: String) -> String:
	var k := binding_of(action)
	if k == 0:
		return "?"
	var s := OS.get_keycode_string(k)
	return s if s != "" else "?"

func move_keys() -> String:
	var ks := [key_name("move_forward"), key_name("move_left"), key_name("move_back"), key_name("move_right")]
	return "WASD" if ks == ["W", "A", "S", "D"] else "/".join(ks)

## One-line keyboard summary (settings footer).
func keys_line() -> String:
	return "Keyboard: %s move · %s sprint · %s jump · %s crouch · RMB aim · LMB fire · %s reload · %s/%s weapons · %s use · %s medkit · %s lamp · %s shoulder · %s logs · Esc pause" % [
		move_keys(), key_name("sprint"), key_name("jump"), key_name("crouch"), key_name("reload"), key_name("weapon_1"),
		key_name("weapon_2"), key_name("interact"), key_name("medkit"), key_name("lamp"), key_name("shoulder_swap"), key_name("journal")]

func set_binding(action: String, keycode: int) -> void:
	var b: Dictionary = settings.get("bindings", {})
	# a key can only do one thing: whoever had it gets this action's old key (a swap)
	var old := binding_of(action)
	for pair in REBINDABLE:
		var other: String = pair[0]
		if other != action and binding_of(other) == keycode:
			b[other] = old
	b[action] = keycode
	settings["bindings"] = b
	apply_bindings()
	save_settings()

func reset_bindings() -> void:
	settings["bindings"] = {}
	apply_bindings()
	save_settings()

func apply_bindings() -> void:
	var used := {}
	for pair in REBINDABLE:
		used[binding_of(pair[0])] = true
	for pair in REBINDABLE:
		var action: String = pair[0]
		if not InputMap.has_action(action):
			continue
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				InputMap.action_erase_event(action, e)
		var keys: Array = [binding_of(action)]
		var d: Array = DEFAULT_KEYS.get(action, [])
		for i in range(1, d.size()):
			if not used.has(int(d[i])):
				keys.append(d[i])
		for k in keys:
			if int(k) == 0:
				continue
			var ev := InputEventKey.new()
			ev.physical_keycode = int(k)
			InputMap.action_add_event(action, ev)

func _setup_input() -> void:
	var keys := DEFAULT_KEYS
	for action in keys.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_mouse("aim", MOUSE_BUTTON_RIGHT)
	_mouse("weapon_next", MOUSE_BUTTON_WHEEL_UP)
	_mouse("weapon_prev", MOUSE_BUTTON_WHEEL_DOWN)
	# controller (secondary per the PRD)
	_joy_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_joy_axis("aim", JOY_AXIS_TRIGGER_LEFT, 1.0)
	for a in ["look_left", "look_right", "look_up", "look_down"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.15)
	_joy_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_joy_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_joy_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_joy_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_joy_btn("jump", JOY_BUTTON_A)
	_joy_btn("crouch", JOY_BUTTON_B)
	_joy_btn("interact", JOY_BUTTON_X)
	_joy_btn("reload", JOY_BUTTON_RIGHT_SHOULDER)
	_joy_btn("weapon_next", JOY_BUTTON_Y)
	_joy_btn("sprint", JOY_BUTTON_LEFT_STICK)
	_joy_btn("lamp", JOY_BUTTON_DPAD_UP)
	_joy_btn("medkit", JOY_BUTTON_LEFT_SHOULDER)
	_joy_btn("melee", JOY_BUTTON_DPAD_RIGHT)
	_joy_btn("shoulder_swap", JOY_BUTTON_RIGHT_STICK)
	_joy_btn("journal", JOY_BUTTON_BACK)
	_joy_btn("pause", JOY_BUTTON_START)
	_joy_btn("skip", JOY_BUTTON_A)

func _mouse(action: String, b: MouseButton) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = b
	InputMap.action_add_event(action, e)

func _joy_axis(action: String, axis: JoyAxis, v: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = v
	InputMap.action_add_event(action, e)

func _joy_btn(action: String, b: JoyButton) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	InputMap.action_add_event(action, e)
