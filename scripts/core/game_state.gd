extends Node

const FUBO_SAVE_STATE := preload("res://scripts/fubo_guling/fubo_save_state.gd")
const ECONOMY := preload("res://scripts/economy/economy_state.gd")
const TRADE := preload("res://scripts/economy/trade_service.gd")
const SAVE_VERSION := 2
const DEFAULT_SAVE_PATH := "user://main_flow_save.json"
const FUBO_SIDE_QUEST_ID := &"fubo_guling"
const ALLOWED_SCENES := [
	"res://scenes/palace/palace_demo.tscn",
	"res://scenes/Scene2.tscn",
	"res://scenes/sea_overworld/sea_overworld.tscn",
	"res://scenes/fubo_guling/fubo_guling.tscn",
	"res://scenes/yuehuan_merchant_harbor/yuehuan_merchant_harbor.tscn",
]

var save_path_override := ""
var _pending_scene_path := ""
var _pending_scene_state: Dictionary = {}
var _world_state: Dictionary = {}


func save_game(scene_path: String, scene_state: Dictionary) -> Dictionary:
	if scene_path not in ALLOWED_SCENES:
		return _reject("unsupported_scene")
	var data := {
		"version": SAVE_VERSION,
		"saved_at_unix": int(Time.get_unix_time_from_system()),
		"scene_path": scene_path,
		"scene_state": scene_state.duplicate(true),
		"world_state": _world_state.duplicate(true),
	}
	var validation := _validate_save_data(data)
	if not validation.get("ok", false):
		return validation
	var write_result := _write_save_data(data)
	if not write_result.get("ok", false):
		return write_result
	return {
		"ok": true,
		"scene_path": scene_path,
		"saved_at_unix": data["saved_at_unix"],
	}


func load_game() -> Dictionary:
	clear_pending_scene_state()
	var save_path := _effective_save_path()
	if not FileAccess.file_exists(save_path):
		return _reject("missing_save")
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return _reject("read_failed")
	var json := JSON.new()
	var parse_error := json.parse(file.get_as_text())
	file.close()
	if parse_error != OK:
		return _reject("invalid_json")
	var parsed = json.data
	if not parsed is Dictionary:
		return _reject("invalid_json")
	var validation := _validate_save_data(parsed)
	if not validation.get("ok", false):
		return validation
	_pending_scene_path = str(parsed["scene_path"])
	_pending_scene_state = (parsed["scene_state"] as Dictionary).duplicate(true)
	_world_state = (parsed.get("world_state", {}) as Dictionary).duplicate(true)
	return {
		"ok": true,
		"scene_path": _pending_scene_path,
		"scene_state": _pending_scene_state.duplicate(true),
	}


func consume_pending_scene_state(scene_path: String) -> Dictionary:
	if scene_path != _pending_scene_path:
		return {}
	var restored := _pending_scene_state.duplicate(true)
	_pending_scene_path = ""
	_pending_scene_state.clear()
	return restored


func clear_pending_scene_state() -> void:
	_pending_scene_path = ""
	_pending_scene_state.clear()


func set_sea_fog_state(state: Dictionary) -> void:
	if state.is_empty():
		_world_state.erase("sea_fog")
		return
	_world_state["sea_fog"] = state.duplicate(true)


func get_sea_fog_state() -> Dictionary:
	var state = _world_state.get("sea_fog", {})
	return (state as Dictionary).duplicate(true) if state is Dictionary else {}


func set_tea_merchant_event_completed(completed: bool) -> void:
	if completed:
		_world_state["tea_merchant_event_completed"] = true
	else:
		_world_state.erase("tea_merchant_event_completed")


func is_tea_merchant_event_completed() -> bool:
	return bool(_world_state.get("tea_merchant_event_completed", false))


func set_sea_main_quest_state(exploration_stage: int, wokou_warning_acknowledged: bool, wokou_battle_completed: bool) -> void:
	var completed := wokou_battle_completed
	_world_state["sea_main_quest"] = {
		"exploration_stage": clampi(exploration_stage, 0, 4),
		"wokou_warning_acknowledged": wokou_warning_acknowledged or completed,
		"wokou_battle_completed": completed,
	}


func get_sea_main_quest_state() -> Dictionary:
	var raw_state: Variant = _world_state.get("sea_main_quest", {})
	var state := (raw_state as Dictionary) if raw_state is Dictionary else {}
	var completed := bool(state.get("wokou_battle_completed", false))
	return {
		"exploration_stage": clampi(int(state.get("exploration_stage", 0)), 0, 4),
		"wokou_warning_acknowledged": bool(state.get("wokou_warning_acknowledged", false)) or completed,
		"wokou_battle_completed": completed,
	}


func accept_fubo_side_quest() -> void:
	var state := get_fubo_side_quest_state()
	state["accepted"] = true
	_world_state["fubo_side_quest"] = state
	_world_state["tracked_side_quest"] = String(FUBO_SIDE_QUEST_ID)


func has_fubo_side_quest() -> bool:
	return bool(get_fubo_side_quest_state().get("accepted", false))


func set_fubo_side_quest_progress(progress_stage: int, keeper_intro_completed: bool) -> void:
	var state := get_fubo_side_quest_state()
	var normalized_stage := clampi(progress_stage, 0, 4)
	state["accepted"] = true
	state["progress_stage"] = normalized_stage
	state["keeper_intro_completed"] = keeper_intro_completed
	state["completed"] = normalized_stage >= 4
	_world_state["fubo_side_quest"] = state
	if state["completed"] and StringName(str(_world_state.get("tracked_side_quest", ""))) == FUBO_SIDE_QUEST_ID:
		_world_state["tracked_side_quest"] = ""


func get_fubo_side_quest_state() -> Dictionary:
	var raw_state: Variant = _world_state.get("fubo_side_quest", {})
	var state := (raw_state as Dictionary).duplicate(true) if raw_state is Dictionary else {}
	var progress_stage := clampi(int(state.get("progress_stage", 0)), 0, 4)
	return {
		"accepted": bool(state.get("accepted", false)),
		"progress_stage": progress_stage,
		"keeper_intro_completed": bool(state.get("keeper_intro_completed", false)),
		"completed": bool(state.get("completed", progress_stage >= 4)) or progress_stage >= 4,
	}


func set_tracked_side_quest(quest_id: StringName) -> void:
	if quest_id == FUBO_SIDE_QUEST_ID and bool(get_fubo_side_quest_state().get("completed", false)):
		_world_state["tracked_side_quest"] = ""
		return
	_world_state["tracked_side_quest"] = String(quest_id)


func get_tracked_side_quest() -> StringName:
	var tracked_id := StringName(str(_world_state.get("tracked_side_quest", "")))
	if tracked_id == FUBO_SIDE_QUEST_ID and bool(get_fubo_side_quest_state().get("completed", false)):
		return &""
	return tracked_id


func reset_runtime_world_state() -> void:
	_world_state.clear()


func get_economy_state() -> Dictionary:
	_ensure_economy()
	return (_world_state["economy"] as Dictionary).duplicate(true)


func add_economy_item(item_id: String, amount: int) -> bool:
	_ensure_economy()
	return ECONOMY.add_item(_world_state["economy"], item_id, amount)


func add_military_pay(amount: int) -> bool:
	if amount <= 0:
		return false
	_ensure_economy()
	_world_state["economy"]["pay"] = int(_world_state["economy"]["pay"]) + amount
	return true


func spend_military_pay(amount: int) -> bool:
	if amount <= 0:
		return false
	_ensure_economy()
	if int(_world_state["economy"]["pay"]) < amount:
		return false
	_world_state["economy"]["pay"] = int(_world_state["economy"]["pay"]) - amount
	return true


func buy_economy_item(item_id: String, quantity: int) -> Dictionary:
	_ensure_economy()
	return TRADE.buy_item(_world_state["economy"], item_id, quantity)


func sell_economy_item(item_id: String, quantity: int) -> Dictionary:
	_ensure_economy()
	return TRADE.sell_item(_world_state["economy"], item_id, quantity)


func buy_economy_blueprint(ship_type_id: String) -> Dictionary:
	_ensure_economy()
	return TRADE.buy_blueprint(_world_state["economy"], ship_type_id)


func build_economy_ship(ship_type_id: String) -> Dictionary:
	_ensure_economy()
	return TRADE.build_ship(_world_state["economy"], ship_type_id)


func repair_economy_ship(ship_id: String) -> Dictionary:
	_ensure_economy()
	return ECONOMY.repair_ship(_world_state["economy"], ship_id)


func upgrade_economy_ship(ship_id: String, project: String) -> Dictionary:
	_ensure_economy()
	return ECONOMY.upgrade_ship(_world_state["economy"], ship_id, project)


func adjust_economy_ship_equipment(ship_id: String, category: String, equipment_id: String, delta: int) -> Dictionary:
	_ensure_economy()
	return ECONOMY.adjust_ship_equipment(_world_state["economy"], ship_id, category, equipment_id, delta)


# —— CHG-20260819（F-1 讨伐饰品）：饰品背包/装备桥接 ——

# 获得讨伐饰品（写 economy_state.accessories.owned，去重）。
func add_economy_accessory(accessory_id: String) -> bool:
	_ensure_economy()
	return ECONOMY.add_accessory(_world_state["economy"], accessory_id)


# 是否已获得某饰品。
func has_economy_accessory(accessory_id: String) -> bool:
	_ensure_economy()
	return ECONOMY.has_accessory(_world_state["economy"], accessory_id)


# 饰品装备到指定舰船（须已持有、舰船存在；重复装备自动迁移）。
func equip_economy_accessory(accessory_id: String, ship_id: String) -> Dictionary:
	_ensure_economy()
	return ECONOMY.equip_accessory(_world_state["economy"], accessory_id, ship_id)


# 卸下饰品（清除装备状态）。
func unequip_economy_accessory(accessory_id: String) -> bool:
	_ensure_economy()
	return ECONOMY.unequip_accessory(_world_state["economy"], accessory_id)


# 饰品当前装备到的舰船 id（未装备返回空串）。
func equipped_economy_accessory_ship(accessory_id: String) -> String:
	_ensure_economy()
	return ECONOMY.equipped_accessory_ship(_world_state["economy"], accessory_id)


# 已获得饰品 id 列表。
func owned_economy_accessories() -> Array:
	_ensure_economy()
	return ECONOMY.owned_accessories(_world_state["economy"])


# 已装备饰品 id → 舰船 id 映射。
func equipped_economy_accessories() -> Dictionary:
	_ensure_economy()
	return ECONOMY.equipped_accessories(_world_state["economy"])


func _ensure_economy() -> void:
	_world_state["economy"] = ECONOMY.normalize(_world_state.get("economy", {}))


func has_save() -> bool:
	return FileAccess.file_exists(_effective_save_path())


func error_message(reason: String) -> String:
	return {
		"missing_save": "尚未找到可读取的存档。",
		"read_failed": "无法读取存档文件。",
		"invalid_json": "存档内容已损坏。",
		"missing_field": "存档缺少必要数据。",
		"unsupported_version": "存档版本与当前游戏不兼容。",
		"invalid_timestamp": "存档时间数据无效。",
		"unsupported_scene": "存档记录了当前版本不支持的场景。",
		"invalid_scene_state": "存档中的场景进度无效。",
		"write_failed": "无法写入存档文件。",
		"replace_failed": "无法替换旧存档，请稍后重试。",
		"unstable_scene": "当前剧情状态不能保存，请先结束对白或过场。",
		"scene_change_failed": "存档已读取，但目标场景加载失败。",
	}.get(reason, "存档操作失败。")


func _write_save_data(data: Dictionary) -> Dictionary:
	var save_path := _effective_save_path()
	var temp_path := save_path + ".tmp"
	var backup_path := save_path + ".bak"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		return _reject("write_failed")
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()

	var temp_absolute := ProjectSettings.globalize_path(temp_path)
	var save_absolute := ProjectSettings.globalize_path(save_path)
	var backup_absolute := ProjectSettings.globalize_path(backup_path)
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	if FileAccess.file_exists(save_path):
		var backup_error := DirAccess.rename_absolute(save_absolute, backup_absolute)
		if backup_error != OK:
			DirAccess.remove_absolute(temp_absolute)
			return _reject("replace_failed")
	var replace_error := DirAccess.rename_absolute(temp_absolute, save_absolute)
	if replace_error != OK:
		if FileAccess.file_exists(backup_path):
			DirAccess.rename_absolute(backup_absolute, save_absolute)
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_absolute)
		return _reject("replace_failed")
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_absolute)
	return {"ok": true}


func _validate_save_data(data: Dictionary) -> Dictionary:
	for key in ["version", "saved_at_unix", "scene_path", "scene_state"]:
		if not data.has(key):
			return _reject("missing_field")
	if not _is_whole_number(data["version"]) or int(data["version"]) not in [1, SAVE_VERSION]:
		return _reject("unsupported_version")
	if not _is_whole_number(data["saved_at_unix"]) or int(data["saved_at_unix"]) < 0:
		return _reject("invalid_timestamp")
	if typeof(data["scene_path"]) != TYPE_STRING or str(data["scene_path"]) not in ALLOWED_SCENES:
		return _reject("unsupported_scene")
	if not data["scene_state"] is Dictionary:
		return _reject("invalid_scene_state")
	if data.has("world_state") and not data["world_state"] is Dictionary:
		return _reject("invalid_scene_state")
	if str(data["scene_path"]) == "res://scenes/fubo_guling/fubo_guling.tscn" and FUBO_SAVE_STATE.decode_snapshot(data["scene_state"]).is_empty():
		return _reject("invalid_scene_state")
	return {"ok": true}


func _effective_save_path() -> String:
	return save_path_override if not save_path_override.is_empty() else DEFAULT_SAVE_PATH


func _is_whole_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return is_finite(float(value)) and is_equal_approx(float(value), round(float(value)))


func _reject(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
