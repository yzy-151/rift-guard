extends Node

const SAVE_PATH := "user://settings.json"
const TRACKS := {
	"menu": preload("res://assets/helltaker/audio/Epitomize.ogg"),
	"dialogue": preload("res://assets/helltaker/audio/Vitality.ogg"),
	"battle": preload("res://assets/helltaker/audio/Vitality.ogg"),
	"endless": preload("res://assets/helltaker/audio/Titanium.ogg")
}

var values := {
	"master": 0.82,
	"music": 0.46,
	"sfx": 0.90,
	"fullscreen": false,
	"reduced_effects": false
}
var save_path := SAVE_PATH
var music_player: AudioStreamPlayer
var current_scene := ""
var combat_duck_db := 0.0

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	var sfx_bus := AudioServer.get_bus_index("SFX")
	if AudioServer.get_bus_effect_count(sfx_bus)==0:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1.0
		AudioServer.add_bus_effect(sfx_bus,limiter)
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	_load_settings()
	if OS.get_name() == "Android": values.fullscreen = true
	_apply_levels()
	if DisplayServer.get_name().to_lower() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(values.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED)

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0:
		return
	AudioServer.add_bus()
	AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)

func set_scene(scene_name: String) -> void:
	var selected_stream: AudioStream = TRACKS.get(scene_name, TRACKS.menu)
	if current_scene == scene_name and music_player.playing:
		return
	current_scene = scene_name
	var stream: AudioStream = selected_stream
	if stream is AudioStreamOggVorbis:
		stream = stream.duplicate()
		stream.loop = true
	music_player.stream = stream
	music_player.play()

func set_setting(key: String, value: Variant) -> void:
	if not values.has(key):
		return
	match key:
		"master", "music", "sfx": values[key] = clampf(float(value), 0.0, 1.0)
		"fullscreen", "reduced_effects": values[key] = bool(value)
	if OS.get_name() == "Android": values.fullscreen = true
	_apply_levels()
	if key == "fullscreen" and DisplayServer.get_name().to_lower() != "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(values.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED)
	_save_settings()

func snapshot() -> Dictionary:
	return values.duplicate(true)

func set_combat_duck(db: float) -> void:
	if is_equal_approx(combat_duck_db,db):return
	combat_duck_db=db
	_set_bus_level("Music",float(values.music))

func _apply_levels() -> void:
	_set_bus_level("Master", float(values.master))
	_set_bus_level("Music", float(values.music))
	_set_bus_level("SFX", float(values.sfx))

func _set_bus_level(bus_name: String, amount: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return
	AudioServer.set_bus_mute(index, amount <= 0.001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.001, amount))+(combat_duck_db if bus_name=="Music" else 0.0))

func _load_settings() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	for key: String in values:
		if parsed.has(key):
			values[key] = parsed[key]

func _save_settings() -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(values, "  "))
