class_name OpeningCutscene
extends Control

const PALACE_SCENE := "res://scenes/palace/palace_demo.tscn"
const CG_TEXTURES := [
	preload("res://assets/开局过场动画/1.png"),
	preload("res://assets/开局过场动画/2.png"),
	preload("res://assets/开局过场动画/3.png"),
	preload("res://assets/开局过场动画/4.png"),
	preload("res://assets/开局过场动画/5.png"),
]
const STORY_CAPTIONS := [
	"靖平三十七年。\n东南沿海，烽烟四起。",
	"倭寇勾结海盗，乘舟犯境，焚村掠镇，劫夺商旅。\n自浙东至闽海，沿岸百姓流离失所。",
	"数州接连告急。\n八百里加急，一封接一封送入京城。",
	"朝堂震动，天子震怒。",
	"是日，一道圣旨传至将军府——\n命伏波将军即刻入宫，领旨南征，平定东南之乱。",
]
const IMAGE_FADE_SECONDS := 0.62
const CAPTION_FADE_IN_SECONDS := 0.3
const CAPTION_SECONDS_PER_CHARACTER := 0.1
const CAPTION_MIN_HOLD_SECONDS := 1.2
const CAPTION_FADE_OUT_SECONDS := 0.26
const ENDING_PAUSE_SECONDS := 0.35
const FINAL_FADE_SECONDS := 0.48

@export_range(0.01, 4.0, 0.01) var duration_scale := 1.0

@onready var image_a: TextureRect = $ImageA
@onready var image_b: TextureRect = $ImageB
@onready var cg_shade: ColorRect = $CGShade
@onready var story_text: Label = $StoryText

var _transitioning := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_reset_visuals()
	_play.call_deferred()


func opening_captions_for_test() -> Array:
	return STORY_CAPTIONS.duplicate()


func texture_paths_for_test() -> Array[String]:
	var paths: Array[String] = []
	for texture in CG_TEXTURES:
		paths.append(texture.resource_path)
	return paths


func estimated_duration_seconds_for_test() -> float:
	return _estimated_duration_seconds()


func finish_immediately_for_test() -> void:
	_go_to_palace()


func _play() -> void:
	await get_tree().process_frame
	var active_image := image_a
	active_image.texture = CG_TEXTURES[0]
	_prepare_image(active_image)

	var image_in := create_tween().set_parallel(true)
	image_in.tween_property(active_image, "modulate:a", 1.0, _duration(IMAGE_FADE_SECONDS))
	image_in.tween_property(cg_shade, "modulate:a", 1.0, _duration(IMAGE_FADE_SECONDS))
	await image_in.finished

	for index in STORY_CAPTIONS.size():
		if index > 0:
			var incoming_image := image_b if active_image == image_a else image_a
			incoming_image.texture = CG_TEXTURES[index]
			_prepare_image(incoming_image)
			var crossfade := create_tween().set_parallel(true)
			crossfade.tween_property(active_image, "modulate:a", 0.0, _duration(IMAGE_FADE_SECONDS))
			crossfade.tween_property(incoming_image, "modulate:a", 1.0, _duration(IMAGE_FADE_SECONDS))
			await crossfade.finished
			active_image.texture = null
			active_image = incoming_image

		var slide_seconds := _caption_sequence_seconds(STORY_CAPTIONS[index])
		create_tween().tween_property(active_image, "scale", Vector2.ONE, _duration(slide_seconds))
		await _show_story_caption(STORY_CAPTIONS[index])

	await _pause(ENDING_PAUSE_SECONDS)
	var image_out := create_tween().set_parallel(true)
	image_out.tween_property(active_image, "modulate:a", 0.0, _duration(FINAL_FADE_SECONDS))
	image_out.tween_property(cg_shade, "modulate:a", 0.0, _duration(FINAL_FADE_SECONDS))
	image_out.tween_property(story_text, "modulate:a", 0.0, _duration(0.28))
	await image_out.finished
	_go_to_palace()


func _reset_visuals() -> void:
	for image in [image_a, image_b]:
		image.texture = null
		image.modulate = Color(1.0, 1.0, 1.0, 0.0)
		image.scale = Vector2.ONE
	cg_shade.modulate = Color(1.0, 1.0, 1.0, 0.0)
	story_text.modulate = Color(1.0, 1.0, 1.0, 0.0)
	story_text.text = ""


func _prepare_image(image: TextureRect) -> void:
	image.pivot_offset = image.size * 0.5
	image.scale = Vector2(1.035, 1.035)
	image.modulate = Color(1.0, 1.0, 1.0, 0.0)


func _show_story_caption(caption: String) -> void:
	story_text.text = caption
	story_text.modulate.a = 0.0
	var fade_in := create_tween()
	fade_in.tween_property(story_text, "modulate:a", 1.0, _duration(CAPTION_FADE_IN_SECONDS))
	await fade_in.finished
	await _pause(_caption_hold_seconds(caption))
	var fade_out := create_tween()
	fade_out.tween_property(story_text, "modulate:a", 0.0, _duration(CAPTION_FADE_OUT_SECONDS))
	await fade_out.finished


func _caption_hold_seconds(caption: String) -> float:
	return maxf(CAPTION_MIN_HOLD_SECONDS, caption.length() * CAPTION_SECONDS_PER_CHARACTER)


func _caption_sequence_seconds(caption: String) -> float:
	return CAPTION_FADE_IN_SECONDS + _caption_hold_seconds(caption) + CAPTION_FADE_OUT_SECONDS


func _estimated_duration_seconds() -> float:
	var total := IMAGE_FADE_SECONDS + ENDING_PAUSE_SECONDS + FINAL_FADE_SECONDS
	total += (CG_TEXTURES.size() - 1) * IMAGE_FADE_SECONDS
	for caption in STORY_CAPTIONS:
		total += _caption_sequence_seconds(caption)
	return total


func _pause(seconds: float) -> void:
	await get_tree().create_timer(_duration(seconds)).timeout


func _duration(seconds: float) -> float:
	return maxf(seconds * duration_scale, 0.001)


func _go_to_palace() -> void:
	if _transitioning:
		return
	_transitioning = true
	var change_error := get_tree().change_scene_to_file(PALACE_SCENE)
	if change_error == OK:
		return
	_transitioning = false
	push_error("Opening cutscene could not load the palace scene: %s" % error_string(change_error))
