extends Node

# Runs only when explicitly requested from an exported executable.
const FLAG := "--smoke-naval-export"


func _ready() -> void:
	if FLAG in OS.get_cmdline_user_args():
		_run.call_deferred()


func _run() -> void:
	# Let the title screen finish its deferred focus request before replacing it.
	await get_tree().create_timer(0.1).timeout
	var error := get_tree().change_scene_to_file("res://scenes/naval/NavalDemo.tscn")
	if error != OK:
		_fail("scene load failed: %s" % error)
		return
	await get_tree().process_frame
	await get_tree().process_frame
	var scene := get_tree().current_scene
	if scene == null:
		_fail("scene is null")
		return
	var deployment := scene.get_node_or_null("Deployment")
	if deployment == null or not deployment.has_method("PlayerShipCount"):
		_fail("deployment controller is missing")
		return
	var player_count: int = deployment.PlayerShipCount()
	var enemy_count: int = deployment.EnemyShipCount()
	var ship_sprites := deployment.get_node_or_null("DeployShips")
	var sea := deployment.get_node_or_null("DeployGrid/AnimatedSeaSurface") as Polygon2D
	if player_count < 1 or enemy_count < 1 or ship_sprites == null or ship_sprites.get_child_count() < 1:
		_fail("fleet not initialized: player=%d enemy=%d" % [player_count, enemy_count])
		return
	if sea == null or sea.polygon.size() < 4 or sea.texture == null:
		_fail("sea surface not initialized")
		return
	if deployment.SelectShipForDeploy("p1") != "":
		_fail("first player ship cannot be selected")
		return
	var command_panel := deployment.get_node_or_null("DeployHud/Panel") as Panel
	var command_backdrop := deployment.get_node_or_null("DeployHud/Panel/Backdrop") as TextureRect
	if command_panel == null or not command_panel.visible or command_backdrop == null or command_backdrop.texture == null:
		_fail("deployment commands are not visible")
		return
	if DisplayServer.get_name() != "headless":
		await get_tree().create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var screenshot_error := image.save_png("user://export_naval_smoke.png")
		if screenshot_error != OK:
			_fail("screenshot failed: %s" % screenshot_error)
			return
	print("EXPORT_NAVAL_SMOKE_OK player=%d enemy=%d sprites=%d sea_vertices=%d" % [
		player_count, enemy_count, ship_sprites.get_child_count(), sea.polygon.size()
	])
	get_tree().quit(0)


func _fail(message: String) -> void:
	push_error("EXPORT_NAVAL_SMOKE_FAILED " + message)
	get_tree().quit(1)
