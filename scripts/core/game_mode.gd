extends Node
## GameMode (PRD BP_EOT_GameMode): game rules and player spawning — area loading, checkpoints, death and
## restart, combat state for the dynamic score, pause. Autoloaded as "GameMode".

var main: Node = null            # scenes/main.tscn root (owns WorldRoot + UI)
var ui: Node = null
var world_root: Node3D = null
var area: Area = null
var player: Player = null
var in_game := false
var loading := false
var _hunters := {}               # enemies currently hunting the player
var _combat := false
var _combat_cool := 0.0
var cinematic_playing := false
var boss_fight := false
var _session := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Events.player_died.connect(_on_player_died)
	Events.checkpoint_reached.connect(_on_checkpoint)

func register_main(m: Node, u: Node, wr: Node3D) -> void:
	main = m
	ui = u
	world_root = wr

func ui_blocking() -> bool:
	return ui != null and ui.has_method("is_blocking") and ui.is_blocking()

func _notification(what: int) -> void:
	# Android back / browser back = pause, never quit (THE DEEP v1.0.1 fix)
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if ui and ui.has_method("back_pressed"):
			ui.back_pressed()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if in_game and not get_tree().paused and ui and ui.has_method("pause") and not cinematic_playing and Game.test_mode == "":
			ui.pause()

# ---------------------------------------------------------------- flow
func new_game() -> void:
	Game.delete_save()
	Game.new_state()
	await load_area("cryo", "cryo_start", true)

func continue_game() -> bool:
	if not Game.load_game():
		return false
	Missions.resync()
	await load_area(str(Game.state["area"]), str(Game.state["checkpoint"]), false)
	return true

## Load (or reload) an area and place the player at a checkpoint (or the manual-save position).
func load_area(area_id: String, checkpoint_id: String, fresh: bool = false) -> void:
	if loading:
		return
	loading = true
	_session += 1
	var session := _session
	in_game = false
	get_tree().paused = false
	if ui:
		ui.show_loading(Missions.area_name(area_id))
		await ui.fade_to(1.0, 0.35)
	Sfx.stop_voice()
	Sfx.stop_all_loops()
	_hunters.clear()
	_combat = false
	boss_fight = false
	cinematic_playing = false
	if area:
		area.queue_free()
		world_root.remove_child(area)
		area = null
		player = null
	await get_tree().process_frame
	if session != _session:
		return           # v1.0.1: a newer load / to_menu owns `loading` now; clearing it here let two loads overlap
	Game.state["area"] = area_id
	var scr: Script = load(Missions.AREAS[area_id]["script"])
	area = scr.new()
	var my_area: Area = area
	area.name = "Area_" + area_id
	area.area_id = area_id
	world_root.add_child(area)
	area.build()
	area.apply_dressing()
	area.apply_grime()
	area.apply_visibility_ranges()
	apply_quality()
	await get_tree().physics_frame
	if session != _session:       # the player went back to the menu (or started another load) while this area was building
		if is_instance_valid(my_area):
			my_area.queue_free()
		return
	area.bake_navigation()
	# player
	player = Player.new()
	area.add_child(player)
	player.apply_state(Game.state["player"])
	var xf: Transform3D = area.checkpoint_xform(checkpoint_id)
	var pos: Variant = Game.state.get("pos")
	var from_manual := false
	if pos is Array and (pos as Array).size() >= 4 and not fresh:
		xf = Transform3D(Basis(Vector3.UP, float(pos[3])), Vector3(float(pos[0]), float(pos[1]), float(pos[2])))
		from_manual = true
	player.place(xf)
	player.controller.make_current()
	Game.state["checkpoint"] = checkpoint_id
	Game.state["pos"] = null
	Game.set_flag("area." + area_id)
	Missions.advance()
	await get_tree().physics_frame
	await get_tree().physics_frame
	if session != _session:
		if is_instance_valid(my_area):
			my_area.queue_free()
		return
	player.controller.snap_to(player.rotation.y)
	if ui:
		ui.on_area_loaded(area_id)
	in_game = true
	loading = false
	Events.area_loaded.emit(area_id)
	area.on_enter(fresh)
	# v1.0.1: continuing from a manual save must not overwrite it with the checkpoint (the position would be lost
	# if the player quit again before reaching a checkpoint)
	if (fresh or checkpoint_id.begins_with(area_id)) and not from_manual:
		save_checkpoint(checkpoint_id, false)
	if ui:
		ui.hide_loading()
		await ui.fade_to(0.0, 0.8)
	if Game.touch_enabled() or Game.test_mode != "":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

## Leave this area for another (doors / lifts at area edges).
func travel(area_id: String, checkpoint_id: String) -> void:
	if loading or player == null:
		return
	Game.state["player"] = player.snapshot()
	await load_area(area_id, checkpoint_id, false)

func save_checkpoint(id: String, notify: bool = true) -> void:
	if player == null or player.dead:
		return
	Game.state["checkpoint"] = id
	Game.state["pos"] = null
	Game.state["player"] = player.snapshot()
	if Game.save_game():
		if notify:
			Events.message.emit("Progress saved", 1.6)
			Sfx.ui("checkpoint", -6.0)

func _on_checkpoint(id: String) -> void:
	save_checkpoint(id)

func can_manual_save() -> String:
	if player == null or player.dead or not in_game:
		return "Nothing to save right now"
	if _combat or boss_fight:
		return "Can't save during combat"
	if cinematic_playing:
		return "Can't save now"
	if not player.is_on_floor():
		return "Can't save now"
	return ""

func manual_save() -> bool:
	if can_manual_save() != "":
		return false
	Game.state["player"] = player.snapshot()
	var p := player.global_position
	Game.state["pos"] = [p.x, p.y + 0.05, p.z, player.rotation.y]
	var ok := Game.save_game()
	Game.state["pos"] = null
	return ok

func _on_player_died() -> void:
	Game.state["stats"]["deaths"] += 1
	in_game = false
	await get_tree().create_timer(2.4, false).timeout
	if ui:
		ui.show_death()

func retry() -> void:
	var ok := Game.load_game()
	if not ok:
		await new_game()
		return
	Missions.resync()
	await load_area(str(Game.state["area"]), str(Game.state["checkpoint"]), false)

## Pause menu "Restart checkpoint": back to the last checkpoint (not a manual-save position).
func restart_checkpoint() -> void:
	var ok := Game.load_game()
	if not ok:
		await new_game()
		return
	Game.state["pos"] = null
	Missions.resync()
	await load_area(str(Game.state["area"]), str(Game.state["checkpoint"]), false)

func to_menu() -> void:
	_session += 1
	in_game = false
	loading = false
	get_tree().paused = false
	Sfx.stop_voice()
	Sfx.stop_all_loops()
	if area:
		area.queue_free()
		world_root.remove_child(area)
		area = null
	player = null
	if ui:
		ui.show_menu()

# ---------------------------------------------------------------- combat state -> music
func hunter(e: Node, on: bool) -> void:
	if on:
		_hunters[e.get_instance_id()] = e
	else:
		_hunters.erase(e.get_instance_id())

func in_combat() -> bool:
	return _combat

func _process(delta: float) -> void:
	if not in_game or get_tree().paused:
		return
	Game.state["stats"]["time"] += delta
	for k in _hunters.keys():
		var e: Variant = _hunters[k]
		if not is_instance_valid(e) or e.get("dead"):
			_hunters.erase(k)
	var hunting := _hunters.size() > 0
	if hunting:
		_combat_cool = 4.0
	else:
		_combat_cool -= delta
	var now := hunting or _combat_cool > 0.0
	if now != _combat:
		_combat = now
		Events.combat_state.emit(_combat)
	if cinematic_playing:
		return
	if boss_fight:
		Sfx.set_music_mode("boss")
	elif _combat:
		Sfx.set_music_mode("combat")
	elif area and area.tension:
		Sfx.set_music_mode("tension")
	else:
		Sfx.set_music_mode("explore")

func apply_quality() -> void:
	var prof := Game.quality_profile()
	Fx.particle_scale = float(prof["particles"])
	if area:
		area.apply_quality(prof)
