extends SceneTree

const Icons = preload("res://scripts/content/generated_icon_catalog.gd")

func _initialize() -> void:
    var missing: Array[String] = []
    var cards_checked := 0
    for filename in ["cards.json", "mechanic_cards.json"]:
        var cards: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/v2/" + filename))
        for card: Dictionary in cards:
            if Icons.card_texture(card) == null:
                missing.append("卡牌：" + str(card.get("name", "")))
            cards_checked += 1
    var characters: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/v2/characters.json"))
    var skills_checked := 0
    var cooldowns: Dictionary = {}
    for character: Dictionary in characters:
        var id := str(character.get("id", ""))
        for key in ["active_skill", "ultimate"]:
            var ability: Dictionary = character[key]
            if key == "ultimate" and float(ability.get("cooldown", 0.0)) < 40.0:
                missing.append(id + " E 冷却不足 40 秒")
            cooldowns[id + key] = float(ability.get("cooldown", 0.0))
            if id != "traveler":
                if Icons.ability_texture(id, key == "ultimate") == null:
                    missing.append(id + " " + key + " 图标")
                skills_checked += 1
    print("V70 ICON QA: %d card icons, %d character skill icons, %d failures" % [cards_checked, skills_checked, missing.size()])
    for item in missing:
        push_error(item)
    quit(1 if not missing.is_empty() else 0)
