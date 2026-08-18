extends SceneTree

const PALACE_SCENE := preload("res://scenes/palace/palace_demo.tscn")
const SCENE_TWO := preload("res://scenes/Scene2.tscn")
const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")

var _failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var ui := root.get_node_or_null("ExplorationUI")
	_expect(ui != null, "ExplorationUI autoload must exist.")
	if ui == null:
		_finish()
		return
	_expect(ui.get_child_count() == 1, "ExplorationUI must own exactly one HUD.")
	var owner_a := Node.new()
	var owner_b := Node.new()
	root.add_child(owner_a)
	root.add_child(owner_b)
	var first := ui.call("acquire", owner_a, &"palace") as Control
	var second := ui.call("acquire", owner_b, &"scene_two") as Control
	_expect(first != null and first == second, "All scenes must acquire the same HUD instance.")
	ui.call("release", owner_a)
	_expect(ui.call("current_owner") == owner_b, "A stale owner must not release the new scene HUD.")
	ui.call("release", owner_b)
	_expect(second != null and not second.visible, "Releasing the current owner must hide the HUD.")
	owner_a.free()
	owner_b.free()
	await _verify_scene_acquisition(ui, PALACE_SCENE, &"palace")
	await _verify_scene_acquisition(ui, SCENE_TWO, &"scene_two")
	await _verify_scene_acquisition(ui, SEA_SCENE, &"sea_overworld")
	_finish()


func _verify_scene_acquisition(ui: Node, packed_scene: PackedScene, context_id: StringName) -> void:
	var scene := packed_scene.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	_expect(scene.get_node_or_null("UI/ExplorationHUD") == null, "%s must not own a private HUD instance." % context_id)
	_expect(ui.call("current_owner") == scene, "%s must acquire the global HUD." % context_id)
	_expect(ui.call("current_context") == context_id, "%s must configure its exact HUD context." % context_id)
	scene.free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("Global exploration UI lifecycle verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
