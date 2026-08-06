class_name OfficialCampaignState
extends RefCounted

const SAVE_VERSION := 2
const INITIAL_PAY := 180
const EMERGENCY_PAY := 45
const UPGRADE_COST := 70
const PROMOTION_MERIT := 30

const ORDERS := {
	"coast_patrol": {
		"id": "coast_patrol",
		"display_name": "近海剿盗",
		"mission_id": "elimination",
		"objective": "击沉两艘侵扰榕湾航路的海盗船",
		"enemy_summary": "黑潮快船 + 黑潮炮船",
		"pay": 90,
		"merit": 10,
	},
	"black_tide_flagship": {
		"id": "black_tide_flagship",
		"display_name": "截击黑潮旗舰",
		"mission_id": "flagship",
		"objective": "击沉敌方炮船旗舰并保护我方火炮战船",
		"enemy_summary": "黑潮快船 + 旗舰炮船",
		"pay": 110,
		"merit": 15,
	},
	"beacon_defense": {
		"id": "beacon_defense",
		"display_name": "固守珠潮航标",
		"mission_id": "beacon",
		"objective": "在完整回合结束时控制航标，率先取得2分",
		"enemy_summary": "黑潮快船 + 黑潮炮船",
		"pay": 100,
		"merit": 12,
	},
}

const BASE_SHIPS := {
	"player_1": {
		"id": "player_1",
		"name": "巡哨快船·镇澜一号",
		"class_id": "fast",
		"class_name": "巡哨快船",
		"hp": 50,
	},
	"player_2": {
		"id": "player_2",
		"name": "火炮战船·靖海二号",
		"class_id": "gunship",
		"class_name": "火炮战船",
		"hp": 70,
	},
}

var rank_id := "trainee"
var pay := INITIAL_PAY
var merit := 0
var completed_orders := 0
var active_order_id := ""
var ships: Dictionary = {}
var last_report := "奉命驻守榕湾水寨。请先到中军帐查看军令。"
var promotion_pending := false


func _init() -> void:
	reset()


func reset() -> void:
	rank_id = "trainee"
	pay = INITIAL_PAY
	merit = 0
	completed_orders = 0
	active_order_id = ""
	last_report = "奉命驻守榕湾水寨。请先到中军帐查看军令。"
	promotion_pending = false
	ships = {}
	for ship_id in BASE_SHIPS:
		var base: Dictionary = BASE_SHIPS[ship_id]
		ships[ship_id] = {
			"id": ship_id,
			"name": base["name"],
			"class_id": base["class_id"],
			"class_name": base["class_name"],
			"hp": base["hp"],
			"max_hp": base["hp"],
			"durability_level": 0,
			"weapon_level": 0,
		}


func rank_name() -> String:
	return "哨队队正" if rank_id == "squad_leader" else "见习水勇"


func orders() -> Dictionary:
	return ORDERS.duplicate(true)


func select_order(order_id: String) -> Dictionary:
	if not ORDERS.has(order_id):
		return _reject("invalid_order")
	active_order_id = order_id
	var order: Dictionary = ORDERS[order_id]
	last_report = "已领取军令《%s》，整备舰队后即可出航。" % order["display_name"]
	return {"ok": true, "order": order.duplicate(true)}


func active_order() -> Dictionary:
	if not ORDERS.has(active_order_id):
		return {}
	return ORDERS[active_order_id].duplicate(true)


func battle_fleet_state() -> Dictionary:
	return ships.duplicate(true)


func resolve_battle(battle_result: String, battle_ships: Dictionary) -> Dictionary:
	if not ORDERS.has(active_order_id):
		return _reject("no_active_order")
	if battle_result not in ["victory", "defeat", "draw"]:
		return _reject("invalid_result")
	var candidate_ships := ships.duplicate(true)
	for ship_id in BASE_SHIPS:
		if not battle_ships.has(ship_id) or not battle_ships[ship_id] is Dictionary:
			return _reject("missing_battle_ship")
		var source: Dictionary = battle_ships[ship_id]
		var target: Dictionary = candidate_ships[ship_id]
		target["hp"] = clampi(int(source.get("hp", target["hp"])), 0, int(target["max_hp"]))
		if battle_result != "victory":
			target["hp"] = maxi(int(target["hp"]), int(ceil(float(target["max_hp"]) * 0.5)))
	ships = candidate_ships
	var order: Dictionary = ORDERS[active_order_id]
	var pay_awarded := int(order["pay"]) if battle_result == "victory" else EMERGENCY_PAY
	var merit_awarded := int(order["merit"]) if battle_result == "victory" else 0
	pay += pay_awarded
	merit += merit_awarded
	completed_orders += 1
	active_order_id = ""
	var promoted := false
	if rank_id == "trainee" and merit >= PROMOTION_MERIT:
		rank_id = "squad_leader"
		promotion_pending = true
		promoted = true
	if battle_result == "victory":
		last_report = "军令完成：军饷 +%d，军功 +%d。战损已带回水寨。" % [pay_awarded, merit_awarded]
	else:
		last_report = "任务未成：发放应急军饷 +%d，沉船已恢复最低出航状态。" % pay_awarded
	if promoted:
		last_report += "  因军功达到 %d，正式晋升为哨队队正。" % PROMOTION_MERIT
	return {
		"ok": true,
		"result": battle_result,
		"pay_awarded": pay_awarded,
		"merit_awarded": merit_awarded,
		"promoted": promoted,
		"rank_id": rank_id,
	}


func repair_quote(ship_id: String) -> int:
	if not ships.has(ship_id):
		return -1
	var ship: Dictionary = ships[ship_id]
	var missing := int(ship["max_hp"]) - int(ship["hp"])
	return int(ceil(float(missing) / 2.0))


func repair_ship(ship_id: String) -> Dictionary:
	var quote := repair_quote(ship_id)
	if quote < 0:
		return _reject("invalid_ship")
	if quote == 0:
		return _reject("already_repaired")
	if pay < quote:
		return _reject("insufficient_pay")
	pay -= quote
	var ship: Dictionary = ships[ship_id]
	ship["hp"] = ship["max_hp"]
	last_report = "%s已完成整船修复，支出军饷 %d。" % [ship["name"], quote]
	return {"ok": true, "cost": quote}


func upgrade_ship(ship_id: String, module_id: String) -> Dictionary:
	if not ships.has(ship_id):
		return _reject("invalid_ship")
	if module_id not in ["durability", "weapon"]:
		return _reject("invalid_module")
	var ship: Dictionary = ships[ship_id]
	var level_key := "%s_level" % module_id
	if int(ship[level_key]) >= 1:
		return _reject("max_level")
	if pay < UPGRADE_COST:
		return _reject("insufficient_pay")
	pay -= UPGRADE_COST
	ship[level_key] = 1
	match module_id:
		"durability":
			ship["max_hp"] = int(ship["max_hp"]) + 6
			ship["hp"] = int(ship["hp"]) + 6
		"weapon":
			pass
	last_report = "%s完成%s一级升级，支出军饷 %d。" % [ship["name"], _module_name(module_id), UPGRADE_COST]
	return {"ok": true, "cost": UPGRADE_COST, "module_id": module_id, "level": 1}


func to_save_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"rank_id": rank_id,
		"pay": pay,
		"merit": merit,
		"completed_orders": completed_orders,
		"active_order_id": active_order_id,
		"ships": ships.duplicate(true),
		"last_report": last_report,
		"promotion_pending": promotion_pending,
	}


func load_save_data(data: Dictionary) -> Dictionary:
	var validation := _validate_save_data(data)
	if not validation.get("ok", false):
		return validation
	var candidate: Dictionary = data.duplicate(true)
	rank_id = str(candidate["rank_id"])
	pay = int(candidate["pay"])
	merit = int(candidate["merit"])
	completed_orders = int(candidate["completed_orders"])
	active_order_id = str(candidate["active_order_id"])
	ships = {}
	for ship_id in BASE_SHIPS:
		var saved_ship: Dictionary = candidate["ships"][ship_id].duplicate(true)
		for numeric_key in ["hp", "max_hp", "durability_level", "weapon_level"]:
			saved_ship[numeric_key] = int(saved_ship[numeric_key])
		ships[ship_id] = saved_ship
	last_report = str(candidate["last_report"])
	promotion_pending = bool(candidate["promotion_pending"])
	return {"ok": true}


func _validate_save_data(data: Dictionary) -> Dictionary:
	var required_keys := ["version", "rank_id", "pay", "merit", "completed_orders", "active_order_id", "ships", "last_report", "promotion_pending"]
	for key in required_keys:
		if not data.has(key):
			return _reject("missing_save_field")
	if not _is_whole_number(data["version"]) or int(data["version"]) != SAVE_VERSION:
		return _reject("unsupported_version")
	if typeof(data["rank_id"]) != TYPE_STRING or str(data["rank_id"]) not in ["trainee", "squad_leader"]:
		return _reject("invalid_rank")
	if not _is_whole_number(data["pay"]) or int(data["pay"]) < 0:
		return _reject("invalid_pay")
	if not _is_whole_number(data["merit"]) or int(data["merit"]) < 0:
		return _reject("invalid_merit")
	if not _is_whole_number(data["completed_orders"]) or int(data["completed_orders"]) < 0:
		return _reject("invalid_completed_orders")
	if typeof(data["active_order_id"]) != TYPE_STRING:
		return _reject("invalid_active_order")
	var saved_order_id := str(data["active_order_id"])
	if saved_order_id != "" and not ORDERS.has(saved_order_id):
		return _reject("invalid_active_order")
	if typeof(data["last_report"]) != TYPE_STRING or typeof(data["promotion_pending"]) != TYPE_BOOL:
		return _reject("invalid_report_state")
	if not data["ships"] is Dictionary:
		return _reject("invalid_ships")
	var saved_ships: Dictionary = data["ships"]
	for ship_id in BASE_SHIPS:
		if not saved_ships.has(ship_id) or not saved_ships[ship_id] is Dictionary:
			return _reject("missing_ship")
		var ship: Dictionary = saved_ships[ship_id]
		var base: Dictionary = BASE_SHIPS[ship_id]
		var ship_keys := ["id", "name", "class_id", "class_name", "hp", "max_hp", "durability_level", "weapon_level"]
		for key in ship_keys:
			if not ship.has(key):
				return _reject("missing_ship_field")
		for numeric_key in ["hp", "max_hp", "durability_level", "weapon_level"]:
			if not _is_whole_number(ship[numeric_key]):
				return _reject("invalid_ship_number")
		if str(ship["id"]) != ship_id or str(ship["class_id"]) != str(base["class_id"]):
			return _reject("invalid_ship_identity")
		for level_key in ["durability_level", "weapon_level"]:
			if int(ship[level_key]) < 0 or int(ship[level_key]) > 1:
				return _reject("invalid_upgrade_level")
		var expected_hp := int(base["hp"]) + 6 * int(ship["durability_level"])
		if int(ship["max_hp"]) != expected_hp:
			return _reject("invalid_ship_maximum")
		if int(ship["hp"]) < 0 or int(ship["hp"]) > expected_hp:
			return _reject("invalid_ship_current")
	return {"ok": true}


func _module_name(module_id: String) -> String:
	return {"durability": "耐久", "weapon": "武备"}.get(module_id, module_id)


func _is_whole_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_equal_approx(float(value), round(float(value)))


func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
