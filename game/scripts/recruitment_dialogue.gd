extends RefCounted
# Reuse authored dialogue and nested branches; only translate the outcome channel.
static func for_character(stories: Dictionary,character_id: String,variant: int) -> Array:
 if character_id not in ["hero_02","hero_06"]: return []
 var key="home_%s_%d" % [character_id,clampi(variant,0,1)]
 var rows: Array=stories.get(key,[]).duplicate(true)
 _convert_outcomes(rows)
 return rows
static func _convert_outcomes(rows: Array) -> void:
 for row in rows:
  for choice in row.get("choices",[]):
   if choice.has("home_success"):
    choice.recruit_success=choice.home_success
    choice.erase("home_success")
    choice.erase("home_reason")
   _convert_outcomes(choice.get("follow_up",[]))
