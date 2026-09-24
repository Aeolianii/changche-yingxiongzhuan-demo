extends RefCounted

const FRAME_COUNTS := {
	"protagonist": {
		"idle": {"down": 16, "left": 16, "right": 16, "up": 16},
		"walk": {"down": 11, "left": 20, "right": 20, "up": 8},
	},
	"emperor": {
		"idle": {"down": 16, "left": 4, "right": 4, "up": 4},
		"walk": {"down": 4, "left": 4, "right": 4, "up": 4},
	},
	"soldier": {
		"idle": {"down": 2, "left": 2, "right": 2, "up": 2},
		"walk": {"down": 9, "left": 9, "right": 9, "up": 9},
	},
	"magistrate": {
		"idle": {"down": 2, "left": 2, "right": 2, "up": 2},
		"walk": {"down": 9, "left": 9, "right": 9, "up": 9},
	},
}


static func paths_for(character_key: String, state: String, direction: String) -> Array[String]:
	var paths: Array[String] = []
	var character_counts: Dictionary = FRAME_COUNTS.get(character_key, {})
	var state_counts: Dictionary = character_counts.get(state, {})
	var frame_count := int(state_counts.get(direction, 0))
	if frame_count == 0:
		push_error("No character frames defined for %s/%s/%s" % [character_key, state, direction])
		return paths
	for frame_number in range(1, frame_count + 1):
		paths.append("res://assets/characters/%s/standard/%s/%s/%d.png" % [character_key, state, direction, frame_number])
	return paths
