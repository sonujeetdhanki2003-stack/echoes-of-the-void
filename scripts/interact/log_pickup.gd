class_name LogPickup
extends Interactable
## A research log on a datapad or terminal. Using it plays the voice log with subtitles and files it in the journal.

@export var log_id := 1
@export var terminal := false     # wall/desk terminal instead of a datapad on the floor
var model: Node3D
var _glow: OmniLight3D
var _t := 0.0

func _ready() -> void:
	super._ready()
	stable_id = "log.%d" % log_id
	range_m = 2.2
	focus_offset = Vector3(0, 0.2 if not terminal else 1.2, 0)
	if not terminal:
		model = Props.instance("datapad")
		add_child(model)
		model.position.y = 0.03
		_glow = OmniLight3D.new()
		_glow.light_color = Color(0.4, 0.85, 1.0)
		_glow.light_energy = 0.8
		_glow.omni_range = 1.6
		_glow.position.y = 0.3
		add_child(_glow)

func _info() -> Dictionary:
	for l in GameData.logs():
		if int(l["id"]) == log_id:
			return l
	return {}

func get_prompt() -> String:
	var i := _info()
	var seen: bool = log_id in Game.state["logs"]
	return ("Replay log: " if seen else "Read log: ") + str(i.get("title", "Log"))

func interact(_p: Player) -> void:
	var first := Game.add_log(log_id)
	Sfx.play("log_pickup", -4.0)
	Sfx.say("log%02d" % log_id, true)
	if first:
		var i := _info()
		Events.message.emit("Log added: %s  ·  %s" % [i.get("title", ""), "LOGS to read" if Game.touch_enabled() else "TAB to read"], 3.0)
		if Game.state["logs"].size() == 1:
			get_tree().create_timer(maxf(6.0, Sfx.voice.stream.get_length() if Sfx.voice.stream else 6.0) + 0.5, false).timeout.connect(func(): Sfx.say("mira_log"))
	Game.set_flag(done_flag())

func _process(delta: float) -> void:
	_t += delta
	if _glow:
		_glow.light_energy = 0.0 if log_id in Game.state["logs"] else 0.6 + sin(_t * 3.0) * 0.25
