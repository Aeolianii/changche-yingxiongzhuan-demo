extends SceneTree

# CHG-20260819（S-2 海面接入）：讨伐战（海怪/营寨）请求 → NavalDemo 集成冒烟——场景根写讨伐请求 meta 后，
# NavalDeploymentController 消费并经 HuntEncounterGenerator.CreateStage 组装 hunt_stage 固定遭遇、
# 登记讨伐会话；返回上下文保留发起方字段并补结算结果。headless 运行：
# godot --headless --script res://tests/test_naval_hunt_request.gd

const NAVAL_SCENE := preload("res://scenes/naval/NavalDemo.tscn")
const REQUEST_META := "sea_hunt_battle_request"
const RETURN_META := "sea_hunt_battle_return_context"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	root.remove_meta(REQUEST_META)
	root.remove_meta(RETURN_META)
	root.set_meta(REQUEST_META, {
		"stage_id": "hunt_stage3",
		"player_position": [4380.0, 2460.0],
		"lunar_day": 3.0,
	})
	var demo := NAVAL_SCENE.instantiate()
	root.add_child(demo)
	current_scene = demo
	await process_frame
	await physics_frame

	var deploy := demo.get_node("Deployment")
	var grid := demo.get_node("Deployment/DeployGrid")
	var controller := demo.get_node("Battle/BattleController")
	_check(bool(controller.call("HuntBattleActive")), "The hunt request meta must activate the hunt battle session.")
	_check(str(controller.call("HuntBattleStageId")) == "hunt_stage3", "The hunt session must carry the stage id (expected hunt_stage3).")
	_check(bool(deploy.call("RandomEncounterActive")), "The hunt battle must build a random encounter.")
	_check(str(deploy.call("RandomEncounterEnemyLabel")) == "倭寇大本营", "The encounter must resolve the wokou stronghold enemy config.")
	_check(deploy.call("RandomEncounterPlayerFleetCount") > 0, "The encounter must carry a player fleet.")
	_check(grid.call("TerrainStampCount") == 1, "The final hunt map must render only the central-camp terrain stamp.")
	_check(grid.call("TerrainStampCoveredCellCount") == 81, "The central-camp terrain stamp must cover 9x9 cells.")
	_check(grid.call("UnstampedNonWaterCellCount") == 0, "All cells outside the central camp must remain open water.")
	_check(bool(grid.call("TerrainStampTexturesReady")), "The central-camp terrain texture must be imported and loadable.")
	_check(deploy.call("ShipOccupiedCellCount", "e1") == 8, "The citadel must occupy 2x4 logical cells.")
	_check(deploy.call("BowX", "e1") == 21 and deploy.call("BowY", "e1") == 7, "The citadel must occupy the centered vertical enemy-zone slot.")
	for i in range(4):
		var turret_id := "e%d" % (i + 2)
		var expected_x := 21 + i % 2
		var expected_y := 6 if i < 2 else 11
		_check(deploy.call("BowX", turret_id) == expected_x and deploy.call("BowY", turret_id) == expected_y, "The four turrets must be paired symmetrically above and below the citadel.")
	var citadel_sprite := load("res://assets/naval/battle/ships/enemy_citadel_vertical_v1.png") as Texture2D
	_check(citadel_sprite != null and citadel_sprite.get_height() > citadel_sprite.get_width() * 1.8, "The citadel sprite must have a vertical 2x4 silhouette.")
	var expected_center: Vector2 = deploy.call("CellToWorld", 21, 8) + Vector2(13, 13)
	_check((Vector2(deploy.call("ShipViewPosX", "e1"), deploy.call("ShipViewPosY", "e1")) - expected_center).length() < 0.5, "The citadel sprite must be centered on its 2x4 footprint.")
	if DisplayServer.get_name() != "headless":
		grid.call("FocusCameraOnTerrainStamp", "hunt_stage3_central_camp_v1")
		await process_frame
		await RenderingServer.frame_post_draw
		var preview_path := "res://.godot/hunt_stage3_central_camp_preview.png"
		var preview_error := root.get_texture().get_image().save_png(preview_path)
		_check(preview_error == OK, "The final hunt terrain preview screenshot must be writable.")
		demo.get_node("Camera2D").position = deploy.call("CellToWorld", 21, 8)
		await RenderingServer.frame_post_draw
		var defense_preview_error := root.get_texture().get_image().save_png("res://.godot/hunt_stage3_defense_preview.png")
		_check(defense_preview_error == OK, "The final hunt defense preview screenshot must be writable.")

	# 返回上下文：保留发起方字段（玩家位置/农历日/阶段 id）并补结算结果（未结算默认平局 outcome=2）。
	var context: Dictionary = controller.call("BuildHuntReturnContext")
	_check(str(context.get("stage_id", "")) == "hunt_stage3", "Return context must carry the hunt stage id.")
	_check(context.get("player_position") is Array, "Return context must preserve the pre-battle player position.")
	_check(is_equal_approx(float(context.get("lunar_day", -1.0)), 3.0), "Return context must preserve the lunar day.")
	_check(int(context.get("outcome", -1)) == 2, "Return context must default outcome to draw before a result is set.")

	_finish(demo)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish(scene: Node) -> void:
	current_scene = null
	if is_instance_valid(scene):
		scene.queue_free()
	if failures.is_empty():
		print("Naval hunt request integration verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)
