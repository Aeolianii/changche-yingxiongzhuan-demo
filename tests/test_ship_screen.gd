extends SceneTree

const HUD := preload("res://scenes/ui/exploration_hud.tscn")
const SCREENSHOT_PATH := "res://.godot/ship_screen_preview.png"
const SCROLL_SCREENSHOT_PATH := "res://.godot/ship_screen_scroll_preview.png"
const EQUIPMENT_SCREENSHOT_PATH := "res://.godot/ship_equipment_preview.png"

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
	_expect(starting_types == ["patrol_boat", "cannon_warship", "escort_junk", "patrol_boat", "cannon_warship"], "New games must begin with five ships and include every catalog type.")

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

	var ship_list := screen.get_node("ShipListScroll/ShipListInset/ShipList") as VBoxContainer
	_expect(ship_list.get_child_count() == 5, "Starting fleet list must show all five owned ships.")
	_expect((screen.get_node("FleetCount") as Label).text.contains("5 艘"), "Fleet header must show the current ship count without a capacity limit.")
	var initial_scrollbar := (screen.get_node("ShipListScroll") as ScrollContainer).get_v_scroll_bar()
	_expect(initial_scrollbar.visible and initial_scrollbar.max_value > initial_scrollbar.page, "The five-ship starting fleet must be scrollable.")
	for index in range(ship_list.get_child_count()):
		var choice := ship_list.get_child(index) as Button
		_expect(choice.get_node_or_null("ShipIcon") is TextureRect, "Every fleet row must show a ship image.")
		_expect(choice.get_node_or_null("ShipName") is Label and choice.get_node_or_null("ShipRole") is Label and choice.get_node_or_null("ShipSummary") is Label, "Every fleet row must show name, role and rough status.")

	_expect(str(screen.call("selected_ship_id_for_test")) == "ship_001", "Opening ships must select the first owned vessel.")
	_expect((screen.get_node("SelectedShipName") as RichTextLabel).text.contains("巡哨快船"), "Default detail must describe the selected patrol boat.")
	_expect((screen.get_node("SelectedShipId") as Label).text == "舰号  001" and not (screen.get_node("SelectedShipId") as Label).text.contains("编制序列"), "Ship detail must show only the vessel number without a formation sequence.")
	_expect((screen.get_node("SelectedShipPreview") as TextureRect).texture.resource_path.ends_with("patrol_boat.png"), "Selected patrol boat must use its existing ship artwork.")
	_expect(screen.get_node("ShipStats").get_child_count() == 4, "Detailed information must include firepower, speed, armor and cargo.")
	_expect((screen.get_node("CrewLabel") as Label).text.contains("26"), "Detailed information must include crew complement.")
	_expect((screen.get_node("ConstructionLabel") as Label).text.contains("军饷") and (screen.get_node("ConstructionLabel") as Label).text.contains("木材"), "Hull upgrade area must show the currently available resources.")
	_expect((screen.get_node("DurabilityLabel") as Label).text == "42 / 60", "The first starting ship must expose its initial hull damage.")
	var repair_button := screen.get_node("RepairButton") as Button
	_expect(not repair_button.disabled and repair_button.position.x > 1100.0, "Hull page must provide an enabled repair button in its upper-right corner for damaged ships.")
	var hull_tab := screen.get_node("HullTab") as Button
	var equipment_tab := screen.get_node("EquipmentTab") as Button
	for detail_button in [hull_tab, equipment_tab, repair_button]:
		var detail_style := (detail_button as Button).get_theme_stylebox("normal")
		_expect(detail_style is StyleBoxTexture and (detail_style as StyleBoxTexture).texture.resource_path.ends_with("ship_detail_button_frame_v1.png"), "Hull, equipment, and repair buttons must use the generated ink-pixel frame.")
	for detail_tab in [hull_tab, equipment_tab]:
		var bottom_border := (detail_tab as Button).get_node("BottomGoldBorder") as ColorRect
		_expect(bottom_border.color == Color(0.73, 0.59, 0.32, 1.0) and bottom_border.size.y == 1.0, "Hull and equipment tabs must expose a one-pixel gold lower border without changing their interior.")
	_expect(repair_button.get_node_or_null("BottomGoldBorder") == null, "The lower-border correction must affect only the hull and equipment tabs.")
	repair_button.pressed.emit()
	await process_frame
	_expect((screen.get_node("DurabilityLabel") as Label).text == "60 / 60" and repair_button.disabled, "Repair button must restore selected ship durability and then disable itself.")
	_expect((game_state.call("get_economy_state") as Dictionary)["ships"][0]["current_hp"] == 60, "Hull repairs must persist in GameState.")
	var upgrade_grid := screen.get_node("ShipUpgradeGrid") as GridContainer
	_expect(upgrade_grid.get_child_count() == 4, "Hull page must provide hull, weapon-slot, skill-slot, and speed upgrade projects.")
	var expected_projects := ["hull", "weapon_slots", "skill_slots", "speed"]
	for project in expected_projects:
		var card := upgrade_grid.get_node("Upgrade_%s" % project) as PanelContainer
		_expect(card.get_node("Content/Plus") is Button and (card.get_node("Content/Value") as Label).text.contains("0/3级"), "Every ship upgrade project must expose a plus button and a three-level test cap.")
	var hull_upgrade := upgrade_grid.get_node("Upgrade_hull/Content/Plus") as Button
	_expect(not hull_upgrade.disabled and (upgrade_grid.get_node("Upgrade_hull/Content/Cost") as Label).text.contains("木材"), "Hull upgrade must show and enforce military-pay plus wood costs.")
	hull_upgrade.pressed.emit()
	await process_frame
	var upgraded_state := game_state.call("get_economy_state") as Dictionary
	_expect(upgraded_state["ships"][0]["max_hp"] == 63 and upgraded_state["ships"][0]["current_hp"] == 63, "Hull upgrade UI must add five percent maximum durability and retain a fully repaired hull.")
	_expect(upgraded_state["pay"] == 700 and upgraded_state["items"]["wood"] == 22, "Hull upgrade UI must persist its military-pay and wood costs.")
	_expect((screen.get_node("DurabilityLabel") as Label).text == "63 / 63" and (upgrade_grid.get_node("Upgrade_hull/Content/Value") as Label).text.contains("1/3级"), "Hull page must refresh upgraded durability and level immediately.")
	var speed_upgrade := upgrade_grid.get_node("Upgrade_speed/Content/Plus") as Button
	speed_upgrade.pressed.emit()
	await process_frame
	upgraded_state = game_state.call("get_economy_state") as Dictionary
	_expect(upgraded_state["ships"][0]["upgrades"]["speed"] == 1 and upgraded_state["ship_upgrade_materials"]["canvas"] == 14, "Speed upgrade UI must add one speed and consume the isolated test canvas stock.")
	_expect((screen.get_node("ShipStats").find_child("航速Value", true, false) as Label).text == "6 / 8", "Speed upgrade must immediately raise the ship's effective speed toward its per-type maximum.")

	(screen.get_node("EquipmentTab") as Button).pressed.emit()
	await process_frame
	var equipment_page := screen.get_node("EquipmentPage") as Panel
	_expect(equipment_page.visible and not (screen.get_node("SelectedShipPreview") as TextureRect).visible, "Equipment tab must replace the hull detail page with its own interface.")
	_expect(not (screen.get_node("UpgradeTitle") as Label).visible and not upgrade_grid.visible, "Hull upgrade controls must stay hidden on the equipment page.")
	_expect((equipment_page.get_node("EquipmentSlotsSummary") as Label).text.contains("武器位 1 / 2"), "Equipment page must show battle-style weapon, skill, and armor slot usage.")
	_expect(equipment_page.get_node("WeaponGrid").get_child_count() == 3 and equipment_page.get_node("SkillGrid").get_child_count() == 4, "Equipment page must reuse every weapon and skill from naval battle configuration.")
	var armor_content := equipment_page.get_node("ArmorRow/Armor_armor/Content") as Control
	var armor_subtitle := armor_content.get_child(1) as Label
	var armor_minus := armor_content.get_node("Minus") as Button
	_expect(armor_subtitle.position.y + armor_subtitle.size.y < armor_minus.position.y, "Armor description and controls must occupy separate rows without overlapping.")
	var ram_plus := equipment_page.get_node("WeaponGrid/Weapon_ram/Content/Plus") as Button
	_expect(ram_plus.get_theme_stylebox("normal") is StyleBoxFlat, "Compact equipment controls must keep their fitted flat button style.")
	ram_plus.pressed.emit()
	await process_frame
	_expect((equipment_page.get_node("WeaponGrid/Weapon_ram/Content/Count") as Label).text == "×1", "Equipment controls must update the selected ship loadout.")
	_expect((game_state.call("get_economy_state") as Dictionary)["ships"][0]["equipment"]["weapons"]["ram"] == 1, "Equipment changes must persist in GameState.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var equipment_screenshot_error := root.get_texture().get_image().save_png(EQUIPMENT_SCREENSHOT_PATH)
		_expect(equipment_screenshot_error == OK, "Ship equipment preview screenshot could not be saved.")
	(screen.get_node("HullTab") as Button).pressed.emit()
	await process_frame

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
	_expect(grabber_style.border_width_left + grabber_style.border_width_right == 12, "Solid scrollbar thumb must have an exact visible width of 14 pixels inside the 26-pixel track.")
	_expect(grabber_style.border_width_top == 34 and grabber_style.border_width_bottom == 34, "Solid scrollbar thumb must leave both generated track end caps fully visible with extra clearance at its travel limits.")
	scrollbar.value = scrollbar.max_value
	await process_frame
	_expect(list_scroll.scroll_vertical > 0, "Dragging the fleet scrollbar must move the ship list.")
	var first_row := ship_list.get_child(0) as Control
	_expect(ship_list.position.x == 6.0, "Fleet rows must be shifted six pixels to the right within the list frame.")
	var scrollbar_gutter := scrollbar.custom_minimum_size.x + 6.0
	_expect(list_scroll.clip_contents and first_row.position.x + first_row.size.x <= list_scroll.size.x - scrollbar_gutter, "Selected ship highlights must end before the scrollbar gutter instead of extending underneath it.")

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
