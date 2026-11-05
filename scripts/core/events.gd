extends Node
## Global event bus (PRD "Event Dispatchers" -> Godot signals). Autoloaded as "Events".
## Systems emit here so unrelated nodes (UI, missions, AI, audio) stay decoupled.

@warning_ignore_start("unused_signal")
signal noise(pos: Vector3, radius: float, source: Node)          # gunshots, sprint steps, impacts -> AI hearing
signal player_damaged(amount: float, from_dir: Vector3)
signal player_died
signal player_healed(amount: float)
signal enemy_alerted(enemy: Node)
signal enemy_killed(enemy: Node, kind: String)
signal hit_confirmed(critical: bool, killed: bool)               # crosshair hit marker
signal weapon_changed(weapon_id: String)
signal ammo_changed(mag: int, reserve: int)
signal interact_focus(prompt: String)                            # "" = nothing in focus
signal message(text: String, secs: float)                        # toast
signal subtitle(speaker: String, text: String, secs: float)
signal log_found(id: int)
signal pickup(kind: String, amount: int)
signal checkpoint_reached(id: String)
signal flag_set(flag: String)
signal objective_changed(text: String)
signal mission_changed(index: int, title: String)
signal combat_state(in_combat: bool)
signal boss_health(name: String, frac: float, visible: bool)
signal cinematic_state(playing: bool)
signal camera_shake(strength: float, secs: float)
signal area_loaded(area_id: String)
@warning_ignore_restore("unused_signal")

func emit_noise(pos: Vector3, radius: float, source: Node = null) -> void:
	noise.emit(pos, radius, source)
