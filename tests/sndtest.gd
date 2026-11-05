extends Node
var cap: AudioEffectCapture
var data := PackedVector2Array()
func _ready() -> void:
	await get_tree().process_frame
	cap = AudioEffectCapture.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("SFX"), cap)
	for i in 15:
		Sfx.play("rifle_fire", -3.0)
		await get_tree().create_timer(0.2).timeout
	await get_tree().create_timer(1.0).timeout
	var mx := 0.0
	for v in data:
		mx = maxf(mx, absf(v.x))
	print("SNDTEST frames ", data.size(), " peak ", linear_to_db(mx), " mixrate ", AudioServer.get_mix_rate(), " driver ", AudioServer.get_driver_name() if AudioServer.has_method("get_driver_name") else "")
	get_tree().quit()
func _process(_d: float) -> void:
	if cap:
		var n := cap.get_frames_available()
		if n > 0:
			data.append_array(cap.get_buffer(n))
