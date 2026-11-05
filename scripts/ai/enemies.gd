class_name Enemies
extends RefCounted
## Enemy factory by type name.

static func make(kind: String) -> EnemyBase:
	match kind:
		"stalker": return Stalker.new()
		"sentinel": return Sentinel.new()
		"brute": return Brute.new()
		"hunter": return Hunter.new()          # v1.1.0 stage 2
		"experimental": return Experimental.new()
	push_error("unknown enemy " + kind)
	return Stalker.new()
