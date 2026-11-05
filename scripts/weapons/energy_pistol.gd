class_name EnergyPistol
extends WeaponBase
## Energy Pistol: precise semi-automatic sidearm for ammunition conservation (PRD §5.2).
## A held trigger re-fires at a slower cadence than tapping, so tapping rewards precision.

func auto_fire_allowed() -> bool:
	return false
