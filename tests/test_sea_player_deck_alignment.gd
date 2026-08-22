extends SceneTree

const SEA_PLAYER_SCRIPT := preload("res://scripts/sea_overworld_player.gd")
const DOWN_SCREENSHOT_PATH := "res://.godot/sea_player_down_deck_alignment.png"
const UP_SCREENSHOT_PATH := "res://.godot/sea_player_up_deck_alignment.png"

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := _build_player()
	root.add_child(player)
	await process_frame
	player.set_physics_process(false)

	await _verify_direction(player, 0, Vector2(3.0, -16.0), DOWN_SCREENSHOT_PATH, "down")
	await _verify_direction(player, 3, Vector2(-9.0, -17.0), UP_SCREENSHOT_PATH, "up")

	player.queue_free()
	await process_frame
	if failures.is_empty():
		print("Sea player deck alignment verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _build_player() -> CharacterBody2D:
	var background := ColorRect.new()
	background.color = Color("239bc4")
	background.size = Vector2(512.0, 512.0)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(background)

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(256.0, 256.0)
	player.set_script(SEA_PLAYER_SCRIPT)

	var wake := Sprite2D.new()
	wake.name = "WakeSprite"
	wake.z_index = -2
	wake.scale = Vector2(0.28, 0.28)
	player.add_child(wake)

	var side_splash := Sprite2D.new()
	side_splash.name = "SideSplashSprite"
	side_splash.z_index = -1
	side_splash.scale = Vector2(0.28, 0.28)
	player.add_child(side_splash)

	var visual_root := Node2D.new()
	visual_root.name = "VisualRoot"
	player.add_child(visual_root)

	var ship := Sprite2D.new()
	ship.name = "ShipSprite"
	ship.z_index = 1
	ship.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ship.scale = Vector2(0.28, 0.28)
	visual_root.add_child(ship)

	var hero := Sprite2D.new()
	hero.name = "HeroSprite"
	hero.z_index = 2
	hero.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	hero.scale = Vector2(0.088, 0.088)
	visual_root.add_child(hero)
	return player


func _verify_direction(
	player: CharacterBody2D,
	direction_index: int,
	expected_hero_position: Vector2,
	screenshot_path: String,
	direction_name: String
) -> void:
	player.call("restore_facing_index", direction_index)
	player.call("_update_direction_textures", true)
	var ship := player.get_node("VisualRoot/ShipSprite") as Sprite2D
	var hero := player.get_node("VisualRoot/HeroSprite") as Sprite2D
	_expect(hero.position.is_equal_approx(expected_hero_position), "The %s-facing protagonist must use the corrected deck-center anchor." % direction_name)
	_expect(is_zero_approx(ship.position.y), "The moving %s-facing ship must use the sailing-row deck anchor." % direction_name)
	if DisplayServer.get_name() != "headless":
		# Enlarge only the isolated QA preview; runtime child scales stay unchanged.
		player.scale = Vector2(4.0, 4.0)
		await RenderingServer.frame_post_draw
		var screenshot_error := root.get_texture().get_image().save_png(screenshot_path)
		_expect(screenshot_error == OK, "The %s-facing deck-alignment preview could not be saved." % direction_name)
		player.scale = Vector2.ONE

	player.call("_update_direction_textures", false)
	_expect(hero.position.is_equal_approx(expected_hero_position), "The %s-facing protagonist must keep the same deck anchor after stopping." % direction_name)
	_expect(is_equal_approx(ship.position.y, -98.0 * ship.scale.y), "The stopped %s-facing hull must retain its approved deck compensation." % direction_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
