extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")

const EXPECTED_ENTRY_CENTERS := {
	"东湾水寨": [Vector2(2180, 760)],
	"雾岚群岛": [Vector2(3475, 830)],
	"伏波古岭": [Vector2(4308, 1069)],
	"珊湾渔链": [Vector2(3180, 1370)],
	"澄海灯岛": [
		Vector2(670, 1390), Vector2(870, 1450), Vector2(930, 1680), Vector2(900, 1900),
		Vector2(660, 1980), Vector2(420, 1910), Vector2(380, 1700), Vector2(430, 1480),
	],
	"红湾卫所": [Vector2(3360, 2190)],
	"倭寇大本营": [Vector2(3750, 2600)],
}

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var scene := SEA_SCENE.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	var locations := get_nodes_in_group("sea_location")
	var player := scene.get_node("World/Player") as CharacterBody2D
	var prompt := scene.get_node("UI/Root/InteractionPrompt") as Control
	var location_label := scene.get_node("UI/Root/InteractionPrompt/LocationName") as Label

	_expect(_find_location(locations, "南澳商港") == null, "The retired South Australia merchant-port location must not remain.")
	for location_name in EXPECTED_ENTRY_CENTERS:
		var location := _find_location(locations, location_name)
		_expect(location != null, "%s location is missing." % location_name)
		if location == null:
			continue
		var shape_nodes := _location_trigger_shapes(location)
		var expected_centers: Array = EXPECTED_ENTRY_CENTERS[location_name]
		var expected_count := expected_centers.size() + (1 if location_name == "珊湾渔链" else 0)
		_expect(shape_nodes.size() == expected_count, "%s has the wrong number of interaction ranges." % location_name)
		for expected_center in expected_centers:
			var matched_shape: CollisionShape2D
			for shape_node in shape_nodes:
				if (location.global_position + shape_node.position).is_equal_approx(expected_center as Vector2):
					matched_shape = shape_node
					break
			_expect(matched_shape != null and matched_shape.shape is CircleShape2D, "%s is missing its focused interaction range at %s." % [location_name, expected_center])
			_expect(_is_water_clear(expected_center as Vector2, 19.0, player), "%s interaction center at %s is blocked by static collision." % [location_name, expected_center])
			player.global_position = Vector2(2200, 1500)
			for _frame in range(2):
				await physics_frame
			player.global_position = expected_center as Vector2
			for _frame in range(3):
				await physics_frame
			_expect(prompt.visible and location_name in location_label.text, "%s interaction center at %s does not activate the correct prompt." % [location_name, expected_center])

	var fubo := _find_location(locations, "伏波古岭")
	if fubo != null:
		var primary := fubo.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(primary.shape is CircleShape2D and primary.position.is_equal_approx(Vector2(48, 289)), "Fubo Ridge must allow landing at the shallow beach shown on its southeast shore.")

	var map_screen := root.get_node("ExplorationUI/HUD/SeaMapScreen") as Control
	player.global_position = Vector2(4308, 1069)
	map_screen.call("_refresh_markers")
	var player_marker := map_screen.get_node("MapPanel/MapViewport/PlayerMarker") as Control
	var player_label := player_marker.get_node("PlayerName") as Label
	var expected_map_position := map_screen.call("_map_position", player.global_position) as Vector2
	_expect(player_marker.position.is_equal_approx(expected_map_position), "The full-map current-position glyph must stay at the ship's true projected coordinates near Fubo Ridge.")
	_expect(player_label.position.x < 0.0 and player_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Near the chart's right edge, only the current-position text must flip left of the glyph.")
	var shanwan := _find_location(locations, "珊湾渔链")
	if shanwan != null:
		var primary := shanwan.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(primary.shape is RectangleShape2D and primary.position.is_equal_approx(Vector2(250, 160)), "Shanwan fishing chain must retain its original lower-right entry.")

	if failures.is_empty():
		print("Sea overworld seven-entry alignment verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _find_location(locations: Array[Node], location_name: String) -> Area2D:
	for location_node in locations:
		if str(location_node.get_meta("location_name", "")) == location_name:
			return location_node as Area2D
	return null


func _location_trigger_shapes(area: Area2D) -> Array[CollisionShape2D]:
	var shapes: Array[CollisionShape2D] = []
	for child in area.get_children():
		if child is CollisionShape2D:
			shapes.append(child as CollisionShape2D)
	return shapes


func _is_water_clear(point: Vector2, radius: float, excluded_body: CollisionObject2D = null) -> bool:
	var query := PhysicsShapeQueryParameters2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	query.shape = circle
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1
	query.collide_with_bodies = true
	query.collide_with_areas = false
	if excluded_body != null:
		query.exclude = [excluded_body.get_rid()]
	return root.world_2d.direct_space_state.intersect_shape(query, 1).is_empty()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
