extends Node2D

enum StoryState {
	OPENING_REPORTS,
	ATTENDANT_WALKS_OUT,
	WAIT_TALK,
	SUMMON_DIALOGUE,
	GO_TO_EMPEROR,
	AUDIENCE_DIALOGUE,
	IMPERIAL_EDICT,
	COMPLETE,
}

const OPENING_REPORTS := [
	"【旁白】\n岭南加急奏疏。",
	"【旁白】\n蕃国贡使血状。",
	"【旁白】\n海防失事文书。\n三份急报，一并送入御前。",
]

const AUDIENCE_LINES := [
	"朕数次调北军南下，北人不习水战、不识星象潮汐、不辨岛礁暗滩，数次巡洋皆未安南海。望卿为朕重整岭南海防、剿灭海盗、收复海岛、重开万国贡路。",
	"臣领旨！定当筑水师、固海防、清海寇、复海岛、安万民、通贡路！海疆不平，臣绝不北归！",
]

const SOLDIER_PORTRAIT := preload("res://assets/characters/soldier/picture.png")
const GENERAL_PORTRAIT := preload("res://assets/characters/protagonist/picture.png")
const ATTENDANT_OUTSIDE_TARGET := Vector2(710.0, 832.0)
const ATTENDANT_INSIDE_TARGET := Vector2(690.0, 350.0)
const SCRIPTED_SPEED := 155.0
const INTERACTION_DISTANCE := 105.0
const SCENE_PATH := "res://scenes/palace/palace_demo.tscn"
const TITLE_SCENE_PATH := "res://scenes/ui/title_screen.tscn"
const NEXT_SCENE_PATH := "res://scenes/Scene2.tscn"
const CHAPTER_ENTRY_META := &"chapter_transition_from_scene_one"
const SCENE_TRANSITION_DELAY := 2.5

@onready var player: CharacterActor = $YSortedCharacters/Player
@onready var emperor: CharacterActor = $YSortedCharacters/Emperor
@onready var attendant: CharacterActor = $YSortedCharacters/Attendant
@onready var dialogue_panel: Control = $UI/Overlay/DialoguePanel
@onready var dialogue_text: Label = $UI/Overlay/DialoguePanel/DialogueText
@onready var continue_button: BaseButton = $UI/Overlay/DialoguePanel/ContinueButton
@onready var portrait_display: Control = $UI/Overlay/PortraitDisplay
@onready var portrait_image: TextureRect = $UI/Overlay/PortraitDisplay/PortraitImage
@onready var portrait_placeholder: ColorRect = $UI/Overlay/PortraitDisplay/PlaceholderFrame
@onready var portrait_placeholder_text: Label = $UI/Overlay/PortraitDisplay/PlaceholderFrame/PlaceholderInner/PlaceholderText
@onready var portrait_name_text: Label = $UI/Overlay/PortraitDisplay/NamePlate/NameText
@onready var interaction_button: BaseButton = $UI/Overlay/InteractionButton
@onready var interaction_text: Label = $UI/Overlay/InteractionButton/Text
var exploration_hud: Control
var _exploration_ui: Node
@onready var transition_timer: Timer = $SceneTransitionTimer
@onready var transition_fade: ColorRect = $UI/Overlay/TransitionFade
@onready var chapter_transition: Control = $UI/Overlay/ChapterTransition

var story_state := StoryState.OPENING_REPORTS
var opening_index := 0
var audience_index := 0
var transition_started := false


func _ready() -> void:
	_exploration_ui = get_node("/root/ExplorationUI")
	exploration_hud = _exploration_ui.call("acquire", self, &"palace") as Control
	continue_button.pressed.connect(_on_continue_pressed)
	interaction_button.pressed.connect(_on_interaction_pressed)
	_connect_global_hud_signals()
	transition_timer.timeout.connect(_start_scene_transition)
	chapter_transition.connect("transition_finished", _change_to_scene_two)
	transition_timer.wait_time = SCENE_TRANSITION_DELAY
	interaction_button.hide()
	player.controls_enabled = true
	var restored_state := _consume_saved_scene_state()
	if restored_state.is_empty():
		_set_task("阅看岭南急报")
		_show_dialogue(OPENING_REPORTS[opening_index])
	else:
		_restore_saved_scene_state(restored_state)


func _exit_tree() -> void:
	if _exploration_ui == null:
		return
	_disconnect_global_hud_signals()
	_exploration_ui.call("release", self)


func _connect_global_hud_signals() -> void:
	for binding in [
		[&"menu_visibility_changed", Callable(self, "_on_menu_visibility_changed")],
		[&"save_requested", Callable(self, "_on_save_requested")],
		[&"load_requested", Callable(self, "_on_load_requested")],
		[&"return_title_requested", Callable(self, "_on_return_title_requested")],
	]:
		if not _exploration_ui.is_connected(binding[0], binding[1]):
			_exploration_ui.connect(binding[0], binding[1])


func _disconnect_global_hud_signals() -> void:
	for binding in [
		[&"menu_visibility_changed", Callable(self, "_on_menu_visibility_changed")],
		[&"save_requested", Callable(self, "_on_save_requested")],
		[&"load_requested", Callable(self, "_on_load_requested")],
		[&"return_title_requested", Callable(self, "_on_return_title_requested")],
	]:
		if _exploration_ui.is_connected(binding[0], binding[1]):
			_exploration_ui.disconnect(binding[0], binding[1])


func _process(delta: float) -> void:
	match story_state:
		StoryState.ATTENDANT_WALKS_OUT:
			if _move_actor(attendant, ATTENDANT_OUTSIDE_TARGET, delta):
				story_state = StoryState.WAIT_TALK
		StoryState.WAIT_TALK:
			_update_interaction_prompt(attendant, "对话")
		StoryState.GO_TO_EMPEROR:
			_move_actor(attendant, ATTENDANT_INSIDE_TARGET, delta)
			_update_interaction_prompt(emperor, "觐见")
	_sync_player_controls()
	_refresh_exploration_hud()


func _unhandled_input(event: InputEvent) -> void:
	if exploration_hud.call("is_menu_open"):
		return
	if not event.is_action_pressed("interact"):
		return
	if event is InputEventKey and event.echo:
		return

	get_viewport().set_input_as_handled()
	if dialogue_panel.visible:
		_on_continue_pressed()
	elif interaction_button.visible:
		_on_interaction_pressed()


func _move_actor(actor: CharacterActor, target: Vector2, delta: float) -> bool:
	var distance := actor.global_position.distance_to(target)
	if distance <= 3.0:
		actor.global_position = target
		actor.set_move_direction(Vector2.ZERO)
		return true
	var direction := actor.global_position.direction_to(target)
	actor.global_position = actor.global_position.move_toward(target, SCRIPTED_SPEED * delta)
	actor.set_move_direction(direction)
	return false


func _update_interaction_prompt(target: Node2D, prompt: String) -> void:
	if player.global_position.distance_to(target.global_position) <= INTERACTION_DISTANCE:
		_show_interaction(prompt)
	else:
		interaction_button.hide()


func _on_continue_pressed() -> void:
	match story_state:
		StoryState.OPENING_REPORTS:
			opening_index += 1
			if opening_index < OPENING_REPORTS.size():
				_show_dialogue(OPENING_REPORTS[opening_index])
			else:
				_hide_dialogue()
				story_state = StoryState.ATTENDANT_WALKS_OUT
				_set_task("听取内侍传召")
		StoryState.SUMMON_DIALOGUE:
			_hide_dialogue()
			story_state = StoryState.GO_TO_EMPEROR
			_set_task("奉诏入殿")
		StoryState.AUDIENCE_DIALOGUE:
			audience_index += 1
			if audience_index < AUDIENCE_LINES.size():
				_show_audience_dialogue()
			else:
				story_state = StoryState.IMPERIAL_EDICT
				_show_dialogue("【圣旨·原型占位】\n命水师主帅总领岭南海防，筹建水师、剿除海寇、收复海岛、重开万国贡路。")
		StoryState.IMPERIAL_EDICT:
			story_state = StoryState.COMPLETE
			_set_task("领旨南下")
			_show_dialogue("【旁白】\n水师主帅领旨南下。场景一完成。")
			_set_continue_text("立即启程")
			transition_timer.start()
		StoryState.COMPLETE:
			_start_scene_transition()


func _on_interaction_pressed() -> void:
	interaction_button.hide()
	match story_state:
		StoryState.WAIT_TALK:
			story_state = StoryState.SUMMON_DIALOGUE
			_show_character_dialogue("伏波大将军，陛下有旨，宣您即刻入殿觐见。", "内侍", SOLDIER_PORTRAIT, false)
		StoryState.GO_TO_EMPEROR:
			story_state = StoryState.AUDIENCE_DIALOGUE
			audience_index = 0
			_set_task("聆听圣谕")
			_show_audience_dialogue()


func _show_audience_dialogue() -> void:
	if audience_index == 0:
		_show_character_dialogue(AUDIENCE_LINES[audience_index], "皇帝", null, false, "帝")
	else:
		_show_character_dialogue(AUDIENCE_LINES[audience_index], "水师主帅", GENERAL_PORTRAIT, true)


func _show_dialogue(text: String) -> void:
	dialogue_text.text = text
	_set_continue_text("继续")
	_set_dialogue_text_layout(-1)
	_hide_portrait()
	dialogue_panel.show()
	_sync_player_controls()


func _show_character_dialogue(text: String, speaker: String, portrait_texture: Texture2D, portrait_on_left: bool, placeholder_text: String = "") -> void:
	dialogue_text.text = text
	_set_continue_text("继续")
	_show_portrait(speaker, portrait_texture, portrait_on_left, placeholder_text)
	_set_dialogue_text_layout(1 if portrait_on_left else 0)
	dialogue_panel.show()
	_sync_player_controls()


func _show_portrait(speaker: String, portrait_texture: Texture2D, portrait_on_left: bool, placeholder_text: String) -> void:
	_set_portrait_side(portrait_on_left)
	portrait_name_text.text = speaker

	if portrait_texture != null:
		portrait_image.texture = portrait_texture
		portrait_image.show()
		portrait_placeholder.hide()
	else:
		portrait_image.texture = null
		portrait_image.hide()
		portrait_placeholder_text.text = placeholder_text
		portrait_placeholder.show()

	portrait_display.show()


func _set_portrait_side(portrait_on_left: bool) -> void:
	portrait_display.anchor_left = 0.0 if portrait_on_left else 1.0
	portrait_display.anchor_right = portrait_display.anchor_left
	if portrait_on_left:
		portrait_display.offset_left = 18.0
		portrait_display.offset_right = 418.0
	else:
		portrait_display.offset_left = -418.0
		portrait_display.offset_right = -18.0


func _set_dialogue_text_layout(speaker_side: int) -> void:
	match speaker_side:
		1:
			dialogue_text.offset_left = 450.0
			dialogue_text.offset_right = -264.0
		0:
			dialogue_text.offset_left = 230.0
			dialogue_text.offset_right = -464.0
		_:
			dialogue_text.offset_left = 272.0
			dialogue_text.offset_right = -344.0


func _hide_portrait() -> void:
	portrait_display.hide()
	portrait_image.hide()
	portrait_placeholder.hide()


func _hide_dialogue() -> void:
	dialogue_panel.hide()
	_hide_portrait()
	_sync_player_controls()


func _sync_player_controls() -> void:
	player.controls_enabled = (
		not transition_started
		and not dialogue_panel.visible
		and not bool(exploration_hud.call("is_menu_open"))
		and _is_free_story_state()
	)


func _show_interaction(text: String) -> void:
	interaction_text.text = text
	interaction_button.show()


func _set_continue_text(text: String) -> void:
	var label := continue_button.get_node_or_null("Text") as Label
	if label != null:
		label.text = "%s  ▼" % text


func _set_task(text: String) -> void:
	exploration_hud.call("set_main_task", text)


func _refresh_exploration_hud() -> void:
	var is_free_exploration: bool = (
		not dialogue_panel.visible
		and not transition_started
		and _is_free_story_state()
	)
	exploration_hud.call("set_exploration_visible", is_free_exploration)


func _is_free_story_state() -> bool:
	return story_state == StoryState.WAIT_TALK or story_state == StoryState.GO_TO_EMPEROR


func _on_menu_visibility_changed(is_open: bool) -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	player.controls_enabled = (
		not is_open
		and not transition_started
		and not dialogue_panel.visible
		and _is_free_story_state()
	)
	if is_open:
		interaction_button.hide()
	_refresh_exploration_hud()


func _on_save_requested() -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	if not _is_free_story_state() or transition_started or dialogue_panel.visible:
		_show_save_message(false, "unstable_scene")
		return
	var game_state := _game_state()
	if game_state == null:
		_show_save_message(false, "write_failed")
		return
	var snapshot := {
		"story_state": story_state,
		"player_position": _vector_to_save(player.global_position),
		"attendant_position": _vector_to_save(attendant.global_position),
	}
	var result: Dictionary = game_state.call("save_game", SCENE_PATH, snapshot)
	_show_save_message(bool(result.get("ok", false)), str(result.get("reason", "")))


func _on_load_requested() -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	var game_state := _game_state()
	if game_state == null:
		_show_save_message(false, "read_failed")
		return
	var result: Dictionary = game_state.call("load_game")
	if not result.get("ok", false):
		_show_save_message(false, str(result.get("reason", "read_failed")))
		return
	var change_error := get_tree().change_scene_to_file(str(result["scene_path"]))
	if change_error != OK:
		game_state.call("clear_pending_scene_state")
		_show_save_message(false, "scene_change_failed")


func _on_return_title_requested() -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	var game_state := _game_state()
	if game_state != null:
		game_state.call("clear_pending_scene_state")
	var change_error := get_tree().change_scene_to_file(TITLE_SCENE_PATH)
	if change_error != OK:
		_show_save_message(false, "scene_change_failed")


func _consume_saved_scene_state() -> Dictionary:
	var game_state := _game_state()
	if game_state == null:
		return {}
	return game_state.call("consume_pending_scene_state", SCENE_PATH) as Dictionary


func _restore_saved_scene_state(snapshot: Dictionary) -> void:
	var restored_story_state := int(snapshot.get("story_state", StoryState.WAIT_TALK))
	if restored_story_state not in [StoryState.WAIT_TALK, StoryState.GO_TO_EMPEROR]:
		restored_story_state = StoryState.WAIT_TALK
	story_state = restored_story_state
	player.global_position = _vector_from_save(snapshot.get("player_position"), player.global_position)
	attendant.global_position = _vector_from_save(snapshot.get("attendant_position"), attendant.global_position)
	attendant.set_move_direction(Vector2.ZERO)
	transition_started = false
	transition_timer.stop()
	_hide_dialogue()
	interaction_button.hide()
	player.controls_enabled = true
	_set_task("听取内侍传召" if story_state == StoryState.WAIT_TALK else "奉诏入殿")
	_refresh_exploration_hud()


func _show_save_message(success: bool, reason: String) -> void:
	if success:
		exploration_hud.call("show_toast", "进度已保存")
		return
	var game_state := _game_state()
	var message := "存档操作失败。" if game_state == null else str(game_state.call("error_message", reason))
	exploration_hud.call("show_toast", message)


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _vector_to_save(value: Vector2) -> Array:
	return [value.x, value.y]


func _vector_from_save(value: Variant, fallback: Vector2) -> Vector2:
	if not value is Array or value.size() != 2:
		return fallback
	var restored := Vector2(float(value[0]), float(value[1]))
	return restored if is_finite(restored.x) and is_finite(restored.y) else fallback


func _start_scene_transition() -> void:
	if transition_started:
		return
	transition_started = true
	transition_timer.stop()
	player.controls_enabled = false
	_refresh_exploration_hud()
	continue_button.disabled = true
	interaction_button.hide()
	_hide_dialogue()
	chapter_transition.call("play")


func _change_to_scene_two() -> void:
	get_tree().root.set_meta(CHAPTER_ENTRY_META, true)
	var change_result := get_tree().change_scene_to_file(NEXT_SCENE_PATH)
	if change_result == OK:
		return

	get_tree().root.remove_meta(CHAPTER_ENTRY_META)
	transition_started = false
	player.controls_enabled = true
	continue_button.disabled = false
	transition_fade.modulate = Color(1.0, 1.0, 1.0, 0.0)
	chapter_transition.call("reset_transition")
	_show_dialogue("【提示】\n南疆场景加载失败，请重试启程。")
	_set_continue_text("重试启程")
