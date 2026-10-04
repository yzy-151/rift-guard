extends SceneTree
## Real AudioStreamPlayer/bus smoke test; --write-movie also records its actual mix.
const Director = preload("res://scripts/battle_audio_director.gd")
var failures: int = 0
var checks: int = 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: "+label)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var director = Director.new()
	root.add_child(director)
	var mixer: int = AudioServer.get_bus_index("BattleMix")
	check(mixer >= 0, "battle voice and effects have a shared safety mixer")
	if mixer >= 0:
		check(AudioServer.get_bus_effect_count(mixer) == 1, "battle mixer contains one limiter")
		var effect: AudioEffect = AudioServer.get_bus_effect(mixer,0)
		check(effect is AudioEffectHardLimiter and effect.ceiling_db <= -3.0, "limiter protects summed battle mix")
	var sim := {"heroes":[{"character_id":"hero_06","element":"electro"}]}
	director.handle_events([{"kind":"deploy","hero_id":0}],sim)
	check(director.voice_player.playing and director.voice_player.stream != null, "deployment plays a decoded AudioStream")
	check(director.players.any(func(p:AudioStreamPlayer)->bool:return p.playing), "deployment effect has a real playing stream")
	for frame in 420:
		if frame == 85: director.handle_events([{"kind":"skill_cast","hero_id":0}],sim)
		if frame == 115: director.handle_events([{"kind":"skill_geometry","hero_id":0,"geometry":{"shape":"line"}}],sim)
		if frame == 145: director.handle_events([{"kind":"skill_impact","hero_id":0}],sim)
		if frame == 220: director.handle_events([{"kind":"slime_bounce"}],sim)
		if frame == 270: director.handle_events([{"kind":"slime_bounce_hit"}],sim)
		if frame == 330: director.handle_events([{"kind":"down","hero_id":0}],sim)
		await process_frame
	check(director.streams.size() >= 8, "independent voice, elemental, creature and body layers loaded")
	director.reset()
	check(not director.voice_player.playing and not director.players.any(func(p:AudioStreamPlayer)->bool:return p.playing), "reset stops actual players")
	director.free()
	# The audio server retires stopped Ogg playbacks on its mixing thread.
	# Give it real wall time even when --fixed-fps runs the test faster than realtime.
	OS.delay_msec(120)
	await process_frame
	print("V91 AUDIO PLAYBACK checks=%d failures=%d" % [checks,failures])
	quit(0 if failures == 0 else 1)
