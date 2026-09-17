extends RefCounted
var checks := 0
var failures := 0

func run(game) -> void:
	var directory := ProjectSettings.globalize_path("res://../docs/v61-validation")
	DirAccess.make_dir_recursive_absolute(directory)
	game.hud.get_child(0).hide()
	game.mode_select_panel.open()
	await _settle(game)
	_expect(_capture(game,directory,"01-mode-select.png"),"模式选择截图")
	game.mode_select_panel.close()
	for stage_id: String in ["stage_01","stage_02","stage_03","stage_04","stage_05"]: game.compendium.cleared_stages[stage_id]=true
	game.stage_select_panel.open()
	await _settle(game)
	_expect(_capture(game,directory,"02-stage-select.png"),"选关页面截图")
	game.stage_select_panel.close()
	for id: String in game.sim.database.characters: game.compendium.unlocked_characters[id]=true
	var squad:Array[String]=["traveler","hero_01","hero_02"]
	game.squad_panel.open("stage_01",squad,[])
	await _settle(game)
	_expect(_capture(game,directory,"03-squad-scroll.png"),"可滚动选角页截图")
	game.squad_panel._open_detail("hero_03")
	await _settle(game)
	_expect(game.squad_panel.detail_panel.visible,"角色详情已打开")
	_expect(_capture(game,directory,"04-character-detail.png"),"角色详情截图")
	game.squad_panel.root.hide()
	_expect(game.begin_dialogue("mode1_opening"),"剧情场景打开")
	await game.get_tree().create_timer(0.72).timeout
	_expect(_capture(game,directory,"05a-dialogue-booper.png"),"剧情点击推进提示截图")
	var dialogue_index_before: int = int(game.dialogue.director.index)
	_expect(game.dialogue.activate_choice_at(Vector2(640, 520)),"点击对话画面触发推进")
	await game.get_tree().process_frame
	_expect(game.dialogue.director.index > dialogue_index_before,"点击画面确实进入下一句")
	game.dialogue.advance()
	await game.get_tree().create_timer(0.34).timeout
	_expect(_capture(game,directory,"05-dialogue-choice.png"),"剧情选项与booper截图")
	game.dialogue.hide()
	game.hud.get_child(0).show()
	game.sim.reset_stage("stage_01",squad,6101); game.sim.start(); game.sim.state="running"; game.selected_id=0;
	for hero: Dictionary in game.sim.heroes: hero.deployed=true
	game.hud.signature=""; game.refresh(); game.hud.overlay.hide()
	await _settle(game)
	_expect(_capture(game,directory,"06-battle-hud.png"),"战斗HUD截图")
	game.sim.state="paused"; game.hud.signature=""; game.refresh(); game.hud.overlay.show(); game.hud.modal_card.hide(); game.hud.pause_details.show(); game.hud.refresh_pause_details(game.sim)
	await _settle(game)
	_expect(_capture(game,directory,"07-pause-panel.png"),"暂停页截图")
	game.sim.reset_stage("stage_endless",squad,6102); game.sim.start(); game.sim.state="running"; game.battle.camera_center=game.sim.ENDLESS_ARENA.get_center(); game.hud.signature=""; game.refresh(); game.hud.overlay.hide()
	await _settle(game)
	_expect(_capture(game,directory,"08-endless-map.png"),"无尽地图截图")
	print("V61 VISUAL QA COMPLETE: %d checks, %d failures -> %s"%[checks,failures,directory])
	game.get_tree().quit(failures)
func _expect(ok:bool,message:String)->void:
	checks+=1
	if ok: print("V61 PASS: "+message)
	else: failures+=1; push_error("V61 FAIL: "+message)
func _settle(game)->void:
	RenderingServer.force_draw(); await game.get_tree().process_frame; await game.get_tree().create_timer(0.14).timeout; RenderingServer.force_draw()
func _capture(game,directory:String,file_name:String)->bool:
	var image:Image=game.get_viewport().get_texture().get_image()
	if image==null:return false
	if image.get_size()!=Vector2i(1920,1080):image.resize(1920,1080,Image.INTERPOLATE_LANCZOS)
	return image.save_png(directory.path_join(file_name))==OK
