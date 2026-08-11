class_name FuboTravelSession
extends RefCounted

const SEA_SCENE_PATH := "res://scenes/sea_overworld/sea_overworld.tscn"
const FUBO_SCENE_PATH := "res://scenes/fubo_guling/fubo_guling.tscn"
const RETURN_CONTEXT_META := &"fubo_guling_sea_return_context"
const RETURN_REQUEST_META := &"sea_overworld_return_from_fubo_guling"
const FALLBACK_SEA_POSITION := Vector2(4200, 1140)


static func make_context(
	ship_position: Vector2,
	facing_index: int,
	exploration_stage: int,
	lunar_day: float
) -> Dictionary:
	return {
		"ship_position": ship_position,
		"facing_index": maxi(0, facing_index),
		"exploration_stage": clampi(exploration_stage, 0, 4),
		"lunar_day": maxf(0.0, lunar_day),
	}


static func decode_context(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var context := value as Dictionary
	for key in ["ship_position", "facing_index", "exploration_stage", "lunar_day"]:
		if not context.has(key):
			return {}

	var ship_position_value: Variant = context["ship_position"]
	var facing_value: Variant = context["facing_index"]
	var exploration_value: Variant = context["exploration_stage"]
	var lunar_value: Variant = context["lunar_day"]
	if not ship_position_value is Vector2:
		return {}
	var ship_position := ship_position_value as Vector2
	if not is_finite(ship_position.x) or not is_finite(ship_position.y):
		return {}
	if not facing_value is int or facing_value < 0 or facing_value > 3:
		return {}
	if not exploration_value is int or exploration_value < 0 or exploration_value > 4:
		return {}
	if not (lunar_value is float or lunar_value is int):
		return {}
	var lunar_day := float(lunar_value)
	if not is_finite(lunar_day) or lunar_day < 0.0:
		return {}

	return make_context(ship_position, int(facing_value), int(exploration_value), lunar_day)
