extends SceneTree

const HUD := preload("res://scenes/ui/exploration_hud.tscn")
const SCREENSHOT_PATH := "res://.godot/ship_screen_preview.png"
const SCROLL_SCREENSHOT_PATH := "res://.godot/ship_screen_scroll_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_runtime_world_state")
	var economy: Dictionary = game_state.call("get_economy_state")
	var starting_types: Array[String] = []
	for ship_value in economy["ships"]:
		starting_types.append(str((ship_value as Dictionary).get("type_id", "")))
	_expect(starting_types == ["patrol_boat", "cannon_warship", "escort_junk"], "New games must begin with one ship of every catalog type.")

	var hud := HUD.instantiate() as Control
	root.add_child(hud)
	await process_frame
	hud.call("set_exploration_visible", true)
	var locks: Array[bool] = []
	hud.menu_visibility_changed.connect(func(value: bool): locks.append(value))
	var ship_button := hud.find_child("ShipButton", true, false) as Button
	_expect(ship_button != null, "Exploration HUD must expose the ship button.")
	ship_button.pressed.emit()
	await process_frame

	var screen := hud.get_node("ShipScreen") as Control
	_expect(screen.visible and hud.call("is_ship_screen_open"), "ShipButton must open the real ship screen.")
	_expect(not hud.get_node("FunctionButtons").visible and not hud.get_node("FunctionButtonsBrushstroke").visible, "Opening ships must hide the exploration function strip.")
	var background := screen.get_node("GeneratedShipBackground") as TextureRect
	_expect(background.texture.resource_path.ends_with("quest_screen_background.png"), "Ship screen must reuse the quest screen ink background.")
	_expect(screen.get_node("ScreenTitle").text == "船只", "Ship screen must have its own title.")
	_expect(screen.get_node("ShipListTitle").text == "舰队名册" and screen.get_node("ShipDetailHeader").text == "舰船详情", "Ship screen must use a clear left-list/right-detail structure.")

	var ship_list := screen.get_node("ShipListScroll/ShipList") as VBoxContainer
	_expect(ship_list.get_child_count() == 3, "Starting fleet list must show all three owned ships.")
	_expect((screen.get_node("FleetCount") as Label).text.contains("3 艘"), "Fleet header must show the current ship count without a capacity limit.")
	_expect(not (screen.get_node("ShipListScroll") as ScrollContainer).get_v_scroll_bar().visible, "Scrollbar must stay hidden when the owned ships already fit in the list.")
	for index in range(ship_list.get_child_count()):
		var choice := ship_list.get_child(index) as Button
		_expect(choice.get_node_or_null("ShipIcon") is TextureRect, "Every fleet row must show a ship image.")
		_expect(choice.get_node_or_null("ShipName") is Label and choice.get_node_or_null("ShipRole") is Label and choice.get_node_or_null("ShipSummary") is Label, "Every fleet row must show name, role and rough status.")

	_expect(str(screen.call("selected_ship_id_for_test")) == "ship_001", "Opening ships must select the first owned vessel.")
	_expect((screen.get_node("SelectedShipName") as RichTextLabel).text.contains("巡哨快船"), "Default detail must describe the selected patrol boat.")
	_expect((screen.get_node("SelectedShipPreview") as TextureRect).texture.resource_path.ends_with("patrol_boat.png"), "Selected patrol boat must use its existing ship artwork.")
	_expect(screen.get_node("ShipStats").get_child_count() == 4, "Detailed information must include firepower, speed, armor and cargo.")
	_expect((screen.get_node("CrewLabel") as Label).text.contains("26"), "Detailed information must include crew complement.")
	_expect((screen.get_node("ConstructionLabel") as Label).text.contains("军饷") and (screen.get_node("ConstructionLabel") as Label).text.contains("木材"), "Detailed information must include shipbuilding requirements.")

	(ship_list.get_child(1) as Button).pressed.emit()
	await process_frame
	_expect(str(screen.call("selected_ship_id_for_test")) == "ship_002", "Selecting a fleet row must update the active ship.")
	_expect((screen.get_node("SelectedShipName") as RichTextLabel).text.contains("火炮战船"), "Right detail panel must refresh for the selected cannon warship.")
	_expect((screen.get_node("DurabilityLabel") as Label).text == "72 / 72", "Selected ship detail must display current and maximum durability.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var initial_screenshot_error := root.get_texture().get_image().save_png(SCREENSHOT_PATH)
		_expect(initial_screenshot_error == OK, "Initial ship screen preview screenshot could not be saved.")

	var long_fleet: Array[Dictionary] = screen.get("_ships")
	for index in range(6):
		var extra := (economy["ships"][index % 3] as Dictionary).duplicate(true)
		extra["id"] = "preview_%03d" % index
		long_fleet.append(extra)
	screen.call("_rebuild_ship_list")
	await process_frame
	var list_scroll := screen.get_node("ShipListScroll") as ScrollContainer
	var scrollbar := list_scroll.get_v_scroll_bar()
	_expect(scrollbar.visible and scrollbar.max_value > scrollbar.page, "Long fleets must expose a usable vertical scrollbar on the right.")
	_expect(scrollbar.custom_minimum_size.x == 26.0, "Fleet scrollbar must be 26 pixels wide.")
	_expect(scrollbar.get_theme_stylebox("scroll") is StyleBoxTexture, "Fleet scrollbar track must use the generated ink-pixel material.")
	_expect(scrollbar.get_theme_stylebox("grabber") is StyleBoxFlat, "Fleet scrollbar thumb must use a non-stretched solid color.")
	var grabber_style := scrollbar.get_theme_stylebox("grabber") as StyleBoxFlat
	_expect(grabber_style.border_width_left + grabber_style.border_width_right == 5, "Solid scrollbar thumb must be about 20 percent narrower than the 26-pixel track.")
	scrollbar.value = scrollbar.max_value
	await process_frame
	_expect(list_scroll.scroll_vertical > 0, "Dragging the fleet scrollbar must move the ship list.")
	var first_row := ship_list.get_child(0) as Control
	_expect(list_scroll.clip_contents and first_row.position.x + first_row.size.x <= list_scroll.size.x, "Selected ship highlights must remain clipped inside the left list frame.")

	if DisplayServer.get_name() != "headless":
		await process_frame
		var screenshot_error := root.get_texture().get_image().save_png(SCROLL_SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "Scrollable ship screen preview screenshot could not be saved.")

	(screen.get_node("ShipReturnSlot/ShipReturnButton") as Button).pressed.emit()
	await process_frame
	_expect(not screen.visible and hud.get_node("FunctionButtons").visible, "Ship return button must restore the exploration HUD.")
	ship_button.pressed.emit()
	await process_frame
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	screen.call("_unhandled_key_input", escape)
	await process_frame
	_expect(not screen.visible, "Escape must close the ship screen.")
	_expect(locks == [true, false, true, false], "Opening and closing ships must lock and restore world input exactly once.")

	hud.queue_free()
	await process_frame
	game_state.call("reset_runtime_world_state")
	if failures.is_empty():
		print("Ship screen verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
