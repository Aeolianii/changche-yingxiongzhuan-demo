extends SceneTree

const NAVAL_SCENE := preload("res://scenes/naval/NavalDemo.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var demo := NAVAL_SCENE.instantiate()
	root.add_child(demo)
	await process_frame
	var deploy := demo.get_node("Deployment")
	var grid := demo.get_node("Deployment/DeployGrid")
	for scheme_id in ["hunt_archipelago", "hunt_lagoon"]:
		if not deploy.ShowHuntTerrainMapPreviewForTest(scheme_id):
			_fail("Could not preview %s" % scheme_id)
			return
		await process_frame
		if grid.TerrainStampCount() != 1 or grid.TerrainStampCoveredCellCount() != 24 * 18 or not grid.TerrainStampTexturesReady():
			_fail("Continuous terrain art missing for %s" % scheme_id)
			return
		if grid.UnstampedNonWaterCellCount() != 0:
			_fail("Per-cell terrain art may still be visible in %s" % scheme_id)
			return
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var path := "res://.godot/%s_terrain_preview.png" % scheme_id
			if root.get_texture().get_image().save_png(path) != OK:
				_fail("Could not save %s screenshot" % scheme_id)
				return
	print("Hunt terrain art verification passed.")
	quit(0)

func _fail(message: String) -> void:
	push_error(message)
	quit(1)
