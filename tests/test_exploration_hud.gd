extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/exploration_hud.tscn")
const PALACE_SCENE := preload("res://scenes/palace/palace_demo.tscn")
const SCENE_TWO := preload("res://scenes/Scene2.tscn")
const SCREENSHOT_PATH := "res://.godot/exploration_hud_preview.png"
const MENU_SCREENSHOT_PATH := "res://.godot/system_menu_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_verify_generated_assets()
	await _verify_component_contract()
	await _verify_palace_visibility()
	await _verify_scene_two_visibility()

	if failures.is_empty():
		print("Exploration HUD runtime verification passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_generated_assets() -> void:
	for asset_path in [
		"res://assets/ui/system_menu/system_menu_frame.png",
		"res://assets/ui/system_menu/menu_button.png",
		"res://assets/ui/system_menu/close_button.png",
		"res://assets/ui/exploration_hud/player_status_frame.png",
		"res://assets/ui/exploration_hud/function_button.png",
	]:
		var texture := load(asset_path) as Texture2D
		var image := texture.get_image() if texture != null else null
		_expect(image != null and not image.is_empty(), "%s could not be loaded." % asset_path)
		if image == null or image.is_empty():
			continue
		_expect(image.get_pixel(0, 0).a < 0.05, "%s must have a transparent corner." % asset_path)
		_expect(image.get_pixel(image.get_width() / 2, image.get_height() / 2).a > 0.95, "%s must keep an opaque component center." % asset_path)

	var quest_texture := load("res://assets/ui/exploration_hud/quest_tracker_frame.png") as Texture2D
	var quest_image := quest_texture.get_image() if quest_texture != null else null
	_expect(quest_image != null and not quest_image.is_empty(), "Generated quest frame could not be loaded.")
	if quest_image != null and not quest_image.is_empty():
		_expect(quest_image.get_pixel(0, 0).a < 0.05, "Generated quest frame must have a transparent corner.")
		_expect(quest_image.get_pixel(quest_image.get_width() / 2, quest_image.get_height() / 2).a < 0.05, "Generated quest frame must keep its center transparent.")


func _verify_component_contract() -> void:
	var hud := HUD_SCENE.instantiate() as Control
	root.add_child(hud)
	await process_frame
	_expect(not hud.visible, "Exploration HUD must start hidden until a scene reports free movement.")

	hud.call("set_exploration_visible", true)
	_expect(hud.visible, "Exploration HUD did not become visible through its public interface.")
	var player_status := hud.get_node("PlayerStatus") as Control
	_expect(player_status.size == Vector2(495, 192), "Player status must be enlarged by 50 percent.")
	var portrait_frame := hud.get_node("PlayerStatus/PortraitFrame") as Control
	_expect(portrait_frame.get_node_or_null("ProtagonistPortrait") != null, "Player portrait is missing.")
	_expect(portrait_frame.position.x >= 25.0, "Player portrait must move right into the generated diamond center.")
	_expect(hud.get_node_or_null("PlayerStatus/StatusSeal") == null, "Player status must not display the lower-right status seal.")
	var name_plate := hud.get_node("PlayerStatus/NamePlate") as Control
	_expect(name_plate.position.y >= 60.0, "Player title block must sit inside the generated paper frame.")
	_expect((name_plate.get_node("PlayerName") as Label).text == "水师元帅", "Player heading must use 水师元帅.")
	_expect((name_plate.get_node("PlayerTitle") as Label).text == "伏波将军 · 南疆水师", "Player subtitle is incorrect.")
	var status_frame := hud.get_node("PlayerStatus/GeneratedStatusFrame") as TextureRect
	_expect(status_frame.texture != null and status_frame.texture.resource_path.ends_with("player_status_frame.png"), "Player status must use the generated ink-wash frame.")
	_expect(hud.get_node_or_null("QuestTracker/MainQuest/CharacterPlaceholder") != null, "Main quest character placeholder is missing.")
	_expect(hud.get_node_or_null("QuestTracker/SideQuest/CharacterPlaceholder") != null, "Side quest character placeholder is missing.")
	var quest_tracker := hud.get_node("QuestTracker") as Control
	_expect(quest_tracker.size.x <= 286.0 and quest_tracker.size.y <= 270.0, "Quest tracker must keep its compact footprint.")
	_expect(quest_tracker.get_theme_stylebox("panel") is StyleBoxEmpty, "Quest tracker body must remain fully transparent.")
	var tracker_background := quest_tracker.get_node("TrackerBackground") as Panel
	var tracker_background_style := tracker_background.get_theme_stylebox("panel") as StyleBoxFlat
	_expect(tracker_background_style != null and is_equal_approx(tracker_background_style.bg_color.a, 1.0), "Quest tracker center must use one opaque gray background.")
	var quest_title := quest_tracker.get_node("TitleRibbon/QuestTitle") as Label
	_expect(quest_title.get_parent().position.y <= -2.0 and quest_title.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "Quest title must move up into the generated plaque center.")
	var quest_frame := hud.get_node("QuestTracker/GeneratedQuestFrame") as TextureRect
	_expect(quest_frame.texture != null and quest_frame.texture.resource_path.ends_with("quest_tracker_frame.png"), "Quest tracker must use the generated ink-wash frame.")
	for entry_path in ["QuestTracker/MainQuest", "QuestTracker/SideQuest"]:
		var entry := hud.get_node(entry_path) as Panel
		var entry_style := entry.get_theme_stylebox("panel") as StyleBoxFlat
		_expect(entry_style != null and is_zero_approx(entry_style.bg_color.a), "%s must remain transparent over the shared tracker background." % entry_path)

	for button_name in ["MenuButton", "InventoryButton", "ShipButton", "CharacterButton"]:
		var button := hud.find_child(button_name, true, false) as Button
		_expect(button != null, "%s is missing." % button_name)
	var action_row := hud.get_node("FunctionButtons")
	_expect(
		action_row.get_child(0).name == "CharacterButtonSlot"
		and action_row.get_child(1).name == "InventoryButtonSlot"
		and action_row.get_child(2).name == "ShipButtonSlot"
		and action_row.get_child(3).name == "MenuButtonSlot",
		"Function buttons must end with MenuButton on the far right."
	)
	for slot in action_row.get_children():
		var function_texture := slot.get_node("GeneratedFunctionTexture") as TextureRect
		_expect(function_texture.texture != null and function_texture.texture.resource_path.ends_with("function_button.png"), "%s must use the generated ink-wash button frame." % slot.name)
		var function_symbol := slot.get_node("Symbol") as Label
		_expect(function_symbol.position.y >= 22.0, "%s symbol must be lowered into the button center." % slot.name)

	var menu_button := hud.find_child("MenuButton", true, false) as Button
	if menu_button != null:
		menu_button.pressed.emit()
		var system_menu := hud.get_node("SystemMenu") as Control
		_expect(system_menu.visible, "MenuButton must open the system menu.")
		_expect(system_menu.get_node_or_null("BackgroundCopy") is BackBufferCopy, "System menu background copy is missing.")
		var blur := system_menu.get_node("BlurredBackground") as ColorRect
		_expect(blur.material is ShaderMaterial, "System menu must blur the captured background with a shader material.")
		var generated_frame := system_menu.get_node("SystemPanel/GeneratedFrame") as TextureRect
		_expect(generated_frame.texture != null and generated_frame.texture.resource_path.ends_with("system_menu_frame.png"), "System menu must use the generated frame texture.")
		var generated_close := system_menu.get_node("SystemPanel/CloseButtonOrnament/GeneratedCloseTexture") as TextureRect
		_expect(generated_close.texture != null and generated_close.texture.resource_path.ends_with("close_button.png"), "System menu must use the generated close-button texture.")
		var menu_title := system_menu.get_node("SystemPanel/MenuTitle") as Label
		_expect(menu_title.position.y <= -30.0, "System menu title must sit inside the generated top plaque.")
		for entry_name in ["ContinueGameButton", "SaveGameButton", "LoadGameButton", "SettingsButton", "ReturnTitleButton", "ExitGameButton"]:
			_expect(hud.find_child(entry_name, true, false) is Button, "%s is missing from the system menu." % entry_name)
		var generated_button := system_menu.find_child("GeneratedButtonTexture", true, false) as TextureRect
		_expect(generated_button != null and generated_button.texture.resource_path.ends_with("menu_button.png"), "System menu entries must use the generated button texture.")
		_expect(generated_button.size.y >= 110.0, "Generated menu button texture must use the second expanded vertical size.")
		var menu_entries := system_menu.get_node("SystemPanel/MenuEntries") as VBoxContainer
		_expect(menu_entries.get_theme_constant("separation") >= 29, "System menu entries need enough spacing to prevent diamond overlap.")
		_expect(menu_entries.position.y <= 60.0, "System menu entries must remain inside the generated frame after spacing increases.")
		var continue_button := hud.find_child("ContinueGameButton", true, false) as Button
		_expect(continue_button.size.y >= 68.0, "System menu click targets must match the second expanded button height.")
		_expect(continue_button.get_theme_font_size("font_size") == 21, "System menu button font size must remain 21.")
		_expect(continue_button.get_theme_stylebox("hover") is StyleBoxEmpty, "System menu buttons must not add a hover highlight.")
		_expect(continue_button.get_theme_color("font_hover_color") == continue_button.get_theme_color("font_color"), "System menu button text color must not change on hover.")
		for entry_slot in menu_entries.get_children():
			var entry_symbol := entry_slot.get_node("EntrySymbol") as Label
			_expect(entry_symbol.position.x <= 24.0, "%s badge symbol must move left into the generated diamond center." % entry_slot.name)
		_expect(hud.find_child("TutorialButton", true, false) == null, "System menu must not include a tutorial button.")
		var exit_button := hud.find_child("ExitGameButton", true, false) as Button
		_expect(exit_button != null and not exit_button.pressed.get_connections().is_empty(), "ExitGameButton must have a quit action connected.")

		var toast := hud.get_node("ComingSoonToast") as Control
		var message := hud.get_node("ComingSoonToast/Message") as Label
		for unfinished_entry in [
			["ContinueGameButton", "继续游戏"],
			["SaveGameButton", "保存进度"],
			["LoadGameButton", "读取进度"],
			["SettingsButton", "游戏设置"],
			["ReturnTitleButton", "返回标题"],
		]:
			var unfinished_button := hud.find_child(unfinished_entry[0], true, false) as Button
			unfinished_button.pressed.emit()
			_expect(toast.visible, "Clicking %s must show a placeholder message." % unfinished_entry[0])
			_expect(unfinished_entry[1] in message.text and "该功能即将实现" in message.text, "%s uses the wrong placeholder message." % unfinished_entry[0])
		var close_button := hud.find_child("CloseMenuButton", true, false) as Button
		_expect(close_button.get_theme_stylebox("hover") is StyleBoxEmpty, "System menu close button must not add a hover highlight.")
		close_button.pressed.emit()
		_expect(not system_menu.visible, "CloseMenuButton must close the system menu.")

	hud.call("set_exploration_visible", false)
	_expect(not hud.visible, "Exploration HUD did not hide through its public interface.")
	hud.queue_free()
	await process_frame


func _verify_palace_visibility() -> void:
	var palace := PALACE_SCENE.instantiate()
	root.add_child(palace)
	await process_frame
	var hud := palace.get_node("UI/ExplorationHUD") as Control
	var dialogue := palace.get_node("UI/Overlay/DialoguePanel") as Control
	var player := palace.get_node("YSortedCharacters/Player")
	_expect(not hud.visible, "Palace opening dialogue must hide the exploration HUD.")

	palace.set("story_state", 2)
	dialogue.hide()
	palace.call("_refresh_exploration_hud")
	_expect(hud.visible, "Palace WAIT_TALK free-movement state must show the exploration HUD.")
	hud.call("set_main_task", "听取内侍传召")
	await process_frame
	var menu_button := hud.find_child("MenuButton", true, false) as Button
	menu_button.pressed.emit()
	await process_frame
	await process_frame
	_expect(hud.call("is_menu_open"), "Palace menu did not open from the shared HUD.")
	_expect(not player.controls_enabled, "Palace player controls must pause while the system menu is open.")
	if DisplayServer.get_name() != "headless":
		var screenshot_error := root.get_texture().get_image().save_png(MENU_SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "System menu preview screenshot could not be saved.")
	var close_button := hud.find_child("CloseMenuButton", true, false) as Button
	close_button.pressed.emit()
	await process_frame
	_expect(player.controls_enabled, "Palace player controls must resume after closing the system menu.")
	if DisplayServer.get_name() != "headless":
		var screenshot_error := root.get_texture().get_image().save_png(SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "Exploration HUD preview screenshot could not be saved.")

	dialogue.show()
	palace.call("_refresh_exploration_hud")
	_expect(not hud.visible, "Palace dialogue must hide the exploration HUD.")
	palace.queue_free()
	await process_frame


func _verify_scene_two_visibility() -> void:
	var scene_two := SCENE_TWO.instantiate()
	if scene_two == null:
		failures.append("Scene2 could not be instantiated for HUD visibility checks.")
		return
	root.add_child(scene_two)
	await process_frame
	await process_frame

	var hud := scene_two.get_node("UI/ExplorationHUD") as Control
	var dialogue := scene_two.get_node("UI/DialoguePanel") as Control
	var drill := scene_two.get_node_or_null("UI/DrillOverlay") as Control
	var player := scene_two.get_node("World/Actors/Player") as CharacterBody2D
	_expect(hud.visible, "Scene2 free-movement state must show the exploration HUD.")

	dialogue.show()
	await physics_frame
	await physics_frame
	_expect(not hud.visible, "Scene2 dialogue must hide the exploration HUD.")

	dialogue.hide()
	if drill != null:
		drill.show()
		await physics_frame
		await physics_frame
		_expect(not hud.visible, "Scene2 drill overlay must hide the exploration HUD.")
		drill.hide()
		await physics_frame
		await physics_frame
		_expect(hud.visible, "Scene2 HUD must return after the drill overlay closes.")
	else:
		failures.append("Scene2 drill overlay was not created.")

	var menu_button := hud.find_child("MenuButton", true, false) as Button
	menu_button.pressed.emit()
	player.velocity = Vector2(120, 0)
	await physics_frame
	await physics_frame
	_expect(player.velocity == Vector2.ZERO, "Scene2 player must stop while the system menu is open.")
	var close_button := hud.find_child("CloseMenuButton", true, false) as Button
	close_button.pressed.emit()
	_expect(not hud.call("is_menu_open"), "Scene2 system menu must close through the shared close button.")

	scene_two.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
