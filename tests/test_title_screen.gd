extends SceneTree

const TITLE_SCENE := preload("res://scenes/ui/title_screen.tscn")
const TEST_SAVE_PATH := "user://test_title_screen_save.json"
const SCENE_TWO_PATH := "res://scenes/Scene2.tscn"
const SCREENSHOT_PATH := "res://.godot/title_screen_preview.png"

var failures: Array[String] = []
var game_state: Node


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	game_state = root.get_node_or_null("GameState")
	_expect(game_state != null, "Title test requires the GameState autoload.")
	if game_state == null:
		quit(1)
		return
	game_state.set("save_path_override", TEST_SAVE_PATH)
	_cleanup_test_files()
	await _verify_empty_title_state()
	await _verify_continue_game()
	await _verify_new_game_preserves_save()
	_cleanup_test_files()
	game_state.set("save_path_override", "")
	game_state.call("clear_pending_scene_state")
	if failures.is_empty():
		print("Title-screen runtime verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_empty_title_state() -> void:
	var title := await _open_title()
	var background := title.get_node("Background") as TextureRect
	var title_artwork := title.get_node("MainContent/MainStack/TitleArtwork") as TextureRect
	var continue_button := title.get_node("%ContinueButton") as Button
	var new_game_button := title.get_node("%NewGameButton") as Button
	var settings_button := title.get_node("%SettingsButton") as Button
	var exit_button := title.get_node("%ExitButton") as Button
	var save_status := title.get_node("%SaveStatus") as Label
	_expect(background.texture != null, "Title screen must load its generated background.")
	if background.texture != null:
		_expect(background.texture.get_width() * 2 == background.texture.get_height() * 3, "Title background must keep the documented 3:2 aspect ratio.")
	_expect(title_artwork.texture != null and title_artwork.texture.resource_path.ends_with("title_calligraphy_v1.png"), "Title screen must use the generated calligraphy title artwork.")
	if title_artwork.texture != null:
		var title_image := title_artwork.texture.get_image()
		_expect(title_image != null and title_image.get_pixel(0, 0).a < 0.05, "Generated title artwork must keep transparent corners.")
	var button_style := continue_button.get_theme_stylebox("normal") as StyleBoxTexture
	_expect(button_style != null and button_style.texture != null and button_style.texture.resource_path.ends_with("menu_button_ink_v1.png"), "Main-menu options must use the generated ink button backing.")
	if button_style != null and button_style.texture != null:
		var button_image := button_style.texture.get_image()
		_expect(button_image != null and button_image.get_pixel(0, 0).a < 0.05, "Generated menu button backing must keep transparent corners.")
	_expect(continue_button.disabled, "Continue must be disabled when the isolated save slot is empty.")
	_expect(not save_status.visible, "Title screen must not show persistent small-print save status.")
	_expect(new_game_button.text == "开始新游戏" and settings_button.text == "游戏设置" and exit_button.text == "退出游戏", "Title screen must expose the documented primary menu.")
	if DisplayServer.get_name() != "headless":
		await create_timer(1.25).timeout
		await RenderingServer.frame_post_draw
		var screenshot := root.get_texture().get_image()
		var screenshot_error := screenshot.save_png(SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "Title screen preview screenshot must save successfully.")

	settings_button.pressed.emit()
	await process_frame
	_expect(bool(title.call("is_settings_open")), "Settings button must open the title settings panel.")
	var music_slider := title.get_node("%MusicSlider") as HSlider
	var music_index := AudioServer.get_bus_index(&"Music")
	music_slider.value = 37.0
	_expect(is_equal_approx(AudioServer.get_bus_volume_db(music_index), linear_to_db(0.37)), "Title music slider must update the Music bus.")
	(title.get_node("%SettingsReturnButton") as Button).pressed.emit()
	await process_frame
	_expect(not bool(title.call("is_settings_open")), "Title settings return must restore the main menu.")
	music_slider.value = 100.0


func _verify_continue_game() -> void:
	var snapshot := {
		"patrol_task_stage": 0,
		"heard_soldier_roles": [],
		"player_position": [612.0, 548.0],
		"last_direction": "left",
	}
	var save_result: Dictionary = game_state.call("save_game", SCENE_TWO_PATH, snapshot)
	_expect(bool(save_result.get("ok", false)), "Title test must create its isolated save.")
	var title := current_scene
	title.call("refresh_save_state")
	var continue_button := title.get_node("%ContinueButton") as Button
	_expect(not continue_button.disabled, "Continue must enable when a save exists.")
	continue_button.pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene != null and current_scene.scene_file_path == SCENE_TWO_PATH, "Continue must enter the scene recorded by the save.")
	if current_scene != null and current_scene.scene_file_path == SCENE_TWO_PATH:
		var player := current_scene.get_node("World/Actors/Player") as CharacterBody2D
		_expect(player.global_position.distance_to(Vector2(612.0, 548.0)) < 1.0, "Continue must restore the saved player position.")
		(current_scene.get_node("UI/ExplorationHUD") as Control).emit_signal("return_title_requested")
		await process_frame
		await process_frame
		_expect(current_scene != null and current_scene.scene_file_path == "res://scenes/ui/title_screen.tscn", "Scene2 system menu route must return to the title screen.")


func _verify_new_game_preserves_save() -> void:
	var save_before := FileAccess.get_file_as_string(TEST_SAVE_PATH)
	game_state.call("set_sea_fog_state", {"version": 1, "revealed_bits": "AQ=="})
	var title := await _open_title()
	(title.get_node("%NewGameButton") as Button).pressed.emit()
	await process_frame
	await process_frame
	_expect(current_scene != null and current_scene.scene_file_path == "res://scenes/palace/palace_demo.tscn", "New game must enter the palace opening scene.")
	_expect(FileAccess.file_exists(TEST_SAVE_PATH), "New game must not delete the existing save.")
	_expect(FileAccess.get_file_as_string(TEST_SAVE_PATH) == save_before, "New game must not rewrite the existing save.")
	_expect((game_state.call("get_sea_fog_state") as Dictionary).is_empty(), "New game must clear runtime chart exploration without touching the disk save.")
	if current_scene != null and current_scene.scene_file_path == "res://scenes/palace/palace_demo.tscn":
		(current_scene.get_node("UI/ExplorationHUD") as Control).emit_signal("return_title_requested")
		await process_frame
		await process_frame
		_expect(current_scene != null and current_scene.scene_file_path == "res://scenes/ui/title_screen.tscn", "Palace system menu route must return to the title screen.")


func _open_title() -> Node:
	if current_scene != null:
		current_scene.queue_free()
		current_scene = null
		await process_frame
	var title := TITLE_SCENE.instantiate()
	root.add_child(title)
	current_scene = title
	await process_frame
	await process_frame
	return title


func _cleanup_test_files() -> void:
	for suffix in ["", ".tmp", ".bak"]:
		var path: String = TEST_SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
