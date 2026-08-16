class_name EconomyState
extends RefCounted

const CATALOG := preload("res://scripts/economy/item_catalog.gd")
const FLEET_LIMIT := 10


static func make_default() -> Dictionary:
	return {
		"pay": 800,
		"items": {"wood": 30, "ironstone": 20},
		"blueprints": [],
		"ships": [
			_make_ship("ship_001", "patrol_boat"),
			_make_ship("ship_002", "cannon_warship"),
			_make_ship("ship_003", "escort_junk"),
		],
		"next_ship_id": 4,
	}


static func normalize(value: Variant) -> Dictionary:
	if not value is Dictionary or value.is_empty():
		return make_default()
	var state := make_default()
	state["pay"] = maxi(0, int(value.get("pay", state["pay"])))
	state["items"] = {}
	var raw_items = value.get("items", {})
	if raw_items is Dictionary:
		for raw_id in raw_items:
			var item_id := str(raw_id)
			var amount := maxi(0, int(raw_items[raw_id]))
			if amount > 0 and not CATALOG.item(item_id).is_empty():
				state["items"][item_id] = amount
	var blueprints: Array = []
	var raw_blueprints = value.get("blueprints", [])
	if raw_blueprints is Array:
		for raw_id in raw_blueprints:
			var ship_type_id := str(raw_id)
			if not CATALOG.ship(ship_type_id).is_empty() and ship_type_id not in blueprints:
				blueprints.append(ship_type_id)
	state["blueprints"] = blueprints
	var ships: Array = []
	var raw_ships = value.get("ships", [])
	if raw_ships is Array:
		for raw_ship in raw_ships:
			if raw_ship is Dictionary and ships.size() < FLEET_LIMIT:
				var type_id := str(raw_ship.get("type_id", ""))
				var definition := CATALOG.ship(type_id)
				var ship_id := str(raw_ship.get("id", ""))
				if not definition.is_empty() and not ship_id.is_empty():
					var max_hp := int(definition["max_hp"])
					ships.append({"id": ship_id, "type_id": type_id, "current_hp": max_hp, "max_hp": max_hp})
	if ships.is_empty():
		ships = (make_default()["ships"] as Array).duplicate(true)
	state["ships"] = ships
	state["next_ship_id"] = maxi(2, int(value.get("next_ship_id", ships.size() + 1)))
	return state


static func add_item(state: Dictionary, item_id: String, amount: int) -> bool:
	if amount <= 0 or CATALOG.item(item_id).is_empty():
		return false
	var items: Dictionary = state["items"]
	items[item_id] = int(items.get(item_id, 0)) + amount
	return true


static func remove_item(state: Dictionary, item_id: String, amount: int) -> bool:
	if amount <= 0:
		return false
	var items: Dictionary = state["items"]
	if int(items.get(item_id, 0)) < amount:
		return false
	var remaining := int(items[item_id]) - amount
	if remaining == 0:
		items.erase(item_id)
	else:
		items[item_id] = remaining
	return true


static func _make_ship(ship_id: String, type_id: String) -> Dictionary:
	var max_hp := int(CATALOG.ship(type_id).get("max_hp", 1))
	return {"id": ship_id, "type_id": type_id, "current_hp": max_hp, "max_hp": max_hp}
