extends SceneTree

const ISLAND := preload("res://scenes/yuehuan_merchant_harbor/yuehuan_merchant_harbor.tscn")
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var island := ISLAND.instantiate()
	root.add_child(island)
	current_scene = island
	await process_frame
	_expect(island is Node2D, "Merchant harbor must be an explorable Node2D world.")
	_expect(island.get_node_or_null("World/Ground/Background") != null, "Island must contain the generated background.")
	var background := island.get_node("World/Ground/Background") as Sprite2D
	_expect(background.texture.resource_path.ends_with("yuehuan_merchant_island_v4.png"), "Island must use the merchant-headquarters V4 background.")
	_expect(island.get_node_or_null("World/WorldObjects/Player") != null, "Island must contain the controllable player.")
	_expect(island.get_node_or_null("World/Collision/WalkableBoundary") != null, "Island must contain coarse world collision.")
	var collision_root := island.get_node("World/Collision")
	_expect(collision_root.get_child_count() == 1, "Red-line collision must be represented by one coarse walkable-boundary body.")
	_expect(island.get_node("World/Collision/WalkableBoundary").get_child_count() == 10, "Fine-tuned red-line boundary must use ten broad rectangles to preserve the dock entrance step.")
	_expect(island.get_node_or_null("World/ShopSigns") == null, "V4 must communicate merchant headquarters through architecture, without floating oversized shop signs.")
	var liang := island.get_node_or_null("World/WorldObjects/LiangTrader")
	var shen := island.get_node_or_null("World/WorldObjects/ShenShipwright")
	_expect(liang != null and liang.get("shop_role") == "goods", "Liang must own goods purchase and collection.")
	_expect(shen != null and shen.get("shop_role") == "shipyard", "Shen must own blueprints and shipbuilding.")
	_expect(liang.position.is_equal_approx(Vector2(460, 655)), "Liang must stand at the camera-calibrated lower-left warehouse forecourt position without hiding behind the quest HUD.")
	_expect(absf(liang.global_position.x - shen.global_position.x) >= 500.0, "Core merchants must stand in separate wide shop forecourts.")
	_expect(liang.has_method("show_bark_for_test"), "Merchants must expose a deterministic ambient-bark test hook.")
	if liang.has_method("show_bark_for_test"):
		liang.call("show_bark_for_test")
		var bark_bubble := liang.get_node_or_null("BarkBubble") as Control
		_expect(bark_bubble != null and bark_bubble.visible, "Ambient merchant bark must appear in a small overhead bubble during exploration.")
		_expect(island.get_node("Interface/MerchantDialogue").visible == false, "Ambient bark must never auto-open full-screen dialogue.")
		island.call("open_merchant_dialogue_for_test", "liang")
		await process_frame
		_expect(not bark_bubble.visible, "Opening full-screen merchant dialogue must hide ambient bark immediately.")
		island.call("close_dialogue_for_test")
	var upper_left := island.get_node("World/Collision/WalkableBoundary/UpperLeftBlock") as CollisionShape2D
	var middle_left := island.get_node("World/Collision/WalkableBoundary/MiddleLeftBlock") as CollisionShape2D
	var dock_entry_left := island.get_node("World/Collision/WalkableBoundary/DockEntryLeft") as CollisionShape2D
	var lower_left := island.get_node("World/Collision/WalkableBoundary/LowerLeftSea") as CollisionShape2D
	_expect(upper_left.position.is_equal_approx(Vector2(277.5, 335.0)) and (upper_left.shape as RectangleShape2D).size == Vector2(555, 420), "Upper-left blocker must leave only the confirmed central street open.")
	_expect(middle_left.position.is_equal_approx(Vector2(87.5, 622.5)) and (middle_left.shape as RectangleShape2D).size == Vector2(175, 155), "Middle-left blocker must preserve the red-line merchant forecourt expansion.")
	_expect(dock_entry_left.position.is_equal_approx(Vector2(285, 715)) and (dock_entry_left.shape as RectangleShape2D).size == Vector2(570, 30), "Dock entrance must retain the confirmed short stepped transition.")
	_expect(lower_left.position.is_equal_approx(Vector2(295, 877)) and (lower_left.shape as RectangleShape2D).size == Vector2(590, 294), "Lower-left sea blocker must follow the actual inner stone-pier edge.")
	await physics_frame
	for point in [Vector2(760, 220), Vector2(300, 620), Vector2(1100, 620), Vector2(750, 715), Vector2(750, 850)]:
		_expect(not _world_point_is_blocked(island, point), "Confirmed red-line interior point %s must remain walkable." % point)
	for point in [Vector2(300, 300), Vector2(1200, 300), Vector2(565, 715), Vector2(935, 715), Vector2(580, 850), Vector2(915, 850)]:
		_expect(_world_point_is_blocked(island, point), "Point %s outside the confirmed red line must be blocked." % point)
	_expect(not bool(island.call("is_shop_open_for_test")), "Entering the island must not auto-open a shop.")
	var exploration_ui := root.get_node("ExplorationUI")
	_expect(exploration_ui.call("current_owner") == island, "Merchant island must acquire the shared exploration HUD.")
	var exploration_hud := exploration_ui.call("get_hud") as Control
	var inventory_button := exploration_ui.find_child("InventoryButton", true, false) as Button
	inventory_button.pressed.emit()
	await process_frame
	_expect(not (island.get_node("World/WorldObjects/Player") as CharacterBody2D).get("controls_enabled"), "Global inventory must lock island movement.")
	var inventory_screen := exploration_ui.find_child("InventoryScreen", true, false)
	(inventory_screen.find_child("CloseButton", true, false) as Button).pressed.emit()
	await process_frame
	_expect((island.get_node("World/WorldObjects/Player") as CharacterBody2D).get("controls_enabled"), "Closing global inventory must restore island movement.")
	var player := island.get_node("World/WorldObjects/Player") as CharacterBody2D
	player.global_position = Vector2(768, 700)
	await physics_frame
	await physics_frame
	player.global_position = liang.global_position + Vector2(58, 0)
	await physics_frame
	await physics_frame
	_expect(island.get_node("Interface/PromptPanel").visible, "Entering Liang's Area2D must show the interaction prompt.")
	_expect(island.call("nearest_interaction_id_for_test") == "liang", "Liang must be the nearest real Area2D interaction target.")
	_send_interact(island)
	await process_frame
	_expect(island.get_node("Interface/MerchantDialogue").visible, "Interact input inside Liang's Area2D must open dialogue.")
	_expect(not (island.get_node("World/WorldObjects/Player") as CharacterBody2D).get("controls_enabled"), "Dialogue must lock movement.")
	island.call("choose_trade_for_test")
	await process_frame
	_expect(island.call("active_shop_role_for_test") == "goods", "Liang dialogue must open the goods shop.")
	_expect(not exploration_hud.visible, "Opening any merchant shop must hide the entire shared exploration HUD.")
	var overlay := island.get_node("Interface/MerchantShopOverlay")
	_expect(overlay.find_child("MerchantStage", true, false) is Control, "Merchant shop must reserve a dedicated merchant-and-counter atmosphere stage.")
	_expect((island.get_node("World/WorldObjects/LiangTrader/Sprite") as Sprite2D).scale.x <= 0.065, "Liang's map sprite must not exceed the player character's visible scale.")
	_expect((island.get_node("World/WorldObjects/ShenShipwright/Sprite") as Sprite2D).scale.x <= 0.065, "Shen's map sprite must not exceed the player character's visible scale.")
	_expect(overlay.find_child("ProductList", true, false) is VBoxContainer, "Merchant shop must use one vertical product list as the primary browsing surface.")
	_expect(overlay.find_child("ItemPreview", true, false) is TextureRect, "Merchant shop must feature a large selected-item preview.")
	_expect(overlay.find_child("CargoGrid", true, false) == null, "Player cargo must not remain as a competing permanent third panel.")
	_expect(overlay.find_child("TransactionStage", true, false) is Control, "Selected-item art and transaction controls must share one dominant right-side stage.")
	_expect(overlay.find_child("MerchantHeaderPortrait", true, false) is TextureRect, "Merchant portrait must be integrated into the title bar instead of consuming a body column.")
	_expect(overlay.find_child("Quick10Button", true, false) is Button, "Goods transactions must provide a +10 quantity shortcut.")
	_expect(overlay.find_child("Quick100Button", true, false) is Button, "Goods transactions must provide a +100 quantity shortcut.")
	_expect(overlay.find_child("MaximumButton", true, false) is Button, "Goods transactions must provide a maximum quantity shortcut.")
	_expect(overlay.find_child("ClearQuantityButton", true, false) is Button, "Goods transactions must provide a clear quantity shortcut.")
	_expect(overlay.find_child("AfterTradePreview", true, false) is Label, "Goods transactions must preview pay and holdings after the trade.")
	_expect(overlay.find_child("ResourceBlocks", true, false) is HBoxContainer, "Bottom resources must be split into evenly spaced icon blocks.")
	_expect(int(overlay.call("maximum_quantity_for_test", "wood")) == 66, "Wood maximum purchase must be computed from current military pay and unit price.")
	var preview := overlay.call("transaction_preview_for_test", "wood", 10) as Dictionary
	_expect(preview.get("pay_after") == 680 and preview.get("held_after") == 40, "Buying ten wood must preview resulting pay and holdings without mutating state.")
	_expect(overlay.has_method("icon_path_for_test"), "Merchant shop must expose its resolved visual asset path for contract testing.")
	if overlay.has_method("icon_path_for_test"):
		_expect(str(overlay.call("icon_path_for_test", "wood")).ends_with("wood.png"), "Wood must use its generated pixel-art item icon.")
	_expect(bool(overlay.call("shop_contains_for_test", "wood")), "Goods shop must sell wood.")
	_expect(bool(overlay.call("shop_contains_for_test", "ironstone")), "Goods shop must sell ironstone.")
	_expect(bool(overlay.call("warehouse_contains_for_test", "yellow_croaker")), "Goods shop warehouse must expose sellable specialties.")
	_expect(not bool(overlay.call("can_buy_for_test", "yellow_croaker")), "Goods shop must not buy specialties from the merchant.")
	island.call("close_shop_for_test")
	_expect(exploration_hud.visible, "Closing a merchant shop must restore the shared exploration HUD.")
	_expect((island.get_node("World/WorldObjects/Player") as CharacterBody2D).get("controls_enabled"), "Closing shop must restore movement.")
	island.call("open_merchant_dialogue_for_test", "shen")
	island.call("choose_trade_for_test")
	await process_frame
	_expect(island.call("active_shop_role_for_test") == "shipyard", "Shen dialogue must open the shipyard.")
	_expect(bool(overlay.call("shop_contains_for_test", "patrol_boat")), "Shipyard must expose ship blueprints.")
	_expect(not bool(overlay.call("shop_contains_for_test", "wood")), "Shipyard must not expose ordinary goods.")
	if overlay.has_method("icon_path_for_test"):
		_expect(str(overlay.call("icon_path_for_test", "patrol_boat")).ends_with("patrol_boat.png"), "Patrol ship card must use the processed art-team ship asset.")
	overlay.call("set_shipbuilding_mode_for_test")
	await process_frame
	_expect(not bool(overlay.call("shop_contains_for_test", "patrol_boat")), "Shipbuilding must hide ship types whose blueprints are not owned.")
	island.queue_free()
	await process_frame
	if failures.is_empty():
		print("Yuehuan merchant island verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _send_interact(island: Node) -> void:
	var event := InputEventAction.new()
	event.action = &"interact"
	event.pressed = true
	island.call("_unhandled_input", event)


func _world_point_is_blocked(island: Node2D, point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	var hits := island.get_world_2d().direct_space_state.intersect_point(query, 8)
	for hit in hits:
		if island.get_node("World/Collision").is_ancestor_of(hit["collider"] as Node):
			return true
	return false
