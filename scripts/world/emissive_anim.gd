class_name EmissiveAnim
extends Node
## Animates the emission of shared materials: "pulse" breathes slowly (alien crystal), "flicker" is a failing light
## strip (mostly on, with short random drop-outs and stutters). Materials are shared by every MultiMesh instance of
## the piece, so all instances in an area move together; cost is a few property writes per frame.

var _mats: Array = []   # [{mat, mode, base}]
var _t := 0.0
var _rng := RandomNumberGenerator.new()
var _off_until := 0.0
var _next_glitch := 0.0

func add(m: BaseMaterial3D, mode: String) -> void:
	_mats.append({"mat": m, "mode": mode, "base": m.emission_energy_multiplier})

func count() -> int:
	return _mats.size()

func _ready() -> void:
	_rng.seed = 4242
	_next_glitch = _rng.randf_range(1.5, 4.0)

func _process(delta: float) -> void:
	_t += delta
	# flicker state machine: steady, then a burst of 1-4 short drop-outs
	if _t >= _next_glitch:
		_off_until = _t + _rng.randf_range(0.04, 0.16)
		_next_glitch = _t + (_rng.randf_range(0.08, 0.3) if _rng.randf() < 0.6 else _rng.randf_range(1.5, 5.0))
	var lit := 0.12 if _t < _off_until else 1.0
	for e in _mats:
		var m: BaseMaterial3D = e["mat"]
		var base: float = e["base"]
		if e["mode"] == "pulse":
			m.emission_energy_multiplier = base * (0.7 + 0.3 * (0.5 + 0.5 * sin(_t * 1.6)) + 0.08 * sin(_t * 5.3))
		else:
			m.emission_energy_multiplier = base * lit
