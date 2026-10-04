extends Node
const Simulation = preload("res://starfall/simulation.gd")
const Catalog = preload("res://starfall/catalog.gd")
const SAVE_PATH := "user://starfall_profile.json"
@onready var arena = $Arena
@onready var ui = $Interface/UI
@onready var music: AudioStreamPlayer = $Music
var sim = Simulation.new()
var settings := {"volume":65.0,"reduced_fx":false,"shake":true,"fullscreen":false}
var records := {"wins":0,"best_wave":0,"best_kills":0,"runs":0}
var paused := false
var running := false
var last_phase := ""
var last_run := {"mode":"campaign","squad":["traveler","hero_03","hero_08"]}
var move_target := Vector2.ZERO
var click_moving := false
var last_aim := Vector2(1100,640)
var last_battle_mouse := Vector2(800,360)
var settings_origin := "title"
var loading := false
var hitstop := 0.0
var voices: Array[AudioStreamPlayer] = []
var sounds: Dictionary = {}
var sound_gate := 0.0
var qa_mode := ""
var qa_dir := ""
var qa_frame := 0
var qa_capturing := false
var qa_trace: Array = []
var shutting_down := false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_load_profile()
	_apply_settings()
	arena.sim = sim
	ui.action.connect(_on_action)
	for i in range(10):
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	sounds = {
		"click":load("res://assets/helltaker/audio/button_menu_confirm_01.wav"),
		"hit":load("res://assets/sfx/combat_hit.wav"),
		"q":load("res://assets/sfx/heroes/furina_splash.wav"),
		"e":load("res://assets/sfx/heroes/neutral_starfall.wav"),
		"dash":load("res://assets/sfx/heroes/neutral_slash.wav"),
		"level":load("res://assets/helltaker/audio/dialogue_success_01.wav"),
		"boss":load("res://assets/sfx/boss/boss_warning_eva.wav")}
	music.stream = load("res://assets/helltaker/audio/Epitomize.ogg")
	music.volume_db = -19
	music.finished.connect(func():music.play())
	music.play()
	show_title()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--starfall-qa="): qa_mode = arg.get_slice("=",1)
		if arg.begins_with("--capture-dir="): qa_dir = arg.trim_prefix("--capture-dir=")
	if not qa_mode.is_empty():
		settings.fullscreen = false
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1280,720))
		if not qa_dir.is_empty(): DirAccess.make_dir_recursive_absolute(qa_dir)
	if qa_mode=="campaign": call_deferred("_start_campaign_check")

func _start_campaign_check() -> void:
	set_process(false)
	set_physics_process(false)
	add_child(load("res://starfall/tests/render_campaign.gd").new())

func show_title() -> void:
	running = false
	paused = false
	click_moving = false
	arena.menu = true
	arena.set_process(true)
	arena.reset()
	ui.show_title(records)
	last_phase = "title"

func start_run(data: Dictionary) -> void:
	if loading: return
	loading = true
	running = false
	ui.show_loading()
	await arena.warm_up(data.squad)
	loading = false
	last_run = data.duplicate(true)
	sim.start(str(data.mode),data.squad,0)
	running = true
	paused = false
	click_moving = false
	last_phase = "battle"
	hitstop = 0
	arena.menu = false
	arena.set_process(true)
	arena.reset()
	arena.camera = Vector2(960,700)
	ui.build_hud(sim)
	ui.toast("守住月泉  ·  Q 技能 / E 终结技 / Shift 闪避")

func _physics_process(dt: float) -> void:
	sound_gate = maxf(0,sound_gate-dt)
	if not running or paused or sim.phase!="battle": return
	if hitstop>0:
		hitstop = maxf(0,hitstop-dt)
		return
	var direction := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	if direction.length_squared()>0.01: click_moving = false
	if click_moving:
		var delta: Vector2 = move_target-sim.heroes[sim.selected].pos
		if delta.length()>12: direction = delta.normalized()
		else: click_moving = false
	last_aim = arena.screen_to_world(last_battle_mouse)
	var aim: Vector2 = last_aim
	if qa_mode=="gallery" or qa_mode=="soak":
		direction = Vector2(cos(sim.time*0.51),sin(sim.time*0.69))
		if not sim.enemies.is_empty(): aim = sim.enemies[0].pos
		if int(sim.time*60)%80==0: sim.cast("q",aim)
		if int(sim.time*60)%130==0: sim.cast("e",aim)
		if int(sim.time*60)%110==0: sim.dash(direction)
	sim.step(dt,direction.normalized(),aim)
	var events: Array = sim.drain_events()
	arena.accept(events)
	play_events(events)
	ui.update_hud(sim)
	_sync_phase()

func _sync_phase() -> void:
	if sim.phase==last_phase: return
	last_phase = sim.phase
	if sim.phase=="upgrade":
		ui.show_draft(sim)
		arena.set_process(false)
		_play("level",-10)
	elif sim.phase in ["won","lost"]:
		var record: bool = sim.mode=="endless" and sim.wave>int(records.best_wave)
		records.runs = int(records.runs)+1
		if sim.phase=="won": records.wins = int(records.wins)+1
		if sim.mode=="endless": records.best_wave = maxi(int(records.best_wave),sim.wave)
		records.best_kills = maxi(int(records.best_kills),sim.kills)
		_save_profile()
		ui.show_result(sim,record)
		_play("level",-8)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and running and not paused and sim.phase=="battle":
		if event.position.y>110 and event.position.y<584:
			last_battle_mouse = event.position
			last_aim = arena.screen_to_world(event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode==KEY_F11:
			settings.fullscreen = not settings.fullscreen
			_apply_settings()
			_save_profile()
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode==KEY_ESCAPE and ui.page=="settings":
			_on_action("settings_back",settings_origin)
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode in [KEY_ESCAPE,KEY_SPACE] and running and sim.phase=="battle":
			if ui.page=="settings":
				_on_action("settings_back",settings_origin)
			elif sim.phase=="battle": _toggle_pause()
			get_viewport().set_input_as_handled()
			return

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if not running or paused or sim.phase!="battle": return
		match event.physical_keycode:
			KEY_1: sim.select_hero(0)
			KEY_2: sim.select_hero(1)
			KEY_3: sim.select_hero(2)
			KEY_Q: _cast("q")
			KEY_E: _cast("e")
			KEY_SHIFT: _dash()
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_RIGHT and running and not paused and sim.phase=="battle":
		move_target = arena.screen_to_world(event.position)
		click_moving = true
		arena.add_effect("rune",move_target,Color("81e0c5"),0.4,19)

func _cast(slot: String) -> void:
	var target: Vector2 = arena.screen_to_world(last_battle_mouse)
	if sim.cast(slot,target):
		_play(slot,-12)
		if slot=="e":
			hitstop = 0.065
			arena.flash = 0.11
			arena.shake = 7.0
	else: ui.toast("技能正在冷却" if slot=="q" else "终结技能量尚未满盈")

func _dash() -> void:
	var dir := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
	if dir.length_squared()<0.01: dir = sim.heroes[sim.selected].pos.direction_to(arena.screen_to_world(last_battle_mouse))
	if sim.dash(dir.normalized()):
		click_moving = false
		_play("dash",-14)

func _toggle_pause() -> void:
	paused = not paused
	arena.set_process(not paused)
	if paused: ui.show_pause()
	else: ui.close_modal()

func _on_action(name: String, value: Variant) -> void:
	match name:
		"ui_click": _play("click",-11)
		"title": show_title()
		"start": start_run(value)
		"retry": start_run(last_run)
		"select":
			if running and not paused and sim.phase=="battle": sim.select_hero(int(value))
		"q","e":
			if running and not paused and sim.phase=="battle": _cast(name)
		"dash":
			if running and not paused and sim.phase=="battle": _dash()
		"upgrade":
			if sim.choose_upgrade(str(value)):
				ui.close_modal()
				last_phase = "battle"
				arena.set_process(true)
				_sync_phase()
		"reroll":
			if sim.reroll(): ui.show_draft(sim)
			else: ui.toast("这次星象已重绘过")
		"pause","resume":
			if running and sim.phase=="battle": _toggle_pause()
		"abandon": show_title()
		"settings":
			settings_origin = str(value)
			ui.show_settings(settings,settings_origin)
		"settings_back":
			_save_profile()
			if str(value)=="pause": ui.show_pause()
			else: show_title()
		"setting":
			settings[str(value.key)] = value.value
			_apply_settings()
		"legacy":
			music.stop()
			for voice in voices: voice.stop()
			await get_tree().create_timer(0.12).timeout
			get_tree().change_scene_to_file("res://main.tscn")

func _apply_settings() -> void:
	var volume: float = float(settings.volume)/100.0
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,volume)))
	AudioServer.set_bus_mute(0,volume<=0)
	arena.reduced_fx = bool(settings.reduced_fx)
	arena.shake_enabled = bool(settings.shake)
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if bool(settings.fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED)

func _load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH): return
	var file := FileAccess.open(SAVE_PATH,FileAccess.READ)
	if file==null: return
	var data: Variant = JSON.parse_string(file.get_as_text())
	if data is Dictionary:
		if data.get("settings") is Dictionary:
			for key in settings:
				var v: Variant = data.settings.get(key,settings[key])
				if key=="volume" and (v is float or v is int): settings[key] = clampf(float(v),0,100)
				elif v is bool: settings[key] = v
		if data.get("records") is Dictionary:
			for key in records:
				var v: Variant = data.records.get(key,0)
				if v is float or v is int: records[key] = maxi(0,int(v))

func _save_profile() -> void:
	# A separate profile leaves the original V86 campaign saves untouched.
	if not qa_mode.is_empty(): return
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file==null:
		ui.toast("战绩未能保存，请检查存档目录权限")
		return
	file.store_string(JSON.stringify({"version":1,"settings":settings,"records":records},"\t"))

func _play(key: String, db: float = -12) -> void:
	if not sounds.has(key): return
	for voice in voices:
		if not voice.playing:
			voice.stream = sounds[key]
			voice.volume_db = db
			voice.pitch_scale = randf_range(0.94,1.06) if key=="hit" else 1.0
			voice.play()
			return

func play_events(events: Array) -> void:
	for e in events:
		match str(e.type):
			"hit":
				if bool(e.get("crit",false)): hitstop = maxf(hitstop,0.025)
				if sound_gate<=0:
					_play("hit",-25)
					sound_gate = 0.075
			"wave": ui.toast("裂隙涌动  ·  第 %d 波" % sim.wave)
			"boss":
				_play("boss",-18)
				ui.toast("裂隙统领降临  ·  观察预警，寻找破绽")

func _process(_dt: float) -> void:
	if qa_mode.is_empty(): return
	qa_frame += 1
	if qa_mode=="smoke":
		if qa_frame==15: start_run(last_run)
		if sim.phase=="upgrade" and not sim.upgrade_choices.is_empty():
			_on_action("upgrade",sim.upgrade_choices[0].id)
		if running and sim.time>=8.0:
			print("STARFALL_SMOKE_PASS time=",sim.time," enemies=",sim.enemies.size()," heroes=",sim.heroes.size())
			_shutdown()
	elif qa_mode=="gallery":
		if qa_frame==50: _capture("01-title")
		if qa_frame==75: ui.show_party("campaign")
		if qa_frame==105: _capture("02-party")
		if qa_frame==135: start_run(last_run)
		if qa_frame==460: _capture("03-battle")
		if qa_frame==495:
			sim.grant_xp(sim.xp_needed+1)
			_sync_phase()
		if qa_frame==525: _capture("04-upgrade")
		if qa_frame==555 and sim.phase=="upgrade": _on_action("upgrade",sim.upgrade_choices[0].id)
		if qa_frame==585:
			sim.spawn_enemy("boss_01",sim.heroes[sim.selected].pos+Vector2(220,-100))
			sim.heroes[sim.selected].energy = 100
			sim.cast("e",sim.heroes[sim.selected].pos+Vector2(180,0))
		if qa_frame==625: _capture("05-boss")
		if qa_frame==655: _toggle_pause()
		if qa_frame==680: _capture("06-pause")
		if qa_frame==705: ui.show_settings(settings,"pause")
		if qa_frame==730: _capture("07-settings")
		if qa_frame==750:
			ui.close_modal()
			paused = false
			sim.core_hp = 0
			arena.set_process(true)
		if qa_frame==795: _capture("08-result")
		if qa_frame>=835 and not qa_capturing:
			print("STARFALL_GALLERY_PASS ",JSON.stringify(qa_trace))
			_shutdown()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST: _shutdown()

func _exit_tree() -> void:
	get_tree().auto_accept_quit = true

func _shutdown() -> void:
	if shutting_down: return
	shutting_down = true
	set_process(false)
	set_physics_process(false)
	music.stop()
	for voice in voices: voice.stop()
	# Let the audio thread release active playback before tearing down resources.
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()

func _capture(label: String) -> void:
	if qa_dir.is_empty() or DisplayServer.get_name()=="headless": return
	qa_capturing = true
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := qa_dir.path_join(label+".png")
	var result := image.save_png(path)
	qa_trace.append({"page":label,"saved":result==OK})
	print("CAPTURE ",label," ",result)
	qa_capturing = false
