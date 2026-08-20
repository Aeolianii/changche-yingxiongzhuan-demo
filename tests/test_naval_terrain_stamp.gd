extends SceneTree

const FIXED_MAP_MAIN_STAMP_IDS: Array[String] = [
	"forest_island_v1",
	"rocky_island_v1",
	"harbor_town_v1",
	"river_mouth_island_v2",
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
	if not deploy.FixedTerrainMapsAreCoherent(32):
		_fail("fixed naval map selector must cover four stable, non-overlapping and connected templates")
		return
	if not deploy.RandomEncountersUseFixedTerrainMaps(32):
		_fail("random encounter entry must select only the four fixed naval maps and expose their names")
		return

	for stamp_id: String in FIXED_MAP_MAIN_STAMP_IDS:
		if not deploy.ShowFixedTerrainMapPreviewForTest(stamp_id):
			_fail("could not build fixed-map preview containing %s" % stamp_id)
			return
		await process_frame
		await process_frame
		var covered_cells: int = grid.TerrainStampCoveredCellCount()
		if grid.TerrainStampCount() != 2 or covered_cells < 57 or covered_cells > 95:
			_fail("main plus companion stamp metadata invalid for %s (count=%d covered=%d)" % [stamp_id, grid.TerrainStampCount(), covered_cells])
			return
		if not grid.TerrainStampTexturesReady():
			_fail("terrain stamp textures were not imported and loaded for %s" % stamp_id)
			return
		if grid.TerrainStampCoastTransitionLayerCount() != 3:
			_fail("terrain stamps must render deep-shadow, shallow-water, and foam transition layers")
			return
		if DisplayServer.get_name() != "headless":
			var preview_path := "res://.godot/naval_fixed_map_%s_preview.png" % stamp_id
			var screenshot_error := root.get_texture().get_image().save_png(preview_path)
			if screenshot_error != OK:
				_fail("could not save terrain stamp preview for %s" % stamp_id)
				return
	print("PASS: four fixed naval maps, deterministic layouts, textures, and whole-image rendering")
	quit(0)
