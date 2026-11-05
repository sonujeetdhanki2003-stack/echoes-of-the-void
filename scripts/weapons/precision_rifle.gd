class_name PrecisionRifle
extends WeaponBase
## v1.1.0 stage 3: Precision Rifle. One aimed shot per trigger pull, heavy damage, slow cadence, tight spread.
## It uses the pulse rifle's cells (ammo_type "rifle"). Tap, aim, wait for the bloom to settle.

func auto_fire_allowed() -> bool:
	return false
