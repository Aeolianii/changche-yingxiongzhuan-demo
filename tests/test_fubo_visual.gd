extends SceneTree

const FUBO_SCENE := preload("res://scenes/fubo_guling/fubo_guling.tscn")
const OUTPUT_DIR := "res://.godot/fubo_ui_verification"

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		print("Fubo visual verification skipped in headless display mode.")
		quit(0)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var level := FUBO_SCENE.instantiate()
	root.add_child(level)
	current_scene = level
	await _capture("01_exploration.png")
	(level.get_node("World/WorldObjects/Player") as Node2D).global_position = Vector2(450, 535)
	await _capture("01b_keeper_focus_no_ring.png")

	level.call("_start_dialogue")
	await _capture("02_dialogue.png")
	for _index in 3:
		level.call("_advance_dialogue")
	var player := level.get_node("World/WorldObjects/Player")
	level.call("_on_fishing_body_entered", player)
	await _capture("03_dock_prompt.png")

	var hud := root.get_node("ExplorationUI/HUD")
	hud.call("_open_quest_screen")
	await _capture("04_quest_screen.png")
	hud.call("_close_quest_screen")
	hud.call("_open_system_menu")
	await _capture("05_system_menu.png")
	hud.call("_close_system_menu")

	level.call("trigger_fishing_for_test")
	await _capture("06_fishing.png")
	var host := level.get_node("Interface/MinigameHost")
	if host.active_minigame != null:
		host.active_minigame.exit_requested.emit()
	await _capture("07_after_minigame.png")
	level.queue_free()
	await process_frame
	if _failures.is_empty():
		print("Fubo visual verification captured eight states.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)


func _capture(file_name: String) -> void:
	for _index in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "%s/%s" % [OUTPUT_DIR, file_name]
	if image == null or image.save_png(path) != OK:
		_failures.append("Could not capture %s." % file_name)
