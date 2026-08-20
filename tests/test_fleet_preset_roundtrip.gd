extends SceneTree
# CHG-20260818：舰队预设保存/列表/载入/删除往返一致 + 与海战布阵共享 user:// JSON schema 的跨语言闭环。
# 入口在 ship_screen：GDScript 侧重写（保存/载入/删除 + 活动预设），C# 侧重读（布阵装配）。

const PRESET_REL := "user://fleet_presets_roundtrip_test.json"

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var preset_path := ProjectSettings.globalize_path(PRESET_REL)
	if FileAccess.file_exists(PRESET_REL):
		DirAccess.remove_absolute(preset_path)

	# ---- 阶段一：ship_screen 预设保存/列表/载入/删除 往返 ----
	var screen_scene: PackedScene = load("res://scenes/ui/ship_screen.tscn")
	if screen_scene == null:
		push_error("FAIL: ship_screen.tscn missing")
		quit(1)
		return
	var screen: Control = screen_scene.instantiate()
	root.add_child(screen)
	screen.fleet_preset_path_override = PRESET_REL
	screen.call("show_screen")
	await process_frame

	_expect(screen.call("save_fleet_preset_for_test", "远征一"), "保存预设「远征一」应成功")
	_expect(screen.call("fleet_preset_names_for_test") == ["远征一"], "保存后预设列表应为 [远征一]")
	var preset_ships: Array = screen.get("_ships")
	_expect(preset_ships.size() == 5, "默认经济舰队应为 5 艘")

	_expect(screen.call("save_fleet_preset_for_test", "远征二"), "保存预设「远征二」应成功")
	_expect(screen.call("fleet_preset_names_for_test").size() == 2, "两个预设应并列")
	_expect(screen.call("load_fleet_preset_for_test", "远征一"), "载入「远征一」应成功")
	_expect(screen.call("active_fleet_preset_for_test") == "远征一", "载入后活动预设 = 远征一")

	_expect(screen.call("delete_fleet_preset_for_test", "远征二"), "删除「远征二」应成功")
	_expect(screen.call("fleet_preset_names_for_test") == ["远征一"], "删除后仅剩 [远征一]")
	_expect(screen.call("delete_fleet_preset_for_test", "远征一"), "删除「远征一」应成功")
	_expect(screen.call("fleet_preset_names_for_test").is_empty(), "全部删除后预设列表应为空")
	_expect(screen.call("active_fleet_preset_for_test") == "", "删除活动预设后活动标记应清除")

	# ---- 阶段二：ship_screen 写入的 JSON 内容（共享 schema 的写侧） ----
	_expect(screen.call("save_fleet_preset_for_test", "巡航"), "保存预设「巡航」应成功")
	var store := _read_store(preset_path)
	# 保存不改活动预设（「载入」才设置）；此前活动预设「远征一」已删除 → ActivePreset 应为空。
	_expect(store["active"] == "", "保存操作不应改写 ActivePreset（当前 %s）" % store["active"])
	var presets: Dictionary = store["presets"]
	_expect(presets.has("巡航"), "JSON 应含预设「巡航」")
	var cruise_ships: Array = presets["巡航"]
	_expect(cruise_ships.size() == preset_ships.size(), "JSON 预设舰数应与当前舰队一致")
	var first: Dictionary = cruise_ships[0]
	_expect(str(first.get("ShipTypeId", "")) == "patrol_boat", "预设首舰 ShipTypeId 应为 patrol_boat")
	var equipment: Dictionary = first.get("Equipment", {})
	_expect((equipment.get("Weapons", {}) as Dictionary).get("bombardment", 0) == 1, "预设装备 weapons.bombardment 应写入")
	_expect((equipment.get("Skills", {}) as Dictionary).get("chain_shot", 0) == 1, "预设装备 skills.chain_shot 应写入")
	_expect(int(equipment.get("ArmorLevel", 0)) == 1, "预设装备 armor_level 应写入")

	# ---- 阶段三：海战布阵消费同一文件（共享 schema 的读侧）——子集预设 → 出战数量与装备按预设 ----
	var subset := {
		"轻巡": [
			{"ShipTypeId": "patrol_boat", "Equipment": {"Weapons": {"ram": 1}, "Skills": {"damage_control": 1}, "ArmorLevel": 3}},
		],
	}
	_write_store(preset_path, "轻巡", subset)
	var scene: PackedScene = load("res://scenes/naval/NavalDemo.tscn")
	if scene == null:
		push_error("FAIL: NavalDemo.tscn missing")
		quit(1)
		return
	var demo: Node = scene.instantiate()
	root.add_child(demo)
	await process_frame
	var deploy: Node = demo.get_node_or_null("Deployment")
	_expect(deploy != null, "Deployment 节点应存在")
	if deploy != null:
		deploy.call("UseFleetPresetsPathForTest", preset_path)
		deploy.call("RebuildBattleForTest", 7)
		await process_frame
		_expect(deploy.PlayerShipCount() == 1, "海战应按活动预设出战 1 舰，实得 %d" % deploy.PlayerShipCount())
		_expect(deploy.PlayerShipType("p1") == "frigate", "预设 ShipTypeId=patrol_boat 应映射为海战护卫舰")
		_expect(deploy.ShipWeaponCount("p1", "ram") == 1, "海战武器应按预设装载（ram:1），实得 %d" % deploy.ShipWeaponCount("p1", "ram"))
		_expect(deploy.ShipSkillSlotCount("p1", "damage_control") == 1, "海战技能应按预设装载（damage_control:1）")
		_expect(deploy.ShipArmorLevel("p1") == 3, "海战护甲应按预设（3）")
		demo.queue_free()

	screen.queue_free()
	await process_frame
	if FileAccess.file_exists(PRESET_REL):
		DirAccess.remove_absolute(preset_path)
	if failures.is_empty():
		print("PASS: fleet preset roundtrip")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(1)


# 读取预设文件 → {presets: {名: Ships数组}, active: 活动预设名}。
func _read_store(path: String) -> Dictionary:
	var presets := {}
	var active := ""
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			active = str((parsed as Dictionary).get("ActivePreset", ""))
			var raw_presets = (parsed as Dictionary).get("Presets", [])
			if raw_presets is Array:
				for entry in raw_presets:
					if entry is Dictionary:
						var name := str((entry as Dictionary).get("Name", ""))
						var ships = (entry as Dictionary).get("Ships", [])
						if not name.is_empty() and ships is Array and not (ships as Array).is_empty():
							presets[name] = ships
	return {"presets": presets, "active": active}


# 写预设文件（schema 与 C# FleetPresetStore / GDScript ship_screen 共用）。
func _write_store(path: String, active: String, presets: Dictionary) -> void:
	var payload := {"ActivePreset": active, "Presets": []}
	for name in presets:
		payload["Presets"].append({"Name": name, "Ships": presets[name]})
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(payload, "\t"))


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
