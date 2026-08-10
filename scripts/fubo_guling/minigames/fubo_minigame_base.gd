class_name FuboMinigameBase
extends Control

signal completed(result: Dictionary)
signal exit_requested
signal round_restarted(round_index: int)

@export var game_id := ""


func build_result(rating: String, mistakes: int, duration_ms: int) -> Dictionary:
	return {
		"game_id": game_id,
		"completed": true,
		"rating": rating,
		"mistakes": maxi(0, mistakes),
		"duration_ms": maxi(0, duration_ms),
	}
