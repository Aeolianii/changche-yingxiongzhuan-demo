class_name CharacterActor
extends CharacterBody2D

const CHARACTER_FRAMES := preload("res://scripts/character_frame_catalog.gd")

@export_enum("protagonist", "soldier", "magistrate", "emperor") var character_key := "protagonist"
@export var facing := "down"
@export var move_speed := 170.0
@export var visual_scale := Vector2.ONE

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

var move_direction := Vector2.ZERO


func _ready() -> void:
	animated_sprite.scale = visual_scale
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
			for path in CHARACTER_FRAMES.paths_for(character_key, state, direction):
				var texture := ResourceLoader.load(path) as Texture2D
				if texture != null:
					frames.add_frame(animation_name, texture)
				else:
					push_error("Character texture missing: %s" % path)
	return frames
