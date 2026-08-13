class_name SeaOverworldPirate
extends CharacterBody2D

signal battle_requested(pirate: SeaOverworldPirate)

enum Behavior { WANDER, REST, CHASE }

const PIRATE_SHIP_ATLAS := preload("res://assets/sprites/sea_overworld/pirate_ship_4dir_states_v1.png")
const WAKE_ATLAS := preload("res://assets/sprites/sea_overworld/ship_wake_fx_atlas_v1.png")
const DIRECTION_VECTORS := [Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT, Vector2.UP]
const DIRECTION_ROTATIONS := [0.0, PI * 0.5, -PI * 0.5, PI]
const WAKE_OFFSET := 52.0
const SIDE_SPLASH_OFFSET := 3.0
const WAKE_FRAME_TIME := 0.11

@export var move_speed := 210.0
@export var patrol_radius := 240.0
@export var detection_radius := 360.0
@export var disengage_radius := 520.0
@export var wander_duration_range := Vector2(1.5, 3.5)
@export var rest_duration_range := Vector2(0.8, 1.8)

@onready var visual_root: Node2D = $VisualRoot
@onready var ship_sprite: Sprite2D = $VisualRoot/ShipSprite
@onready var wake_sprite: Sprite2D = $WakeSprite
@onready var side_splash_sprite: Sprite2D = $SideSplashSprite
@onready var contact_area: Area2D = $ContactArea

var _player: Node2D
var _spawn_origin := Vector2.ZERO
var _movement_bounds := Rect2()
var _behavior := Behavior.REST
var _behavior_time_left := 0.0
var _wander_target := Vector2.ZERO
var _facing_index := 0
var _last_visual_direction := -1
var _last_visual_moving := false
var _wake_elapsed := 0.0
var _wake_frame := -1
var _bob_elapsed := 0.0
var _navigation_enabled := true
var _battle_requested := false
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	contact_area.body_entered.connect(_on_contact_body_entered)
	wake_sprite.hide()
	side_splash_sprite.hide()
	_start_rest()
	_update_motion_visuals(0.0, false)


func setup(player_node: Node2D, spawn_position: Vector2, random_seed: int, movement_bounds: Rect2) -> void:
	_player = player_node
	_spawn_origin = spawn_position
	_movement_bounds = movement_bounds
	_rng.seed = random_seed
	global_position = spawn_position
	_start_wander()


func _physics_process(delta: float) -> void:
	if not _navigation_enabled or _battle_requested or not is_instance_valid(_player):
		velocity = Vector2.ZERO
		_update_motion_visuals(delta, false)
		return

	var distance_to_player := global_position.distance_to(_player.global_position)
	if _behavior == Behavior.CHASE:
		if distance_to_player > disengage_radius:
			_start_wander()
	elif distance_to_player <= detection_radius:
		_behavior = Behavior.CHASE

	var desired_direction := Vector2.ZERO
	if _behavior == Behavior.CHASE:
		desired_direction = global_position.direction_to(_player.global_position)
	else:
		_behavior_time_left -= delta
		if _behavior == Behavior.REST:
			if _behavior_time_left <= 0.0:
				_start_wander()
		else:
			if _behavior_time_left <= 0.0 or global_position.distance_to(_wander_target) <= 18.0:
				_start_rest()
			else:
				desired_direction = global_position.direction_to(_wander_target)

	if desired_direction.length_squared() > 0.01:
		_update_facing(desired_direction)
	velocity = desired_direction * move_speed
	var before_move := global_position
	move_and_slide()
	if _movement_bounds.has_area():
		global_position = global_position.clamp(_movement_bounds.position, _movement_bounds.end)
	var moved := global_position.distance_squared_to(before_move) > 0.01
	if _behavior == Behavior.WANDER and desired_direction != Vector2.ZERO and not moved:
		_start_rest()
	_update_motion_visuals(delta, moved)


func set_navigation_enabled(value: bool) -> void:
	_navigation_enabled = value
	velocity = Vector2.ZERO
	contact_area.set_deferred("monitoring", value and not _battle_requested)
	if not value:
		_update_motion_visuals(0.0, false)


func is_chasing() -> bool:
	return _behavior == Behavior.CHASE


func spawn_origin() -> Vector2:
	return _spawn_origin


func behavior_name_for_test() -> String:
	return Behavior.keys()[_behavior].to_lower()


func is_navigation_enabled_for_test() -> bool:
	return _navigation_enabled


func force_wander_for_test(target: Vector2, duration: float) -> void:
	_behavior = Behavior.WANDER
	_wander_target = target
	_behavior_time_left = duration


func force_rest_for_test(duration: float) -> void:
	_behavior = Behavior.REST
	_behavior_time_left = duration
	velocity = Vector2.ZERO


func request_battle_for_test() -> void:
	_request_battle()


func _start_wander() -> void:
	_behavior = Behavior.WANDER
	_behavior_time_left = _rng.randf_range(wander_duration_range.x, wander_duration_range.y)
	var angle := _rng.randf_range(0.0, TAU)
	var radius := _rng.randf_range(patrol_radius * 0.35, patrol_radius)
	_wander_target = _spawn_origin + Vector2.from_angle(angle) * radius
	if _movement_bounds.has_area():
		_wander_target = _wander_target.clamp(_movement_bounds.position, _movement_bounds.end)


func _start_rest() -> void:
	_behavior = Behavior.REST
	_behavior_time_left = _rng.randf_range(rest_duration_range.x, rest_duration_range.y)
	velocity = Vector2.ZERO


func _update_facing(direction: Vector2) -> void:
	if absf(direction.x) > absf(direction.y):
		_facing_index = 2 if direction.x > 0.0 else 1
	else:
		_facing_index = 0 if direction.y > 0.0 else 3


func _update_motion_visuals(delta: float, is_moving: bool) -> void:
	if _last_visual_direction != _facing_index or _last_visual_moving != is_moving:
		_last_visual_direction = _facing_index
		_last_visual_moving = is_moving
		ship_sprite.texture = _atlas_region(PIRATE_SHIP_ATLAS, 4, 2, _facing_index, 1 if is_moving else 0)
	_bob_elapsed += delta * (7.0 if is_moving else 3.2)
	visual_root.position.y = sin(_bob_elapsed) * (1.5 if is_moving else 0.65)
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
	side_splash_sprite.position = facing_vector * SIDE_SPLASH_OFFSET


func _on_contact_body_entered(body: Node) -> void:
	if body == _player:
		_request_battle()


func _request_battle() -> void:
	if _battle_requested or not _navigation_enabled:
		return
	_battle_requested = true
	velocity = Vector2.ZERO
	contact_area.set_deferred("monitoring", false)
	_update_motion_visuals(0.0, false)
	battle_requested.emit(self)


func _atlas_region(texture: Texture2D, columns: int, rows: int, column: int, row: int) -> AtlasTexture:
	var frame_size := Vector2(texture.get_width() / float(columns), texture.get_height() / float(rows))
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = texture
	atlas_texture.region = Rect2(Vector2(column, row) * frame_size, frame_size)
	return atlas_texture
