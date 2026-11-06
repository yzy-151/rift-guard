extends SceneTree
## Read-only snapshot from the previous packaged build, before this skill pass.
func _initialize() -> void:
	var bank: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/combat_audio_v92.json"))
	var result := {"source":"previous packaged EXE, read-only bank and clip hashes", "cues":{}, "sha256":{}}
	for key: String in bank:
		if key.begins_with("attack_") or key == "traveler_anemo_q":
			result.cues[key] = bank[key]
			for path: String in bank[key].files:
				var clip = load(path)
				var packets = clip.get("packet_sequence").get("packet_data")
				var hash := HashingContext.new()
				hash.start(HashingContext.HASH_SHA256); hash.update(var_to_bytes(packets))
				result.sha256[path] = hash.finish().hex_encode()
				assert(packets != null, "Imported audio packet content is required")
	var file := FileAccess.open("C:/Users/23081/Desktop/codex/rift-guard/outputs/skills_20261005/audio-preservation-baseline.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"\t")); file.close()
	print("PACKAGED PRESERVATION SNAPSHOT cues=",result.cues.size()," clips=",result.sha256.size())
	quit(0)
