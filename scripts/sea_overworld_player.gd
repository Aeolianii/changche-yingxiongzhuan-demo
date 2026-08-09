class_name SeaOverworldPlayer
extends CharacterBody2D

signal sailed(delta: float)

const PLAYER_SHIP_ATLAS := preload("res://assets/sprites/sea_overworld/player_ship_4dir_states_v1.png")
const PROTAGONIST_ATLAS := preload("res://assets/sprites/sea_overworld/protagonist_chibi_4dir_v1.png")
const WAKE_ATLAS := preload("res://assets/sprites/sea_overworld/ship_wake_fx_atlas_v1.png")

const DIRECTION_VECTORS := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
const DIRECTION_ROTATIONS := [0.0, PI * 0.5, -PI * 0.5, PI]
const HERO_OFFSETS := [Vector2(0, -19), Vector2(-4, -18), Vector2(4, -18), Vector2(0, -20)]
const SHIP_FRAME_Y_OFFSETS := [-98.0, 0.0]
const WAKE_OFFSET := 76.0
const WAKE_FRAME_TIME := 0.11

@export var move_speed := 260.0
@export var controls_enabled := true
@export var movement_bounds := Rect2(34, 34, 2440, 1344)

@onready var visual_root: Node2D = $VisualRoot
@onready var ship_sprite: Sprite2D = $VisualRoot/ShipSprite
@onready var hero_sprite: Sprite2D = $VisualRoot/HeroSprite
@onready var wake_sprite: Sprite2D = $WakeSprite
@onready var side_splash_sprite: Sprite2D = $SideSplashSprite

var _facing_index := 0
var _last_ship_state := -1
var _last_ship_direction := -1
var _wake_frame := -1
var _wake_elapsed := 0.0
var _bob_elapsed := 0.0


func _ready() -> void:
	_update_direction_textures(false)
	wake_sprite.hide()
	side_splash_sprite.hide()


func save_facing_index() -> int:
	return _facing_index


func restore_facing_index(value: int) -> void:
	_facing_index = clampi(value, 0, DIRECTION_VECTORS.size() - 1)
	_last_ship_state = -1
	_last_ship_direction = -1
	_update_direction_textures(false)


func _physics_process(delta: float) -> void:
	var input_direction := Vector2.ZERO
	if controls_enabled:
		input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	var is_moving := input_direction.length_squared() > 0.01
	if is_moving:
		_update_facing(input_direction)
	velocity = input_direction * move_speed
	var position_before_move := global_position
	move_and_slide()
	global_position = global_position.clamp(movement_bounds.position, movement_bounds.end)
	if global_position.distance_squared_to(position_before_move) > 0.01:
		sailed.emit(delta)
	_update_motion_visuals(delta, is_moving)


func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		_facing_index = 2 if direction.x > 0.0 else 1
	else:
		_facing_index = 0 if direction.y > 0.0 else 3


func _update_motion_visuals(delta: float, is_moving: bool) -> void:
	_update_direction_textures(is_moving)
	_bob_elapsed += delta * (7.5 if is_moving else 3.5)
	visual_root.position.y = sin(_bob_elapsed) * (1.7 if is_moving else 0.75)

	if not is_moving:
		wake_sprite.hide()
		side_splash_sprite.hide()
		_wake_elapsed = 0.0
		_wake_frame = -1
		return

	wake_sprite.show()
	side_splash_sprite.show()
	_wake_elapsed += delta
	var next_frame := int(floor(_wake_elapsed / WAKE_FRAME_TIME)) % 4
	if next_frame != _wake_frame:
		_wake_frame = next_frame
		wake_sprite.texture = _atlas_region(WAKE_ATLAS, 4, 2, _wake_frame, 0)
		side_splash_sprite.texture = _atlas_region(WAKE_ATLAS, 4, 2, (_wake_frame + 2) % 4, 1)

	var facing_vector: Vector2 = DIRECTION_VECTORS[_facing_index]
	var facing_rotation: float = DIRECTION_ROTATIONS[_facing_index]
	wake_sprite.rotation = facing_rotation
	side_splash_sprite.rotation = facing_rotation
	wake_sprite.position = -facing_vector * WAKE_OFFSET
	side_splash_sprite.position = facing_vector * 4.0


func _update_direction_textures(is_moving: bool) -> void:
	var ship_state := 1 if is_moving else 0
	if ship_state == _last_ship_state and _facing_index == _last_ship_direction:
		return
	_last_ship_state = ship_state
	_last_ship_direction = _facing_index
	ship_sprite.texture = _atlas_region(PLAYER_SHIP_ATLAS, 4, 2, _facing_index, ship_state)
	# The sailing row shifts the ship art 98 source pixels upward to make room for its wake.
	# Align the stopped row to that deck anchor without moving the protagonist.
	ship_sprite.position = Vector2(0.0, SHIP_FRAME_Y_OFFSETS[ship_state] * ship_sprite.scale.y)
	hero_sprite.texture = _atlas_region(PROTAGONIST_ATLAS, 4, 1, _facing_index, 0)
	hero_sprite.position = HERO_OFFSETS[_facing_index]


func _atlas_region(texture: Texture2D, columns: int, rows: int, column: int, row: int) -> AtlasTexture:
	var frame_size := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = Rect2(Vector2(column, row) * frame_size, frame_size)
	return atlas_texture
