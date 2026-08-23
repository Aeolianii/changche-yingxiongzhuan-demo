extends SceneTree

const NAVAL_SCENE := preload("res://scenes/naval/NavalDemo.tscn")
const CAPTURE_PATH := "res://.godot/naval_result_preview.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var demo := NAVAL_SCENE.instantiate()
	root.add_child(demo)
	await process_frame
	var deploy := demo.get_node("Deployment")
	var controller := demo.get_node("Battle/BattleController")
	var deployment_error: String = deploy.ConfirmDeployment()
	if not deployment_error.is_empty():
		_fail("Could not enter battle for result preview: %s" % deployment_error)
		return
	controller.ForceBattleEndForDemo()
	await process_frame

	var result_text: String = controller.ResultText()
	if not result_text.begins_with("我方胜利\n") or "金币结余" in result_text:
		_fail("Result title must be the centered outcome without a balance suffix: %s" % result_text)
		return
	if "移交" in result_text or "永久固定" in result_text or " · " in result_text:
		_fail("Loss summary still contains removed entries or dot separators: %s" % result_text)
		return
	for reward_name: String in ["银钱", "木材", "铁石", "织布"]:
		if reward_name not in result_text:
			_fail("Loot summary missing full reward name: %s" % reward_name)
			return
	var panel := demo.get_node_or_null("Battle/Hud/ResultPanel") as Panel
	var title := demo.get_node_or_null("Battle/Hud/ResultPanel/ResultTitle") as Label
	var return_button := demo.get_node_or_null("Battle/Hud/ResultPanel/ReturnToSeaButton") as Button
	if panel == null or title == null or return_button == null or not panel.visible:
		_fail("Result panel did not open with its title and return button.")
		return
	if title.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or return_button.text != "返回":
		_fail("Result title alignment or return-button copy is incorrect.")
		return
	if demo.get_node_or_null("Battle/Hud/ResultPanel/NewGameButton") != null:
		_fail("Result panel must not contain a replay button.")
		return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var capture_error := root.get_texture().get_image().save_png(CAPTURE_PATH)
		if capture_error != OK:
			_fail("Could not save result preview screenshot.")
			return
	print("Naval result UI verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
