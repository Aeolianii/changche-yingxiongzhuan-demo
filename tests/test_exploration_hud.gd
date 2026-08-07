extends SceneTree

const HUD_SCENE := preload("res://scenes/ui/exploration_hud.tscn")
const PALACE_SCENE := preload("res://scenes/palace/palace_demo.tscn")
const SCENE_TWO := preload("res://scenes/Scene2.tscn")
const SCREENSHOT_PATH := "res://.godot/exploration_hud_preview.png"
const MENU_SCREENSHOT_PATH := "res://.godot/system_menu_preview.png"
const QUEST_SCREENSHOT_PATH := "res://.godot/quest_screen_preview.png"
const COMPLETED_QUEST_SCREENSHOT_PATH := "res://.godot/quest_screen_completed_preview.png"

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
		"res://assets/ui/exploration_hud/function_buttons_brushstroke.png",
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
		_expect(quest_image.get_pixel(quest_image.get_width() / 2, quest_image.get_height() / 2).a > 0.95, "Generated quest frame must include an opaque ink-wash center.")

	var quest_screen_texture := load("res://assets/ui/quest_screen/quest_screen_background.png") as Texture2D
	var quest_screen_image := quest_screen_texture.get_image() if quest_screen_texture != null else null
	_expect(quest_screen_image != null and not quest_screen_image.is_empty(), "Quest screen background could not be loaded.")
	if quest_screen_image != null and not quest_screen_image.is_empty():
		_expect(quest_screen_image.get_width() * 2 == quest_screen_image.get_height() * 3, "Quest screen background must keep the 3:2 viewport composition.")
		_expect(quest_screen_image.get_pixel(quest_screen_image.get_width() / 2, quest_screen_image.get_height() / 2).a > 0.95, "Quest screen background must keep an opaque ink-wash panel center.")

	for icon_path in [
		"res://assets/ui/icons/hud_quest.png",
		"res://assets/ui/icons/hud_character.png",
		"res://assets/ui/icons/hud_inventory.png",
		"res://assets/ui/icons/hud_ship.png",
		"res://assets/ui/icons/hud_menu.png",
		"res://assets/ui/icons/menu_continue.png",
		"res://assets/ui/icons/menu_save.png",
		"res://assets/ui/icons/menu_load.png",
		"res://assets/ui/icons/menu_settings.png",
		"res://assets/ui/icons/menu_return_title.png",
		"res://assets/ui/icons/menu_exit.png",
	]:
		var icon_texture := load(icon_path) as Texture2D
		var icon_image := icon_texture.get_image() if icon_texture != null else null
		_expect(icon_image != null and not icon_image.is_empty(), "%s could not be loaded." % icon_path)
		if icon_image == null or icon_image.is_empty():
			continue
		_expect(icon_image.get_pixel(0, 0).a < 0.05, "%s must have a transparent corner." % icon_path)
		_expect(icon_image.get_used_rect().has_area(), "%s must contain visible icon pixels." % icon_path)


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
	var player_heading := name_plate.get_node("PlayerName") as Label
	_expect(player_heading.text == "水师元帅", "Player heading must use 水师元帅.")
	_expect(player_heading.position.y >= 8.0, "Player heading must move down inside the paper frame.")
	_expect((name_plate.get_node("PlayerTitle") as Label).text == "伏波将军 · 南疆水师", "Player subtitle is incorrect.")
	var status_frame := hud.get_node("PlayerStatus/GeneratedStatusFrame") as TextureRect
	_expect(status_frame.texture != null and status_frame.texture.resource_path.ends_with("player_status_frame.png"), "Player status must use the generated pixel ink-wash frame.")
	_expect(status_frame.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Player status frame must preserve crisp pixel-art edges.")
	_expect(hud.get_node_or_null("QuestTracker/MainQuest/CharacterPlaceholder") == null, "Main quest must not display a character badge.")
	_expect(hud.get_node_or_null("QuestTracker/SideQuest/CharacterPlaceholder") == null, "Side quest must not display a character badge.")
	var quest_tracker := hud.get_node("QuestTracker") as Control
	_expect(quest_tracker.size.x <= 286.0 and quest_tracker.size.y <= 270.0, "Quest tracker must keep its compact footprint.")
	_expect(quest_tracker.get_theme_stylebox("panel") is StyleBoxEmpty, "Quest tracker body must remain fully transparent.")
	_expect(quest_tracker.get_node_or_null("TrackerBackground") == null, "Quest tracker must not layer a programmatic gray rectangle over the generated panel.")
	var quest_title := quest_tracker.get_node("TitleRibbon/QuestTitle") as Label
	_expect(quest_title.get_parent().position.y <= -2.0 and quest_title.vertical_alignment == VERTICAL_ALIGNMENT_CENTER, "Quest title must move up into the generated plaque center.")
	var quest_frame := hud.get_node("QuestTracker/GeneratedQuestFrame") as TextureRect
	_expect(quest_frame.texture != null and quest_frame.texture.resource_path.ends_with("quest_tracker_frame.png"), "Quest tracker must use the generated pixel ink-wash frame.")
	_expect(quest_frame.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Quest tracker must preserve crisp pixel-art edges.")
	for entry_path in ["QuestTracker/MainQuest", "QuestTracker/SideQuest"]:
		var entry := hud.get_node(entry_path) as Panel
		var entry_style := entry.get_theme_stylebox("panel") as StyleBoxFlat
		_expect(entry_style != null and is_zero_approx(entry_style.bg_color.a), "%s must remain transparent over the shared tracker background." % entry_path)
		_expect(entry_style.get_border_width(SIDE_LEFT) == 0 and entry_style.get_border_width(SIDE_TOP) == 0 and entry_style.get_border_width(SIDE_RIGHT) == 0, "%s must not draw a full rectangular outline." % entry_path)
		_expect((entry.get_node("QuestType") as Label).position.x <= 18.0, "%s category must use the space released by the removed badge." % entry_path)
		_expect((entry.get_node("TaskName") as Label).position.x <= 19.0, "%s task name must align with the category text." % entry_path)
		_expect((entry.get_node("Objective") as Label).position.x <= 19.0, "%s objective must align with the task name." % entry_path)
	var main_entry_style := (hud.get_node("QuestTracker/MainQuest") as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	var side_entry_style := (hud.get_node("QuestTracker/SideQuest") as Panel).get_theme_stylebox("panel") as StyleBoxFlat
	_expect(main_entry_style.get_border_width(SIDE_BOTTOM) == 1, "Main quest must keep one lightweight divider.")
	_expect(side_entry_style.get_border_width(SIDE_BOTTOM) == 0, "Side quest must not add a redundant bottom card border.")

	for button_name in ["QuestButton", "MenuButton", "InventoryButton", "ShipButton", "CharacterButton"]:
		var button := hud.find_child(button_name, true, false) as Button
		_expect(button != null, "%s is missing." % button_name)
	var action_row := hud.get_node("FunctionButtons")
	var function_brushstroke := hud.get_node("FunctionButtonsBrushstroke") as TextureRect
	_expect(function_brushstroke.texture != null and function_brushstroke.texture.resource_path.ends_with("function_buttons_brushstroke.png"), "Function buttons must use the shared ink brushstroke texture.")
	_expect(function_brushstroke.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Function button brushstroke must crop its transparent padding while preserving aspect ratio.")
	_expect(function_brushstroke.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Function button brushstroke must preserve its pixel-art bristle edges.")
	_expect(function_brushstroke.size.x >= action_row.size.x, "Function button brushstroke must span the complete five-button row.")
	_expect(function_brushstroke.position.x <= action_row.position.x - 80.0, "Function button brushstroke must extend visibly beyond the left side of the button row.")
	_expect(function_brushstroke.get_index() < action_row.get_index(), "Function button brushstroke must render below the five buttons.")
	_expect(function_brushstroke.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Function button brushstroke must not block button input.")
	_expect(
		action_row.get_child_count() == 5
		and action_row.get_child(0).name == "QuestButtonSlot"
		and action_row.get_child(1).name == "CharacterButtonSlot"
		and action_row.get_child(2).name == "InventoryButtonSlot"
		and action_row.get_child(3).name == "ShipButtonSlot"
		and action_row.get_child(4).name == "MenuButtonSlot",
		"Function buttons must start with QuestButton and end with MenuButton."
	)
	_expect(action_row.size.x >= 562.0, "Function button row must expand to fit five entries.")
	var expected_hud_icons := ["hud_quest.png", "hud_character.png", "hud_inventory.png", "hud_ship.png", "hud_menu.png"]
	for slot_index in range(action_row.get_child_count()):
		var slot := action_row.get_child(slot_index)
		var function_texture := slot.get_node("GeneratedFunctionTexture") as TextureRect
		_expect(function_texture.texture != null and function_texture.texture.resource_path.ends_with("function_button.png"), "%s must use the generated pixel ink-wash button frame." % slot.name)
		_expect(function_texture.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s button frame must preserve crisp pixel-art edges." % slot.name)
		var function_icon := slot.get_node("FunctionIcon") as TextureRect
		_expect(function_icon.texture != null and function_icon.texture.resource_path.ends_with(expected_hud_icons[slot_index]), "%s must use its generated pixel ink-wash function icon." % slot.name)
		_expect(function_icon.size == Vector2(56, 56), "%s icon must fill the generated diamond without losing its center." % slot.name)
		_expect(function_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s icon must preserve the shared pixel density." % slot.name)
		_expect(slot.get_node_or_null("Symbol") == null, "%s must not retain its text symbol." % slot.name)

	var quest_button := hud.find_child("QuestButton", true, false) as Button
	quest_button.pressed.emit()
	var quest_screen := hud.get_node("QuestScreen") as Control
	_expect(quest_screen.visible and hud.call("is_quest_screen_open"), "QuestButton must open the interactive quest screen.")
	_expect(not action_row.visible and not function_brushstroke.visible, "Opening the quest screen must hide the five function buttons and their brushstroke.")
	var quest_background := quest_screen.get_node("GeneratedQuestBackground") as TextureRect
	_expect(quest_background.texture != null and quest_background.texture.resource_path.ends_with("quest_screen_background.png"), "Quest screen must use the generated pixel ink-wash background.")
	var screen_title := quest_screen.get_node("ScreenTitle") as Label
	var list_header := quest_screen.get_node("QuestListTitle") as Label
	var detail_header := quest_screen.get_node("QuestDetailHeader") as Label
	_expect(screen_title.position.x >= 175.0 and screen_title.position.y >= 55.0 and screen_title.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER, "Quest screen title must sit in the center of the upper-left ink brushstroke.")
	_expect(list_header.position.y >= 170.0 and detail_header.position.y >= 170.0, "Quest panel headings must sit in the vertical center of their plaques.")
	var active_tab := quest_screen.get_node("QuestFilterTabs/ActiveQuestTab") as Button
	var completed_tab := quest_screen.get_node("QuestFilterTabs/CompletedQuestTab") as Button
	_expect(active_tab.position.y >= 0.0 and active_tab.get_parent().position.x >= 100.0 and active_tab.get_parent().position.y >= 235.0, "Quest filters must move right and down inside the list panel.")
	var quest_choices := quest_screen.get_node("QuestChoices") as VBoxContainer
	_expect(quest_choices.get_node_or_null("QuestChoice0") is Button and quest_choices.get_node_or_null("QuestChoice1") is Button, "Quest screen must demonstrate one main quest and one side quest.")
	var selected_title := quest_screen.get_node("SelectedQuestTitle") as RichTextLabel
	var selected_description := quest_screen.get_node("SelectedQuestDescription") as RichTextLabel
	_expect(selected_title.position.y >= 270.0 and selected_description.position.y >= 315.0, "Overall quest wording must sit lower in its summary frame.")
	_expect(quest_screen.get_node_or_null("QuestFlowHint") == null, "Quest flow must not retain the triangle instruction hint.")
	var steps_scroll := quest_screen.get_node("QuestStepsScroll") as ScrollContainer
	_expect(steps_scroll.position.x >= 540.0, "Quest step markers, titles and descriptions must move right together.")
	_expect("奉诏入殿" in selected_title.text, "Quest screen must select the demo main quest by default.")
	_expect("[color=#f1c24f]" in selected_description.text, "Quest description keywords must use yellow BBCode highlighting.")
	var steps := quest_screen.get_node("QuestStepsScroll/QuestSteps") as VBoxContainer
	_expect(steps.get_child_count() == 3, "Demo main quest must expose three concrete task steps.")
	var expanded_description := steps.get_node("QuestStep1/StepDescription") as RichTextLabel
	var expanded_toggle := steps.get_node("QuestStep1/StepHeader/StepToggle") as Button
	_expect(expanded_description.visible and expanded_toggle.text == "▼", "Current quest step must start expanded.")
	expanded_toggle.pressed.emit()
	_expect(not expanded_description.visible and expanded_toggle.text == "▶", "Quest step triangle must collapse its concrete description.")
	expanded_toggle.pressed.emit()
	_expect(expanded_description.visible and expanded_toggle.text == "▼", "Quest step triangle must restore its concrete description.")
	var side_choice := quest_choices.get_node("QuestChoice1") as Button
	side_choice.pressed.emit()
	_expect("访查军港" in selected_title.text and steps.get_child_count() == 3, "Selecting the side quest must refresh the right-hand task flow.")
	var quest_return := quest_screen.find_child("QuestReturnButton", true, false) as Button
	quest_return.pressed.emit()
	_expect(not quest_screen.visible and action_row.visible and function_brushstroke.visible, "Quest return button must restore the game HUD function buttons and brushstroke.")
	_expect(not hud.call("is_menu_open"), "Quest return button must leave modal UI state.")

	hud.call("set_main_task", "巡视水师驻地")
	_expect((hud.get_node("QuestTracker/MainQuest/TaskName") as Label).text == "巡视水师驻地", "Story task updates must reach the compact HUD tracker.")
	quest_button.pressed.emit()
	_expect("巡视水师驻地" in selected_title.text, "Story task updates must also reach the full quest screen.")
	_expect("中军楼船" in selected_description.text and "[color=#f1c24f]" in selected_description.text, "Chapter two quest details must replace the chapter one placeholder content.")
	completed_tab.pressed.emit()
	var completed_choice := quest_choices.get_node("QuestChoice0") as Button
	_expect((completed_choice.get_node("QuestName") as Label).text == "奉诏入殿", "Completed filter must hide active tasks and show the preceding completed quest.")
	_expect("奉诏入殿" in selected_title.text, "Completed quest selection must refresh the right-hand details.")
	active_tab.pressed.emit()
	var restored_active_choice := quest_choices.get_node("QuestChoice0") as Button
	_expect((restored_active_choice.get_node("QuestName") as Label).text == "巡视水师驻地", "Active filter must restore the current story task and hide completed tasks.")
	quest_return.pressed.emit()

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
		_expect(generated_frame.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "System menu frame must preserve crisp pixel-art edges.")
		_expect(generated_frame.size.x >= 610.0 and generated_frame.size.y >= 780.0, "System menu frame must be enlarged around the spaced entries.")
		var generated_close := system_menu.get_node("SystemPanel/CloseButtonOrnament/GeneratedCloseTexture") as TextureRect
		_expect(generated_close.texture != null and generated_close.texture.resource_path.ends_with("close_button.png"), "System menu must use the generated close-button texture.")
		_expect(generated_close.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "System menu close-button texture must preserve its pixel-art edges.")
		var menu_title := system_menu.get_node("SystemPanel/MenuTitle") as Label
		_expect(menu_title.position.y <= -30.0, "System menu title must sit inside the generated top plaque.")
		for entry_name in ["ContinueGameButton", "SaveGameButton", "LoadGameButton", "SettingsButton", "ReturnTitleButton", "ExitGameButton"]:
			_expect(hud.find_child(entry_name, true, false) is Button, "%s is missing from the system menu." % entry_name)
		var generated_button := system_menu.find_child("GeneratedButtonTexture", true, false) as TextureRect
		_expect(generated_button != null and generated_button.texture.resource_path.ends_with("menu_button.png"), "System menu entries must use the generated button texture.")
		_expect(generated_button.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "System menu button backgrounds must preserve crisp pixel-art edges.")
		_expect(generated_button.size.y >= 110.0, "Generated menu button texture must use the second expanded vertical size.")
		var menu_entries := system_menu.get_node("SystemPanel/MenuEntries") as VBoxContainer
		_expect(menu_entries.get_theme_constant("separation") >= 29, "System menu entries need enough spacing to prevent diamond overlap.")
		_expect(menu_entries.position.y <= 60.0, "System menu entries must remain inside the generated frame after spacing increases.")
		var last_slot := menu_entries.get_child(menu_entries.get_child_count() - 1) as Control
		var last_texture := last_slot.get_node("GeneratedButtonTexture") as TextureRect
		var last_texture_bottom := menu_entries.position.y + last_slot.position.y + last_texture.position.y + last_texture.size.y
		var frame_bottom := generated_frame.position.y + generated_frame.size.y
		_expect(last_texture_bottom <= frame_bottom - 20.0, "Bottom system-menu button must keep visible clearance above the enlarged frame border.")
		var continue_button := hud.find_child("ContinueGameButton", true, false) as Button
		_expect(continue_button.size.y >= 68.0, "System menu click targets must match the second expanded button height.")
		_expect(continue_button.get_theme_font_size("font_size") == 21, "System menu button font size must remain 21.")
		_expect(continue_button.get_theme_stylebox("hover") is StyleBoxEmpty, "System menu buttons must not add a hover highlight.")
		_expect(continue_button.get_theme_stylebox("pressed") is StyleBoxEmpty, "System menu buttons must not add a rectangular pressed highlight.")
		_expect(continue_button.get_theme_color("font_hover_color") == continue_button.get_theme_color("font_color"), "System menu button text color must not change on hover.")
		var hover_highlight := continue_button.get_parent().get_node("HoverHighlight") as TextureRect
		_expect(hover_highlight.texture == generated_button.texture, "System menu hover highlight must reuse the button texture as its alpha mask.")
		_expect(hover_highlight.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "System menu hover highlight must follow the button's pixel silhouette.")
		_expect(hover_highlight.material is ShaderMaterial, "System menu hover highlight must use an alpha-masked shader material.")
		continue_button.mouse_entered.emit()
		_expect(hover_highlight.visible, "System menu hover highlight must appear when the pointer enters a button.")
		continue_button.mouse_exited.emit()
		_expect(not hover_highlight.visible, "System menu hover highlight must disappear when the pointer exits a button.")
		var expected_menu_icons := ["menu_continue.png", "menu_save.png", "menu_load.png", "menu_settings.png", "menu_return_title.png", "menu_exit.png"]
		for entry_index in range(menu_entries.get_child_count()):
			var entry_slot := menu_entries.get_child(entry_index)
			var entry_icon := entry_slot.get_node("EntryIcon") as TextureRect
			_expect(entry_icon.texture != null and entry_icon.texture.resource_path.ends_with(expected_menu_icons[entry_index]), "%s must use its generated ink-wash menu icon." % entry_slot.name)
			_expect(entry_icon.position.x <= 20.0 and entry_icon.size == Vector2(54, 54), "%s icon must fill the generated diamond while remaining centered." % entry_slot.name)
			_expect(entry_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "%s icon must preserve its pixel-art edges." % entry_slot.name)
			_expect(entry_slot.get_node_or_null("EntrySymbol") == null, "%s must not retain its text badge." % entry_slot.name)
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
	var quest_button := hud.find_child("QuestButton", true, false) as Button
	quest_button.pressed.emit()
	await process_frame
	_expect(hud.call("is_quest_screen_open"), "Palace QuestButton must open the shared quest screen.")
	_expect(not player.controls_enabled, "Palace player controls must pause while the quest screen is open.")
	if DisplayServer.get_name() != "headless":
		var quest_screenshot_error := root.get_texture().get_image().save_png(QUEST_SCREENSHOT_PATH)
		_expect(quest_screenshot_error == OK, "Quest screen preview screenshot could not be saved.")
	var quest_return := hud.find_child("QuestReturnButton", true, false) as Button
	quest_return.pressed.emit()
	await process_frame
	_expect(player.controls_enabled, "Palace player controls must resume after returning from the quest screen.")
	var menu_button := hud.find_child("MenuButton", true, false) as Button
	menu_button.pressed.emit()
	await process_frame
	await process_frame
	_expect(hud.call("is_menu_open"), "Palace menu did not open from the shared HUD.")
	_expect(not player.controls_enabled, "Palace player controls must pause while the system menu is open.")
	var return_title_button := hud.find_child("ReturnTitleButton", true, false) as Button
	return_title_button.mouse_entered.emit()
	await process_frame
	if DisplayServer.get_name() != "headless":
		var screenshot_error := root.get_texture().get_image().save_png(MENU_SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "System menu preview screenshot could not be saved.")
	return_title_button.mouse_exited.emit()
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

	var quest_button := hud.find_child("QuestButton", true, false) as Button
	quest_button.pressed.emit()
	await process_frame
	var quest_title := hud.get_node("QuestScreen/SelectedQuestTitle") as RichTextLabel
	_expect("巡视水师驻地" in quest_title.text, "Scene2 quest screen must follow its 巡视水师驻地 story task.")
	player.velocity = Vector2(120, 0)
	await physics_frame
	await physics_frame
	_expect(player.velocity == Vector2.ZERO, "Scene2 player must stop while the quest screen is open.")
	if DisplayServer.get_name() != "headless":
		var quest_screenshot_error := root.get_texture().get_image().save_png(QUEST_SCREENSHOT_PATH)
		_expect(quest_screenshot_error == OK, "Scene2 quest screen preview screenshot could not be saved.")
		var completed_tab := hud.get_node("QuestScreen/QuestFilterTabs/CompletedQuestTab") as Button
		completed_tab.pressed.emit()
		await process_frame
		await process_frame
		_expect("奉诏入殿" in quest_title.text, "Completed quest preview must render the completed selection.")
		var completed_screenshot_error := root.get_texture().get_image().save_png(COMPLETED_QUEST_SCREENSHOT_PATH)
		_expect(completed_screenshot_error == OK, "Completed quest screen preview screenshot could not be saved.")
		var active_tab := hud.get_node("QuestScreen/QuestFilterTabs/ActiveQuestTab") as Button
		active_tab.pressed.emit()
		await process_frame
	var quest_return := hud.find_child("QuestReturnButton", true, false) as Button
	quest_return.pressed.emit()
	_expect(not hud.call("is_menu_open"), "Scene2 quest return button must close the shared quest screen.")

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
