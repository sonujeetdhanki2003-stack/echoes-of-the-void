class_name BreachCannon
extends WeaponBase
## v1.5.0: Breach Cannon, the heavy weapon. One slow, heavy slug per trigger pull, a short magazine and a long reload.
## It draws on the pulse rifle's cells (ammo_type "rifle").
## v1.6.0 (stage D): splash damage. Every shot blasts where it lands: enemies within SPLASH_RADIUS take damage that
## falls off with distance (not the one it hit directly, which already took the full slug). Walls block the blast.

const SPLASH_RADIUS := 3.2
const SPLASH_FRACTION := 0.55     ## damage at the centre of the blast, as a share of the slug's damage

func auto_fire_allowed() -> bool:
	return false

func _apply_hit(hit: Dictionary, dir: Vector3) -> void:
	super._apply_hit(hit, dir)
	_splash(hit["position"], hit["normal"], dir, hit["collider"])

func _splash(pos: Vector3, normal: Vector3, dir: Vector3, col: Object) -> void:
	Sfx.play_at("breach_boom", pos, 2.0, 90.0)
	Fx.burst(pos + normal * 0.2, Color(1.0, 0.6, 0.25), 2.2, 60)
	Events.camera_shake.emit(0.45, 0.35)
	# the enemy the slug hit directly is not hit twice
	var direct: Node = null
	if col is Node:
		direct = (col as Node).get_meta("hit_owner") if (col as Node).has_meta("hit_owner") else col as Node
	var space := owner_player.get_world_3d().direct_space_state
	for e in owner_player.get_tree().get_nodes_in_group("enemy"):
		if not (e is EnemyBase) or not is_instance_valid(e) or (e as EnemyBase).dead:
			continue
		if e == direct or (direct and direct.is_ancestor_of(e)) or (direct and e.is_ancestor_of(direct)):
			continue
		var en := e as EnemyBase
		var c := en.global_position + Vector3.UP * 0.9
		var d := c.distance_to(pos)
		if d > SPLASH_RADIUS:
			continue
		var q := PhysicsRayQueryParameters3D.create(pos + normal * 0.1, c, 1)
		if not space.intersect_ray(q).is_empty():
			continue
		var falloff := 1.0 - d / SPLASH_RADIUS
		en.take_hit(data.damage * SPLASH_FRACTION * falloff, {"pos": c, "dir": dir, "critical": false,
			"source": owner_player, "kind": "splash", "normal": normal})
