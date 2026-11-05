class_name Melee
extends RefCounted
## v1.6.0 (stage B): the suit's melee strike. One key (G) or the MELEE touch button swings in a short arc in front of
## the player. A swing lands on the nearest living enemy in the arc, staggers it, and a second hit on a staggered
## enemy is a finishing move (instant on ordinary enemies, a large hit on bosses).

const RANGE := 2.1           ## metres from the player's chest to the target's edge
const ARC_COS := 0.45        ## cos of the half-angle of the arc (~63 degrees)
const DAMAGE := 34.0
const COOLDOWN := 0.6
const FINISH_MULT := 14.0    ## a finishing move on an ordinary enemy (kills it)
const BOSS_FINISH := 70.0    ## a finishing move on a boss (flat damage)

## Where the swing goes: the way the camera looks (the body can face another way when standing still).
static func _facing(p: Player) -> Vector3:
	var f := p.forward()
	if p.controller != null and is_instance_valid(p.controller):
		var aim: Vector3 = p.controller.aim_point(6.0) - p.global_position
		aim.y = 0.0
		if aim.length() > 0.2:
			f = aim
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD

static func target_in_arc(p: Player) -> Node:
	var fwd := _facing(p)
	if fwd.length() < 0.01:
		return null
	fwd = fwd.normalized()
	var origin := p.global_position + Vector3.UP * 0.9
	var best: Node = null
	var best_d := INF
	for e in p.get_tree().get_nodes_in_group("enemy"):
		if not (e is EnemyBase) or (e as EnemyBase).dead or not is_instance_valid(e):
			continue
		var en := e as EnemyBase
		var to := en.global_position - p.global_position
		to.y = 0.0
		var d := to.length()
		if d > RANGE + 0.45 or d < 0.01:
			continue
		if to.normalized().dot(fwd) < ARC_COS:
			continue
		if not _clear(p, origin, en.global_position + Vector3.UP * 0.9):
			continue
		if d < best_d:
			best_d = d
			best = en
	return best

static func _clear(p: Player, from: Vector3, to: Vector3) -> bool:
	var space := p.get_world_3d().direct_space_state
	if space == null:
		return true
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 1
	q.exclude = [p.get_rid()]
	return space.intersect_ray(q).is_empty()

## Try a swing. Returns "" when nothing is in reach, else "hit", "stagger" or "finish".
static func swing(p: Player) -> String:
	var t := target_in_arc(p) as EnemyBase
	if t == null:
		return ""
	var was_staggered := t.is_staggered()
	var face := _facing(p)
	var info := {"pos": t.global_position + Vector3.UP * 0.9, "dir": face, "critical": false,
		"source": p, "kind": "melee", "normal": -face, "melee": true}
	if was_staggered:
		var boss := t.is_in_group("boss")
		info["kind"] = "finisher"
		info["critical"] = true
		t.take_hit(BOSS_FINISH if boss else maxf(t.health.max_hp, 1.0) * FINISH_MULT, info)
		Fx.burst(info["pos"], Color(1.0, 0.45, 0.2), 1.4, 60)
		Sfx.play_at("finisher_crunch", info["pos"], 0.0, 25.0)
		Events.camera_shake.emit(0.5, 0.3)
		Feedback.hit_stop(0.09)
		Feedback.on_hit_confirmed(true, t.dead)
		if GameMode.ui:
			GameMode.ui.toast("FINISHED" if t.dead else "FINISHER", 1.2)
		return "finish"
	t.melee_hit(DAMAGE, info)
	Fx.burst(info["pos"], Color(0.6, 0.9, 1.0), 0.7, 24)
	Sfx.play_at("melee_hit", info["pos"], -2.0, 20.0)
	Feedback.on_hit_confirmed(false, t.dead)
	return "stagger"
