class_name EnemyData
extends Resource
## Data asset for an enemy type (PRD "Data Tables / Data Assets"): data/enemies/*.tres

@export var id := ""
@export var display_name := ""
@export var max_hp := 100.0
@export var walk_speed := 2.0
@export var run_speed := 6.0
@export var turn_speed := 8.0
@export var sight_range := 28.0
@export var sight_fov := 120.0          # degrees, full cone
@export var hearing := 1.0              # multiplier on noise radius
@export var melee_damage := 15.0
@export var melee_range := 2.5
@export var ranged_damage := 10.0
@export var preferred_range := 12.0
@export var attack_cooldown := 1.5
@export var crit_mult := 2.0
@export var stagger_threshold := 60.0   # damage within 2 s that causes a flinch
@export var model := ""
@export var radius := 0.5
@export var height := 1.8
