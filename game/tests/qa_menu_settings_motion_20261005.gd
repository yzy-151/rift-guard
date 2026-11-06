extends SceneTree
const MOTION = preload("res://scripts/poster_motion.gd")
const LAYOUT = preload("res://data/ui_layout_profile.tres")
var app
var checks := 0
var failures: Array[String] = []
var closed_count := 0

func _initialize() -> void: run.call_deferred()

func check(ok: bool, label: String) -> void:
	checks += 1
	print(("PASS " if ok else "FAIL ") + label)
	if not ok: failures.append(label)

func settle(owner: Node, amount := 1.0) -> void:
	var tween: Tween = MOTION.active(owner)
	if tween != null:
		tween.pause()
		tween.custom_step(amount)

func run() -> void:
	app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await process_frame
	app.test_mode = true
	app.process_mode = Node.PROCESS_MODE_DISABLED
	var menu = app.mode_select_panel
	for index in 12:
		menu.open()
		var left: Button = menu.buttons.rift_watch
		check(left.position.x < LAYOUT.mode_campaign_rect.position.x - 60 and menu.portrait.modulate.a == 0, "menu entrance separates paper and portrait layers %d" % index)
		settle(menu)
		check(left.get_rect().is_equal_approx(LAYOUT.mode_campaign_rect) and menu.portrait.get_rect().is_equal_approx(LAYOUT.mode_portrait_rect), "menu entrance preserves exact geometry and portrait crop %d" % index)
		menu.close()
	var settings = app.settings_panel
	settings.closed.connect(func(): closed_count += 1)
	var values := {"master": .31, "music": .67, "sfx": .92, "reduced_effects": false}
	settings.open(values)
	settle(settings)
	for name: String in settings.sliders:
		var slider: HSlider = settings.sliders[name]
		check(slider.get_global_rect().position.x == LAYOUT.settings_frame_rect.position.x + LAYOUT.settings_slider_origin.x and slider.get_global_rect().end.x < 1208, "animated slider retains global input geometry " + name)
	check(settings.value_labels.master.text == "31%" and settings.value_labels.music.text == "67%", "animation preserves supplied volume state")
	for index in 12:
		settings.open(values)
		settle(settings, .10)
		settings.close()
		var cancelled: Tween = settings.closing_tween
		cancelled.pause()
		settings.open(values)
		cancelled.custom_step(.5)
		check(settings.is_open() and closed_count == 0, "reopening prevents a stale close callback from hiding settings %d" % index)
		settle(settings)
		check(settings.portrait.get_rect().position.is_equal_approx(LAYOUT.settings_portrait_rect.position + Vector2(5, 5)) and settings.close_button.get_rect().is_equal_approx(LAYOUT.settings_close_rect), "settings layers settle without cumulative drift %d" % index)
	settings.close()
	settings.closing_tween.pause()
	settings.closing_tween.custom_step(.2)
	check(not settings.is_open() and closed_count == 1, "normal settings close emits one return event")
	values.reduced_effects = true
	settings.open(values)
	check(settings.sliders.master.get_parent().position == LAYOUT.settings_slider_origin - Vector2(16, 11), "low effects skips slider translation")
	settle(settings, .2)
	check(settings.portrait.modulate.a > .99, "low effects retains a short completed reveal")
	for player: Node in app.find_children("*", "AudioStreamPlayer", true, false): player.stop(); player.stream = null
	app.queue_free(); app = null
	await process_frame; await process_frame; await create_timer(.12).timeout
	print("MENU SETTINGS MOTION QA: %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)
