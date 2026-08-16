class_name EconomyState
extends RefCounted

const CATALOG := preload("res://scripts/economy/item_catalog.gd")
const WEAPON_IDS := ["ram", "bombardment", "cannon"]
const SKILL_IDS := ["chain_shot", "fire_oil", "damage_control", "mine"]


static func make_default() -> Dictionary:
	return {
		"pay": 800,
		"items": {"wood": 30, "ironstone": 20},
		"blueprints": [],
		"ships": [
			make_ship("ship_001", "patrol_boat", 42),
			make_ship("ship_002", "cannon_warship"),
			make_ship("ship_003", "escort_junk", 70),
			make_ship("ship_004", "patrol_boat"),
			make_ship("ship_005", "cannon_warship"),
		],
		"next_ship_id": 6,
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
			if raw_ship is Dictionary:
				var type_id := str(raw_ship.get("type_id", ""))
				var definition := CATALOG.ship(type_id)
				var ship_id := str(raw_ship.get("id", ""))
				if not definition.is_empty() and not ship_id.is_empty():
					var max_hp := int(definition["max_hp"])
					var current_hp := clampi(int(raw_ship.get("current_hp", max_hp)), 0, max_hp)
					ships.append({
						"id": ship_id,
						"type_id": type_id,
						"current_hp": current_hp,
						"max_hp": max_hp,
						"equipment": _normalize_equipment(raw_ship.get("equipment", {}), definition, type_id),
					})
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


static func repair_ship(state: Dictionary, ship_id: String) -> Dictionary:
	for ship_value in state.get("ships", []):
		if ship_value is Dictionary and str(ship_value.get("id", "")) == ship_id:
			var ship := ship_value as Dictionary
			var max_hp := maxi(1, int(ship.get("max_hp", 1)))
			if int(ship.get("current_hp", max_hp)) >= max_hp:
				return {"ok": false, "reason": "already_repaired"}
			ship["current_hp"] = max_hp
			return {"ok": true, "current_hp": max_hp}
	return {"ok": false, "reason": "unknown_ship"}


static func adjust_ship_equipment(state: Dictionary, ship_id: String, category: String, equipment_id: String, delta: int) -> Dictionary:
	if delta != -1 and delta != 1:
		return {"ok": false, "reason": "invalid_delta"}
	for ship_value in state.get("ships", []):
		if not ship_value is Dictionary or str(ship_value.get("id", "")) != ship_id:
			continue
		var ship := ship_value as Dictionary
		var definition := CATALOG.ship(str(ship.get("type_id", "")))
		var equipment := ship.get("equipment", {}) as Dictionary
		if category == "armor":
			var armor_cap := int(definition.get("armor_slots", 0))
			var armor_level := int(equipment.get("armor_level", 0))
			if delta > 0 and armor_level >= armor_cap:
				return {"ok": false, "reason": "slots_full"}
			if delta < 0 and armor_level <= 0:
				return {"ok": false, "reason": "none_equipped"}
			equipment["armor_level"] = armor_level + delta
			ship["equipment"] = equipment
			return {"ok": true}
		var allowed_ids: Array = WEAPON_IDS if category == "weapons" else SKILL_IDS if category == "skills" else []
		if equipment_id not in allowed_ids:
			return {"ok": false, "reason": "unknown_equipment"}
		var entries := equipment.get(category, {}) as Dictionary
		var current := int(entries.get(equipment_id, 0))
		var used := 0
		for count in entries.values():
			used += int(count)
		var cap_key := "weapon_slots" if category == "weapons" else "skill_slots"
		var cap := int(definition.get(cap_key, 0))
		if delta > 0:
			if used >= cap or (category == "weapons" and equipment_id == "ram" and current >= 1):
				return {"ok": false, "reason": "slots_full"}
			entries[equipment_id] = current + 1
		elif current <= 0:
			return {"ok": false, "reason": "none_equipped"}
		elif current == 1:
			entries.erase(equipment_id)
		else:
			entries[equipment_id] = current - 1
		equipment[category] = entries
		ship["equipment"] = equipment
		return {"ok": true}
	return {"ok": false, "reason": "unknown_ship"}


static func make_ship(ship_id: String, type_id: String, current_hp := -1) -> Dictionary:
	var max_hp := int(CATALOG.ship(type_id).get("max_hp", 1))
	return {
		"id": ship_id,
		"type_id": type_id,
		"current_hp": max_hp if current_hp < 0 else clampi(current_hp, 0, max_hp),
		"max_hp": max_hp,
		"equipment": _default_equipment(type_id),
	}


static func _normalize_equipment(raw_value: Variant, definition: Dictionary, type_id: String) -> Dictionary:
	var fallback := _default_equipment(type_id)
	if not raw_value is Dictionary:
		return fallback
	var raw := raw_value as Dictionary
	var normalized := {"weapons": {}, "skills": {}, "armor_level": clampi(int(raw.get("armor_level", fallback["armor_level"])), 0, int(definition.get("armor_slots", 0)))}
	for category in ["weapons", "skills"]:
		var allowed_ids: Array = WEAPON_IDS if category == "weapons" else SKILL_IDS
		var cap_key := "weapon_slots" if category == "weapons" else "skill_slots"
		var remaining := int(definition.get(cap_key, 0))
		var raw_entries = raw.get(category, fallback[category])
		if raw_entries is Dictionary:
			for equipment_id in allowed_ids:
				var count := mini(remaining, maxi(0, int(raw_entries.get(equipment_id, 0))))
				if category == "weapons" and equipment_id == "ram":
					count = mini(count, 1)
				if count > 0:
					normalized[category][equipment_id] = count
					remaining -= count
	return normalized


static func _default_equipment(type_id: String) -> Dictionary:
	match type_id:
		"patrol_boat":
			return {"weapons": {"bombardment": 1}, "skills": {"chain_shot": 1}, "armor_level": 1}
		"cannon_warship":
			return {"weapons": {"cannon": 2}, "skills": {"fire_oil": 1}, "armor_level": 2}
		"escort_junk":
			return {"weapons": {"ram": 1}, "skills": {"damage_control": 1}, "armor_level": 3}
	return {"weapons": {}, "skills": {}, "armor_level": 0}
