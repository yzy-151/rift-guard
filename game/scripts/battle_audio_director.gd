extends Node
## Forward one drained event batch. Music and the SFX settings bus remain external.
const Profile = preload("res://scripts/battle_audio_profile.gd")
const MAX_SFX: int = 12
const MAX_QUEUED: int = 32
const MAX_VOICE_QUEUE: int = 4
var profile = Profile.new()
var enabled: bool = true
var playback_enabled: bool = true
var clock: float = 0.0
var duck_db: float = 0.0
var active_sfx: Array[Dictionary] = []
var voice: Dictionary = {}
var queued: Array[Dictionary] = []
var last_played: Dictionary = {}
var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var voice_player: AudioStreamPlayer
var played: int = 0
var dropped: int = 0

func _ready() -> void:
	_ensure_players()

func preview_event(event: Dictionary, sim = null) -> Array[Dictionary]:
	return profile.describe(event, sim)

func handle_events(events: Array, sim = null) -> void:
	if not enabled: return
	for event: Dictionary in events:
		for cue: Dictionary in profile.describe(event, sim):
			var key: String = str(cue.dedupe_key)
			if clock - float(last_played.get(key,-1000.0)) < float(cue.min_interval):
				dropped += 1
				continue
			last_played[key] = clock
			cue["at"] = clock + float(cue.get("delay",0.0))
			cue["expires"] = clock + (3.5 if cue.category == "voice" else 0.6)
			if queued.size() < MAX_QUEUED:
				queued.append(cue)
			else:
				dropped += 1
	_flush_queue()

func _process(dt: float) -> void:
	advance(dt)

func advance(dt: float) -> void:
	clock += maxf(0.0,dt)
	for index in range(active_sfx.size()-1,-1,-1):
		active_sfx[index].remaining -= dt
		if float(active_sfx[index].remaining) <= 0.0:
			_stop_slot(int(active_sfx[index].slot))
			active_sfx.remove_at(index)
	if not voice.is_empty():
		voice.remaining -= dt
		if float(voice.remaining) <= 0.0:
			voice.clear()
			if is_instance_valid(voice_player): voice_player.stop()
	_flush_queue()
	var target: float = -7.5 if not voice.is_empty() else 0.0
	duck_db = move_toward(duck_db,target,dt*(85.0 if target < duck_db else 15.0))
	if playback_enabled:
		var bus: int = AudioServer.get_bus_index("BattleFX")
		if bus >= 0: AudioServer.set_bus_volume_db(bus,duck_db)

func _flush_queue() -> void:
	queued.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return int(a.priority)>int(b.priority))
	var retained: Array[Dictionary] = []
	var waiting_voices: int = 0
	for cue: Dictionary in queued:
		if clock > float(cue.expires):
			dropped += 1
			continue
		if clock < float(cue.at):
			retained.append(cue)
			continue
		if cue.category == "voice":
			if not voice.is_empty() and int(voice.priority) >= int(cue.priority):
				if waiting_voices < MAX_VOICE_QUEUE:
					retained.append(cue)
					waiting_voices += 1
				else: dropped += 1
				continue
			voice = cue.duplicate(true)
			voice["remaining"] = float(cue.duration)
			_play(cue,-1)
		else:
			var slot: int = _available_slot()
			if slot < 0:
				var weakest: int = -1
				for i in active_sfx.size():
					if int(active_sfx[i].priority) < int(cue.priority) and (weakest < 0 or int(active_sfx[i].priority) < int(active_sfx[weakest].priority)): weakest = i
				if weakest < 0:
					dropped += 1
					continue
				slot = int(active_sfx[weakest].slot)
				_stop_slot(slot)
				active_sfx.remove_at(weakest)
			active_sfx.append({"slot":slot,"remaining":float(cue.duration),"priority":int(cue.priority),"key":str(cue.key)})
			_play(cue,slot)
	queued = retained

func _available_slot() -> int:
	for slot in MAX_SFX:
		if not active_sfx.any(func(c:Dictionary)->bool:return int(c.slot)==slot): return slot
	return -1

func _play(cue: Dictionary, slot: int) -> void:
	played += 1
	if not playback_enabled: return
	_ensure_players()
	var path: String = str(cue.path)
	if not streams.has(path):
		# Raw loader supports developer tests before the root's single editor import.
		streams[path] = load(path) if ResourceLoader.exists(path) else AudioStreamOggVorbis.load_from_file(path)
	var stream: AudioStream = streams[path]
	if stream == null:
		dropped += 1
		return
	var player: AudioStreamPlayer = voice_player if slot < 0 else players[slot]
	player.stop()
	player.stream = stream
	player.volume_db = clampf(float(cue.volume_db),-30.0,0.0)
	player.pitch_scale = 1.0
	player.play()

func _ensure_players() -> void:
	if not playback_enabled or not players.is_empty(): return
	for name in ["SFX","BattleMix","BattleFX","BattleVoice"]:
		if AudioServer.get_bus_index(name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,name)
		if name != "SFX": AudioServer.set_bus_send(AudioServer.get_bus_index(name),"SFX" if name == "BattleMix" else "BattleMix")
	var mix_bus: int = AudioServer.get_bus_index("BattleMix")
	if AudioServer.get_bus_effect_count(mix_bus) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -3.0
		limiter.pre_gain_db = 0.0
		limiter.release = 0.16
		AudioServer.add_bus_effect(mix_bus,limiter)
	for i in MAX_SFX:
		var player := AudioStreamPlayer.new()
		player.bus = "BattleFX"
		add_child(player)
		players.append(player)
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "BattleVoice"
	add_child(voice_player)

func _stop_slot(slot: int) -> void:
	if slot >= 0 and slot < players.size(): players[slot].stop()

func set_enabled(value: bool) -> void:
	enabled = value
	if not value: reset()

func reset() -> void:
	for player in players: player.stop()
	if is_instance_valid(voice_player): voice_player.stop()
	active_sfx.clear()
	voice.clear()
	queued.clear()
	last_played.clear()
	duck_db = 0.0
	var bus: int = AudioServer.get_bus_index("BattleFX")
	if bus >= 0: AudioServer.set_bus_volume_db(bus,0.0)

func debug_snapshot() -> Dictionary:
	return {"active_sfx":active_sfx.size(),"voice_key":str(voice.get("key","")),"queued":queued.size(),"duck_db":duck_db,"played":played,"dropped":dropped,"enabled":enabled}
