extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const SCREENSHOT_PATH := "res://.godot/sea_overworld_preview.png"
const MOVEMENT_SCREENSHOT_PATH := "res://.godot/sea_overworld_movement_preview.png"
const STOPPED_SCREENSHOT_PATH := "res://.godot/sea_overworld_stopped_preview.png"
const QUEST_SCREENSHOT_PATH := "res://.godot/sea_overworld_quest_preview.png"
const MAP_SCREENSHOT_PATH := "res://.godot/sea_overworld_map_preview.png"
const FULL_MOON_SCREENSHOT_PATH := "res://.godot/sea_overworld_lunar_full_preview.png"
const B_ZONE_SCREENSHOT_PATH := "res://.godot/sea_overworld_b_zone_preview.png"
const C_ZONE_SCREENSHOT_PATH := "res://.godot/sea_overworld_c_zone_preview.png"
const D_ZONE_SCREENSHOT_PATH := "res://.godot/sea_overworld_d_zone_preview.png"
const CENTRAL_SEAM_SCREENSHOT_PATH := "res://.godot/sea_overworld_central_seam_preview.png"
const EXPECTED_LOCATIONS := {
	"南海军港": Vector2(480, 1040),
	"川山渔村": Vector2(1080, 650),
	"东湾水寨": Vector2(2040, 520),
	"青屿秘境": Vector2(2380, 540),
	"沧门礁堡": Vector2(2780, 1080),
	"月环商港": Vector2(3650, 360),
	"雾岚群岛": Vector2(3070, 850),
	"伏波古岭": Vector2(4260, 780),
	"珊湾渔链": Vector2(3670, 1150),
	"澄海灯岛": Vector2(480, 1680),
	"龙门海寨": Vector2(860, 2260),
	"白沙渔岛": Vector2(1460, 2460),
	"玄潮古屿": Vector2(2100, 2240),
	"红湾卫所": Vector2(2980, 1760),
	"倭寇营地": Vector2(4380, 2460),
}
const A_LOCATIONS := ["南海军港", "川山渔村", "东湾水寨", "青屿秘境"]
const B_LOCATIONS := ["沧门礁堡", "月环商港", "雾岚群岛", "伏波古岭", "珊湾渔链"]
const C_LOCATIONS := ["澄海灯岛", "龙门海寨", "白沙渔岛", "玄潮古屿"]
const D_LOCATIONS := ["红湾卫所", "倭寇营地"]
const NAVIGATION_ROUTES := {
	"A_TO_B": [Vector2(1500, 800), Vector2(2100, 800), Vector2(2388, 800), Vector2(2700, 800), Vector2(3050, 800)],
	"A_TO_C": [Vector2(1700, 1050), Vector2(1700, 1292), Vector2(1700, 1500), Vector2(1550, 1750), Vector2(1400, 1950)],
	"B_TO_D": [Vector2(4200, 1140), Vector2(4200, 1292), Vector2(4200, 1600), Vector2(3900, 1750)],
	"C_TO_D": [Vector2(1900, 1400), Vector2(2388, 1400), Vector2(2850, 1400), Vector2(3150, 1500)],
	"FORTRESS_ABOVE": [Vector2(2200, 800), Vector2(3050, 800)],
	"FORTRESS_BELOW": [Vector2(2200, 1450), Vector2(3400, 1450)],
	"FORTRESS_LEFT": [Vector2(2250, 800), Vector2(2250, 1450)],
	"FORTRESS_RIGHT": [Vector2(3125, 800), Vector2(3125, 1450)],
}
const LAND_COLLISION_PROBES := [
	Vector2(900, 500), Vector2(700, 885), Vector2(1900, 640), Vector2(2400, 520),
	Vector2(2780, 1080), Vector2(3650, 285), Vector2(3330, 730), Vector2(4300, 850),
	Vector2(3500, 1150), Vector2(620, 1650), Vector2(850, 2250), Vector2(1650, 2400),
	Vector2(2220, 2340), Vector2(3050, 1950), Vector2(3600, 2300), Vector2(4300, 2100),
]
var EXPECTED_COLLISION_POLYGONS := {
	"NorthwestCoast": PackedVector2Array([
		Vector2(0, 0), Vector2(1810, 0), Vector2(1780, 100), Vector2(1650, 145),
		Vector2(1530, 205), Vector2(1470, 310), Vector2(1510, 430), Vector2(1650, 520),
		Vector2(1710, 610), Vector2(1600, 675), Vector2(1450, 650), Vector2(1320, 720),
		Vector2(1180, 690), Vector2(1040, 735), Vector2(880, 725), Vector2(720, 770),
		Vector2(570, 800), Vector2(470, 880), Vector2(445, 970), Vector2(330, 1040),
		Vector2(180, 1030), Vector2(0, 1090),
	]),
	"EastBaySandbar": PackedVector2Array([
		Vector2(1710, 620), Vector2(1830, 565), Vector2(2010, 590), Vector2(2135, 670),
		Vector2(2040, 715), Vector2(1830, 705),
	]),
	"QingyuPagodaIsland": PackedVector2Array([
		Vector2(2260, 495), Vector2(2380, 425), Vector2(2490, 475), Vector2(2515, 600),
		Vector2(2420, 650), Vector2(2290, 610),
	]),
	"CangmenFortress": PackedVector2Array([
		Vector2(2490, 1050), Vector2(2630, 950), Vector2(2860, 945), Vector2(2995, 1040),
		Vector2(3010, 1195), Vector2(2900, 1280), Vector2(2660, 1280), Vector2(2500, 1190),
	]),
	"CangmenDock": PackedVector2Array([
		Vector2(2370, 1165), Vector2(2525, 1095), Vector2(2580, 1160), Vector2(2450, 1230),
	]),
	"WulanVillageIsland": PackedVector2Array([
		Vector2(3185, 700), Vector2(3290, 650), Vector2(3430, 680), Vector2(3500, 760),
		Vector2(3410, 825), Vector2(3240, 800),
	]),
	"FuboRidge": PackedVector2Array([
		Vector2(3860, 735), Vector2(3970, 665), Vector2(4170, 700), Vector2(4390, 820),
		Vector2(4710, 935), Vector2(4780, 1035), Vector2(4560, 1080), Vector2(4350, 1010),
		Vector2(4140, 950), Vector2(3950, 895),
	]),
	"ShanwanMountain": PackedVector2Array([
		Vector2(3260, 1040), Vector2(3440, 940), Vector2(3620, 1020), Vector2(3810, 1180),
		Vector2(3700, 1330), Vector2(3440, 1390), Vector2(3230, 1290),
	]),
	"ChenghaiLighthouse": PackedVector2Array([
		Vector2(500, 1510), Vector2(640, 1460), Vector2(760, 1570), Vector2(785, 1790),
		Vector2(680, 1880), Vector2(520, 1850), Vector2(440, 1700),
	]),
	"LongmenStronghold": PackedVector2Array([
		Vector2(540, 2150), Vector2(720, 2070), Vector2(980, 2090), Vector2(1175, 2230),
		Vector2(1120, 2390), Vector2(850, 2440), Vector2(580, 2340),
	]),
	"BaishaSandbar": PackedVector2Array([
		Vector2(1360, 2370), Vector2(1550, 2270), Vector2(1810, 2260), Vector2(1990, 2375),
		Vector2(1890, 2490), Vector2(1590, 2535), Vector2(1380, 2475),
	]),
	"RedBayMountain": PackedVector2Array([
		Vector2(2820, 1800), Vector2(2990, 1710), Vector2(3170, 1780), Vector2(3370, 1970),
		Vector2(3310, 2160), Vector2(3140, 2240), Vector2(2920, 2190), Vector2(2740, 2040),
	]),
	"NanaoWestWall": PackedVector2Array([
		Vector2(3510, 2260), Vector2(3680, 2140), Vector2(3790, 2280), Vector2(3650, 2410),
		Vector2(3510, 2440),
	]),
	"NanaoCitadel": PackedVector2Array([
		Vector2(3690, 2080), Vector2(3860, 1920), Vector2(4250, 1820), Vector2(4540, 1940),
		Vector2(4720, 2160), Vector2(4680, 2360), Vector2(4550, 2480), Vector2(4250, 2460),
		Vector2(4130, 2350), Vector2(4000, 2350), Vector2(3900, 2270), Vector2(3730, 2300),
	]),
}
var EXPECTED_COLLISION_CIRCLES := {
	"SouthHarborWestRock": {"position": Vector2(350, 1020), "radius": 105.0},
	"SouthHarborNorthwestWall": {"position": Vector2(500, 925), "radius": 120.0},
	"SouthHarborNorthWall": {"position": Vector2(700, 885), "radius": 115.0},
	"SouthHarborNortheastWall": {"position": Vector2(930, 900), "radius": 125.0},
	"SouthHarborEastWall": {"position": Vector2(1160, 985), "radius": 145.0},
	"SouthHarborEastRock": {"position": Vector2(1360, 1090), "radius": 115.0},
	"MoonHarborNorthwest": {"position": Vector2(3380, 400), "radius": 120.0},
	"MoonHarborNorth": {"position": Vector2(3500, 300), "radius": 110.0},
	"MoonHarborCrown": {"position": Vector2(3650, 285), "radius": 120.0},
	"MoonHarborEast": {"position": Vector2(3780, 365), "radius": 130.0},
	"MoonHarborSoutheast": {"position": Vector2(3810, 510), "radius": 125.0},
	"MoonHarborSouth": {"position": Vector2(3690, 600), "radius": 105.0},
	"XuanchaoWestReef": {"position": Vector2(1980, 2395), "radius": 38.0},
	"XuanchaoMainReef": {"position": Vector2(2220, 2340), "radius": 58.0},
	"XuanchaoSouthReef": {"position": Vector2(2130, 2460), "radius": 34.0},
	"CentralNorthReef": {"position": Vector2(1950, 1585), "radius": 38.0},
	"CentralEastReef": {"position": Vector2(2310, 1840), "radius": 34.0},
	"ShanwanOuterReef": {"position": Vector2(3970, 1240), "radius": 46.0},
}

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var game_state := root.get_node_or_null("GameState")
	if game_state != null:
		game_state.call("clear_pending_scene_state")
	root.set_meta("sea_overworld_lunar_day", 0.0)
	var scene := SEA_SCENE.instantiate()
	_verify_serialized_collision_tree(scene)
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame

	_verify_assets()
	_verify_location_layout(scene)
	await _verify_production_entry_alignment(scene)
	await _verify_shared_exploration_hud(scene)
	await _verify_keyboard_movement(scene)
	await _verify_location_interaction(scene)
	await _verify_b_expansion(scene)
	await _verify_c_expansion(scene)
	await _verify_d_expansion(scene)
	_verify_navigation_collisions(scene)
	await _capture_central_seam(scene)
	await _verify_auto_triggers(scene)
	await _capture_preview(scene)

	if failures.is_empty():
		print("Sea overworld runtime verification passed.")
		quit(0)
		return

	for failure in failures:
		push_error(failure)
	quit(1)


func _verify_serialized_collision_tree(scene: Node) -> void:
	var world_collision := scene.get_node("World/WorldCollision") as StaticBody2D
	_expect(world_collision.get_child_count() == 32, "Packed sea-overworld scene must serialize exactly 32 world-collision nodes before runtime startup.")
	_expect(world_collision.collision_layer == 1 and world_collision.collision_mask == 1, "Serialized world collision must retain layer 1 and mask 1.")
	_expect(EXPECTED_COLLISION_POLYGONS.size() == 14 and EXPECTED_COLLISION_CIRCLES.size() == 18, "Collision geometry contract must contain fourteen polygons and eighteen circles.")
	for collision_name in EXPECTED_COLLISION_POLYGONS:
		var node := world_collision.get_node_or_null(collision_name) as CollisionPolygon2D
		_expect(node != null, "Serialized collision polygon %s is missing or has the wrong type." % collision_name)
		if node != null:
			_expect(_packed_vectors_equal(node.polygon, EXPECTED_COLLISION_POLYGONS[collision_name]), "Serialized collision polygon %s does not match its approved vertices." % collision_name)
	var circle_shape_ids: Dictionary = {}
	for collision_name in EXPECTED_COLLISION_CIRCLES:
		var node := world_collision.get_node_or_null(collision_name) as CollisionShape2D
		_expect(node != null, "Serialized circle collision %s is missing or has the wrong node type." % collision_name)
		if node == null:
			continue
		var circle := node.shape as CircleShape2D
		var expected: Dictionary = EXPECTED_COLLISION_CIRCLES[collision_name]
		_expect(circle != null, "Serialized collision %s must use CircleShape2D." % collision_name)
		_expect(node.position.is_equal_approx(expected["position"] as Vector2), "Serialized circle collision %s moved from its approved center." % collision_name)
		if circle != null:
			_expect(is_equal_approx(circle.radius, float(expected["radius"])), "Serialized circle collision %s changed radius." % collision_name)
			var shape_id := circle.get_instance_id()
			_expect(not circle_shape_ids.has(shape_id), "Circle collision %s must own an independent editable Shape resource." % collision_name)
			circle_shape_ids[shape_id] = collision_name
	var source_code := (scene.get_script() as Script).get_source_code()
	_expect("_build_world_collisions" not in source_code, "Sea-overworld script must not retain runtime world-collision generation.")
	_expect("_add_polygon_blocker" not in source_code and "_add_circle_blocker" not in source_code, "Sea-overworld script must not retain obsolete static-collision builder helpers.")


func _packed_vectors_equal(actual: PackedVector2Array, expected: PackedVector2Array) -> bool:
	if actual.size() != expected.size():
		return false
	for index in range(actual.size()):
		if not actual[index].is_equal_approx(expected[index]):
			return false
	return true


func _verify_assets() -> void:
	var packed_scene_state := SEA_SCENE.get_state()
	var serialized_backgrounds := {
		NodePath("./World/Background"): false,
		NodePath("./World/EastBackground"): false,
		NodePath("./World/CBackground"): false,
		NodePath("./World/DBackground"): false,
	}
	for node_index in range(packed_scene_state.get_node_count()):
		var node_path := packed_scene_state.get_node_path(node_index)
		if serialized_backgrounds.has(node_path):
			serialized_backgrounds[node_path] = true
	for background_path in serialized_backgrounds:
		_expect(bool(serialized_backgrounds[background_path]), "%s must be serialized for editor visibility." % background_path)

	var chunk_paths := [
		"res://assets/backgrounds/sea_overworld/guangdong_sea_zone_a_v3.png",
		"res://assets/backgrounds/sea_overworld/guangdong_sea_zone_b_v3.png",
		"res://assets/backgrounds/sea_overworld/guangdong_sea_zone_c_v3.png",
		"res://assets/backgrounds/sea_overworld/guangdong_sea_zone_d_v3.png",
	]
	var chunk_textures: Array[Texture2D] = []
	for asset_path in chunk_paths:
		var chunk_texture := load(asset_path) as Texture2D
		chunk_textures.append(chunk_texture)
		_expect(chunk_texture != null and chunk_texture.get_size() == Vector2(3344, 1882), "%s must be a 3344x1882 v3 production chunk." % asset_path)
	for asset_path in [
		"res://assets/sprites/sea_overworld/protagonist_chibi_4dir_v1.png",
		"res://assets/sprites/sea_overworld/player_ship_4dir_states_v1.png",
		"res://assets/sprites/sea_overworld/event_ships_atlas_v2.png",
		"res://assets/sprites/sea_overworld/ship_wake_fx_atlas_v1.png",
		"res://assets/ui/sea_overworld/interaction_button_ink_v1.png",
		"res://assets/ui/sea_overworld/interaction_button_ink_active_v1.png",
		"res://assets/ui/sea_overworld/moon_clock_moon.png",
	]:
		var texture := load(asset_path) as Texture2D
		_expect(texture != null and texture.get_width() > 0, "%s could not be loaded." % asset_path)
	var moon_texture := load("res://assets/ui/sea_overworld/moon_clock_moon.png") as Texture2D
	var moon_image := moon_texture.get_image() if moon_texture != null else null
	_expect(moon_texture != null and moon_texture.get_size() == Vector2(256, 256), "Generated moon texture must use the compact 256x256 project size.")
	_expect(moon_image != null and moon_image.get_pixel(0, 0).a == 0.0 and moon_image.get_pixel(255, 255).a == 0.0, "Generated moon texture must retain transparent outer corners.")
	_expect(load("res://shaders/moon_phase.gdshader") is Shader, "Moon phase shader could not be loaded.")
	_expect(load("res://shaders/map_chunk_blend.gdshader") is Shader, "Map chunk blend shader could not be loaded.")

	var background_names := ["Background", "EastBackground", "CBackground", "DBackground"]
	var expected_origins := [Vector2.ZERO, Vector2(2388, 0), Vector2(0, 1292), Vector2(2388, 1292)]
	for index in range(background_names.size()):
		var background := current_scene.get_node("World/%s" % background_names[index]) as Sprite2D
		_expect(background.texture == chunk_textures[index], "%s must use its matching v3 production chunk." % background_names[index])
		_expect(background.position.is_equal_approx(expected_origins[index]), "%s has the wrong two-by-two chunk origin." % background_names[index])
		_expect(background.scale.is_equal_approx(Vector2(0.75, 0.75)), "%s must retain the 0.75 production scale." % background_names[index])
		var texture_node_count := 0
		for world_child in current_scene.get_node("World").get_children():
			if world_child is Sprite2D and (world_child as Sprite2D).texture == chunk_textures[index]:
				texture_node_count += 1
		_expect(texture_node_count == 1, "%s must not be duplicated at runtime." % background_names[index])

	var b_background := current_scene.get_node("World/EastBackground") as Sprite2D
	var c_background := current_scene.get_node("World/CBackground") as Sprite2D
	var d_background := current_scene.get_node("World/DBackground") as Sprite2D
	var a_background := current_scene.get_node("World/Background") as Sprite2D
	_expect(a_background.material is ShaderMaterial, "A map chunk must use animated water shading.")
	_expect((a_background.material as ShaderMaterial).get_shader_parameter("world_origin") == Vector2.ZERO, "A water animation must start at the world origin.")
	_expect((a_background.material as ShaderMaterial).get_shader_parameter("waterNoise") is NoiseTexture2D, "Overworld water must use the same seamless surface-noise approach as Scene 2.")
	_expect((a_background.material as ShaderMaterial).get_shader_parameter("waterDistortionNoise") is NoiseTexture2D, "Overworld water must use Scene 2-style flow distortion noise.")
	_expect(b_background.material is ShaderMaterial, "B map chunk must use alpha seam blending.")
	_expect((b_background.material as ShaderMaterial).get_shader_parameter("world_origin") == Vector2(2388, 0), "B water animation must align with world coordinates.")
	_expect(c_background.material is ShaderMaterial and bool((c_background.material as ShaderMaterial).get_shader_parameter("fade_from_top")), "C map chunk must fade from its north edge.")
	_expect(not bool((c_background.material as ShaderMaterial).get_shader_parameter("fade_from_left")), "C map chunk must not fade from its west edge.")
	_expect(d_background.material is ShaderMaterial and bool((d_background.material as ShaderMaterial).get_shader_parameter("fade_from_left")), "D map chunk must fade from its west edge.")
	_expect(bool((d_background.material as ShaderMaterial).get_shader_parameter("fade_from_top")), "D map chunk must fade from its north edge.")

	var player := current_scene.get_node("World/Player") as CharacterBody2D
	var camera := player.get_node("Camera2D") as Camera2D
	var ship := player.get_node("VisualRoot/ShipSprite") as Sprite2D
	var hero := player.get_node("VisualRoot/HeroSprite") as Sprite2D
	var wake := player.get_node("WakeSprite") as Sprite2D
	var side_splash := player.get_node("SideSplashSprite") as Sprite2D
	var player_shape := (player.get_node("CollisionShape2D") as CollisionShape2D).shape as CircleShape2D
	_expect(camera.limit_right == 4896 and camera.limit_bottom == 2704, "Camera limits must cover the complete A/B/C/D world.")
	_expect((player.get("movement_bounds") as Rect2).end.is_equal_approx(Vector2(4862, 2670)), "Player movement bounds must cover the complete sea-world envelope.")
	_expect(ship.scale.is_equal_approx(Vector2(0.28, 0.28)), "Player ship must use the compact production-map scale.")
	_expect(hero.scale.is_equal_approx(Vector2(0.088, 0.088)), "Player chibi must use the compact production-map scale.")
	_expect(wake.scale.is_equal_approx(Vector2(0.28, 0.28)) and side_splash.scale.is_equal_approx(Vector2(0.28, 0.28)), "Sailing effects must match the compact ship scale.")
	_expect(player_shape != null and is_equal_approx(player_shape.radius, 19.0), "Player collision radius must match the compact hull.")


func _verify_location_layout(scene: Node) -> void:
	var locations := get_nodes_in_group("sea_location")
	_expect(locations.size() == 15, "Production map must expose exactly fifteen enterable locations.")
	var region_names := {
		"A": A_LOCATIONS,
		"B": B_LOCATIONS,
		"C": C_LOCATIONS,
		"D": D_LOCATIONS,
	}
	for location_name in EXPECTED_LOCATIONS:
		var location := _find_location(locations, location_name)
		_expect(location != null, "Production location %s is missing." % location_name)
		if location != null:
			_expect(location.position.distance_to(EXPECTED_LOCATIONS[location_name]) <= 80.0, "%s exceeds the approved ±80 coordinate tolerance." % location_name)
	for location_name in region_names["A"]:
		var location := _find_location(locations, location_name)
		_expect(location != null and location.position.x < 2388.0 and location.position.y < 1292.0, "%s must remain in A northwest of both seams." % location_name)
	for location_name in region_names["B"]:
		var location := _find_location(locations, location_name)
		_expect(location != null and location.position.x > 2388.0 and location.position.y < 1292.0, "%s must remain in B northeast of the seams." % location_name)
	for location_name in region_names["C"]:
		var location := _find_location(locations, location_name)
		_expect(location != null and location.position.x < 2388.0 and location.position.y > 1292.0, "%s must remain in C southwest of the seams." % location_name)
	for location_name in region_names["D"]:
		var location := _find_location(locations, location_name)
		_expect(location != null and location.position.x > 2388.0 and location.position.y > 1292.0, "%s must remain in D southeast of the seams." % location_name)
	_expect(A_LOCATIONS.size() == 4 and B_LOCATIONS.size() == 5 and C_LOCATIONS.size() == 4 and D_LOCATIONS.size() == 2, "Region responsibility must remain A4/B5/C4/D2.")
	var moon_harbor := _find_location(locations, "月环商港")
	if moon_harbor != null:
		var moon_shape_node := moon_harbor.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(moon_shape_node.shape is RectangleShape2D and moon_shape_node.position.x < 0.0, "Moon harbor must retain its left-facing rectangular entry.")
	var qingyu := _find_location(locations, "青屿秘境")
	if qingyu != null:
		var qingyu_shape_node := qingyu.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(not _is_water_clear(qingyu.position, 2.0), "Qingyu location center must sit on the visible pagoda island.")
		_expect(qingyu_shape_node.shape is RectangleShape2D and qingyu_shape_node.position.y > 0.0, "Qingyu must use its south-side water entry.")
		_expect(_is_water_clear(_find_clear_entry_point(qingyu), 19.0), "Qingyu south-side entry must remain reachable open water.")
		var qingyu_map_offset := qingyu.get_meta("map_label_offset", Vector2.ZERO) as Vector2
		_expect(qingyu_map_offset.x > 0.0 and qingyu_map_offset.y < 0.0, "Qingyu full-map label must be offset to the pagoda island's upper-right.")
	var white_sand := _find_location(locations, "白沙渔岛")
	if white_sand != null:
		var white_sand_shape := white_sand.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(white_sand_shape.shape is RectangleShape2D, "White Sand fishing island must use a dedicated rectangular dock entry.")
		_expect(white_sand_shape.position.x > 0.0 and white_sand_shape.position.y > 0.0, "White Sand dock entry must stay southeast of the island center.")
		_expect(_is_water_clear(white_sand.global_position + white_sand_shape.position, 19.0), "White Sand dock entry must remain reachable open water.")
	var xuanchao := _find_location(locations, "玄潮古屿")
	if xuanchao != null:
		var xuanchao_shapes := _location_trigger_shapes(xuanchao)
		_expect(xuanchao_shapes.size() == 3, "Xuanchao ancient reefs must expose exactly three directional entry points.")
		var trigger_offsets := xuanchao.get_meta("entry_trigger_offsets", []) as Array
		_expect(trigger_offsets.size() == 3, "Xuanchao directional entry metadata must list north, south and east points.")
		if trigger_offsets.size() == 3:
			_expect((trigger_offsets[0] as Vector2).y < 0.0, "Xuanchao first entry point must sit north of the reefs.")
			_expect((trigger_offsets[1] as Vector2).y > 0.0, "Xuanchao second entry point must sit south of the reefs.")
			_expect((trigger_offsets[2] as Vector2).x > 0.0, "Xuanchao third entry point must sit east of the reefs.")
		for shape_node in xuanchao_shapes:
			_expect(_is_water_clear(xuanchao.global_position + shape_node.position, 19.0), "Every Xuanchao directional entry point must remain reachable open water.")
		_expect(not _trigger_contains_point(xuanchao, Vector2(1880, 2395)), "Xuanchao must not expose a west-side entry toward White Sand fishing island.")
		var xuanchao_map_offset := xuanchao.get_meta("map_label_offset", Vector2.ZERO) as Vector2
		_expect(xuanchao_map_offset.x > 0.0 and xuanchao_map_offset.y > 0.0, "Xuanchao full-map label must be offset to the reefs' lower-right.")
	var script_constants := (scene.get_script() as Script).get_script_constant_map()
	var spawn := script_constants.get("SOUTH_SEA_HARBOR_SPAWN", Vector2.ZERO) as Vector2
	var south_harbor := _find_location(locations, "南海军港")
	var chuanshan := _find_location(locations, "川山渔村")
	var sea_player := scene.get_node("World/Player") as CharacterBody2D
	_expect(_is_water_clear(spawn, 19.0, sea_player), "South Sea harbor spawn must remain outside static collision.")
	_expect(south_harbor != null and _trigger_contains_point(south_harbor, spawn), "South Sea harbor spawn must still activate its entry trigger.")
	_expect(sea_player.global_position.is_equal_approx(spawn), "A fresh sea map must start inside South Sea Harbor's crescent basin.")
	if south_harbor != null:
		var harbor_shapes := _location_trigger_shapes(south_harbor)
		_expect(harbor_shapes.size() == 5, "South Sea Harbor must follow the crescent basin with five entry segments.")
		for shape_node in harbor_shapes:
			_expect(shape_node.shape is CircleShape2D, "Every South Sea Harbor crescent entry segment must be circular.")
			_expect(_is_water_clear(south_harbor.global_position + shape_node.position, 19.0), "Every South Sea Harbor crescent entry segment must sit on navigable basin water.")
		var harbor_offsets := south_harbor.get_meta("entry_trigger_offsets", []) as Array
		if harbor_offsets.size() == 5:
			_expect((harbor_offsets[0] as Vector2).y > (harbor_offsets[2] as Vector2).y and (harbor_offsets[4] as Vector2).y > (harbor_offsets[2] as Vector2).y, "South Sea Harbor entry segments must form a shallow crescent inside the basin.")
	if chuanshan != null:
		var chuanshan_shape := chuanshan.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(chuanshan_shape.shape is CircleShape2D and chuanshan_shape.position.is_equal_approx(Vector2(390, 30)), "Chuanshan fishing village must use the screenshot-marked southeast dock point.")
		_expect((chuanshan.global_position + chuanshan_shape.position).is_equal_approx(Vector2(1470, 680)), "Chuanshan's entry center must match the red current-position marker at the small dock.")
		_expect(_is_water_clear(chuanshan.global_position + chuanshan_shape.position, 19.0), "Chuanshan's lower dock entry must remain reachable open water.")
		var chuanshan_map_offset := chuanshan.get_meta("map_label_offset", Vector2.ZERO) as Vector2
		_expect(chuanshan_map_offset.is_equal_approx(Vector2(0, -220)), "Chuanshan's full-map label must move upward onto the mainland houses.")


func _verify_production_entry_alignment(scene: Node) -> void:
	var locations := get_nodes_in_group("sea_location")
	var player := scene.get_node("World/Player") as CharacterBody2D
	var prompt := scene.get_node("UI/Root/InteractionPrompt") as Control
	var location_label := scene.get_node("UI/Root/InteractionPrompt/LocationName") as Label
	var expected_entry_centers := {
		"东湾水寨": [Vector2(2180, 760)],
		"雾岚群岛": [Vector2(3475, 830)],
		"伏波古岭": [Vector2(4308, 1069)],
		"珊湾渔链": [Vector2(3180, 1370)],
		"澄海灯岛": [
			Vector2(670, 1390), Vector2(870, 1450), Vector2(930, 1680), Vector2(900, 1900),
			Vector2(660, 1980), Vector2(420, 1910), Vector2(380, 1700), Vector2(430, 1480),
		],
		"红湾卫所": [Vector2(3360, 2190)],
		"倭寇营地": [Vector2(3750, 2600)],
	}
	for location_name in expected_entry_centers:
		var location := _find_location(locations, location_name)
		_expect(location != null, "%s must exist for production-entry alignment verification." % location_name)
		if location == null:
			continue
		var expected_centers: Array = expected_entry_centers[location_name]
		var shape_nodes := _location_trigger_shapes(location)
		var expected_shape_count := expected_centers.size()
		if location_name == "珊湾渔链":
			expected_shape_count += 1
		_expect(shape_nodes.size() == expected_shape_count, "%s must expose the approved number of production-map entry ranges." % location_name)
		for expected_center in expected_centers:
			var matched_shape: CollisionShape2D
			for shape_node in shape_nodes:
				if (location.global_position + shape_node.position).is_equal_approx(expected_center as Vector2):
					matched_shape = shape_node
					break
			_expect(matched_shape != null, "%s is missing its approved entry at %s." % [location_name, expected_center])
			if matched_shape == null:
				continue
			_expect(matched_shape.shape is CircleShape2D, "%s's dock/directional entry must use a focused circular range." % location_name)
			_expect(_is_water_clear(expected_center as Vector2, 19.0, player), "%s entry at %s must sit on navigable water." % [location_name, expected_center])
			player.global_position = Vector2(1800, 1200)
			for _frame in range(2):
				await physics_frame
			player.global_position = expected_center as Vector2
			for _frame in range(3):
				await physics_frame
			_expect(prompt.visible and location_name in location_label.text, "%s entry at %s must activate the correct prompt." % [location_name, expected_center])

	var fubo := _find_location(locations, "伏波古岭")
	if fubo != null:
		var fubo_primary := fubo.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(fubo_primary.shape is CircleShape2D and fubo_primary.position.is_equal_approx(Vector2(48, 289)), "Fubo Ridge must allow landing at the shallow beach shown on its southeast shore.")
	var shanwan := _find_location(locations, "珊湾渔链")
	if shanwan != null:
		var shanwan_primary := shanwan.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(shanwan_primary.shape is RectangleShape2D and shanwan_primary.position.is_equal_approx(Vector2(250, 160)), "Shanwan fishing chain must retain its original lower-right entry while adding the lower-left entry.")
	player.global_position = Vector2(1800, 1200)
	for _frame in range(3):
		await physics_frame


func _verify_shared_exploration_hud(scene: Node) -> void:
	var hud := root.get_node("ExplorationUI/HUD") as Control
	var player := scene.get_node("World/Player") as CharacterBody2D
	var main_task := hud.get_node("QuestTracker/MainQuest/TaskName") as Label
	var main_objective := hud.get_node("QuestTracker/MainQuest/Objective") as Label
	var side_task := hud.get_node("QuestTracker/SideQuest/TaskName") as Label
	_expect(hud.visible, "Sea overworld must reuse the shared exploration HUD from scenes one and two.")
	_expect(main_task.text == "探索海域，完善海图" and "点击进入按钮" in main_objective.text, "Spawning inside South Sea Harbor must advance the chart-exploration task to the location-entry step.")
	_expect(side_task.text == "海上见闻", "Sea overworld must replace the shared HUD's old placeholder side task.")
	_expect(scene.get_node_or_null("UI/Root/TitlePanel") == null and scene.get_node_or_null("UI/Root/HelpPanel") == null, "Old sea-map title and help panels must be removed.")
	_expect(scene.get_node_or_null("UI/Root/ToastPanel") == null, "Old sea-map toast UI must be replaced by the shared HUD toast.")

	var quest_button := hud.find_child("QuestButton", true, false) as Button
	quest_button.pressed.emit()
	await process_frame
	var quest_screen := hud.get_node("QuestScreen") as Control
	var selected_title := quest_screen.get_node("SelectedQuestTitle") as RichTextLabel
	var steps := quest_screen.get_node("QuestStepsScroll/QuestSteps") as VBoxContainer
	_expect(quest_screen.visible and "探索海域，完善海图" in selected_title.text, "Shared quest screen must open on the chart-exploration task.")
	_expect(steps.get_child_count() == 4, "Explore-map quest must display its four-step task flow.")
	_expect("奉诏入殿" not in selected_title.text and "巡视水师驻地" not in selected_title.text, "Sea-map quest screen must not show scene-one or scene-two task names.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var screenshot_error := root.get_texture().get_image().save_png(QUEST_SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "Sea overworld quest preview screenshot could not be saved.")
	var return_button := quest_screen.find_child("QuestReturnButton", true, false) as Button
	return_button.pressed.emit()
	await process_frame
	_expect(not quest_screen.visible, "Returning from the sea-map quest screen must restore exploration.")

	var moon_status := hud.get_node("PlayerStatus") as Control
	var moon_frame := moon_status.get_node("GeneratedStatusFrame") as TextureRect
	var moon_icon := moon_status.get_node("PortraitFrame/MoonIcon") as TextureRect
	var moon_phase_name := moon_status.get_node("MoonPhaseName") as Label
	var moon_material := moon_icon.material as ShaderMaterial
	var map_status := hud.get_node("SeaMapStatus") as Control
	var map_frame := map_status.get_node("GeneratedMapFrame") as TextureRect
	var map_icon := map_status.get_node("MapIcon") as TextureRect
	var map_button := map_status.get_node("MapButton") as Button
	var quest_tracker := hud.get_node("QuestTracker") as Control
	_expect(not moon_status.get_node("NamePlate").visible, "Sea-map HUD must remove the player information plate.")
	_expect(not moon_status.get_node("PortraitFrame/ProtagonistPortrait").visible, "Sea-map HUD must replace the protagonist portrait.")
	_expect(moon_frame.texture.resource_path.ends_with("function_button.png"), "Lunar clock must retain the standalone diamond frame.")
	_expect(moon_icon.texture.resource_path.ends_with("moon_clock_moon.png") and moon_icon.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Lunar clock must use the generated nearest-filtered moon texture.")
	_expect(moon_phase_name.text == "新月", "Sea-map lunar clock must begin at the new moon.")
	hud.call("set_lunar_day", 7.375)
	_expect(moon_phase_name.text == "上弦月" and is_equal_approx(float(moon_material.get_shader_parameter("phase")), 0.25), "Quarter-cycle lunar day must display the first-quarter moon.")
	hud.call("set_lunar_day", 14.75)
	_expect(moon_phase_name.text == "满月" and is_equal_approx(float(moon_material.get_shader_parameter("phase")), 0.5), "Half-cycle lunar day must display the full moon.")
	if DisplayServer.get_name() != "headless":
		await process_frame
		var full_moon_screenshot_error := root.get_texture().get_image().save_png(FULL_MOON_SCREENSHOT_PATH)
		_expect(full_moon_screenshot_error == OK, "Full-moon HUD preview screenshot could not be saved.")
	hud.call("set_lunar_day", float(root.get_meta("sea_overworld_lunar_day", 0.0)))
	_expect(moon_status.size.is_equal_approx(Vector2(195.0, 195.0)), "Lunar clock must keep the large top-left diamond footprint.")
	_expect(moon_status.position.x > quest_tracker.position.x and moon_status.position.y + moon_status.size.y < quest_tracker.position.y, "Lunar clock must sit directly above and to the right of the task tracker origin.")
	_expect(map_frame.texture.resource_path.ends_with("function_button.png"), "Sea-map entry must retain the standalone diamond frame.")
	_expect(map_icon.texture.resource_path.ends_with("hud_map_v1.png"), "Sea-map entry must use the generated ink-wash map icon.")
	_expect(map_status.size.is_equal_approx(Vector2(136.0, 136.0)), "Sea-map diamond must use the compact bottom-right footprint.")
	_expect(is_equal_approx(map_status.anchor_left, 1.0) and is_equal_approx(map_status.anchor_top, 1.0), "Sea-map diamond must stay anchored to the bottom-right corner.")

	map_button.pressed.emit()
	await process_frame
	await process_frame
	var map_screen := hud.get_node("SeaMapScreen") as Control
	var map_panel := map_screen.get_node("MapPanel") as Panel
	var map_title := map_panel.get_node("Title") as Label
	var generated_scroll_frame := map_panel.get_node("GeneratedScrollFrame") as TextureRect
	var map_viewport := map_panel.get_node("MapViewport") as Control
	var map_texture_layer := map_screen.get_node("MapPanel/MapViewport/MapTextureLayer") as Control
	var map_texture := map_texture_layer.get_node("MapTexture") as TextureRect
	var east_map_texture := map_texture_layer.get_node("MapTexture2") as TextureRect
	var c_map_texture := map_texture_layer.get_node("MapTexture3") as TextureRect
	var d_map_texture := map_texture_layer.get_node("MapTexture4") as TextureRect
	var location_layer := map_screen.get_node("MapPanel/MapViewport/MapLocationLayer") as Control
	var player_name := map_screen.get_node("MapPanel/MapViewport/PlayerMarker/PlayerName") as Label
	_expect(map_screen.visible, "Clicking the sea-map diamond must open the full map screen.")
	_expect(map_panel.size.is_equal_approx(Vector2(1280, 853)), "Full sea map must use the large unfolded-chart footprint.")
	_expect(generated_scroll_frame.texture.resource_path.ends_with("sea_map_scroll_frame_v1.png"), "Full sea map must use the generated ink-pixel chart scroll frame.")
	_expect(map_viewport.size.is_equal_approx(Vector2(870, 510)), "Detailed map content must sit inside the scroll's central safe area.")
	_expect(map_panel.get_node_or_null("Hint") == null, "Full sea map must not retain the old bottom explanatory caption.")
	_expect(is_equal_approx(map_title.position.y, 102.0), "The Lingnan sea-map title must move farther down inside its plaque.")
	_expect(not player.controls_enabled, "Opening the full map must pause sea-map movement.")
	var paused_lunar_day := float(root.get_meta("sea_overworld_lunar_day", 0.0))
	Input.action_press("move_right")
	for _frame in range(3):
		await physics_frame
	Input.action_release("move_right")
	_expect(is_equal_approx(float(root.get_meta("sea_overworld_lunar_day", 0.0)), paused_lunar_day), "Opening the full map must pause lunar time progression.")
	_expect(map_texture.texture.resource_path.ends_with("guangdong_sea_zone_a_v3.png"), "Full map screen must show production chunk A.")
	_expect(east_map_texture.texture.resource_path.ends_with("guangdong_sea_zone_b_v3.png"), "Full map screen must show production chunk B.")
	_expect(east_map_texture.material is ShaderMaterial, "Full map B texture must retain seam blending.")
	_expect(c_map_texture.texture.resource_path.ends_with("guangdong_sea_zone_c_v3.png"), "Full map screen must show production chunk C.")
	_expect(c_map_texture.material is ShaderMaterial, "Full map C-zone texture must retain seam blending.")
	_expect(bool((c_map_texture.material as ShaderMaterial).get_shader_parameter("fade_from_top")), "Full map C-zone texture must fade from its north edge.")
	_expect(d_map_texture.texture.resource_path.ends_with("guangdong_sea_zone_d_v3.png"), "Full map screen must show production chunk D.")
	_expect(d_map_texture.material is ShaderMaterial, "Full map D-zone texture must retain seam blending.")
	_expect(bool((d_map_texture.material as ShaderMaterial).get_shader_parameter("fade_from_left")), "Full map D-zone texture must fade from its west edge.")
	_expect(bool((d_map_texture.material as ShaderMaterial).get_shader_parameter("fade_from_top")), "Full map D-zone texture must fade from its north edge.")
	_expect(location_layer.get_child_count() == 15, "Full map must show exactly the fifteen enterable island labels.")
	var location_names: Array[String] = []
	var east_bay_map_label: Label
	var qingyu_map_label: Label
	var xuanchao_map_label: Label
	var south_harbor_map_label: Label
	var chuanshan_map_label: Label
	for location_label in location_layer.get_children():
		var label := location_label as Label
		location_names.append(label.text)
		if "东湾水寨" in label.text:
			east_bay_map_label = label
		elif "青屿秘境" in label.text:
			qingyu_map_label = label
		elif "玄潮古屿" in label.text:
			xuanchao_map_label = label
		elif "南海军港" in label.text:
			south_harbor_map_label = label
		elif "川山渔村" in label.text:
			chuanshan_map_label = label
	for expected_name in ["南海军港", "川山渔村", "东湾水寨", "青屿秘境", "红湾卫所", "倭寇营地", "澄海灯岛", "龙门海寨", "白沙渔岛", "玄潮古屿", "沧门礁堡", "月环商港", "雾岚群岛", "伏波古岭", "珊湾渔链"]:
		_expect(location_names.any(func(text: String) -> bool: return expected_name in text), "Full map is missing the %s island label." % expected_name)
	_expect(location_names.all(func(text: String) -> bool: return "南澳商港" not in text), "Full map must not retain the retired South Australia merchant-port name.")
	for hidden_name in ["茶叶商船", "私盐商船", "岭南商船", "漂流木箱"]:
		_expect(location_names.all(func(text: String) -> bool: return hidden_name not in text), "Full map must not display NPC ships or random events.")
	_expect(qingyu_map_label != null and (qingyu_map_label.get_meta("world_position", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(2800, 400)), "Qingyu full-map label must align to the pagoda island's upper-right.")
	_expect(xuanchao_map_label != null and (xuanchao_map_label.get_meta("world_position", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(2620, 2600)), "Xuanchao full-map label must sit at the reefs' lower-right.")
	_expect(south_harbor_map_label != null and (south_harbor_map_label.get_meta("world_position", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(480, 1040)), "South Sea Harbor's full-map name must move to the southwest crescent harbor.")
	_expect(chuanshan_map_label != null and (chuanshan_map_label.get_meta("world_position", Vector2.ZERO) as Vector2).is_equal_approx(Vector2(1080, 430)), "Chuanshan's full-map name must move upward onto the northeast mainland houses.")
	if east_bay_map_label != null and qingyu_map_label != null:
		var east_bay_label_center := east_bay_map_label.position + east_bay_map_label.size * 0.5
		var qingyu_label_center := qingyu_map_label.position + qingyu_map_label.size * 0.5
		_expect(absf(qingyu_label_center.x - east_bay_label_center.x) >= 120.0, "Qingyu and East Bay label text must retain clear horizontal separation on the full map.")
	_expect(player_name.text == "当前位置", "Full map player marker must display only the current-position label.")
	if DisplayServer.get_name() != "headless":
		var map_screenshot_error := root.get_texture().get_image().save_png(MAP_SCREENSHOT_PATH)
		_expect(map_screenshot_error == OK, "Sea overworld full-map preview screenshot could not be saved.")
	var map_close_button := map_screen.get_node("MapPanel/CloseButton") as Button
	map_close_button.pressed.emit()
	await process_frame
	_expect(not map_screen.visible and player.controls_enabled, "Closing the full map must restore sea-map movement.")


func _verify_keyboard_movement(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var wake := player.get_node("WakeSprite") as Sprite2D
	var ship := player.get_node("VisualRoot/ShipSprite") as Sprite2D
	var hero := player.get_node("VisualRoot/HeroSprite") as Sprite2D
	var starting_position := player.position
	var starting_lunar_day := float(root.get_meta("sea_overworld_lunar_day", 0.0))
	Input.action_press("move_right")
	for _frame in range(4):
		await physics_frame
	var moving_ship_y := ship.position.y
	var moving_hero_y := hero.position.y
	_expect(player.position.x > starting_position.x, "WASD/direction input did not move the sea-map ship.")
	_expect(wake.visible, "Moving ship must show the animated wake layer.")
	_expect(float(root.get_meta("sea_overworld_lunar_day", 0.0)) > starting_lunar_day, "Sailing must advance lunar time.")
	var task_objective := root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/Objective") as Label
	_expect("点击进入按钮" in task_objective.text, "Sailing from the harbor spawn must not regress the location-entry task step.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var screenshot_error := root.get_texture().get_image().save_png(MOVEMENT_SCREENSHOT_PATH)
		_expect(screenshot_error == OK, "Sea overworld movement preview screenshot could not be saved.")
	Input.action_release("move_right")
	await physics_frame
	await physics_frame
	_expect(not wake.visible, "Ship wake must hide after movement stops.")
	_expect(is_zero_approx(moving_ship_y), "The sailing ship frame must retain its approved visual position.")
	_expect(is_equal_approx(ship.position.y, -98.0 * ship.scale.y), "The stopped ship frame must compensate its 98-pixel atlas deck-anchor offset.")
	_expect(is_equal_approx(hero.position.y, moving_hero_y), "The protagonist must stay attached to the same ship-deck anchor when movement stops.")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var stopped_screenshot_error := root.get_texture().get_image().save_png(STOPPED_SCREENSHOT_PATH)
		_expect(stopped_screenshot_error == OK, "Sea overworld stopped-state preview screenshot could not be saved.")
	var stopped_lunar_day := float(root.get_meta("sea_overworld_lunar_day", 0.0))
	for _frame in range(3):
		await physics_frame
	_expect(is_equal_approx(float(root.get_meta("sea_overworld_lunar_day", 0.0)), stopped_lunar_day), "Lunar time must stop when the ship is not sailing.")


func _verify_location_interaction(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var prompt := scene.get_node("UI/Root/InteractionPrompt") as Control
	var enter_button := scene.get_node("UI/Root/InteractionPrompt/EnterButton") as BaseButton
	var texture_button := enter_button as TextureButton
	var location_label := scene.get_node("UI/Root/InteractionPrompt/LocationName") as Label
	var toast := root.get_node("ExplorationUI/HUD/ComingSoonToast") as Control
	var toast_label := root.get_node("ExplorationUI/HUD/ComingSoonToast/Message") as Label
	var task_objective := root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/Objective") as Label
	var locations := get_nodes_in_group("sea_location")
	_expect(not locations.is_empty(), "Sea overworld must provide at least one location trigger.")
	_expect(texture_button.texture_normal.resource_path == "res://assets/ui/sea_overworld/interaction_button_ink_v1.png", "Location interaction must use the ink-wash normal button asset.")
	_expect(texture_button.texture_pressed.resource_path == "res://assets/ui/sea_overworld/interaction_button_ink_active_v1.png", "Location interaction must use the ink-wash pressed button asset.")
	_expect(prompt.size.is_equal_approx(Vector2(360.0, 88.0)), "Ink-wash interaction prompt must keep its intended 2x asset scale.")
	if locations.is_empty():
		return
	var location := _find_location(locations, "川山渔村")
	_expect(location != null, "A non-harbor location is required for the coming-soon interaction check.")
	if location == null:
		return
	_expect(location.get_node_or_null("IslandOutline") == null, "Location proximity must not draw a yellow island outline.")
	_expect(location.get_node_or_null("HighlightRing") == null, "Location highlight must not use a circular ring.")
	_expect(location.get_node_or_null("HighlightedName") == null, "Location names must not be drawn over islands; the bottom prompt is sufficient.")
	player.global_position = _find_clear_entry_point(location)
	await physics_frame
	await physics_frame
	_expect(prompt.visible, "Approaching a location must show the highlighted interaction prompt.")
	_expect("川山渔村" in location_label.text, "The bottom interaction prompt must retain the active location name.")
	_expect("点击进入按钮" in task_objective.text, "Approaching an island must advance the explore-map task flow.")
	var position_before_prompt := player.position
	await physics_frame
	_expect(player.position.is_equal_approx(position_before_prompt), "Location proximity must not automatically move or slow the stopped ship.")
	enter_button.pressed.emit()
	await process_frame
	_expect(toast.visible and "该地点即将开放" in toast_label.text, "Enter button must show the location coming-soon message.")
	_expect("接触海上的船只" in task_objective.text, "Trying to enter an island must advance the explore-map task flow.")
	player.global_position = Vector2(1800, 1200)
	for _frame in range(4):
		await physics_frame
	await process_frame
	_expect(not prompt.visible, "Leaving a location range must hide its interaction prompt.")

	var east_bay: Area2D
	var qingyu: Area2D
	for location_node in locations:
		if str(location_node.get_meta("location_name", "")) == "东湾水寨":
			east_bay = location_node as Area2D
		elif str(location_node.get_meta("location_name", "")) == "青屿秘境":
			qingyu = location_node as Area2D
	_expect(east_bay != null, "East Bay stronghold trigger is missing.")
	if east_bay != null:
		var east_bay_shape_node := east_bay.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(east_bay_shape_node.shape is CircleShape2D, "East Bay must use a focused circular dock entry.")
		_expect((east_bay.global_position + east_bay_shape_node.position).is_equal_approx(Vector2(2180, 760)), "East Bay entry range must align to the island's lower dock.")
		player.global_position = _find_clear_entry_point(east_bay)
		for _frame in range(3):
			await physics_frame
		_expect(prompt.visible and "东湾水寨" in location_label.text, "East Bay entry must remain reachable from open water.")
	player.global_position = Vector2(1800, 1200)
	for _frame in range(3):
		await physics_frame
	_expect(qingyu != null, "Qingyu secret realm trigger is missing.")
	if qingyu != null:
		var qingyu_shape_node := qingyu.get_node("EntryTriggerShape") as CollisionShape2D
		_expect(qingyu_shape_node.shape is RectangleShape2D and qingyu_shape_node.position.y > 0.0, "Qingyu pagoda-island entry must use a south-side rectangular trigger.")
		player.global_position = _find_clear_entry_point(qingyu)
		await physics_frame
		await physics_frame
		_expect(prompt.visible and "青屿秘境" in location_label.text, "Qingyu secret realm must remain reachable from open water.")


func _verify_b_expansion(scene: Node) -> void:
	var b_locations := _collect_region_locations(B_LOCATIONS, "B")
	_expect(b_locations.size() == 5, "B must contain five upper-right water-combat locations.")
	await _verify_region_interactions(scene, b_locations, "月环商港", B_ZONE_SCREENSHOT_PATH)


func _verify_c_expansion(scene: Node) -> void:
	var c_locations := _collect_region_locations(C_LOCATIONS, "C")
	_expect(c_locations.size() == 4, "C must contain four lower-left frontier locations.")
	await _verify_c_directional_entries(scene, c_locations)
	await _verify_region_interactions(scene, c_locations, "龙门海寨", C_ZONE_SCREENSHOT_PATH)


func _verify_c_directional_entries(scene: Node, c_locations: Array[Area2D]) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var prompt := scene.get_node("UI/Root/InteractionPrompt") as Control
	var location_label := scene.get_node("UI/Root/InteractionPrompt/LocationName") as Label
	var xuanchao := _find_location(c_locations, "玄潮古屿")
	var white_sand := _find_location(c_locations, "白沙渔岛")
	if xuanchao != null:
		for shape_node in _location_trigger_shapes(xuanchao):
			player.global_position = Vector2(1800, 2100)
			for _frame in range(2):
				await physics_frame
			player.global_position = xuanchao.global_position + shape_node.position
			for _frame in range(3):
				await physics_frame
			_expect(prompt.visible and "玄潮古屿" in location_label.text, "Each Xuanchao north/south/east entry point must activate the location prompt.")
		player.global_position = Vector2(1880, 2395)
		for _frame in range(3):
			await physics_frame
		_expect(not prompt.visible or "玄潮古屿" not in location_label.text, "The west side of Xuanchao must not activate its location prompt.")
	if white_sand != null:
		player.global_position = Vector2(1800, 2100)
		for _frame in range(2):
			await physics_frame
		var dock_shape := white_sand.get_node("EntryTriggerShape") as CollisionShape2D
		player.global_position = white_sand.global_position + dock_shape.position
		for _frame in range(3):
			await physics_frame
		_expect(prompt.visible and "白沙渔岛" in location_label.text, "White Sand's south dock entry point must activate the location prompt.")


func _verify_d_expansion(scene: Node) -> void:
	var d_locations := _collect_region_locations(D_LOCATIONS, "D")
	_expect(d_locations.size() == 2, "D must contain two lower-right enemy-core locations matching the two visible islands.")
	await _verify_region_interactions(scene, d_locations, "倭寇营地", D_ZONE_SCREENSHOT_PATH)


func _collect_region_locations(names: Array, region_name: String) -> Array[Area2D]:
	var all_locations := get_nodes_in_group("sea_location")
	var region_locations: Array[Area2D] = []
	for expected_name in names:
		var location := _find_location(all_locations, expected_name)
		_expect(location != null, "%s-zone location %s is missing." % [region_name, expected_name])
		if location == null:
			continue
		region_locations.append(location)
		if expected_name == "伏波古岭":
			_expect(str(location.get_meta("entry_message", "")) == "进入伏波古岭", "Fubo Ridge must retain its playable entry message.")
			_expect(str(location.get_meta("target_scene_path", "")).ends_with("fubo_guling.tscn"), "Fubo Ridge must retain its playable scene target.")
		else:
			_expect(str(location.get_meta("entry_message", "")) == "该岛屿即将开放", "%s must use the island coming-soon message." % expected_name)
	return region_locations


func _verify_region_interactions(scene: Node, locations: Array[Area2D], preview_name: String, screenshot_path: String) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var prompt := scene.get_node("UI/Root/InteractionPrompt") as Control
	var enter_button := scene.get_node("UI/Root/InteractionPrompt/EnterButton") as BaseButton
	var location_label := scene.get_node("UI/Root/InteractionPrompt/LocationName") as Label
	var toast_label := root.get_node("ExplorationUI/HUD/ComingSoonToast/Message") as Label
	for location in locations:
		player.global_position = Vector2(1800, 1200)
		for _frame in range(3):
			await physics_frame
		player.global_position = _find_clear_entry_point(location)
		for _frame in range(3):
			await physics_frame
		var location_name := str(location.get_meta("location_name", ""))
		_expect(prompt.visible and location_name in location_label.text, "%s must expose its entry prompt from collision-free water." % location_name)
		if not str(location.get_meta("target_scene_path", "")).is_empty():
			continue
		enter_button.pressed.emit()
		await process_frame
		_expect(location_name in toast_label.text and "该岛屿即将开放" in toast_label.text, "%s must show the island coming-soon toast." % location_name)

	if DisplayServer.get_name() != "headless":
		var preview_location := _find_location(locations, preview_name)
		if preview_location != null:
			player.global_position = _find_clear_entry_point(preview_location)
			(player.get_node("Camera2D") as Camera2D).reset_smoothing()
			for _frame in range(3):
				await physics_frame
			enter_button.pressed.emit()
			await process_frame
			await RenderingServer.frame_post_draw
			var screenshot_error := root.get_texture().get_image().save_png(screenshot_path)
			_expect(screenshot_error == OK, "%s preview screenshot could not be saved." % preview_name)

	player.global_position = Vector2(1800, 1200)
	for _frame in range(3):
		await physics_frame


func _verify_navigation_collisions(scene: Node) -> void:
	var world_collision := scene.get_node("World/WorldCollision") as StaticBody2D
	_expect(world_collision.get_child_count() == 32, "Production map must retain the approved 32 serialized coastline/island blockers without runtime duplication.")
	for collision_child in world_collision.get_children():
		_expect(not collision_child.name.is_empty(), "Every production collision component must have a diagnostic name.")
		_expect("wreck" not in collision_child.name.to_lower(), "The decorative central wreck must not receive collision.")
	for route_name in NAVIGATION_ROUTES:
		var points: Array = NAVIGATION_ROUTES[route_name]
		for index in range(points.size() - 1):
			var start: Vector2 = points[index]
			var finish: Vector2 = points[index + 1]
			var steps := maxi(1, ceili(start.distance_to(finish) / 24.0))
			for step in range(steps + 1):
				var point := start.lerp(finish, step / float(steps))
				if not _is_water_clear(point, 19.0):
					_expect(false, "Navigation route %s is blocked at %s." % [route_name, point])
					break
	for land_point in LAND_COLLISION_PROBES:
		_expect(not _is_water_clear(land_point, 2.0), "Major visible land at %s must block navigation." % land_point)
	for water_point in [Vector2(880, 1170), Vector2(3200, 440), Vector2(2150, 1720), Vector2(4280, 2640)]:
		_expect(_is_water_clear(water_point, 19.0), "Required spawn/harbor/wreck water at %s must remain clear." % water_point)
	for location in get_nodes_in_group("sea_location"):
		_expect(_is_water_clear(_find_clear_entry_point(location as Area2D), 19.0), "%s entry must retain reachable water." % location.get_meta("location_name"))
	for trigger in get_nodes_in_group("sea_auto_trigger"):
		_expect(_is_water_clear((trigger as Area2D).global_position, 19.0), "%s auto trigger must remain on open water." % trigger.get_meta("display_name"))


func _capture_central_seam(scene: Node) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var player := scene.get_node("World/Player") as CharacterBody2D
	player.global_position = Vector2(2450, 1400)
	(root.get_node("ExplorationUI/HUD/ComingSoonToast") as Control).hide()
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	for _frame in range(3):
		await physics_frame
	await RenderingServer.frame_post_draw
	var screenshot_error := root.get_texture().get_image().save_png(CENTRAL_SEAM_SCREENSHOT_PATH)
	_expect(screenshot_error == OK, "Central four-chunk seam screenshot could not be saved.")


func _verify_auto_triggers(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var toast_label := root.get_node("ExplorationUI/HUD/ComingSoonToast/Message") as Label
	var event_dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	var triggers := get_nodes_in_group("sea_auto_trigger")
	var saw_event := false
	var saw_ship := false
	for trigger_node in triggers:
		var trigger := trigger_node as Area2D
		player.global_position = Vector2(1240, 1120)
		await physics_frame
		player.global_position = trigger.global_position
		await physics_frame
		await physics_frame
		var kind := str(trigger.get_meta("trigger_kind"))
		if kind == "ship":
			saw_ship = saw_ship or "该船只开发中" in toast_label.text
		elif kind == "event":
			saw_event = saw_event or event_dialogue.visible
			var option_box := event_dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer
			if option_box.get_child_count() == 2:
				(option_box.get_child(1) as Button).pressed.emit()
				await process_frame
	_expect(saw_ship, "Touching a sea-map ship must automatically show its development placeholder.")
	_expect(saw_event, "Touching the drifting crate must open the soldier choice dialogue.")
	var task_objective := root.get_node("ExplorationUI/HUD/QuestTracker/MainQuest/Objective") as Label
	_expect(task_objective.text == "继续探索岭南海域", "Sea target contact must finish the prototype exploration task flow.")


func _capture_preview(scene: Node) -> void:
	var player := scene.get_node("World/Player") as CharacterBody2D
	var enter_button := scene.get_node("UI/Root/InteractionPrompt/EnterButton") as BaseButton
	var locations := get_nodes_in_group("sea_location")
	if locations.is_empty():
		return
	var location := _find_location(locations, "川山渔村")
	if location == null:
		return
	player.global_position = _find_clear_entry_point(location)
	for _frame in range(4):
		await physics_frame
	enter_button.pressed.emit()
	await process_frame
	await process_frame
	if DisplayServer.get_name() == "headless":
		print("Sea overworld preview skipped in headless display mode.")
		return
	var screenshot_error := root.get_texture().get_image().save_png(SCREENSHOT_PATH)
	_expect(screenshot_error == OK, "Sea overworld preview screenshot could not be saved.")


func _find_location(locations: Array, location_name: String) -> Area2D:
	for location_node in locations:
		if str(location_node.get_meta("location_name", "")) == location_name:
			return location_node as Area2D
	return null


func _find_clear_entry_point(area: Area2D) -> Vector2:
	var shape_node := area.get_node("EntryTriggerShape") as CollisionShape2D
	var offsets: Array[Vector2] = [shape_node.position]
	if shape_node.shape is RectangleShape2D:
		var size := (shape_node.shape as RectangleShape2D).size
		for x_factor in [-0.4, 0.0, 0.4]:
			for y_factor in [-0.4, 0.0, 0.4]:
				offsets.append(shape_node.position + Vector2(size.x * x_factor, size.y * y_factor))
	elif shape_node.shape is CircleShape2D:
		var radius := (shape_node.shape as CircleShape2D).radius * 0.75
		for index in range(8):
			offsets.append(shape_node.position + Vector2.from_angle(TAU * index / 8.0) * radius)
	for offset in offsets:
		var point := area.global_position + offset
		if _is_water_clear(point, 19.0):
			return point
	return area.global_position + shape_node.position


func _trigger_contains_point(area: Area2D, point: Vector2) -> bool:
	for shape_node in _location_trigger_shapes(area):
		var local_point := point - area.global_position - shape_node.position
		if shape_node.shape is RectangleShape2D:
			var half_size := (shape_node.shape as RectangleShape2D).size * 0.5
			if absf(local_point.x) <= half_size.x and absf(local_point.y) <= half_size.y:
				return true
		elif shape_node.shape is CircleShape2D:
			if local_point.length() <= (shape_node.shape as CircleShape2D).radius:
				return true
	return false


func _location_trigger_shapes(area: Area2D) -> Array[CollisionShape2D]:
	var shape_nodes: Array[CollisionShape2D] = []
	for child in area.get_children():
		if child is CollisionShape2D:
			shape_nodes.append(child as CollisionShape2D)
	return shape_nodes


func _is_water_clear(point: Vector2, radius: float, excluded_body: CollisionObject2D = null) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1
	query.collide_with_areas = false
	query.collide_with_bodies = true
	if excluded_body != null:
		query.exclude = [excluded_body.get_rid()]
	return root.world_2d.direct_space_state.intersect_shape(query, 1).is_empty()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
