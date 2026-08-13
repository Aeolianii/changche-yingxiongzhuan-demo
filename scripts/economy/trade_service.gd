class_name TradeService
extends RefCounted

const CATALOG := preload("res://scripts/economy/item_catalog.gd")
const ECONOMY := preload("res://scripts/economy/economy_state.gd")


static func buy_item(state: Dictionary, item_id: String, quantity: int) -> Dictionary:
	if quantity <= 0:
		return _fail("invalid_quantity")
	var definition := CATALOG.item(item_id)
	if definition.is_empty():
		return _fail("unknown_item")
	var price := int(definition.get("buy_price", 0))
	if price <= 0:
		return _fail("not_for_sale")
	var total := price * quantity
	if int(state.get("pay", 0)) < total:
		return _fail("insufficient_pay")
	state["pay"] = int(state["pay"]) - total
	ECONOMY.add_item(state, item_id, quantity)
	return {"ok": true, "cost": total}


static func sell_item(state: Dictionary, item_id: String, quantity: int) -> Dictionary:
	if quantity <= 0:
		return _fail("invalid_quantity")
	var definition := CATALOG.item(item_id)
	if definition.is_empty():
		return _fail("unknown_item")
	if int((state.get("items", {}) as Dictionary).get(item_id, 0)) < quantity:
		return _fail("insufficient_stock")
	var total := int(definition["sell_price"]) * quantity
	ECONOMY.remove_item(state, item_id, quantity)
	state["pay"] = int(state.get("pay", 0)) + total
	return {"ok": true, "income": total}


static func buy_blueprint(state: Dictionary, ship_type_id: String) -> Dictionary:
	var definition := CATALOG.ship(ship_type_id)
	if definition.is_empty():
		return _fail("unknown_ship_type")
	var blueprints: Array = state["blueprints"]
	if ship_type_id in blueprints:
		return _fail("already_owned")
	var price := int(definition["blueprint_price"])
	if int(state.get("pay", 0)) < price:
		return _fail("insufficient_pay")
	state["pay"] = int(state["pay"]) - price
	blueprints.append(ship_type_id)
	return {"ok": true, "cost": price}


static func build_ship(state: Dictionary, ship_type_id: String) -> Dictionary:
	var ships: Array = state["ships"]
	if ships.size() >= ECONOMY.FLEET_LIMIT:
		return _fail("fleet_full")
	var definition := CATALOG.ship(ship_type_id)
	if definition.is_empty():
		return _fail("unknown_ship_type")
	if ship_type_id not in (state["blueprints"] as Array):
		return _fail("blueprint_required")
	if int(state.get("pay", 0)) < int(definition["pay"]):
		return _fail("insufficient_pay")
	var items: Dictionary = state["items"]
	if int(items.get("wood", 0)) < int(definition["wood"]):
		return _fail("insufficient_wood")
	if int(items.get("ironstone", 0)) < int(definition["ironstone"]):
		return _fail("insufficient_ironstone")
	state["pay"] = int(state["pay"]) - int(definition["pay"])
	ECONOMY.remove_item(state, "wood", int(definition["wood"]))
	ECONOMY.remove_item(state, "ironstone", int(definition["ironstone"]))
	var next_id := int(state.get("next_ship_id", ships.size() + 1))
	var ship_id := "ship_%03d" % next_id
	var max_hp := int(definition["max_hp"])
	ships.append({"id": ship_id, "type_id": ship_type_id, "current_hp": max_hp, "max_hp": max_hp})
	state["next_ship_id"] = next_id + 1
	return {"ok": true, "ship_id": ship_id}


static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
