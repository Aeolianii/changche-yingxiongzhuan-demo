extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const EXPECTED_SPAWN := Vector2(880, 1170)

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := SEA_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	var player := scene.get_node("World/Player") as CharacterBody2D
	_expect(player.global_position.is_equal_approx(EXPECTED_SPAWN), "Fresh sea overworld must use the adjusted lower-right spawn point.")
	_expect(_is_water_clear(EXPECTED_SPAWN, 19.0, player), "Adjusted sea-overworld spawn must remain on open water.")
	_expect(str(scene.get("_active_location_name")) == "南海军港", "Adjusted spawn must remain inside the South Sea Harbor entry area.")
	var prompt := scene.get_node("UI/Root/InteractionPrompt") as Control
	_expect(prompt.visible, "South Sea Harbor prompt must remain visible at the adjusted spawn.")

	scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("Sea overworld spawn verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _is_water_clear(point: Vector2, radius: float, excluded_body: CollisionObject2D) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	query.exclude = [excluded_body.get_rid()]
	return root.world_2d.direct_space_state.intersect_shape(query, 1).is_empty()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
