class_name FuboFishingBoard
extends Control

signal cast_requested

const FISHING_BACKGROUND := preload("res://assets/fubo_guling/minigames/fishing/fishing_background_v1.png")
const FISHING_HOOK := preload("res://assets/fubo_guling/minigames/fishing/fishing_hook_v1.png")
const ITEM_TEXTURES := {
	"small_fish": preload("res://assets/fubo_guling/minigames/fishing/small_yellow_croaker_v1.png"),
	"big_fish": preload("res://assets/fubo_guling/minigames/fishing/large_grouper_v1.png"),
	"crab": preload("res://assets/fubo_guling/minigames/fishing/blue_green_crab_v1.png"),
	"rock": preload("res://assets/fubo_guling/minigames/fishing/sea_rock_v1.png"),
}
const ITEM_DRAW_SIZES := {
	"small_fish": Vector2(72, 42),
	"big_fish": Vector2(100, 56),
	"crab": Vector2(88, 52),
	"rock": Vector2(72, 56),
}
const ROPE := Color("f0d79b")
const OUTLINE := Color("193b3b")

var game: FuboFishingGame
var _flash_time := 0.0


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()


func _process(delta: float) -> void:
	_flash_time = maxf(0.0, _flash_time - delta)
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		cast_requested.emit()
		accept_event()


func flash_catch() -> void:
	_flash_time = 0.28


func _draw() -> void:
	var frame := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	draw_texture_rect(FISHING_BACKGROUND, frame, false)
	if game == null:
		return
	_draw_items()
	_draw_rope_and_hook()
	if _flash_time > 0.0:
		draw_rect(frame.grow(-5), Color(1.0, 0.86, 0.36, _flash_time), false, 7.0)
	draw_rect(frame, Color("d5c081"), false, 4.0)

func _draw_rope_and_hook() -> void:
	var hook := game.get_hook_position()
	var hook_attachment := hook - Vector2(0, 33)
	draw_line(FuboFishingGame.PIVOT, hook_attachment, OUTLINE, 5.0, false)
	draw_line(FuboFishingGame.PIVOT, hook_attachment, ROPE, 2.0, false)
	draw_texture_rect(FISHING_HOOK, Rect2(hook - Vector2(18, 35), Vector2(36, 52)), false)


func _draw_items() -> void:
	var items := game.get_items()
	for index in items.size():
		var item: Dictionary = items[index]
		if not bool(item["active"]):
			continue
		var position := Vector2(item["position"])
		var facing := signf(float(Vector2(item["velocity"]).x))
		if index == game.get_caught_index():
			position = game.get_hook_position() + Vector2(0, 21)
		var kind := String(item["kind"])
		var texture := ITEM_TEXTURES.get(kind) as Texture2D
		var draw_size: Vector2 = ITEM_DRAW_SIZES.get(kind, Vector2(64, 48))
		if texture == null:
			continue
		position.x = clampf(position.x, 4.0 + draw_size.x * 0.5, size.x - 4.0 - draw_size.x * 0.5)
		position.y = clampf(position.y, 4.0 + draw_size.y * 0.5, size.y - 4.0 - draw_size.y * 0.5)
		if facing == 0.0:
			facing = 1.0
		draw_set_transform(position, 0.0, Vector2(facing, 1.0))
		draw_texture_rect(texture, Rect2(-draw_size * 0.5, draw_size), false)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func get_background_texture_path_for_test() -> String:
	return FISHING_BACKGROUND.resource_path


func get_hook_texture_path_for_test() -> String:
	return FISHING_HOOK.resource_path


func get_item_texture_paths_for_test() -> Dictionary:
	var paths := {}
	for kind in ITEM_TEXTURES:
		paths[kind] = (ITEM_TEXTURES[kind] as Texture2D).resource_path
	return paths
