extends SceneTree

const STAMP_IDS: Array[String] = [
	"river_mouth_island_v2",
	"forest_island_v1",
	"grass_sandbar_v1",
	"reef_shoal_v1",
	"rocky_island_v1",
	"harbor_town_v1",
]
const MAIN_STAMP_IDS: Array[String] = [
	"river_mouth_island_v2",
	"forest_island_v1",
	"rocky_island_v1",
	"harbor_town_v1",
]

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
	if not deploy.RandomTerrainStampsAreCoherent(96):
		_fail("sampled random maps must cover the complete non-overlapping terrain-stamp library outside deployment and exit cells")
		return

	for stamp_id: String in STAMP_IDS:
		if not deploy.ShowRandomTerrainStampKindPreviewForTest(stamp_id):
			_fail("could not build deterministic preview containing %s" % stamp_id)
			return
		await process_frame
		await process_frame
		var covered_cells: int = grid.TerrainStampCoveredCellCount()
		if grid.TerrainStampCount() != 2 or covered_cells < 40 or covered_cells > 72:
			_fail("main plus companion stamp metadata invalid for %s (count=%d covered=%d)" % [stamp_id, grid.TerrainStampCount(), covered_cells])
			return
		if not grid.TerrainStampTexturesReady():
			_fail("terrain stamp textures were not imported and loaded for %s" % stamp_id)
			return
		if DisplayServer.get_name() != "headless" and stamp_id in MAIN_STAMP_IDS:
			var preview_path := "res://.godot/naval_terrain_stamp_%s_preview.png" % stamp_id
			var screenshot_error := root.get_texture().get_image().save_png(preview_path)
			if screenshot_error != OK:
				_fail("could not save terrain stamp preview for %s" % stamp_id)
				return
	print("PASS: complete naval terrain stamp library generation, metadata, texture, and whole-image rendering")
	quit(0)
