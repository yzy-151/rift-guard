extends SceneTree
## Root owns the native window; this fixture is run only when its capture slot is free.
const OUT := "res://../qa/hero_skill_vfx_20261005"
var app
var frame_index := 0
var manifest: Array[Dictionary] = []

func _initialize() -> void: run.call_deferred()

func capture(key: String, marks: Array[String]) -> void:
	app.battle.queue_redraw()
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_texture().get_image()
	picture.resize(1280,720,Image.INTERPOLATE_LANCZOS)
	picture.save_png(OUT + "/frames/frame-%04d.png" % frame_index)
	for mark: String in marks: picture.save_png(OUT + "/" + key + "-" + mark + ".png")
	frame_index += 1

func setup(character: String) -> void:
	var squad: Array[String] = [character, "traveler"]
	app.sim.reset_stage("stage_02", squad, 20261005)
	app.sim.start()
	app.sim.enemies.clear(); app.sim.enemy_lookup.clear(); app.sim.terrain_features.clear()
	app.battle.reset_transients()
	for index in app.sim.heroes.size():
		var hero: Dictionary = app.sim.heroes[index]
		hero.deployed = true; hero.pos = Vector2(430 + index * 140, 350 + index * 30); hero.target = hero.pos
		hero.energy = hero.max_energy; hero.hp = float(hero.max_hp) * .45
	for point in [Vector2(715,350), Vector2(815,350), Vector2(880,350), Vector2(785,290), Vector2(785,425)]:
		var enemy: Dictionary = app.sim.spawn_enemy(point, "grunt")
		enemy.hp = 100000; enemy.max_hp = enemy.hp; enemy.armor = 0; enemy.shield = 0
	app.sim.drain_events(); app.selected_id = 0; app.refresh()

func run() -> void:
	if DisplayServer.get_name() == "headless": quit(1); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT + "/frames"))
	app = load("res://main.tscn").instantiate(); root.add_child(app)
	await process_frame; await process_frame
	app.test_mode = true; app.set_process(false); app.set_physics_process(false)
	app.mode_select_panel.close(); app.stage_select_panel.close(); app.squad_panel.root.hide(); app.dialogue.hide()
	app.hud.get_child(0).show()
	for character in ["hero_03", "hero_13"]:
		for ultimate in [false, true]:
			setup(character)
			var key: String = ("furina" if character == "hero_03" else "gwen") + ("_e" if ultimate else "_q")
			var target := Vector2(755,350)
			var ability: Dictionary = app.sim.hero_ability(0,ultimate)
			var accepted: bool = app.sim.activate_hero_ultimate(0,target) if ultimate else app.sim.activate_hero_skill(0,target)
			if not accepted: push_error("Cast rejected " + key); quit(1); return
			var batch: Array[Dictionary] = app.sim.drain_events()
			var hit_delay := .34
			for event: Dictionary in batch:
				if event.kind in ["skill_cast", "ultimate_cast"]: hit_delay = float(event.get("hit_delay",.34))
			app.battle.accept_events(batch)
			var first_hit := -1.0
			var first_shot := false
			var marks_done: Dictionary = {}
			var begin := frame_index
			# 120 Hz mechanics and view time; PNG frames at 24 Hz, exact requested peak times.
			for tick in 480:
				var dt := 1.0 / 120.0
				app.sim.elapsed += dt
				app.sim._pending_impact_tick(dt); app.sim._skill_effect_tick(dt)
				var events: Array[Dictionary] = app.sim.drain_events()
				app.battle.accept_events(events); app.battle.advance(dt); app.refresh()
				var time := float(tick + 1) / 120.0
				for event: Dictionary in events:
					if first_hit < 0.0 and event.kind in ["signature_salon_hit", "signature_needle_hit"]: first_hit = time
				var marks: Array[String] = []
				for stage: String in ["cast", "impact", "hit"]:
					var origin := 0.0 if stage == "cast" else hit_delay if stage == "impact" else first_hit
					if origin < 0.0: continue
					for peak in [.08,.18,.32]:
						var mark: String = stage + "-%03dms" % roundi(peak * 1000)
						if not marks_done.has(mark) and time >= origin + peak:
							marks.append(mark); marks_done[mark] = time
				if not first_shot:
					for zone: Dictionary in app.sim.skill_effects:
						if str(zone.kind) in ["salon_summon", "needle_barrage"] and zone.get("shots",[]).any(func(shot: Dictionary) -> bool: return not bool(shot.get("done",false)) and float(shot.get("age",0)) > .1):
							marks.append("projectile"); first_shot = true
				if tick % 5 == 0 or not marks.is_empty(): await capture(key,marks)
			manifest.append({"key":key,"skill":ability.get("name",key),"start":begin,"end":frame_index,"mechanic_dt":1.0/120.0,"frame_fps":24,"first_hit":first_hit,"peak_capture_times":marks_done})
			print("HERO REAL DRAW ", key, " frames=", frame_index-begin, " first_hit=", first_hit)
	var file := FileAccess.open(OUT + "/manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t")); file.close()
	app.queue_free(); await process_frame; app = null; await process_frame
	print("HERO CAPTURE COMPLETE ", frame_index)
	quit(0)
