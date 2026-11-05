@tool
extends Node3D
## Doc 03 weapon scenes (pulse_rifle.tscn, energy_pistol.tscn): the weapon's model plus its data resource. In play,
## CombatComponent builds the live weapon from the same data (scripts/weapons/*.gd) and attaches it to bone prop.R.
@export var data: WeaponData
