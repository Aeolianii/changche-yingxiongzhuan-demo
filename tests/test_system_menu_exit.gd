extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/exploration_hud.tscn")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var watchdog := create_timer(2.0)
	watchdog.timeout.connect(_fail_if_game_did_not_exit)

	var hud := HUD_SCENE.instantiate() as Control
	root.add_child(hud)
	await process_frame
	hud.call("set_exploration_visible", true)
	var menu_button := hud.find_child("MenuButton", true, false) as Button
	menu_button.pressed.emit()
	var exit_button := hud.find_child("ExitGameButton", true, false) as Button
	print("System menu exit action dispatched.")
	exit_button.pressed.emit()


func _fail_if_game_did_not_exit() -> void:
	push_error("ExitGameButton did not quit the scene tree.")
	quit(1)
