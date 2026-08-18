extends SceneTree
# CHG-20260818：经济舰队 → 海战舰队映射闭环（类型 / 装备 / 数量上限）。
# 玩家自由模式舰队 = economy_state 拥有舰，映射为海战 ShipState（海战 ShipDefinition 数值 + economy 装备）；
# 出战数量按活动预设（默认 = 拥有数量，预设上限 = 拥有数量，超限回落默认）。

var failures: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var preset_path := ProjectSettings.globalize_path("user://fleet_presets_mapping_test.json")
	# 清空预设库 → 无活动预设 → 默认全经济舰出战。
	_write_store(preset_path, "", {})

	var scene: PackedScene = load("res://scenes/naval/NavalDemo.tscn")
	if scene == null:
		push_error("FAIL: NavalDemo.tscn missing")
		quit(1)
		return
	var demo: Node = scene.instantiate()
	root.add_child(demo)
	await process_frame
	var deploy: Node = demo.get_node_or_null("Deployment")
	if deploy == null:
		push_error("FAIL: Deployment node missing")
		quit(1)
		return
	deploy.call("UseFleetPresetsPathForTest", preset_path)
	deploy.call("RebuildBattleForTest", 7)
	await process_frame

	# ---- 阶段一：默认映射 / 装备 / 数量 ----
	_expect(deploy.PlayerShipCount() == 5 and deploy.EnemyShipCount() == 4, "经济舰队默认 5 舰出战，敌方保持 4 舰")
	_expect(deploy.PlayerFleetCount() == 5, "默认出战数量 = 拥有数量")
	var expected := {
		"p1": {"type": "frigate",  "hp": 200,  "armor": 1, "weapons": {"bombardment": 1}, "skills": {"chain_shot": 1}},
		"p2": {"type": "flagship", "hp": 100,  "armor": 2, "weapons": {"cannon": 2},      "skills": {"fire_oil": 1}},
		"p3": {"type": "merchant", "hp": 1000, "armor": 3, "weapons": {"ram": 1},         "skills": {"damage_control": 1}},
		"p4": {"type": "frigate",  "hp": 200,  "armor": 1, "weapons": {"bombardment": 1}, "skills": {"chain_shot": 1}},
		"p5": {"type": "flagship", "hp": 100,  "armor": 2, "weapons": {"cannon": 2},      "skills": {"fire_oil": 1}},
	}
	for ship_id: String in expected:
		var exp: Dictionary = expected[ship_id]
		_expect(deploy.PlayerShipType(ship_id) == exp["type"], "%s 舰型映射应为 %s，实得 %s" % [ship_id, exp["type"], deploy.PlayerShipType(ship_id)])
		_expect(deploy.ShipHitPoints(ship_id) == exp["hp"], "%s 耐久应取海战定义 %d" % [ship_id, exp["hp"]])
		_expect(deploy.ShipArmorLevel(ship_id) == exp["armor"], "%s 护甲应取经济装备 %d" % [ship_id, exp["armor"]])
		for wid: String in exp["weapons"]:
			_expect(deploy.ShipWeaponCount(ship_id, wid) == exp["weapons"][wid], "%s 武器 %s 应=%d" % [ship_id, wid, exp["weapons"][wid]])
		for sid: String in exp["skills"]:
			_expect(deploy.ShipSkillSlotCount(ship_id, sid) == exp["skills"][sid], "%s 技能 %s 应=%d" % [ship_id, sid, exp["skills"][sid]])

	# ---- 阶段二：合法子集预设 → 出战数量按预设（≤ 拥有数），装备按预设覆盖经济默认 ----
	_write_store(preset_path, "单旗舰", {"单旗舰": [
		{"ShipTypeId": "cannon_warship", "Equipment": {"Weapons": {"cannon": 1}, "Skills": {"fire_oil": 1}, "ArmorLevel": 2}},
	]})
	deploy.call("UseFleetPresetsPathForTest", preset_path)
	deploy.call("RebuildBattleForTest", 7)
	await process_frame
	_expect(deploy.PlayerShipCount() == 1, "合法子集预设应只出战 1 舰，实得 %d" % deploy.PlayerShipCount())
	_expect(deploy.PlayerShipType("p1") == "flagship", "预设首舰应为第一艘 cannon_warship → flagship")
	_expect(deploy.ShipWeaponCount("p1", "cannon") == 1, "预设装备应覆盖经济默认（cannon:1），实得 %d" % deploy.ShipWeaponCount("p1", "cannon"))
	_expect(deploy.ShipSkillSlotCount("p1", "fire_oil") == 1, "预设技能应保留（fire_oil:1）")
	_expect(deploy.ShipArmorLevel("p1") == 2, "预设护甲应为 2")

	# ---- 阶段三：请求数量超过拥有数 → 回落全部拥有舰（上限 = 拥有数量） ----
	_write_store(preset_path, "超额", {"超额": [
		{"ShipTypeId": "cannon_warship", "Equipment": {"Weapons": {"cannon": 2}, "Skills": {"fire_oil": 1}, "ArmorLevel": 2}},
		{"ShipTypeId": "cannon_warship", "Equipment": {"Weapons": {"cannon": 2}, "Skills": {"fire_oil": 1}, "ArmorLevel": 2}},
		{"ShipTypeId": "cannon_warship", "Equipment": {"Weapons": {"cannon": 2}, "Skills": {"fire_oil": 1}, "ArmorLevel": 2}},
	]})
	deploy.call("UseFleetPresetsPathForTest", preset_path)
	deploy.call("RebuildBattleForTest", 7)
	await process_frame
	_expect(deploy.PlayerShipCount() == 5, "预设请求 3 旗舰但仅拥有 2 → 应回落全部拥有舰（5），实得 %d" % deploy.PlayerShipCount())
	_expect(deploy.PlayerShipType("p2") == "flagship" and deploy.PlayerShipType("p3") == "merchant", "回落后保持默认经济舰队序列")

	# 清理测试文件
	if FileAccess.file_exists("user://fleet_presets_mapping_test.json"):
		DirAccess.remove_absolute(preset_path)
	if failures.is_empty():
		print("PASS: economy fleet mapping")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: " + failure)
	quit(1)


# 写预设文件（schema 与 C# FleetPresetStore / GDScript ship_screen 共用：ActivePreset + Presets[]）。
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
