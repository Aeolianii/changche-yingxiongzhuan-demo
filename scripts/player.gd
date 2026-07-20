extends CharacterActor

@export var controls_enabled := true


func _physics_process(_delta: float) -> void:
	if not controls_enabled:
		velocity = Vector2.ZERO
		set_move_direction(Vector2.ZERO)
		return
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	set_move_direction(input_direction)
	velocity = input_direction * move_speed
	move_and_slide()
