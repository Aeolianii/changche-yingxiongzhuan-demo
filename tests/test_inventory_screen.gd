extends SceneTree

const HUD := preload("res://scenes/ui/exploration_hud.tscn")
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var hud := HUD.instantiate(); root.add_child(hud); await process_frame; hud.call("set_exploration_visible", true)
	var locks: Array[bool] = []; hud.menu_visibility_changed.connect(func(value: bool): locks.append(value))
	var inventory_button := hud.find_child("InventoryButton", true, false) as Button
	_expect(inventory_button != null, "Inventory function button must exist.")
	inventory_button.pressed.emit(); await process_frame
	var screen := hud.find_child("InventoryScreen", true, false) as Control
	_expect(screen != null and screen.visible, "Inventory button must open the real inventory screen.")
	_expect(screen.find_child("InventoryFrame", true, false) is PanelContainer, "Inventory V2 must use one code-native macro frame.")
	_expect(screen.find_child("InventoryBackdrop", true, false) == null, "Inventory V2 must not depend on the V1 backdrop with baked tabs, detail bands, and footer cells.")
	var filter_tabs := screen.find_child("FilterTabs", true, false) as HBoxContainer
	_expect(filter_tabs != null and filter_tabs.get_child_count() == 5, "Inventory must expose five clear category tabs across the top.")
	var grid := screen.find_child("ItemGrid", true, false) as GridContainer
	_expect(grid != null and grid.columns == 6, "Inventory must use a six-column item grid.")
	_expect(grid != null and grid.get_child_count() == 12, "Inventory V2 must show exactly twelve first-screen slots instead of twenty-four permanent boxes.")
	var item_scroll := screen.find_child("ItemScroll", true, false) as ScrollContainer
	_expect(item_scroll != null and item_scroll.size.x >= 824.0, "Inventory scroll viewport must reserve enough width for six cards after a vertical scrollbar appears.")
	if grid != null and grid.get_child_count() > 0:
		var first_card := grid.get_child(0) as Button
		_expect(first_card.find_child("ItemIcon", true, false) is TextureRect, "Every inventory card must show a pixel-art item icon.")
		_expect(first_card.find_child("QuantityBadge", true, false) is Label, "Every inventory card must show a quantity badge.")
	_expect(screen.find_child("ItemPreview", true, false) is TextureRect, "Inventory detail panel must feature a large item preview.")
	_expect(screen.find_child("DetailName", true, false) is Label, "Inventory detail panel must show the selected item name.")
	_expect(screen.find_child("DetailType", true, false) is Label, "Inventory detail panel must show the selected item type.")
	_expect(screen.find_child("DetailDescription", true, false) is RichTextLabel, "Inventory detail panel must show a concise selected-item description.")
	_expect(screen.find_child("DetailSource", true, false) is Label, "Inventory detail panel must show the selected item source.")
	_expect(screen.find_child("DetailUse", true, false) is Label, "Inventory detail panel must show the selected item use.")
	var detail_type := screen.find_child("DetailType", true, false) as Label
	_expect(screen.find_child("DetailQuality", true, false) == null, "Inventory must not fabricate a quality tag that does not exist in the item catalog.")
	var detail_description := screen.find_child("DetailDescription", true, false) as RichTextLabel
	var detail_use := screen.find_child("DetailUse", true, false) as Label
	var detail_source := screen.find_child("DetailSource", true, false) as Label
	_expect(detail_description.position.x == detail_use.position.x and detail_use.position.x == detail_source.position.x, "Description, use, and source blocks must share one horizontal content boundary.")
	_expect(detail_description.size.x == detail_use.size.x and detail_use.size.x == detail_source.size.x, "Description, use, and source blocks must use the same text width.")
	_expect(not detail_description.text.begins_with("[center]") and detail_use.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT and detail_source.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT, "Description, use, and source copy must share a readable left-aligned axis.")
	_expect(detail_use.vertical_alignment == VERTICAL_ALIGNMENT_TOP and detail_source.vertical_alignment == VERTICAL_ALIGNMENT_TOP, "Detail copy must begin at the top of its content region instead of floating in decorative bands.")
	var iron_card := screen.find_child("Item_ironstone", true, false) as Button
	var iron_name := iron_card.find_child("ItemName", true, false) as Label
	_expect(is_equal_approx(iron_name.position.x + iron_name.size.x * 0.5, iron_card.size.x * 0.5), "Ironstone card name must be centered inside its own slot.")
	_expect(screen.has_method("selected_entry_for_test") and str(screen.call("selected_entry_for_test")) == "wood", "Opening inventory must select the first visible item and populate its detail panel.")
	var detail_name := screen.find_child("DetailName", true, false) as Label
	_expect(detail_name != null and detail_name.text == "木材", "Default selection must display wood details instead of a fixed warehouse explanation.")
	screen.call("_set_filter", "cargo")
	var misc_entries: Array = screen.call("_visible_entries", {"items": {"old_boot": 1}, "blueprints": []})
	_expect(misc_entries.size() == 1 and str(misc_entries[0]["id"]) == "old_boot", "The Sea Cargo tab must also include misc sea salvage such as the old boot.")
	screen.call("_set_filter", "all")
	screen.call("_select_entry", {
		"id": "patrol_boat", "kind": "blueprint", "name": "巡哨快船图纸",
		"category": "blueprint", "quantity": 1,
		"data": {"pay": 240, "wood": 36, "ironstone": 14},
	})
	_expect(detail_type.text == "造船图纸", "Blueprint detail must use the real type label '造船图纸' instead of derived permanence wording.")
	screen.call("_set_filter", "all")
	for label in screen.find_children("*", "RichTextLabel", true, false):
		_expect(not str(label.text).contains("仓库说明"), "Inventory must remove the fixed warehouse explanation copy.")
	var sort_button := screen.find_child("SortButton", true, false) as OptionButton
	_expect(sort_button != null and sort_button.item_count == 3, "Inventory grid must provide a compact three-mode sort dropdown.")
	if sort_button != null:
		var original_sort := sort_button.text
		sort_button.select(1); sort_button.item_selected.emit(1); await process_frame
		_expect(sort_button.text != original_sort, "Sort control must cycle to another ordering mode.")
	var close_button := screen.find_child("CloseButton", true, false) as Button
	var close_normal := close_button.get_theme_stylebox("normal")
	_expect(close_normal is StyleBoxTexture and (close_normal as StyleBoxTexture).texture.resource_path.ends_with("interaction_button_ink_v1.png"), "Inventory close button must reuse the system black-gold UI texture.")
	_expect((screen.find_child("PayLabel", true, false) as Label).text.contains("800"), "Inventory must display military pay.")
	_expect((screen.find_child("FleetLabel", true, false) as Label).text.contains("3 / 10"), "Inventory must display the three-ship starting fleet count.")
	var pay_label := screen.find_child("PayLabel", true, false) as Label
	var fleet_label := screen.find_child("FleetLabel", true, false) as Label
	_expect(not bool(pay_label.size_flags_horizontal & Control.SIZE_EXPAND) and not bool(fleet_label.size_flags_horizontal & Control.SIZE_EXPAND), "Footer labels must not expand and push resource groups off center.")
	_expect((screen.find_child("PayBlock", true, false) as HBoxContainer).alignment == BoxContainer.ALIGNMENT_CENTER and (screen.find_child("FleetBlock", true, false) as HBoxContainer).alignment == BoxContainer.ALIGNMENT_CENTER, "Footer icon-and-text groups must be centered in their decorative frames.")
	var footer := screen.find_child("FooterBar", true, false) as PanelContainer
	var fleet_block := screen.find_child("FleetBlock", true, false) as HBoxContainer
	var pay_block := screen.find_child("PayBlock", true, false) as HBoxContainer
	_expect(footer != null, "Inventory V2 must use one continuous footer bar.")
	_expect(footer != null and pay_block.global_position.x < fleet_block.global_position.x and fleet_block.global_position.x + fleet_block.size.x <= footer.global_position.x + footer.size.x, "Footer must keep military pay on the left and the complete fleet group on the right.")
	var first_pressed := (grid.get_child(0) as Button).get_theme_stylebox("pressed") as StyleBoxFlat
	_expect(first_pressed != null and first_pressed.bg_color.get_luminance() < 0.28, "Selected item cards must remain dark instead of becoming a large beige slab.")
	var selected_tab := (filter_tabs.get_child(0) as Button).get_theme_stylebox("normal") as StyleBoxFlat
	_expect(selected_tab != null and selected_tab.bg_color.get_luminance() < 0.28 and selected_tab.border_width_bottom >= 2, "Selected tabs must use a dark fill with a clear gold lower edge.")
	var selected_tab_hover := (filter_tabs.get_child(0) as Button).get_theme_stylebox("hover") as StyleBoxFlat
	_expect(selected_tab_hover != null and selected_tab_hover.bg_color.get_luminance() < 0.28, "Selected tabs must remain dark while hovered instead of falling back to a beige default state.")
	_expect(detail_source.size.x >= 356.0, "Detail source copy must have enough width to avoid isolating the final word on a separate line.")
	_expect(locks == [true], "Opening inventory must emit the shared movement lock.")
	close_button.pressed.emit(); await process_frame
	_expect(not screen.visible and locks == [true, false], "Closing inventory must restore movement.")
	inventory_button.pressed.emit(); await process_frame
	_expect(screen.has_method("_unhandled_key_input"), "Inventory must expose Escape keyboard handling.")
	if screen.has_method("_unhandled_key_input"):
		var escape := InputEventKey.new(); escape.keycode = KEY_ESCAPE; escape.pressed = true
		screen.call("_unhandled_key_input", escape); await process_frame
		_expect(not screen.visible and locks == [true, false, true, false], "Escape must close inventory and restore movement.")
	else:
		(screen.find_child("CloseButton", true, false) as Button).pressed.emit(); await process_frame
	hud.queue_free(); await process_frame
	if failures.is_empty(): print("Inventory screen verification passed."); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)
func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
