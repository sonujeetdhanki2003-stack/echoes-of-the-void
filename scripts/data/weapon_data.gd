class_name WeaponData
extends Resource
## Data asset for a weapon (PRD "Data Tables / Data Assets"): data/weapons/*.tres

@export var id := ""
@export var display_name := ""
@export var ammo_type := "pistol"
@export var damage := 20.0
@export var crit_mult := 2.0
@export var fire_rate := 4.0            # rounds per second
@export var automatic := false
@export var mag_size := 12
@export var reload_time := 1.4
@export var equip_time := 0.45
@export var spread_hip := 1.6           # degrees
@export var spread_aim := 0.4
@export var spread_per_shot := 0.3
@export var spread_max := 4.0
@export var spread_recover := 6.0       # degrees per second
@export var recoil_pitch := 1.2         # degrees per shot (camera kick)
@export var recoil_yaw := 0.4
@export var range := 120.0
@export var impulse := 2.0
@export var noise_radius := 32.0
@export var aim_fov := 52.0
@export var tracer_color := Color(0.4, 0.9, 1.0)
@export var model := ""
@export var sfx_fire := ""
@export var sfx_reload := ""
@export var pellets := 1               # v1.1.0: shotgun pellets per trigger pull (1 = a normal shot)
