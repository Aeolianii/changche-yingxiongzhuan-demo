extends CharacterActor

const CLICK_STOP_DISTANCE := 6.0
const CLICK_STUCK_TIMEOUT := 0.5
const CLICK_PROGRESS_EPSILON := 0.2

@export var controls_enabled := true

var _has_move_target := false
var _move_target := Vector2.ZERO
var _stuck_elapsed := 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not controls_enabled or not event is InputEventMouseButton:
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	var world_position := get_viewport().get_canvas_transform().affine_inverse() * mouse_event.position
	request_move_to(world_position)
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	if not controls_enabled:
		cancel_move_target()
		velocity = Vector2.ZERO
		set_move_direction(Vector2.ZERO)
		return
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_direction.length_squared() > 0.01:
		cancel_move_target()
	elif _has_move_target:
		if global_position.distance_to(_move_target) <= CLICK_STOP_DISTANCE:
			cancel_move_target()
		else:
			input_direction = global_position.direction_to(_move_target)

	set_move_direction(input_direction)
	velocity = input_direction * move_speed
	var distance_before_move := global_position.distance_to(_move_target) if _has_move_target else 0.0
	move_and_slide()
	_update_click_move_progress(distance_before_move, delta)


func request_move_to(world_position: Vector2) -> void:
	_move_target = world_position
	_has_move_target = global_position.distance_to(_move_target) > CLICK_STOP_DISTANCE
	_stuck_elapsed = 0.0


func cancel_move_target() -> void:
	_has_move_target = false
	_stuck_elapsed = 0.0


func has_move_target() -> bool:
	return _has_move_target


func move_target() -> Vector2:
	return _move_target


func _update_click_move_progress(distance_before_move: float, delta: float) -> void:
	if not _has_move_target:
		return
	var distance_after_move := global_position.distance_to(_move_target)
	if distance_after_move <= CLICK_STOP_DISTANCE:
		cancel_move_target()
		velocity = Vector2.ZERO
		set_move_direction(Vector2.ZERO)
		return
	if distance_before_move - distance_after_move > CLICK_PROGRESS_EPSILON:
		_stuck_elapsed = 0.0
		return
	_stuck_elapsed += delta
	if _stuck_elapsed >= CLICK_STUCK_TIMEOUT:
		cancel_move_target()
		velocity = Vector2.ZERO
		set_move_direction(Vector2.ZERO)
