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
	var brush := demo.get_node_or_null("Battle/Hud/ResultPanel/ResultBrushBackdrop") as TextureRect
	var title := demo.get_node_or_null("Battle/Hud/ResultPanel/ResultTitle") as Label
	var victory_title := demo.get_node_or_null("Battle/Hud/ResultPanel/VictoryTitleImage") as TextureRect
	var return_button := demo.get_node_or_null("Battle/Hud/ResultPanel/ReturnToSeaButton") as Button
	if panel == null or title == null or return_button == null or not panel.visible:
		_fail("Result panel did not open with its title and return button.")
		return
	if brush == null or demo.get_node_or_null("Battle/Hud/ResultPanel/BackdropUpper") != null or demo.get_node_or_null("Battle/Hud/ResultPanel/BackdropLower") != null:
		_fail("Result details must use one unified wide brush backing instead of two stacked strokes.")
		return
	if brush.offset_left > -30.0 or brush.offset_right < 30.0 or brush.size.y < 200.0:
		_fail("The unified result brush must remain wide and tall enough to contain both detail sections.")
		return
	if title.horizontal_alignment != HORIZONTAL_ALIGNMENT_CENTER or return_button.text != "返回":
		_fail("Result title alignment or return-button copy is incorrect.")
		return
	if victory_title == null or not victory_title.visible or title.visible:
		_fail("Player victory must replace the ordinary title label with the generated calligraphy image.")
		return
	if victory_title.texture == null or not victory_title.texture.resource_path.ends_with("battle_result_victory_calligraphy_v1.png"):
		_fail("Victory calligraphy must use the generated transparent title asset.")
		return
	if victory_title.size.x < 475.0 or victory_title.size.y < 90.0 or victory_title.offset_bottom >= brush.offset_top:
		_fail("Victory calligraphy must be enlarged by about twenty percent and sit fully above the detail brush.")
		return
	var return_style := return_button.get_theme_stylebox("normal") as StyleBoxTexture
	if return_button.get_theme_font_size("font_size") < 24 or return_style == null or return_style.texture == null or not return_style.texture.resource_path.ends_with("level_select_return_brush.png"):
		_fail("Return must use larger text over the tutorial's small return brush backing.")
		return
	if return_button.anchor_top != 1.0 or return_button.offset_top < -62.0 or brush.position.y + brush.size.y >= return_button.position.y:
		_fail("Return button must sit below the unified detail brush without overlap.")
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
