class_name CharacterActor
extends CharacterBody2D

@export_enum("protagonist", "soldier", "magistrate") var character_key := "protagonist"
@export var facing := "down"
@export var move_speed := 170.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var move_direction := Vector2.ZERO


func _ready() -> void:
	animated_sprite.sprite_frames = _build_sprite_frames()
	_play_state("idle")


func set_move_direction(direction: Vector2) -> void:
	move_direction = direction
	if direction.length_squared() > 0.01:
		if absf(direction.x) > absf(direction.y):
			facing = "right" if direction.x > 0.0 else "left"
		else:
			facing = "down" if direction.y > 0.0 else "up"
		_play_state("walk")
	else:
		_play_state("idle")


func _play_state(state: String) -> void:
	var animation_name := "%s_%s" % [state, facing]
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for state in ["idle", "walk"]:
		for direction in ["up", "left", "down", "right"]:
			var animation_name := "%s_%s" % [state, direction]
			frames.add_animation(animation_name)
			frames.set_animation_loop(animation_name, true)
			frames.set_animation_speed(animation_name, 4.0 if state == "idle" else 8.0)
			var folder := "res://assets/characters/%s/standard/%s/%s" % [character_key, state, direction]
			var files := _sorted_png_files(folder)
			for file_name in files:
				var texture := load("%s/%s" % [folder, file_name]) as Texture2D
				if texture != null:
					frames.add_frame(animation_name, texture)
	return frames


func _sorted_png_files(folder: String) -> Array[String]:
	var files: Array[String] = []
	for file_name in DirAccess.get_files_at(folder):
		if file_name.get_extension().to_lower() == "png":
			files.append(file_name)
	files.sort_custom(func(a: String, b: String) -> bool: return a.get_basename().to_int() < b.get_basename().to_int())
	return files
