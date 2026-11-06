extends SceneTree
const Sim=preload("res://scripts/combat_simulation.gd")
const Catalog=preload("res://scripts/combat_catalog.gd")
const BossVfx=preload("res://scripts/boss_skill_vfx_20261006.gd")
var checks:=0
var failures: Array[String]=[]
func _initialize()->void: run.call_deferred()
func check(value: bool,label: String)->void:
	checks+=1
	if not value: failures.append(label)
func card(sim,id: String)->Dictionary:
	for row: Dictionary in sim.database.cards:
		if str(row.id)==id:return row
	return {}
func fixture(stage: String="stage_endless"):
	var sim=Sim.new(6106206,true)
	var squad: Array[String]=["traveler","hero_03","hero_13"]
	sim.reset_stage(stage,squad,6106206)
	return sim
func run()->void:
	for relic: bool in [false,true]:
		for purchases in [1,2,3,4,99]:
			var source=fixture("stage_02")
			var hero: Dictionary=source.heroes[0]
			hero.card_levels={"orbit_add":purchases,"orbit_spell_add":purchases}
			source.run_state.buff_levels={"orbit_arcane_blades":purchases,"orbit_spell_rings":purchases,"evolve_fireball":purchases}
			source.fireball_level=6
			for id: String in ["orbit_arcane_blades","orbit_spell_rings"]:
				var row: Dictionary=source._orbital_card_state(hero,card(source,id),6,float(card(source,id).value))
				row.timer=.17;row.age=3.7;row.phase=1.21;row.storm_timer=2.19;row.element="electro"
				source.orbitals.append(row)
			var snapshot: Dictionary=source.export_run_snapshot()
			var unchanged:=JSON.stringify(snapshot)
			var target=fixture()
			if relic:target.run_state.equipped_relics.relic_orbit_foundry=true
			check(target.import_run_snapshot(snapshot),"import %d/%s"%[purchases,relic])
			var expected_phase: int=[1,3,6,9][mini(3,purchases-1)]
			check(target.fireball_level==expected_phase,"meteor phase %d/%s"%[purchases,relic])
			for index in 2:
				var row: Dictionary=target.orbitals[index]
				var definition:=card(target,str(row.source_card))
				var phase: int=target._card_evolution_level(definition,purchases)
				check(row.level==phase,"orbital phase")
				# Unchanged phases retain their saved execution fields and modifiers.
				if phase!=6:
					var expected: Dictionary=target._orbital_card_state(target.heroes[0],definition,phase,float(definition.value))
					for key: String in ["count","damage","radius","interval","visual"]:
						check(row[key]==expected[key],"rebuilt canonical "+key)
				for key: String in ["timer","age","phase","storm_timer","element","hero_id"]:
					check(row[key]==snapshot.orbitals[index][key],"retained execution "+key)
			check(JSON.stringify(snapshot)==unchanged,"source snapshot is read-only")
			var exported: Dictionary=target.export_run_snapshot()
			check(exported.buff_levels==snapshot.buff_levels,"purchase records unchanged")
			check(exported.heroes[0].card_levels==snapshot.heroes[0].card_levels,"hero purchase records unchanged")
			var second=fixture()
			if relic:second.run_state.equipped_relics.relic_orbit_foundry=true
			check(second.import_run_snapshot(exported) and second.fireball_level==target.fireball_level,"second checkpoint import")
			for index in 2:check(second.orbitals[index]==target.orbitals[index],"idempotent orbital import")
	var source=fixture();source.fireball_level=6
	var row: Dictionary=source._orbital_card_state(source.heroes[0],card(source,"orbit_arcane_blades"),6,3)
	source.orbitals.append(row)
	var unknown:=source.export_run_snapshot()
	unknown.erase("buff_levels")
	var target=fixture();target.import_run_snapshot(unknown)
	check(target.fireball_level==6 and target.orbitals[0].level==6,"no explicit purchase evidence keeps saved phase")
	for seconds in [0,150,300,600,900,1200]:
		target.elapsed=float(seconds)
		check(target._endless_enemy_level(target._endless_tier())==maxi(1,1+floori(pow(seconds/60.0,2)*.44)),"endless level curve unchanged "+str(seconds))
		if seconds==900:check(target._endless_enemy_level(target._endless_tier())==100,"15 minutes level100")
	var ranged: Dictionary=target.heroes[0];ranged.range=200.0
	for y in [200,500,1000,1450]:
		ranged.pos=Vector2(1360,y);target.elapsed+=1
		check(target.attack_range_screen_radii(ranged).is_equal_approx(Vector2(166,66.4)),"fixed visual attack ellipse")
		check(target.ability_area_screen_radii(ranged.pos,200).is_equal_approx(Vector2(166,66.4)),"fixed ability ellipse")
		check(target.is_in_attack_range(ranged,ranged.pos+Vector2(100,8)),"translated inner target")
		check(not target.is_in_attack_range(ranged,ranged.pos+Vector2(180,8)),"translated outer target")
	var campaign=fixture("stage_02")
	campaign.elapsed=385;var minion: Dictionary=campaign.spawn_enemy(Vector2(1000,360),"grunt")
	check(minion.level==8,"normal v2 level cap")
	var boss: Dictionary=campaign.spawn_enemy(Vector2(1000,360),"boss_02")
	var expected_boss:=float(Catalog.ENEMIES.boss_02.hp)*1.4*3*Sim.CAMPAIGN_BOSS_HEALTH_MULTIPLIER*float(campaign.stage_runtime.definition.get("enemy_health_multiplier",1))*float(campaign.stage_runtime.definition.get("boss_health_multiplier",1))
	check(is_equal_approx(float(boss.max_hp),expected_boss),"boss independent multiplier")
	campaign.v2_mode=false;campaign.wave=5;campaign.elapsed=900
	minion=campaign.spawn_enemy(Vector2(1000,360),"grunt")
	check(minion.level==5,"legacy wave level retained")
	# The current skill-specific dispatcher is intentionally enabled. Test the explicit
	# opt-out contract without assuming the live product flag remains disabled.
	var rendering_before:bool=BossVfx.rendering_enabled
	BossVfx.rendering_enabled=false
	check(not BossVfx.rendering_enabled,"renderer can be explicitly disabled")
	check(not BossVfx.draw_warning(null,{}) and not BossVfx.draw_effect(null,{}) and not BossVfx.draw_projectile(null,{}) and not BossVfx.draw_hazard(null,{}) and not BossVfx.draw_support_warning(null,"barrage"),"disabled helper returns control to original paths")
	BossVfx.rendering_enabled=rendering_before
	var result: Dictionary={"checks":checks,"failures":failures}
	var file:=FileAccess.open("res://../qa/performance-20261006/snapshot-evolution-correctness.json",FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
	print(JSON.stringify(result));quit(0 if failures.is_empty() else 1)
