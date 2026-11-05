class_name PulseRifle
extends WeaponBase
## Pulse Rifle: full-auto medium-range rifle with climbing recoil (PRD §5.2).
## The first shot after a pause is accurate; sustained fire blooms and climbs.

var _burst := 0

func auto_fire_allowed() -> bool:
	return true

func fire() -> bool:
	var ok := super.fire()
	if ok:
		_burst += 1
		if _burst > 4:
			owner_player.controller.add_recoil(data.recoil_pitch * 0.25, 0.0)
	return ok

func _process(delta: float) -> void:
	super._process(delta)
	if not owner_player.controller.fire_held:
		_burst = 0
