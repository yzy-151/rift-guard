extends RefCounted
## Real viewport input and native captures for the character-led pause presentation.
const Icons = preload("res://scripts/content/generated_icon_catalog.gd")
var game
var tree: SceneTree
var output := ""
var requested_size := Vector2i(1280,720)
var failures: Array[String] = []
var checks := 0
var snapshots: Array[Dictionary] = []

func check(ok: bool, message: String) -> void:
	checks += 1
	print("V95 PAUSE %s: %s" % ["PASS" if ok else "FAIL",message])
	if not ok: failures.append(message)

func key(code: Key, target: Viewport = null) -> void:
	var viewport: Viewport = game.get_viewport() if target == null else target
	for down: bool in [true,false]:
		var event := InputEventKey.new()
		event.keycode=code; event.physical_keycode=code; event.pressed=down
		viewport.push_input(event,true)
		await tree.process_frame

func click(button: Control) -> void:
	var point := button.get_global_transform() * (button.size*0.5)
	var motion := InputEventMouseMotion.new()
	motion.position=point; motion.global_position=point
	game.get_viewport().push_input(motion,true)
	await tree.process_frame
	for down: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.position=point; event.global_position=point
		event.button_index=MOUSE_BUTTON_LEFT; event.pressed=down
		game.get_viewport().push_input(event,true)
		await tree.process_frame

func capture(name: String) -> void:
	game.refresh()
	await tree.process_frame
	await tree.process_frame
	if DisplayServer.get_name()=="headless": return
	await RenderingServer.frame_post_draw
	var picture: Image=game.get_viewport().get_texture().get_image()
	check(picture.get_size()==requested_size,"native capture has exact requested resolution: "+name)
	check(picture.save_png(output.path_join(name+".png"))==OK,"save native capture: "+name)

func node_count(node: Node) -> int:
	var count := 1
	for child: Node in node.get_children(): count+=node_count(child)
	return count

func visible_copy(node: Node) -> String:
	var value := ""
	if node is CanvasItem and not node.is_visible_in_tree(): return value
	if node is Label or node is Button: value+=node.text+"\n"
	for child: Node in node.get_children(): value+=visible_copy(child)
	return value

func fixture() -> void:
	game.mode_select_panel.close(); game.stage_select_panel.close()
	game.squad_panel.root.hide(); game.dialogue.root.hide(); game.story.reset()
	game.campaign_map_panel.root.hide(); game.campaign_event_panel.root.hide()
	game.hud.get_child(0).show()
	var squad: Array[String]=["traveler","hero_03","hero_04"]
	game.sim.reset_stage("stage_02",squad,95005); game.sim.start()
	game.sim.enemies.clear(); game.sim.run_state.crystal_level=8
	game.sim.heroes[0].hp*=0.8; game.sim.heroes[2].hp*=0.43
	game.sim.heroes[0].deployed=true; game.sim.heroes[1].deployed=true; game.sim.heroes[2].deployed=false
	game.sim.heroes[0].pos=Vector2(520,380); game.sim.heroes[1].pos=Vector2(660,370)
	game.selected_id=1; game.battle.selected_id=1
	game.hud.signature=""; game.refresh()

func run(target: Node) -> int:
	game=target; tree=game.get_tree()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa-output="): output=arg.trim_prefix("--qa-output=")
		if arg.begins_with("--qa-size="):
			var parts := arg.trim_prefix("--qa-size=").split("x")
			requested_size=Vector2i(int(parts[0]),int(parts[1]))
	if not output.is_absolute_path():
		printerr("V95 PAUSE requires absolute --qa-output"); return 2
	DirAccess.make_dir_recursive_absolute(output)
	await tree.process_frame
	game.test_mode=true; game.set_process(false); game.set_physics_process(false)
	await tree.create_timer(0.3).timeout
	if DisplayServer.get_name()!="headless":
		tree.root.mode=Window.MODE_WINDOWED; tree.root.borderless=true
		await tree.process_frame
		tree.root.size=requested_size
		await tree.create_timer(0.15).timeout
	check(game.qa_storage_path.begins_with(output),"saves isolated beneath QA output")
	fixture()
	await key(KEY_SPACE)
	var panel=game.hud.pause_presentation
	check(game.sim.state=="paused" and panel.is_visible_in_tree(),"Space opens actual pause presentation")
	check(game.hud.modal_card.visible==false,"legacy blank text card stays hidden")
	check(game.get_viewport().gui_get_focus_owner()==panel.actions["continue"],"dominant Continue receives initial keyboard focus")
	check(panel.standing.texture!=null and panel.standing.size.y>=400,"selected hero uses large original character art")
	check(panel.hero_name.text.contains(str(game.sim.heroes[1].name)),"large portrait identifies selected character")
	check(panel.build_empty.visible and not panel.build_scroll.visible,"empty build has authored next-step guidance")
	for i in 3:
		var hero: Dictionary=game.sim.heroes[i]
		check(panel.hero_rows[i].portrait.texture==game.hud.portrait_texture(hero,game.sim),"original portrait retained for hero %d" % i)
		check(panel.hero_rows[i].hp.text=="生命 %d / %d" %[ceili(hero.hp),ceili(hero.max_hp)],"real HP hierarchy for hero %d" % i)
		check(panel.hero_rows[i].stats.text.contains("攻击 %.0f" %hero.damage) and panel.hero_rows[i].stats.text.contains("攻速 %.2f" %hero.rate),"real combat stats for hero %d" % i)
		check(is_equal_approx(panel.hero_rows[i].bar.size.y*panel.hero_rows[i].bar.scale.y,3.0) and panel.hero_rows[i].stats.position.y>=57,"HP stays a thin strip separated from two stat lines for hero %d" %i)
	check(not game.hud.pause_help_button.is_visible_in_tree(),"internal reward debug hook is absent from player presentation")
	var copy := visible_copy(panel)
	check(not copy.contains("PERF") and not copy.contains("丢弃") and not copy.contains("调试"),"player copy contains no technical telemetry")
	var before_clock: float=game.sim.elapsed
	game.sim.tick(1.0)
	check(is_equal_approx(game.sim.elapsed,before_clock),"actual simulation clock remains frozen while paused")
	await capture("01-pause-empty")
	var revision: int=panel.render_revision
	var nodes: int=node_count(panel)
	for i in 240: game.hud.refresh(game.sim,game.selected_id)
	check(panel.render_revision==revision and node_count(panel)==nodes,"240 unchanged refreshes neither rebuild content nor create children")
	game.sim.heroes[1].damage+=7; game.hud.refresh(game.sim,game.selected_id)
	check(panel.render_revision==revision+1 and panel.hero_rows[1].stats.text.contains("攻击 %.0f" %game.sim.heroes[1].damage),"stat-only change refreshes pause data exactly once")
	var expected: Dictionary={}
	for card: Dictionary in game.sim.database.cards:
		if Icons.card_texture(card)==null: continue
		var id:=str(card.id); var level:=1+expected.size()%3
		game.sim.run_state.buff_levels[id]=level; expected[id]={"card":card,"level":level}
		if expected.size()>=14: break
	game.refresh(); await tree.process_frame
	check(panel.chip_details.size()==expected.size() and expected.size()>=14,"full build retains every upgrade beyond first four")
	for detail: Dictionary in panel.chip_details:
		var item: Dictionary=expected[detail.id]
		check(detail.name==str(item.card.name) and detail.level==item.level and detail.icon==Icons.card_texture(item.card),"upgrade preserves original name, icon and level: "+detail.id)
	check(panel.build_scroll.visible and not panel.build_empty.visible,"full build replaces empty state with compact original icon chips")
	await capture("02-pause-full")
	var scroll: HScrollBar=panel.build_scroll.get_h_scroll_bar()
	check(scroll.max_value>scroll.page,"all upgrades remain reachable through horizontal scroll")
	var wheel := InputEventMouseButton.new()
	wheel.position=panel.build_scroll.get_global_rect().get_center(); wheel.global_position=wheel.position
	wheel.button_index=MOUSE_BUTTON_WHEEL_RIGHT; wheel.pressed=true
	game.get_viewport().push_input(wheel,true); await tree.process_frame
	check(panel.build_scroll.scroll_horizontal>0,"mouse wheel navigates full upgrade strip")
	panel.build_scroll.scroll_horizontal=int(scroll.max_value)
	await capture("03-pause-full-tail")
	panel.build_scroll.scroll_horizontal=0
	revision=panel.render_revision; nodes=node_count(panel)
	for i in 240: game.hud.refresh(game.sim,game.selected_id)
	check(panel.render_revision==revision and node_count(panel)==nodes,"full build cache keeps node count and render revision stable")
	game.hud.reduced=true; game.hud.refresh(game.sim,game.selected_id)
	check(panel.render_revision==revision,"reduced effects preserves static pause content")
	await capture("04-pause-reduced")
	game.hud.reduced=false; game.hud.refresh(game.sim,game.selected_id)
	panel.actions["continue"].grab_focus()
	for i in panel.focus_order.size():
		await key(KEY_TAB)
		check(game.get_viewport().gui_get_focus_owner()==panel.focus_order[(i+1)%panel.focus_order.size()],"Tab follows all pause actions %d" %i)
	await key(KEY_ENTER)
	check(game.sim.state=="running" and not panel.is_visible_in_tree(),"Enter on Continue resumes real battle")
	await key(KEY_SPACE); await click(panel.actions["continue"])
	check(game.sim.state=="running" and not panel.is_visible_in_tree(),"mouse Continue resumes real battle")
	await key(KEY_SPACE); await click(panel.actions.settings)
	check(game.settings_panel.is_open(),"mouse Settings opens existing settings")
	await key(KEY_ESCAPE); await tree.create_timer(0.2).timeout
	check(not game.settings_panel.is_open() and game.sim.state=="paused","Escape returns from Settings to pause")
	await key(KEY_F10)
	check(game.settings_panel.is_open(),"F10 shortcut remains available")
	await key(KEY_ESCAPE); await tree.create_timer(0.2).timeout
	await click(panel.actions.compendium)
	check(game.compendium_panel.is_open(),"mouse Gallery opens original compendium")
	await key(KEY_ESCAPE)
	check(not game.compendium_panel.is_open() and game.sim.state=="paused","Escape returns from Gallery to pause")
	game.checkpoint_phase="route"
	await click(panel.actions.map)
	check(game.campaign_map_panel.is_open(),"mouse Route preserves existing eligible campaign navigation")
	await key(KEY_ESCAPE)
	check(not game.campaign_map_panel.is_open() and game.sim.state=="paused","Escape returns from Route to pause")
	await click(panel.actions.restart)
	check(game.hud.restart_dialog.visible,"mouse Retry opens existing confirmation")
	game.hud.restart_dialog.get_cancel_button().grab_focus()
	await key(KEY_ENTER,game.hud.restart_dialog)
	check(not game.hud.restart_dialog.visible and game.sim.state=="paused","Enter on Cancel returns to pause without losing current battle")
	await key(KEY_R)
	check(game.hud.restart_dialog.visible,"R shortcut opens existing restart confirmation")
	game.hud.restart_dialog.get_ok_button().grab_focus()
	await key(KEY_ENTER,game.hud.restart_dialog)
	await tree.create_timer(0.1).timeout
	check(game.sim.state=="ready" and game.sim.current_stage_id=="stage_02" and game.sim.run_state.buff_levels.is_empty(),"Enter confirms actual retry and resets the current run")
	game.sim.start(); game.refresh(); await key(KEY_SPACE)
	await click(panel.actions.menu)
	check(game.mode_select_panel.is_open(),"mouse Menu returns to existing mode selection")
	var report:={"checks":checks,"failures":failures,"display":DisplayServer.get_name(),"resolution":str(requested_size),"pause_refresh_revision":panel.render_revision,"pause_nodes":node_count(panel),"original_upgrades_checked":expected.size()}
	var file:=FileAccess.open(output.path_join("pause-results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("V95 PAUSE RESULT "+JSON.stringify(report))
	return 0 if failures.is_empty() else 1
