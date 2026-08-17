extends SceneTree

const LEVEL_SELECT := preload("res://scenes/naval/LevelSelect.tscn")
const NAVAL_DEMO_PATH := "res://scenes/naval/NavalDemo.tscn"

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var select := LEVEL_SELECT.instantiate()
	root.add_child(select)
	current_scene = select
	await process_frame
	select.call("ResetProgressForTest")
	select.call("EnterLevel", "1-1")
	if not await _wait_for_scene(NAVAL_DEMO_PATH):
		_expect(false, "Tutorial level 1-1 did not open NavalDemo.")
		_finish()
		return

	var demo := current_scene
	var level_play := demo.get_node_or_null("LevelPlay")
	var controller := demo.get_node_or_null("Battle/BattleController")
	_expect(level_play != null and level_play.call("LevelMode"), "Tutorial hint layer must be active in level 1-1.")
	_expect(level_play.get_node_or_null("ObjectiveBar") == null, "Tutorial overlay must not keep the rectangular objective card.")
	_expect(level_play.call("HintUsesBrushTexture"), "Tutorial hint must use the generated dry-brush texture.")
	_expect(is_equal_approx(float(level_play.call("HintBarWidth")), 720.0), "Tutorial brush strip must expand by 20 percent to 720 px wide.")
	_expect(is_equal_approx(float(level_play.call("HintBarHeight")), 164.0), "Tutorial brush strip must expand by about 20 percent to 164 px high.")
	var hint_bar: Control = level_play.get_node("HintBar")
	var collapse_button: Control = level_play.get_node("CollapseHintBar")
	var hint_title: Control = level_play.get_node("HintBar/Box/Title")
	var hint_content: Control = level_play.get_node("HintBar/Box/Content")
	_expect(is_equal_approx(hint_bar.position.y, 90.0), "Tutorial brush must sit directly below the second top HUD line.")
	_expect(is_equal_approx(hint_bar.get_global_rect().get_center().x, 672.0), "Tutorial brush must be horizontally centered in the 1344 px reference viewport.")
	_expect(is_equal_approx(hint_title.get_global_rect().get_center().x, hint_bar.get_global_rect().get_center().x), "Tutorial title must center independently of the collapse button.")
	_expect(is_equal_approx(hint_content.get_global_rect().get_center().x, hint_bar.get_global_rect().get_center().x), "Tutorial body must center independently of the collapse button.")
	_expect(is_equal_approx(collapse_button.position.x, 886.0), "Tutorial collapse/expand button must move slightly farther right.")
	_expect(absf(collapse_button.get_global_rect().get_center().y - hint_content.get_global_rect().get_center().y) <= 0.5, "Tutorial collapse/expand button must vertically align with the body tutorial row.")
	_expect(hint_bar.get_global_rect().encloses(collapse_button.get_global_rect()), "Tutorial brush must visually cover the collapse/expand button.")
	_expect(level_play.call("HintTitleText") == "第一步 · 选中舰船", "First tutorial title must describe selecting a ship.")
	_expect(str(level_play.call("HintText")).contains("点击己方舰选中"), "First tutorial body must preserve the level hint text.")
	_expect(int(level_play.call("HintTitleFontSizeValue")) == 24, "Tutorial gold title must increase to 24 px.")
	_expect(int(level_play.call("HintFontSize")) == 20 and int(level_play.call("HintToggleFontSizeValue")) == 20, "Tutorial body and collapse/expand text must increase to 20 px.")
	_expect(int(level_play.call("HintTitleOutlineSize")) == 4 and int(level_play.call("HintBodyOutlineSize")) == 4, "Tutorial title/body must use strong black outlines.")
	_expect(level_play.call("HintTitleColor") == "f0c865" and level_play.call("HintBodyColor") == "f4e8cd", "Tutorial title/body colors must be gold and warm paper white.")
	_expect(level_play.call("HintOutlineColor") == "000000", "Tutorial text outline must be pure black.")
	_expect(not level_play.call("HintPrevVisible") and not level_play.call("HintNextVisible"), "Tutorial hint must not show previous/next controls.")
	_expect(float(level_play.call("HintTransitionSeconds")) >= 0.4, "Tutorial step transition must configure a visible fade out/in duration.")

	controller.call("OnShipClicked", "p1")
	await process_frame
	_expect(int(level_play.call("HintIndex")) == 1, "Selecting the tutorial ship must automatically advance the hint index.")
	_expect(level_play.call("HintTitleText") == "第二步 · 移动舰船", "Automatic advance must show the second step title.")
	var second_body := str(level_play.call("HintText"))
	_expect(second_body.contains("点击目标格移动") and not second_body.contains("下一步"), "Automatic advance must show only the next hint body without next-step feedback copy.")

	_finish()

func _wait_for_scene(path: String, timeout_seconds := 4.0) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if current_scene != null and current_scene.scene_file_path == path:
			await process_frame
			return true
		await process_frame
	return false

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("PASS: naval tutorial brush hint")
		quit(0)
		return
	for failure in failures:
		push_error("FAIL: %s" % failure)
	quit(1)
