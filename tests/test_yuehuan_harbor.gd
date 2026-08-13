extends SceneTree

const SEA := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const HARBOR := preload("res://scenes/yuehuan_merchant_harbor/yuehuan_merchant_harbor.tscn")
const TRAVEL := preload("res://scripts/fubo_guling/fubo_travel_session.gd")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var sea := SEA.instantiate(); root.add_child(sea); current_scene = sea
	await process_frame
	var found := false
	for area in sea.get_node("World/WorldMarkers").get_children():
		if area.get_meta("location_name", "") == "月环商港":
			found = area.get_meta("target_scene_path", "") == "res://scenes/yuehuan_merchant_harbor/yuehuan_merchant_harbor.tscn"
	_expect(found, "Yuehuan map location must target the real harbor scene.")
	current_scene = null; sea.queue_free(); await process_frame
	var harbor := HARBOR.instantiate(); root.add_child(harbor); current_scene = harbor
	await process_frame
	_expect(harbor is Node2D, "Harbor must open as an explorable island world.")
	_expect(not harbor.call("is_shop_open_for_test"), "Harbor must not open a shop before merchant dialogue.")
	harbor.call("open_merchant_dialogue_for_test", "liang")
	harbor.call("choose_trade_for_test")
	await process_frame
	_expect(harbor.call("active_shop_role_for_test") == "goods", "Liang must open the goods shop after dialogue.")
	var overlay := harbor.get_node("Interface/MerchantShopOverlay")
	_expect(overlay.find_child("ShopTabs", true, false) != null, "Merchant shop must expose role-specific tabs.")
	_expect(overlay.find_child("ProductList", true, false) is VBoxContainer, "Merchant shop must expose the single-column product list.")
	var resource_blocks := overlay.find_child("ResourceBlocks", true, false) as HBoxContainer
	_expect(resource_blocks != null and resource_blocks.get_child_count() == 4, "Merchant shop must show military pay, materials and fleet capacity in four resource blocks.")
	(overlay.find_child("ProductList", true, false).get_child(0) as Button).pressed.emit()
	var before: Dictionary = root.get_node("GameState").call("get_economy_state")
	(overlay.find_child("BuyButton", true, false) as Button).pressed.emit()
	var after: Dictionary = root.get_node("GameState").call("get_economy_state")
	_expect(after["pay"] == before["pay"] - 12 and after["items"]["wood"] == before["items"]["wood"] + 1, "Merchant buy action must use the economy service.")
	harbor.call("close_shop_for_test")
	var return_position := Vector2(3610, 520)
	root.set_meta(TRAVEL.RETURN_CONTEXT_META, TRAVEL.make_context(return_position, 2, 3, 8.5))
	var player := harbor.get_node("World/WorldObjects/Player") as CharacterBody2D
	player.global_position = harbor.get_node("World/Triggers/DockReturn").global_position
	await physics_frame; await physics_frame
	var interact := InputEventAction.new(); interact.action = &"interact"; interact.pressed = true
	harbor.call("_unhandled_input", interact)
	await process_frame; await process_frame; await physics_frame
	_expect(current_scene != null and current_scene.scene_file_path == "res://scenes/sea_overworld/sea_overworld.tscn", "Harbor return must load the sea chart.")
	if current_scene != null and current_scene.scene_file_path.ends_with("sea_overworld.tscn"):
		_expect((current_scene.get_node("World/Player") as Node2D).global_position.is_equal_approx(return_position), "Harbor return must restore the ship's entry position.")
	if failures.is_empty(): print("Yuehuan harbor verification passed."); quit(0); return
	for failure in failures: push_error(failure)
	quit(1)
func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
