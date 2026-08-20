extends SceneTree

const PREVIEW_PATH := "res://.godot/naval_terrain_stamp_preview.png"

func _fail(message: String) -> void:
	push_error("FAIL: " + message)
	quit(1)

func _init() -> void:
	var scene := load("res://scenes/naval/NavalDemo.tscn") as PackedScene
	if scene == null:
		_fail("NavalDemo.tscn missing")
		return
	var demo := scene.instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame

	var deploy := demo.get_node_or_null("Deployment")
	var grid := demo.get_node_or_null("Deployment/DeployGrid")
	if deploy == null or grid == null:
		_fail("deployment terrain preview nodes missing")
		return
	if not deploy.RandomTerrainStampsAreCoherent(48):
		_fail("sampled random maps must keep one complete source-to-mouth stamp outside deployment and exit cells")
		return
	if not deploy.ShowRandomTerrainStampPreviewForTest(17):
		_fail("could not build deterministic terrain stamp preview")
		return
	await process_frame
	await process_frame
	if grid.TerrainStampCount() != 1 or grid.TerrainStampCoveredCellCount() != 48:
		_fail("6x8 terrain stamp metadata was not attached to the battle grid")
		return
	if not grid.TerrainStampTexturesReady():
		_fail("terrain stamp texture was not imported and loaded")
		return

	if DisplayServer.get_name() != "headless":
		var screenshot_error := root.get_texture().get_image().save_png(PREVIEW_PATH)
		if screenshot_error != OK:
			_fail("could not save terrain stamp preview")
			return
	print("PASS: naval terrain stamp generation, metadata, texture, and whole-image rendering")
	quit(0)
