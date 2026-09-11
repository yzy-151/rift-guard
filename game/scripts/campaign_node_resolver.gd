extends RefCounted

func build_options(node: Dictionary, run_state, database) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var node_id: String = str(node.get("id", "node"))
	match str(node.get("type", "")):
		"shop":
			var price: int = 55
			for relic: Dictionary in database.relics.values():
				if run_state.equipped_relics.has(str(relic.id)):
					continue
				options.append({"id":"buy_"+str(relic.id),"node_id":node_id,"kind":"relic","value":str(relic.id),"name":str(relic.name),"description":str(relic.description),"cost":price})
				price += 20
				if options.size() >= 2:
					break
			options.append({"id":"buy_luck","node_id":node_id,"kind":"luck","value":0.18,"name":"命运筹码","description":"本次远征幸运提高0.18，高阶卡牌权重上升。","cost":45})
		"rest":
			options = [
				{"id":"rest_fortify","node_id":node_id,"kind":"perk","value":"fortify","name":"修筑壁垒","description":"后续关卡基地最大生命+25，角色最大生命+8%。","cost":0},
				{"id":"rest_charge","node_id":node_id,"kind":"perk","value":"charged_start","name":"整备能量","description":"后续关卡全队初始能量+18。","cost":0},
				{"id":"rest_supply","node_id":node_id,"kind":"supply","value":35,"name":"搜索补给","description":"获得35裂隙币并提高0.05幸运。","cost":0}
			]
		"recruit":
			for character_id: String in database.characters:
				if character_id == "traveler" or character_id in run_state.squad:
					continue
				var character: Dictionary = database.characters[character_id]
				options.append({"id":"recruit_"+character_id,"node_id":node_id,"kind":"recruit","value":character_id,"unlock_character":character_id,"name":"招募 · "+str(character.name),"description":"加入远征编队；满员时替换第三名角色。","cost":0})
				if options.size() >= 3:
					break
		"hidden":
			var unlock_id: String = str(node.get("unlock", "hero_12"))
			var name: String = str(database.characters.get(unlock_id, {}).get("name", "隐藏角色"))
			options = [
				{"id":"hidden_trust","node_id":node_id,"kind":"hidden","value":"trust","unlock_character":unlock_id,"name":"回应信号 · "+name,"description":"解锁隐藏角色并获得羁绊线索。","cost":0},
				{"id":"hidden_cache","node_id":node_id,"kind":"supply","value":70,"name":"搜刮密库","description":"放弃信号，获得70裂隙币。","cost":0},
				{"id":"hidden_prism","node_id":node_id,"kind":"perk","value":"elemental_focus","name":"触碰棱镜","description":"后续关卡元素反应伤害+12%。","cost":0}
			]
	return options

func apply_option(option: Dictionary, run_state) -> Dictionary:
	var node_id: String = str(option.get("node_id", ""))
	if not node_id.is_empty() and run_state.resolved_nodes.has(node_id):
		return {"ok":false,"message":"该节点已完成。"}
	var cost: int = int(option.get("cost", 0))
	if not run_state.spend_shards(cost):
		return {"ok":false,"message":"裂隙币不足，需要%d。" % cost}
	var message: String = ""
	match str(option.get("kind", "")):
		"relic":
			if not run_state.grant_relic(str(option.value)):
				run_state.rift_shards += cost
				return {"ok":false,"message":"该遗物已经持有。"}
			message = "获得遗物：" + str(option.name)
		"luck":
			run_state.luck += float(option.value)
			message = "幸运提高至 %.2f" % run_state.luck
		"perk":
			run_state.add_campaign_perk(str(option.value), 1)
			message = "远征增益已生效：" + str(option.name)
		"supply":
			run_state.rift_shards += int(option.value)
			run_state.luck += 0.05
			message = "获得%d裂隙币" % int(option.value)
		"recruit":
			var next_squad: Array[String] = run_state.squad.duplicate()
			var character_id: String = str(option.value)
			if next_squad.size() >= run_state.MAX_SQUAD_SIZE:
				next_squad[next_squad.size()-1] = character_id
			else:
				next_squad.append(character_id)
			if not run_state.set_squad(next_squad):
				return {"ok":false,"message":"编队调整失败。"}
			message = str(option.name) + " 已加入编队"
		"hidden":
			run_state.set_story_flag("hidden_signal_resolved")
			run_state.add_relationship(str(option.get("unlock_character", "hero_12")), 2)
			message = "隐藏信号回应成功。"
		_:
			return {"ok":false,"message":"未知节点选项。"}
	if not node_id.is_empty():
		run_state.resolved_nodes[node_id] = str(option.id)
	return {"ok":true,"message":message,"unlock_character":str(option.get("unlock_character", ""))}
