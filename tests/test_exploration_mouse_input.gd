extends SceneTree

const FUBO_SCENE := preload("res://scenes/fubo_guling/fubo_guling.tscn")
const YUEHUAN_SCENE := preload("res://scenes/yuehuan_merchant_harbor/yuehuan_merchant_harbor.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _verify_fubo_prompt()
	await _verify_yuehuan_prompt()
	if failures.is_empty():
		print("Exploration prompt mouse-input verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_fubo_prompt() -> void:
	var scene := FUBO_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	var player := scene.get_node("World/WorldObjects/Player") as CharacterBody2D
	var prompt := scene.get_node("Interface/HUD/PromptPanel") as TextureButton
	var prompt_label := prompt.get_node("Prompt") as Label
	var minigame_host := scene.get_node("Interface/MinigameHost") as Control
	scene.call("_on_fishing_body_entered", player)
	_expect(prompt.visible, "Fubo interaction prompt must be visible for the click test.")
	_expect(prompt_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Fubo prompt text must not intercept its button's mouse events.")
	_expect(minigame_host.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Idle Fubo minigame host must not intercept exploration mouse events.")
	_expect(not prompt.pressed.get_connections().is_empty(), "Fubo prompt button must have an interaction callback.")
	if DisplayServer.get_name() != "headless":
		await _expect_real_click(prompt, "Fubo interaction prompt")
	scene.queue_free()
	await process_frame


func _verify_yuehuan_prompt() -> void:
	var scene := YUEHUAN_SCENE.instantiate()
	root.add_child(scene)
	await process_frame
	var player := scene.get_node("World/WorldObjects/Player") as CharacterBody2D
	var merchant := scene.get_node("World/WorldObjects/LiangTrader") as Node2D
	var prompt := scene.get_node("Interface/PromptPanel") as TextureButton
	var prompt_label := prompt.get_node("Prompt") as Label
	scene.call("_on_merchant_entered", player, merchant)
	_expect(prompt.visible, "Yuehuan interaction prompt must be visible for the click test.")
	_expect(prompt_label.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Yuehuan prompt text must not intercept its button's mouse events.")
	_expect(not prompt.pressed.get_connections().is_empty(), "Yuehuan prompt button must have an interaction callback.")
	if DisplayServer.get_name() != "headless":
		await _expect_real_click(prompt, "Yuehuan interaction prompt")
	scene.queue_free()
	await process_frame


func _expect_real_click(button: BaseButton, label: String) -> void:
	var press_count := [0]
	button.pressed.connect(func() -> void: press_count[0] += 1)
	var click_position := button.get_global_rect().get_center()
	_send_mouse_motion(click_position)
	await process_frame
	var hovered := root.get_viewport().gui_get_hovered_control()
	_send_mouse_button(click_position, true)
	await process_frame
	_send_mouse_button(click_position, false)
	await process_frame
	_expect(
		press_count[0] == 1,
		"%s must receive a real mouse click; hovered control was %s." % [label, hovered.get_path() if hovered != null else "<none>"]
	)


func _send_mouse_motion(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	root.get_viewport().push_input(event)


func _send_mouse_button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = position
	event.global_position = position
	root.get_viewport().push_input(event)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
