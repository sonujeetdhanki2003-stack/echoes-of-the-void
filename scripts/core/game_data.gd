class_name GameData
extends RefCounted
## Read-only game data tables loaded from data/ (logs and dialogue are JSON tables; weapons, enemies and
## missions are typed Resources).

static var _logs: Array = []

static func logs() -> Array:
	if _logs.is_empty():
		var j := JSON.new()
		if j.parse(FileAccess.get_file_as_string("res://data/logs.json")) == OK and j.data is Array:
			_logs = j.data
	return _logs

static func log_info(id: int) -> Dictionary:
	for l in logs():
		if int(l["id"]) == id:
			return l
	return {}
