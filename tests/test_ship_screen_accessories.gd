extends SceneTree

# CHG-20260819（F-1 讨伐饰品）：饰品装备/卸下 UI + 装备后海战加成断言。
# 在 ship_screen 装备页把饰品装备到选中舰 → economy 状态持久化 → 开始讨伐战斗 →
# 旗舰撞角系数/砲击伤害/全舰队射程按装备饰品生效。headless 运行：
# godot --headless --script res://tests/test_ship_screen_accessories.gd

const HUD := preload("res://scenes/ui/exploration_hud.tscn")
const NAVAL_SCENE := preload("res://scenes/naval/NavalDemo.tscn")
const REQUEST_META := "sea_hunt_battle_request"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node("GameState")
	game_state.call("reset_runtime_world_state")
	# 直接授予三件讨伐饰品（等价于讨伐胜利战利品落袋），供装备 UI 断言。
	_check(bool(game_state.call("add_economy_accessory", "sea_monster_horn")), "The sea monster horn accessory must be added.")
	_check(bool(game_state.call("add_economy_accessory", "sun_piercing_spear")), "The sun piercing spear accessory must be added.")
	_check(bool(game_state.call("add_economy_accessory", "wokou_banner")), "The wokou banner accessory must be added.")

	# 装备页 UI：饰品卡可见，未装备态可点击装备。
	var hud := HUD.instantiate() as Control
	root.add_child(hud)
	await process_frame
	hud.call("set_exploration_visible", true)
	var ship_button := hud.find_child("ShipButton", true, false) as Button
	ship_button.pressed.emit()
	await process_frame
	var screen := hud.get_node("ShipScreen") as Control
	(screen.get_node("EquipmentTab") as Button).pressed.emit()
	await process_frame
	var equipment_page := screen.get_node("EquipmentPage") as Panel
	_check(equipment_page.get_node_or_null("AccessoryRow") != null, "The equipment page must expose the accessory rig block.")
	for accessory_id in ["sea_monster_horn", "sun_piercing_spear", "wokou_banner"]:
		var card := equipment_page.get_node_or_null("AccessoryRow/Accessory_%s" % accessory_id) as PanelContainer
		_check(card != null, "Every owned accessory must render a card.")
		var state_label := (card.get_node("Content/State") as Label).text
		_check(state_label == "未装备", "An owned un-equipped accessory must read 未装备 (got %s)." % state_label)
		var action := card.get_node("Content/Action") as Button
		_check(not action.disabled and action.text == "装备", "An owned accessory must offer an enabled equip action.")

	# 选中 ship_002（火炮战船/旗舰），把三件饰品装备到该舰。
	(screen.get_node("ShipListScroll/ShipListInset/ShipList").get_child(1) as Button).pressed.emit()
	await process_frame
	_check(str(screen.call("selected_ship_id_for_test")) == "ship_002", "Selecting the second row must select ship_002.")
	for accessory_id in ["sea_monster_horn", "sun_piercing_spear", "wokou_banner"]:
		var card := equipment_page.get_node("AccessoryRow/Accessory_%s" % accessory_id) as PanelContainer
		(card.get_node("Content/Action") as Button).pressed.emit()
		await process_frame
		var state_label := (card.get_node("Content/State") as Label).text
		_check(state_label == "已装备", "Equipping an accessory must mark it 已装备 on the selected ship (got %s)." % state_label)
	var after: Dictionary = game_state.call("get_economy_state")
	var equipped := (after.get("accessories", {}) as Dictionary).get("equipped", {}) as Dictionary
	_check(str(equipped.get("sea_monster_horn", "")) == "ship_002" and str(equipped.get("wokou_banner", "")) == "ship_002", "Equipped accessories must persist their ship.")
	# 卸下再装备，验证 toggle（装备到当前舰 → 卸下 → 未装备）。
	var horn_card := equipment_page.get_node("AccessoryRow/Accessory_sea_monster_horn") as PanelContainer
	(horn_card.get_node("Content/Action") as Button).pressed.emit()
	await process_frame
	_check((horn_card.get_node("Content/State") as Label).text == "未装备", "Toggling an equipped accessory must unequip it.")
	(horn_card.get_node("Content/Action") as Button).pressed.emit()
	await process_frame
	_check((horn_card.get_node("Content/State") as Label).text == "已装备", "Toggling an unequipped accessory must equip it again.")

	# 关闭 ship_screen，进入讨伐战斗（hunt_stage1 海怪：金2000 + 海怪之角）。
	(screen.get_node("ShipReturnSlot/ShipReturnButton") as Button).pressed.emit()
	await process_frame
	hud.queue_free()
	await process_frame
	root.remove_meta(REQUEST_META)
	root.set_meta(REQUEST_META, {
		"stage_id": "hunt_stage1",
		"player_position": [4380.0, 2460.0],
		"lunar_day": 3.0,
	})
	var demo := NAVAL_SCENE.instantiate()
	root.add_child(demo)
	current_scene = demo
	await process_frame
	await physics_frame
	var deploy := demo.get_node("Deployment")
	var controller := demo.get_node("Battle/BattleController")
	var confirm_err := str(deploy.call("ConfirmDeployment"))
	_check(confirm_err.is_empty(), "Confirming the accessory hunt deployment must succeed (err: %s)." % confirm_err)
	await process_frame
	_check(bool(controller.call("HuntBattleActive")), "The hunt battle must be active for accessory bonuses.")

	# 装备加成 → BattleState：军旗→全舰队射程 +1；海怪之角→旗舰撞角 Lv4（系数1.8）；贯日神枪→旗舰砲击 Lv4（420伤害）。
	_check(int(controller.call("RangeBonus")) == 1, "The wokou banner must add +1 fleet-wide range (got %d)." % int(controller.call("RangeBonus")))
	_check(int(controller.call("FlagshipRamLevel")) == 4, "The sea monster horn must set flagship ram to Lv4 (got %d)." % int(controller.call("FlagshipRamLevel")))
	_check(int(controller.call("FlagshipBombardmentLevel")) == 4, "The sun piercing spear must set flagship bombardment to Lv4 (got %d)." % int(controller.call("FlagshipBombardmentLevel")))
	# 规则层数值直达：撞角系数 1.8；旗舰砲击单发 420。
	_check(is_equal_approx(float(controller.call("FlagshipRamCoefficient")), 1.8), "Flagship ram coefficient must reach Lv4 1.8 (got %s)." % str(controller.call("FlagshipRamCoefficient")))
	_check(int(controller.call("FlagshipBombardmentDamage")) == 420, "Flagship bombardment damage must reach Lv4 420 (got %d)." % int(controller.call("FlagshipBombardmentDamage")))

	_finish(demo, game_state)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(scene: Node, game_state: Node) -> void:
	current_scene = null
	if is_instance_valid(scene):
		scene.queue_free()
	await process_frame
	game_state.call("reset_runtime_world_state")
	if failures.is_empty():
		print("Ship screen accessory verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
