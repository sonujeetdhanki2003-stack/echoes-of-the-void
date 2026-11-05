extends Node
## MissionManager (PRD BP_EOT_MissionManager): objective tracking. Autoloaded as "Missions".
## Objectives complete when their flag is set (Events.flag_set), so any system can progress the story
## without knowing about missions. Already-set later flags are skipped, so sequence breaks never softlock.

const AREAS := {
	"cryo": {"name": "CRYO CHAMBER", "script": "res://scripts/areas/area_cryo.gd"},
	"research": {"name": "RESEARCH WING", "script": "res://scripts/areas/area_research.gd"},
	"security": {"name": "SECURITY SECTOR", "script": "res://scripts/areas/area_security.gd"},
	"reactor": {"name": "REACTOR CORE", "script": "res://scripts/areas/area_reactor.gd"},
	"exterior": {"name": "ALIEN EXTERIOR", "script": "res://scripts/areas/area_exterior.gd"},
	"extraction": {"name": "EXTRACTION ZONE", "script": "res://scripts/areas/area_extraction.gd"},
	"hollows": {"name": "THE HOLLOWS", "script": "res://scripts/areas/area_hollows.gd"},
}

var data: MissionList

func _ready() -> void:
	data = load("res://data/missions.tres")
	Events.flag_set.connect(_on_flag)

func area_exists(id: String) -> bool:
	return AREAS.has(id)

func area_name(id: String) -> String:
	return AREAS.get(id, {}).get("name", id.to_upper())

func mission_count() -> int:
	return data.missions.size()

func mission_title(i: int) -> String:
	if i >= mission_count():
		return "EPILOGUE"
	return data.missions[clampi(i, 0, mission_count() - 1)]["title"]

func current_mission() -> Dictionary:
	var i: int = Game.state["mission"]
	return data.missions[i] if i < mission_count() else {}

func current_objective() -> Dictionary:
	var m := current_mission()
	if m.is_empty():
		return {}
	var o: int = Game.state["objective"]
	var objs: Array = m["objectives"]
	return objs[o] if o < objs.size() else {}

func objective_text() -> String:
	var o := current_objective()
	return o.get("text", "")

func is_current(obj_id: String) -> bool:
	return current_objective().get("id", "") == obj_id

func _on_flag(f: String) -> void:
	var o := current_objective()
	if o.is_empty():
		return
	if o["flag"] == f:
		advance()
		return
	# v1.6.0: a LATER objective of this mission whose flag is set early (a route taken out of order) counts as passed,
	# so the list never waits on a step the player has already done.
	var objs: Array = current_mission().get("objectives", [])
	for i in range(Game.state["objective"] + 1, objs.size()):
		if objs[i]["flag"] == f:
			Game.state["objective"] = i
			advance()
			return

## Move past every objective whose flag is already set; announce the new one.
func advance() -> void:
	var changed_mission := false
	while true:
		var o := current_objective()
		if o.is_empty():
			break
		if not Game.flag(o["flag"]):
			break
		Game.state["objective"] += 1
		var m := current_mission()
		if Game.state["objective"] >= (m["objectives"] as Array).size():
			Game.state["mission"] += 1
			Game.state["objective"] = 0
			changed_mission = true
			if Game.state["mission"] >= mission_count():
				break
	if changed_mission and Game.state["mission"] < mission_count():
		Events.mission_changed.emit(Game.state["mission"], mission_title(Game.state["mission"]))
	Events.objective_changed.emit(objective_text())
	if objective_text() != "":
		Sfx.ui("objective", -6.0)

## Called after a load so the state is consistent with the saved flags.
func resync() -> void:
	advance()
