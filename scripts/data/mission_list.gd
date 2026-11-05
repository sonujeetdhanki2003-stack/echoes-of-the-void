class_name MissionList
extends Resource
## Data asset for the mission sequence (PRD "Data Tables" -> a Godot Resource, data/missions.tres).
## Each mission: {id, title, subtitle, objectives: [{id, text, flag}]}. An objective completes when its flag is set.

@export var missions: Array[Dictionary] = []
