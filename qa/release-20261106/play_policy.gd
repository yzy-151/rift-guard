extends RefCounted
const STEP := 1.0 / 30.0
var sim
var build := "coherent"
var choices: Array[Dictionary] = []
var casts: Array[Dictionary] = []
var purchases: Array[Dictionary] = []
var control_timer := 0.0
var plant_timer := 0.0
var bought := 0
var decision_rng := RandomNumberGenerator.new()
var pending_choice := -1
var pending_recipient := -1

func initialize(source, seed_value: int, strategy: String = "coherent") -> void:
	sim=source
	build=strategy
	decision_rng.seed=seed_value+91
	control_timer=0.0
	plant_timer=0.0
	bought=0
	choices.clear()
	casts.clear()
	purchases.clear()
	pending_choice=-1

func prepare_reward() -> Dictionary:
	if sim.state!="reward" or sim.rewards.offered.is_empty(): return {}
	var best:=0
	var top:=-INF
	for i in sim.rewards.offered.size():
		var rank:=score(sim.rewards.offered[i],build,sim)
		if rank>top: top=rank;best=i
	pending_choice=best
	var card:Dictionary=sim.rewards.offered[best]
	pending_recipient=recipient(card,sim,decision_rng,build)
	return {"time":sim.elapsed,"level":sim.run_state.crystal_level,"index":best,"recipient":pending_recipient,"id":card.id,"name":card.get("name",""),"rarity":card.rarity,"offered":sim.rewards.offered.duplicate(true)}

func take_reward() -> bool:
	var record:=prepare_reward()
	if record.is_empty():return false
	var ok:bool=sim.choose_reward(pending_choice,pending_recipient)
	if ok:choices.append(record)
	pending_choice=-1
	return ok

func controls() -> void:
	if sim.state!="running":return
	var nearest:Dictionary={}
	var boss_target:Dictionary={}
	var bosses:Array[Dictionary]=[]
	for enemy:Dictionary in sim.enemies:
		if float(enemy.hp)<=0:continue
		var closer:bool=Vector2(enemy.pos).distance_squared_to(sim.heroes[0].pos)<Vector2(nearest.get("pos",Vector2(99999,99999))).distance_squared_to(sim.heroes[0].pos) if sim.endless_mode else (nearest.is_empty() or enemy.pos.x<nearest.pos.x)
		if nearest.is_empty() or closer:nearest=enemy
		if str(enemy.kind).begins_with("boss_"):
			bosses.append(enemy)
			boss_target=enemy
	control_timer-=STEP
	for h:Dictionary in sim.heroes:
		if float(h.hp)<=0:continue
		if not bool(h.deployed) and sim.deployment_slot_unlocked(int(h.id)):
			sim.deploy_hero(int(h.id),Vector2(540.0+int(h.id)*40,300.0+int(h.id)*65))
		if not bool(h.deployed) or nearest.is_empty():continue
		if control_timer<=0:
			var focus:Dictionary=nearest
			if not bosses.is_empty() and str(h.character_id)=="traveler":focus=bosses[0]
			if sim.endless_mode:
				# Follow the leader on a broad loop through the real arena.
				if int(h.id)==0:
					var center:Vector2=sim.ENDLESS_ARENA.get_center()
					sim.command_move(0,center+Vector2(cos(sim.elapsed*.035)*260,sin(sim.elapsed*.035)*190),false)
			else:
				var tank:=int(h.block)>0 and str(focus.kind).begins_with("boss_")
				var gap:=30.0 if tank else float(h.range)*.48
				var x:=clampf(float(focus.pos.x)-gap,145,1050)
				var y:=clampf(float(focus.pos.y)+(0 if tank else (int(h.id)-1)*35),160,555)
				if tank and Vector2(h.pos).distance_to(focus.pos)<42.0:x=h.pos.x;y=h.pos.y
				sim.command_move(int(h.id),safe_destination(sim,h,Vector2(x,y)),false)
			var aim:Vector2=nearest.pos if boss_target.is_empty() else boss_target.pos
			for ultimate:bool in [false,true]:
				var ability:Dictionary=sim.hero_ability(int(h.id),ultimate)
				var ok:bool=sim.activate_hero_ultimate(int(h.id),aim) if ultimate else sim.activate_hero_skill(int(h.id),aim)
				if ok:casts.append({"time":sim.elapsed,"hero":h.character_id,"ultimate":ultimate,"ability":ability.get("name",""),"element":h.element})
	if control_timer<=0:control_timer=.45
	plant_timer-=STEP
	if not sim.endless_mode and plant_timer<=0 and bought<9:
		plant_timer=6.0
		var kind:="sunflower" if bought==0 else ("barricade" if bought in [4,7] else "pea")
		if sim.battle_devices.gold>=sim.battle_devices.price_of(kind):
			for point in [Vector2(420,220),Vector2(540,260),Vector2(540,380),Vector2(540,500),Vector2(720,380),Vector2(420,380),Vector2(660,500),Vector2(780,260),Vector2(660,260)]:
				if sim.battle_devices.select(sim,kind) and sim.battle_devices.place(sim,point):
					bought+=1
					purchases.append({"time":sim.elapsed,"kind":kind,"pos":[point.x,point.y],"gold_after":sim.battle_devices.gold})
					break

func score(card: Dictionary, build: String, sim) -> float:
	var effect := str(card.get("effect",""))
	if effect == "assign_traveler_element": return 140.0 if str(card.value)=="electro" else 95.0
	if effect == "card_bundle":
		var sum := 0.0
		for part: Dictionary in card.components: sum += score(part,build,sim)*.65
		return sum
	var strong := {"attack_multiplier":70,"squad_attack_multiplier":88,"attack_rate_multiplier":64,"squad_rate_multiplier":78,"projectile_count_add":95,"pierce_add":84,"chain_add":90,"blast_add":86,"echo_add":64,"third_strike":66,"lethal_tempo":93,"conqueror":80,"support_barrage":99,"support_crossfire":93,"support_finale":102,"orbit_add":65,"orbit_spell_add":60,"evolving_fireball":67,"elite_damage_add":72,"execute_threshold_add":68,"skill_power_add":76,"skill_cooldown_add":74,"reaction_damage_add":60,"energy_gain_add":57,"death_burst_add":87,"device_evolve_pea":70,"device_damage_add":59,"device_attack_interval_reduce":60,"device_evolve_melon":79}
	var safe := {"health_multiplier":83,"squad_health_multiplier":82,"armor_flat":80,"squad_armor_flat":85,"range_flat":70,"squad_range_flat":72,"move_speed_flat":75,"crit_flat":40,"heartsteel":87,"warmogs_armor":85,"attack_mend":79,"last_stand":62,"desperate_guard":65,"support_heal":85,"crystal_heal":110,"crystal_health_flat":95,"device_health_add":80}
	var value := float(strong.get(effect, 25))
	if build in ["coherent","lucky","poor_position"] and sim.run_state.crystal_level>=6:
		var durability:=0
		for held:String in sim.run_state.buff_levels:
			if held in ["single_health_common","single_health_rare","single_health_epic","global_health_1","global_health_epic","warmogs_armor","support_tidal_aid","v75_field_medicine","v75_randuin_barrier","v75_titan_vigor","v75_vitality_drill","v75_guardian_pact","v75_immortal_legion"]:durability+=int(sim.run_state.buff_levels[held])
		if durability<2 and effect in ["health_multiplier","squad_health_multiplier","warmogs_armor","support_heal"]:value+=72
		elif durability<1 and effect in ["armor_flat","squad_armor_flat","attack_mend"]:value+=50
	if build=="defensive_random": value=float(safe.get(effect,18))
	if build=="lucky":
		if effect=="luck_add":return 128.0 if sim.elapsed<200.0 else 30.0
		value += {"common":0,"rare":8,"epic":16,"legendary":30,"mythic":45}.get(str(card.get("rarity","common")),0)
	if sim.base_hp < 6 and effect=="crystal_heal": value+=100
	# Evaluate the actual scaled purchase instead of treating +24% and +125% as peers.
	if effect in ["attack_multiplier","squad_attack_multiplier","attack_rate_multiplier","squad_rate_multiplier","health_multiplier","squad_health_multiplier"]:value+=minf(55.0,float(card.get("value",0.0))*45.0)
	if effect in ["armor_flat","squad_armor_flat"]:value+=minf(45.0,float(card.get("value",0.0))*.45)
	return value+float(card.get("next_level",1))*3.0

func recipient(card:Dictionary,sim,decision_rng:RandomNumberGenerator,build:String)->int:
	if str(card.get("character_id",""))!="":
		for hero:Dictionary in sim.heroes:
			if str(hero.character_id)==str(card.character_id):return int(hero.id)
	if build=="random":return decision_rng.randi_range(0,sim.heroes.size()-1)
	var result:=0
	var strongest:=-INF
	for hero:Dictionary in sim.heroes:
		if hero.hp<=0:continue
		var rank:=float(hero.damage)*float(hero.rate)*maxi(1,int(hero.projectile_count))
		if str(card.get("effect","")) in ["health_multiplier","armor_flat","warmogs_armor","attack_mend"]:rank=-float(hero.max_hp)/(1+float(hero.armor)/100.0)
		if rank>strongest:strongest=rank;result=int(hero.id)
	return result

func safe_destination(sim,h:Dictionary,wanted:Vector2)->Vector2:
	var best:=wanted
	var best_score:=INF
	for offset in [Vector2.ZERO,Vector2(0,-95),Vector2(0,95),Vector2(-75,-70),Vector2(-75,70),Vector2(0,-150),Vector2(0,150),Vector2(100,-95),Vector2(100,95),Vector2(160,0)]:
		var point:=wanted+Vector2(offset)
		point=Vector2(clampf(point.x,145,1100),clampf(point.y,160,555))
		if sim._terrain_blocks(point,17):continue
		var danger:=0.0
		for e:Dictionary in sim.enemies:
			if e.hp<=0:continue
			if e.attack_pending and sim.is_in_ability_area(e.warning_pos,point,float(e.warning_radius)+28):danger+=3
			if e.special_pending:
				var move:=str(e.get("special_move",""))
				for center:Vector2 in e.get("special_warning_positions",[]):
					if move=="galio_punch":
						var direction:Vector2=(center-Vector2(e.pos)).normalized()
						if sim._distance_to_segment(point,e.pos,Vector2(e.pos)+direction*520.0)<float(e.special_warning_radius)+25.0:danger+=5
					elif move=="kindred_lasers":
						if sim._distance_to_segment(point*Vector2(1,2.5),Vector2(e.get("kindred_laser_source",e.pos))*Vector2(1,2.5),center*Vector2(1,2.5))<34.0:danger+=5
					elif sim.is_in_ability_area(center,point,float(e.get("special_warning_radius",150))+28):danger+=5
		for hazard:Dictionary in sim.enemy_hazards:
			if sim.is_in_ability_area(hazard.get("pos",Vector2.ZERO),point,float(hazard.get("radius",50))+20):danger+=4
		var rating:=danger*10000+point.distance_to(wanted)+point.distance_to(h.pos)*.2
		if rating<best_score:best_score=rating;best=point
	return best
