class_name Enemies
extends RefCounted
## Enemy factory by type name.

static func make(kind: String) -> EnemyBase:
	match kind:
		"stalker": return Stalker.new()
		"sentinel": return Sentinel.new()
		"brute": return Brute.new()
	push_error("unknown enemy " + kind)
	return Stalker.new()
