class_name Bolt
extends Area3D
## A Sentinel's resonance bolt: a visible, dodgeable projectile.

var velocity := Vector3.ZERO
var damage := 10.0
var life := 3.0
var source: Node
var color := Color(1.0, 0.3, 0.9)

func _ready() -> void:
	collision_layer = 32
	collision_mask = 1 | 2
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.16
	cs.shape = sp
	add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.24
	mi.mesh = sm
	mi.material_override = Fx.glow_mat(color, 5.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var trail := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.0
	cm.height = 1.1
	trail.mesh = cm
	trail.material_override = Fx.glow_mat(color, 2.0)
	trail.rotation.x = -PI * 0.5
	trail.position.z = 0.55
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail)
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = 1.6
	l.omni_range = 3.5
	add_child(l)
	body_entered.connect(_hit)

func launch(from: Vector3, dir: Vector3, speed: float) -> void:
	global_position = from
	velocity = dir.normalized() * speed
	if dir.length() > 0.01:
		look_at(from + dir, Vector3.UP if absf(dir.normalized().y) < 0.95 else Vector3.FORWARD)

func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	var from := global_position
	var to := from + velocity * delta
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	if source is CollisionObject3D:
		q.exclude = [(source as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		global_position = hit["position"]
		_hit(hit["collider"])
		return
	global_position = to

func _hit(b: Object) -> void:
	if is_queued_for_deletion():
		return
	if b is Player:
		(b as Player).health.take_damage(damage, {"pos": global_position - velocity.normalized(), "kind": "bolt", "source": source})
	Fx.impact(global_position, -velocity.normalized(), "crystal", 1.0)
	Sfx.play_at("bolt_impact", global_position, -4.0, 30.0)
	queue_free()
