extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_runtime_world_state")
	var trade_scene := await _spawn_scene()
	await _verify_trade_flow(trade_scene)
	trade_scene.queue_free()
	await process_frame

	var restored_scene := await _spawn_scene()
	_expect(restored_scene.get_node_or_null("World/WorldMarkers/LingnanMerchantShip") == null, "Completed Lingnan merchant encounter must stay removed after re-entering the sea map.")
	restored_scene.queue_free()
	await process_frame

	game_state.call("reset_runtime_world_state")
	var ignore_scene := await _spawn_scene()
	await _verify_ignore_flow(ignore_scene)
	ignore_scene.queue_free()
	await process_frame
	game_state.call("reset_runtime_world_state")

	if failures.is_empty():
		print("Sea overworld Lingnan merchant verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _spawn_scene() -> Node:
	var scene := SEA_SCENE.instantiate()
	scene.set("_random_event_seed_override", 0)
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	return scene


func _verify_trade_flow(scene: Node) -> void:
	var ship := scene.get_node_or_null("World/WorldMarkers/LingnanMerchantShip") as Area2D
	_expect(ship != null, "The existing Lingnan merchant ship must be present before the encounter is completed.")
	if ship == null:
		return
	var player := scene.get_node("World/Player") as CharacterBody2D
	player.global_position = ship.global_position
	for _frame in range(3):
		await physics_frame
	var dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	var speaker := dialogue.get_node("NamePlate/SpeakerLabel") as Label
	var line := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label
	var option_box := _option_box(dialogue)
	_expect(dialogue.visible and speaker.text == "水师士兵", "Approaching the Lingnan merchant must open a soldier report.")
	_expect("前方" in line.text and "岭南商船" in line.text, "The soldier report must explain that a merchant ship is ahead.")
	_expect(option_box.get_child_count() == 2, "The initial Lingnan merchant report must show exactly two choices.")
	if option_box.get_child_count() != 2:
		return
	_expect((option_box.get_child(0) as Button).text == "查看货物  ▶", "The first choice must be 查看货物.")
	_expect((option_box.get_child(1) as Button).text == "无视  ▶", "The second choice must be 无视.")
	(option_box.get_child(0) as Button).pressed.emit()
	await process_frame

	var overlay := scene.get_node("UI/LingnanMerchantShopOverlay") as Control
	var exploration_hud := root.get_node("ExplorationUI/HUD") as Control
	_expect(overlay.visible, "Choosing 查看货物 must open the merchant shop overlay.")
	_expect(not exploration_hud.visible and not player.controls_enabled, "The shop must hide the sea HUD and lock sailing.")
	_expect(overlay.call("active_price_profile_for_test") == &"lingnan_ship", "The sea merchant must use its dedicated price profile.")
	var wood_buy := int(overlay.call("unit_price_for_test", "wood", "goods"))
	var wood_sell := int(overlay.call("unit_price_for_test", "wood", "sell"))
	var iron_buy := int(overlay.call("unit_price_for_test", "ironstone", "goods"))
	var iron_sell := int(overlay.call("unit_price_for_test", "ironstone", "sell"))
	_expect(wood_buy == 9 and wood_sell == 8, "Lingnan wood must be cheaper to buy and better to sell than at Moon Harbor, without arbitrage.")
	_expect(iron_buy == 13 and iron_sell == 12, "Lingnan ironstone must be cheaper to buy and better to sell than at Moon Harbor, without arbitrage.")
	_expect(wood_sell < wood_buy and iron_sell < iron_buy, "Every two-way Lingnan trade must sell back for less than its purchase price.")

	overlay.call("_buy_action")
	var economy := root.get_node("GameState").call("get_economy_state") as Dictionary
	_expect(economy["pay"] == 791 and economy["items"]["wood"] == 31, "Buying from the Lingnan ship must charge the discounted price, not the Moon Harbor price.")
	overlay.call("_set_mode", "sell")
	overlay.call("_sell_action")
	economy = root.get_node("GameState").call("get_economy_state") as Dictionary
	_expect(economy["pay"] == 799 and economy["items"]["wood"] == 30, "Selling back must use the premium sell price while still losing one silver coin overall.")

	overlay.call("close_shop")
	await process_frame
	option_box = _option_box(dialogue)
	_expect(dialogue.visible and speaker.text == "岭南商人" and ("感谢" in line.text or "多谢" in line.text), "Closing the shop must open the merchant thank-you dialogue.")
	_expect(option_box.get_child_count() == 1 and (option_box.get_child(0) as Button).text == "继续  ▶", "The thank-you dialogue must have only one 继续 choice.")
	if option_box.get_child_count() == 1:
		(option_box.get_child(0) as Button).pressed.emit()
		await process_frame
		await process_frame
	_expect(not dialogue.visible and player.controls_enabled, "Choosing 继续 must return control to the sea map.")
	_expect(scene.get_node_or_null("World/WorldMarkers/LingnanMerchantShip") == null, "The Lingnan merchant ship must disappear after the thank-you dialogue.")
	_expect(bool(root.get_node("GameState").call("is_lingnan_merchant_event_completed")), "Lingnan merchant completion must persist in world state.")


func _verify_ignore_flow(scene: Node) -> void:
	var ship := scene.get_node_or_null("World/WorldMarkers/LingnanMerchantShip") as Area2D
	if ship == null:
		_expect(false, "Lingnan merchant ship must exist for the ignore branch.")
		return
	var player := scene.get_node("World/Player") as CharacterBody2D
	player.global_position = ship.global_position
	for _frame in range(3):
		await physics_frame
	var dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	var option_box := _option_box(dialogue)
	if option_box.get_child_count() == 2:
		(option_box.get_child(1) as Button).pressed.emit()
		await process_frame
	_expect(not dialogue.visible and player.controls_enabled, "Choosing 无视 must immediately resume sailing.")
	_expect(scene.get_node_or_null("World/WorldMarkers/LingnanMerchantShip") != null, "Ignoring the ship must leave it available for a later visit.")


func _option_box(dialogue: Control) -> VBoxContainer:
	return dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
