class_name WokouVictoryCutscene
extends Control

signal cutscene_finished

const STORY_CAPTIONS := [
	"伏波将军上任以来，整饬水师，巡弋诸岛，誓平海疆宿患。",
	"今率厂车将士直捣贼巢，破寨毁舟，倭寇之乱终告平定。",
	"自此商船复通，渔火重明，流离百姓也得以重返故里。",
	"沿海乡镇炊烟再起，百业渐兴，军民无不称颂将军。",
	"护境有方，治军有度；从此海晏民安，万家长享太平。",
]
const IMAGE_FADE_SECONDS := 0.62
const CAPTION_FADE_IN_SECONDS := 0.3
const CAPTION_SECONDS_PER_CHARACTER := 0.065
const CAPTION_MIN_HOLD_SECONDS := 1.2
const CAPTION_FADE_OUT_SECONDS := 0.26
const ENDING_PAUSE_SECONDS := 0.35
const FINAL_FADE_SECONDS := 0.48

@export_range(0.01, 4.0, 0.01) var duration_scale := 1.0

@onready var cg_image: TextureRect = $CGImage
@onready var cg_shade: ColorRect = $CGShade
@onready var story_text: Label = $StoryText

var _playing := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()


func play() -> void:
	if _playing:
		return
	_playing = true
	_reset_visuals()
	show()
	await get_tree().process_frame
	cg_image.pivot_offset = cg_image.size * 0.5
	cg_image.scale = Vector2(1.035, 1.035)

	create_tween().tween_property(cg_image, "scale", Vector2.ONE, _duration(_estimated_duration_seconds()))
	var image_in := create_tween().set_parallel(true)
	image_in.tween_property(cg_image, "modulate:a", 1.0, _duration(IMAGE_FADE_SECONDS))
	image_in.tween_property(cg_shade, "modulate:a", 1.0, _duration(IMAGE_FADE_SECONDS))
	await image_in.finished

	for caption in STORY_CAPTIONS:
		await _show_story_caption(caption)
	await _pause(ENDING_PAUSE_SECONDS)

	var image_out := create_tween().set_parallel(true)
	image_out.tween_property(cg_image, "modulate:a", 0.0, _duration(FINAL_FADE_SECONDS))
	image_out.tween_property(cg_shade, "modulate:a", 0.0, _duration(FINAL_FADE_SECONDS))
	image_out.tween_property(story_text, "modulate:a", 0.0, _duration(0.28))
	await image_out.finished

	hide()
	_playing = false
	cutscene_finished.emit()


func is_playing_for_test() -> bool:
	return _playing


func story_captions_for_test() -> Array:
	return STORY_CAPTIONS.duplicate()


func estimated_duration_seconds_for_test() -> float:
	return _estimated_duration_seconds()


func _reset_visuals() -> void:
	cg_image.modulate = Color(1.0, 1.0, 1.0, 0.0)
	cg_image.scale = Vector2.ONE
	cg_shade.modulate = Color(1.0, 1.0, 1.0, 0.0)
	story_text.modulate = Color(1.0, 1.0, 1.0, 0.0)
	story_text.text = ""


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


func _estimated_duration_seconds() -> float:
	var total := IMAGE_FADE_SECONDS + ENDING_PAUSE_SECONDS + FINAL_FADE_SECONDS
	for caption in STORY_CAPTIONS:
		total += CAPTION_FADE_IN_SECONDS + _caption_hold_seconds(caption) + CAPTION_FADE_OUT_SECONDS
	return total


func _pause(seconds: float) -> void:
	await get_tree().create_timer(_duration(seconds)).timeout


func _duration(seconds: float) -> float:
	return maxf(seconds * duration_scale, 0.001)
