class_name EconomyState
extends RefCounted

const CATALOG := preload("res://scripts/economy/item_catalog.gd")
const WEAPON_IDS := ["ram", "bombardment", "cannon"]
const SKILL_IDS := ["chain_shot", "fire_oil", "damage_control", "mine"]
const SHIP_UPGRADE_RULES := {
	"hull": {"resource": "wood", "pay": 100, "material": 8},
	"weapon_slots": {"resource": "ironstone", "pay": 140, "material": 6},
	"skill_slots": {"resource": "ironstone", "pay": 120, "material": 5},
	"speed": {"resource": "canvas", "pay": 100, "material": 6},
}
const SHIP_UPGRADE_CAPS := {
	"patrol_boat": {"hull": 3, "weapon_slots": 3, "skill_slots": 3, "speed": 3},
	"cannon_warship": {"hull": 3, "weapon_slots": 3, "skill_slots": 3, "speed": 3},
	"escort_junk": {"hull": 3, "weapon_slots": 3, "skill_slots": 3, "speed": 3},
}


static func make_default() -> Dictionary:
	return {
		"pay": 800,
		"items": {"wood": 30, "ironstone": 20},
		"ship_upgrade_materials": {"canvas": 20},
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
	var raw_upgrade_materials = value.get("ship_upgrade_materials", state["ship_upgrade_materials"])
	state["ship_upgrade_materials"] = {"canvas": maxi(0, int((raw_upgrade_materials as Dictionary).get("canvas", 0)))} if raw_upgrade_materials is Dictionary else {"canvas": 0}
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
					var upgrades := _normalize_upgrades(raw_ship.get("upgrades", {}), type_id)
					var max_hp := _upgraded_max_hp(definition, int(upgrades["hull"]))
					var current_hp := clampi(int(raw_ship.get("current_hp", max_hp)), 0, max_hp)
					var effective_definition := _effective_definition(definition, upgrades)
					ships.append({
						"id": ship_id,
						"type_id": type_id,
						"current_hp": current_hp,
						"max_hp": max_hp,
						"upgrades": upgrades,
						"equipment": _normalize_equipment(raw_ship.get("equipment", {}), effective_definition, type_id),
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


static func ship_upgrade_cost(ship: Dictionary, project: String) -> Dictionary:
	var definition := CATALOG.ship(str(ship.get("type_id", "")))
	var rule := SHIP_UPGRADE_RULES.get(project, {}) as Dictionary
	if definition.is_empty() or rule.is_empty():
		return {}
	var type_id := str(ship.get("type_id", ""))
	var upgrades := _normalize_upgrades(ship.get("upgrades", {}), type_id)
	var current_level := int(upgrades.get(project, 0))
	var cap := int((SHIP_UPGRADE_CAPS.get(type_id, {}) as Dictionary).get(project, 0))
	var multiplier := current_level + 1
	return {
		"project": project,
		"level": current_level,
		"cap": cap,
		"pay": int(rule["pay"]) * multiplier,
		"resource": str(rule["resource"]),
		"material": int(rule["material"]) * multiplier,
	}


static func upgrade_ship(state: Dictionary, ship_id: String, project: String) -> Dictionary:
	for ship_value in state.get("ships", []):
		if not ship_value is Dictionary or str(ship_value.get("id", "")) != ship_id:
			continue
		var ship := ship_value as Dictionary
		var cost := ship_upgrade_cost(ship, project)
		if cost.is_empty():
			return {"ok": false, "reason": "unknown_upgrade"}
		if int(cost["level"]) >= int(cost["cap"]):
			return {"ok": false, "reason": "max_level"}
		if int(state.get("pay", 0)) < int(cost["pay"]):
			return {"ok": false, "reason": "insufficient_pay"}
		var resource_id := str(cost["resource"])
		var stock := int((state.get("ship_upgrade_materials", {}) as Dictionary).get(resource_id, 0)) if resource_id == "canvas" else int((state.get("items", {}) as Dictionary).get(resource_id, 0))
		if stock < int(cost["material"]):
			return {"ok": false, "reason": "insufficient_material"}
		state["pay"] = int(state["pay"]) - int(cost["pay"])
		if resource_id == "canvas":
			state["ship_upgrade_materials"]["canvas"] = stock - int(cost["material"])
		else:
			remove_item(state, resource_id, int(cost["material"]))
		var upgrades := _normalize_upgrades(ship.get("upgrades", {}), str(ship.get("type_id", "")))
		var previous_max_hp := int(ship.get("max_hp", 1))
		upgrades[project] = int(upgrades.get(project, 0)) + 1
		ship["upgrades"] = upgrades
		if project == "hull":
			var definition := CATALOG.ship(str(ship.get("type_id", "")))
			var upgraded_max_hp := _upgraded_max_hp(definition, int(upgrades["hull"]))
			ship["max_hp"] = upgraded_max_hp
			ship["current_hp"] = mini(upgraded_max_hp, int(ship.get("current_hp", previous_max_hp)) + upgraded_max_hp - previous_max_hp)
		return {"ok": true, "level": int(upgrades[project]), "project": project}
	return {"ok": false, "reason": "unknown_ship"}


static func adjust_ship_equipment(state: Dictionary, ship_id: String, category: String, equipment_id: String, delta: int) -> Dictionary:
	if delta != -1 and delta != 1:
		return {"ok": false, "reason": "invalid_delta"}
	for ship_value in state.get("ships", []):
		if not ship_value is Dictionary or str(ship_value.get("id", "")) != ship_id:
			continue
		var ship := ship_value as Dictionary
		var definition := _effective_definition(CATALOG.ship(str(ship.get("type_id", ""))), ship.get("upgrades", {}) as Dictionary)
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
		"upgrades": {"hull": 0, "weapon_slots": 0, "skill_slots": 0, "speed": 0},
		"equipment": _default_equipment(type_id),
	}


static func _normalize_upgrades(raw_value: Variant, type_id: String) -> Dictionary:
	var raw := raw_value as Dictionary if raw_value is Dictionary else {}
	var caps := SHIP_UPGRADE_CAPS.get(type_id, {}) as Dictionary
	var upgrades := {}
	for project in SHIP_UPGRADE_RULES:
		upgrades[project] = clampi(int(raw.get(project, 0)), 0, int(caps.get(project, 0)))
	return upgrades


static func _upgraded_max_hp(definition: Dictionary, hull_level: int) -> int:
	var base_hp := maxi(1, int(definition.get("max_hp", 1)))
	return roundi(float(base_hp) * (1.0 + 0.05 * hull_level))


static func _effective_definition(definition: Dictionary, upgrades: Dictionary) -> Dictionary:
	var effective := definition.duplicate(true)
	effective["weapon_slots"] = int(definition.get("weapon_slots", 0)) + int(upgrades.get("weapon_slots", 0))
	effective["skill_slots"] = int(definition.get("skill_slots", 0)) + int(upgrades.get("skill_slots", 0))
	effective["speed"] = int(definition.get("speed", 0)) + int(upgrades.get("speed", 0))
	return effective


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
