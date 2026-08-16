extends SceneTree

const CATALOG := preload("res://scripts/economy/item_catalog.gd")
const ECONOMY := preload("res://scripts/economy/economy_state.gd")
const TRADE := preload("res://scripts/economy/trade_service.gd")

var failures: Array[String] = []


func _initialize() -> void:
	_run()


func _run() -> void:
	_test_catalog_has_only_sourced_goods()
	_test_default_state()
	_test_ship_upgrades()
	_test_material_buy_and_sell()
	_test_sell_only_goods()
	_test_atomic_failures()
	_test_blueprints_and_shipbuilding()
	_test_fishing_catch_mapping()
	_finish()


func _test_catalog_has_only_sourced_goods() -> void:
	var expected := ["green_crab", "grouper", "ironstone", "longjing_tea", "old_boot", "private_salt", "wood", "yellow_croaker"]
	var ids: Array = CATALOG.item_ids()
	ids.sort()
	_expect(ids == expected, "Catalog must contain exactly the sourced first-release goods.")
	for item_id in ids:
		var item: Dictionary = CATALOG.item(item_id)
		_expect(not str(item.get("source", "")).is_empty(), "%s must declare a production source." % item_id)


func _test_default_state() -> void:
	var state: Dictionary = ECONOMY.make_default()
	_expect(state["pay"] == 800, "New games must start with 800 military pay.")
	_expect(state["items"] == {"wood": 30, "ironstone": 20}, "New games must start with documented materials only.")
	_expect((state["blueprints"] as Array).is_empty(), "New games must not own blueprints.")
	var starting_types := (state["ships"] as Array).map(func(ship: Dictionary): return str(ship["type_id"]))
	_expect(starting_types == ["patrol_boat", "cannon_warship", "escort_junk", "patrol_boat", "cannon_warship"], "New games must own five ships while retaining every available type.")
	_expect(state["ships"][0]["current_hp"] == 42 and state["ships"][2]["current_hp"] == 70, "New games must include two damaged ships for repair testing.")
	_expect(state["ships"][0]["equipment"]["weapons"] == {"bombardment": 1}, "Starting ships must carry persisted battle-compatible equipment IDs.")
	_expect(state["ships"][0]["upgrades"] == {"hull": 0, "weapon_slots": 0, "skill_slots": 0, "speed": 0} and state["ship_upgrade_materials"]["canvas"] == 20, "Starting ships must expose four zero-level upgrades and an isolated test canvas stock.")
	_expect(ECONOMY.normalize({}) == state, "An uninitialized economy dictionary must normalize to new-game defaults.")
	var repaired_state := ECONOMY.normalize(state)
	_expect(repaired_state["ships"][0]["current_hp"] == 42, "Economy normalization must preserve current ship durability.")
	_expect(ECONOMY.repair_ship(repaired_state, "ship_001").get("ok", false) and repaired_state["ships"][0]["current_hp"] == 60, "Ship repair must restore and persist maximum durability.")
	_expect(ECONOMY.adjust_ship_equipment(repaired_state, "ship_001", "weapons", "ram", 1).get("ok", false), "Ship equipment must accept battle weapon IDs while slots remain.")


func _test_ship_upgrades() -> void:
	var state := ECONOMY.make_default()
	var hull_result := ECONOMY.upgrade_ship(state, "ship_001", "hull")
	_expect(hull_result.get("ok", false) and state["ships"][0]["upgrades"]["hull"] == 1, "Hull upgrading must persist its level on the selected ship.")
	_expect(state["ships"][0]["max_hp"] == 63 and state["ships"][0]["current_hp"] == 45, "Each hull level must add five percent of base durability while preserving existing damage.")
	_expect(state["pay"] == 700 and state["items"]["wood"] == 22, "Hull upgrading must consume military pay and wood.")

	state = ECONOMY.make_default()
	_expect(ECONOMY.upgrade_ship(state, "ship_001", "weapon_slots").get("ok", false), "Weapon-slot upgrading must succeed with sufficient resources.")
	_expect(state["ships"][0]["upgrades"]["weapon_slots"] == 1 and state["pay"] == 660 and state["items"]["ironstone"] == 14, "Weapon-slot upgrading must add one slot level and consume military pay plus ironstone.")
	_expect(ECONOMY.adjust_ship_equipment(state, "ship_001", "weapons", "ram", 1).get("ok", false) and ECONOMY.adjust_ship_equipment(state, "ship_001", "weapons", "cannon", 1).get("ok", false), "An upgraded weapon-slot cap must be honored by equipment configuration.")

	state = ECONOMY.make_default()
	_expect(ECONOMY.upgrade_ship(state, "ship_001", "skill_slots").get("ok", false), "Skill-slot upgrading must succeed with sufficient resources.")
	_expect(state["ships"][0]["upgrades"]["skill_slots"] == 1 and state["pay"] == 680 and state["items"]["ironstone"] == 15, "Skill-slot upgrading must add one slot level and consume military pay plus ironstone.")

	state = ECONOMY.make_default()
	_expect(ECONOMY.upgrade_ship(state, "ship_001", "speed").get("ok", false), "Speed upgrading must succeed with sufficient resources.")
	_expect(state["ships"][0]["upgrades"]["speed"] == 1 and state["pay"] == 700 and state["ship_upgrade_materials"]["canvas"] == 14, "Speed upgrading must add one speed level and consume military pay plus isolated test canvas.")
	state["pay"] = 10000
	state["ship_upgrade_materials"]["canvas"] = 100
	_expect(ECONOMY.upgrade_ship(state, "ship_001", "speed").get("ok", false) and ECONOMY.upgrade_ship(state, "ship_001", "speed").get("ok", false), "Test ships must allow three speed upgrade levels.")
	var before_max_attempt := state.duplicate(true)
	_expect(ECONOMY.upgrade_ship(state, "ship_001", "speed").get("reason") == "max_level" and state == before_max_attempt, "A fourth upgrade must be rejected atomically at the per-type level cap.")
	_expect(ECONOMY.normalize(state)["ships"][0]["upgrades"]["speed"] == 3, "Upgrade levels must survive economy normalization.")


func _test_material_buy_and_sell() -> void:
	var state := ECONOMY.make_default()
	var buy: Dictionary = TRADE.buy_item(state, "wood", 5)
	_expect(buy.get("ok", false), "Wood purchase must succeed with enough pay.")
	_expect(state["pay"] == 740 and state["items"]["wood"] == 35, "Wood purchase must apply quantity and unit price.")
	var sell: Dictionary = TRADE.sell_item(state, "wood", 3)
	_expect(sell.get("ok", false), "Wood sale must succeed with enough stock.")
	_expect(state["pay"] == 758 and state["items"]["wood"] == 32, "Wood sale must pay the fixed sell price.")


func _test_sell_only_goods() -> void:
	var state := ECONOMY.make_default()
	ECONOMY.add_item(state, "grouper", 2)
	var buy: Dictionary = TRADE.buy_item(state, "grouper", 1)
	_expect(not buy.get("ok", false) and buy.get("reason") == "not_for_sale", "Specialties must not be purchasable.")
	var sell: Dictionary = TRADE.sell_item(state, "grouper", 2)
	_expect(sell.get("ok", false) and state["pay"] == 890, "Two groupers must sell for 90 pay.")
	_expect(not state["items"].has("grouper"), "Zero-quantity goods must be removed from inventory.")


func _test_atomic_failures() -> void:
	var state := ECONOMY.make_default()
	var before := state.duplicate(true)
	_expect(not TRADE.buy_item(state, "ironstone", 0).get("ok", false), "Zero quantity must be rejected.")
	_expect(state == before, "Rejected quantity must not mutate state.")
	state["pay"] = 1
	before = state.duplicate(true)
	_expect(TRADE.buy_item(state, "ironstone", 1).get("reason") == "insufficient_pay", "Insufficient pay must be explicit.")
	_expect(state == before, "Failed purchase must be atomic.")
	before = state.duplicate(true)
	_expect(TRADE.sell_item(state, "wood", 999).get("reason") == "insufficient_stock", "Insufficient stock must be explicit.")
	_expect(state == before, "Failed sale must be atomic.")


func _test_blueprints_and_shipbuilding() -> void:
	var state := ECONOMY.make_default()
	var missing: Dictionary = TRADE.build_ship(state, "patrol_boat")
	_expect(missing.get("reason") == "blueprint_required", "Shipbuilding must require its blueprint.")
	var purchase: Dictionary = TRADE.buy_blueprint(state, "patrol_boat")
	_expect(purchase.get("ok", false) and state["pay"] == 500, "Patrol blueprint must cost 300 pay.")
	var after_purchase := state.duplicate(true)
	_expect(TRADE.buy_blueprint(state, "patrol_boat").get("reason") == "already_owned", "Blueprint cannot be purchased twice.")
	_expect(state == after_purchase, "Duplicate blueprint purchase must not mutate state.")
	ECONOMY.add_item(state, "wood", 20)
	var built: Dictionary = TRADE.build_ship(state, "patrol_boat")
	_expect(built.get("ok", false), "Owned blueprint and sufficient costs must build a ship.")
	_expect((state["ships"] as Array).size() == 6 and state["ships"][5]["id"] == "ship_006", "Built ship must receive a unique sequential id after the five starting ships.")
	_expect(state["pay"] == 260 and state["items"]["wood"] == 14 and state["items"]["ironstone"] == 6, "Shipbuilding must consume the documented costs.")
	state["pay"] = 10000
	state["items"]["wood"] = 2000
	state["items"]["ironstone"] = 2000
	for _index in range(12):
		_expect(TRADE.build_ship(state, "patrol_boat").get("ok", false), "Fleet building must remain available beyond the old ten-ship limit.")
	_expect((state["ships"] as Array).size() == 18, "Fleet capacity must be unlimited by gameplay rules.")
	_expect((ECONOMY.normalize(state)["ships"] as Array).size() == 18, "Saving and loading must preserve fleets larger than ten ships.")


func _test_fishing_catch_mapping() -> void:
	var mapping := {"small_fish": "yellow_croaker", "big_fish": "grouper", "crab": "green_crab", "boot": "old_boot"}
	for catch_kind in mapping:
		_expect(CATALOG.fishing_reward_id(catch_kind) == mapping[catch_kind], "%s must map to its documented warehouse item." % catch_kind)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("Economy trade verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
