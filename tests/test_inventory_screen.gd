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
	_expect((screen.find_child("PayLabel", true, false) as Label).text.contains("800"), "Inventory must display military pay.")
	_expect((screen.find_child("FleetLabel", true, false) as Label).text.contains("1 / 10"), "Inventory must display fleet count.")
	_expect(locks == [true], "Opening inventory must emit the shared movement lock.")
	(screen.find_child("CloseButton", true, false) as Button).pressed.emit(); await process_frame
	_expect(not screen.visible and locks == [true, false], "Closing inventory must restore movement.")
	hud.queue_free(); await process_frame
	if failures.is_empty(): print("Inventory screen verification passed."); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)
func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
