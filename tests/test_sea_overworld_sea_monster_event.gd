extends SceneTree

const SEA_SCENE := preload("res://scenes/sea_overworld/sea_overworld.tscn")
const SHADOW_SOURCE_PATHS := [
	"res://assets/sprites/sea_overworld/random_events/海怪水下影1_v2.png",
	"res://assets/sprites/sea_overworld/random_events/海怪水下影2_v2.png",
	"res://assets/sprites/sea_overworld/random_events/海怪水下影3_v2.png",
]
const SURFACE_MIST_PATH := "res://assets/sprites/sea_overworld/random_events/海怪贴海薄雾_v2.png"
const PORTRAIT_PATHS := [
	"res://assets/sea_overworld/portraits/海怪1.png",
	"res://assets/sea_overworld/portraits/海怪2.png",
	"res://assets/sea_overworld/portraits/海怪3.png",
]
const DEEP_WATER_SPAWN_POINTS: Array[Vector2] = [
	Vector2(1600, 1900),
	Vector2(4580, 250),
	Vector2(4580, 1530),
]
const SEA_MONSTER_SPAWN_CLEARANCE := 220.0
const MAP_PREVIEW_PATHS := [
	"res://.godot/sea_overworld_monster_mist_variant1_preview.png",
	"res://.godot/sea_overworld_monster_mist_variant2_preview.png",
	"res://.godot/sea_overworld_monster_mist_variant3_preview.png",
]
const DIALOGUE_PREVIEW_PATH := "res://.godot/sea_overworld_monster_dialogue_preview.png"

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for variant in range(3):
		var scene := await _spawn_scene(variant)
		await _verify_default_victory(scene, variant)
		scene.queue_free()
		await process_frame
	var avoid_scene := await _spawn_scene(0)
	await _verify_avoid_branch(avoid_scene)
	avoid_scene.queue_free()
	await process_frame
	if failures.is_empty():
		print("Sea overworld sea-monster event verification passed.")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	quit(1)


func _spawn_scene(variant: int) -> Node:
	root.get_node("GameState").call("reset_runtime_world_state")
	var scene := SEA_SCENE.instantiate()
	scene.set("_random_event_seed_override", 1)
	scene.set("_sea_monster_variant_override", variant)
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	return scene


func _verify_default_victory(scene: Node, variant: int) -> void:
	var event := _verify_map_visual(scene, variant)
	if event == null:
		return
	var player := scene.get_node("World/Player") as CharacterBody2D
	var dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	var economy_before: Dictionary = root.get_node("GameState").call("get_economy_state")
	await _capture_map_preview(scene, event, player, variant)
	player.global_position = event.global_position
	for _frame in range(3):
		await physics_frame
	_verify_initial_dialogue(dialogue, player)
	var option_box := _option_box(dialogue)
	if option_box.get_child_count() != 2:
		return
	(option_box.get_child(0) as Button).pressed.emit()
	await process_frame
	var speaker := dialogue.get_node("NamePlate/SpeakerLabel") as Label
	var line := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label
	var portrait := dialogue.get_node("LargeTransparentPortrait") as TextureRect
	_expect(speaker.text == "海中异兽" and "海怪" in line.text, "Approaching the mist must reveal a sea monster in dialogue.")
	_expect(portrait.texture != null and portrait.texture.resource_path == PORTRAIT_PATHS[variant], "Sea-monster variant %d must reveal its matching portrait." % (variant + 1))
	if portrait.texture != null:
		var portrait_image := portrait.texture.get_image()
		var portrait_last := portrait_image.get_size() - Vector2i.ONE
		_expect(
			portrait_image.get_pixel(0, 0).a < 0.05
			and portrait_image.get_pixel(portrait_last.x, 0).a < 0.05
			and portrait_image.get_pixel(0, portrait_last.y).a < 0.05
			and portrait_image.get_pixel(portrait_last.x, portrait_last.y).a < 0.05,
			"Sea-monster portrait variant %d must have a transparent outer background." % (variant + 1)
		)
	if variant == 1:
		await _capture_dialogue_preview()
	option_box = _option_box(dialogue)
	_expect(option_box.get_child_count() == 1, "Revealed sea monster must provide one placeholder battle choice.")
	if option_box.get_child_count() != 1:
		return
	_expect("默认获胜" in (option_box.get_child(0) as Button).text, "Placeholder battle choice must explicitly state the default victory.")
	(option_box.get_child(0) as Button).pressed.emit()
	await process_frame
	await process_frame
	_expect(scene.get_node_or_null("World/WorldMarkers/SeaMonsterMistEvent") == null, "Winning must remove the current mist event instance.")
	var result_line := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label
	var detail := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DetailLabel") as RichTextLabel
	_expect("战胜海怪" in result_line.text, "Default victory result must explicitly say the sea monster was defeated.")
	_expect("木材 +500" in detail.get_parsed_text() and "铁石 +500" in detail.get_parsed_text(), "Victory result must show both large material rewards.")
	var economy_after: Dictionary = root.get_node("GameState").call("get_economy_state")
	_expect(
		int(economy_after["items"].get("wood", 0)) == int(economy_before["items"].get("wood", 0)) + 500
		and int(economy_after["items"].get("ironstone", 0)) == int(economy_before["items"].get("ironstone", 0)) + 500,
		"Default victory must add 500 wood and 500 ironstone to the real inventory."
	)
	option_box = _option_box(dialogue)
	if option_box.get_child_count() == 1:
		(option_box.get_child(0) as Button).pressed.emit()
		await process_frame
	_expect(not dialogue.visible and player.controls_enabled, "Finishing the sea-monster result must resume sailing.")


func _verify_avoid_branch(scene: Node) -> void:
	var event := _verify_map_visual(scene, 0)
	if event == null:
		return
	var player := scene.get_node("World/Player") as CharacterBody2D
	var dialogue := scene.get_node("UI/FieldEventDialogue") as Control
	var before: Dictionary = root.get_node("GameState").call("get_economy_state")
	player.global_position = event.global_position
	for _frame in range(3):
		await physics_frame
	var option_box := _option_box(dialogue)
	if option_box.get_child_count() != 2:
		return
	(option_box.get_child(1) as Button).pressed.emit()
	await process_frame
	await process_frame
	var after: Dictionary = root.get_node("GameState").call("get_economy_state")
	_expect(not dialogue.visible and player.controls_enabled, "Choosing to go around must close dialogue and resume sailing.")
	_expect(scene.get_node_or_null("World/WorldMarkers/SeaMonsterMistEvent") == null, "Going around must remove the current mist event.")
	_expect(after["items"] == before["items"], "Going around the suspicious shadow must grant no materials.")


func _verify_map_visual(scene: Node, variant: int) -> Area2D:
	var event := scene.get_node_or_null("World/WorldMarkers/SeaMonsterMistEvent") as Area2D
	_expect(event != null, "Sea-monster seed must create the suspicious mist event.")
	if event == null:
		return null
	var events: Array = scene.call("_active_random_events") as Array
	_expect(events.size() == 3, "Sea-monster entry must respect the three-event limit.")
	_expect(str(event.get_meta("display_name")) == "雾中可疑身影", "Map event must remain unidentified before interaction.")
	_expect(int(event.get_meta("sea_monster_variant", -1)) == variant, "Sea-monster event must retain its selected variant identity.")
	var uses_deep_water_anchor := false
	for spawn_point in DEEP_WATER_SPAWN_POINTS:
		if event.global_position.distance_to(spawn_point) < 0.1:
			uses_deep_water_anchor = true
		_expect(
			bool(scene.call("_is_open_water_for_random_event", spawn_point, SEA_MONSTER_SPAWN_CLEARANCE)),
			"Sea-monster deep-water anchor %s must keep a 220-unit clear radius from island collision." % spawn_point
		)
	_expect(uses_deep_water_anchor, "Sea-monster event must spawn at one of the three approved broad-water anchors.")
	var sprite := event.get_node("EventVisual/MistSprite") as Sprite2D
	_expect(sprite.texture != null and sprite.texture.resource_path == SURFACE_MIST_PATH, "Sea-monster event must use the shared low-contrast surface-mist layer.")
	var mist_image := sprite.texture.get_image()
	var last_pixel := mist_image.get_size() - Vector2i.ONE
	_expect(
		mist_image.get_pixel(0, 0).a < 0.05
		and mist_image.get_pixel(last_pixel.x, 0).a < 0.05
		and mist_image.get_pixel(0, last_pixel.y).a < 0.05
		and mist_image.get_pixel(last_pixel.x, last_pixel.y).a < 0.05,
		"Sea-monster variant %d must retain a genuinely transparent outer background." % (variant + 1)
	)
	var shader_material := sprite.material as ShaderMaterial
	_expect(shader_material != null and shader_material.shader.resource_path.ends_with("sea_event_vignette.gdshader"), "Mist sprite must use edge fading so it blends into the overworld sea.")
	_expect(float(shader_material.get_shader_parameter("fog_motion_speed")) > 0.0, "Mist shader must animate the surface fog with time-driven drift.")
	_expect(float(shader_material.get_shader_parameter("fog_opacity_variation")) > 0.0, "Mist shader must give the surface fog a restrained opacity variation.")
	_expect(float(shader_material.get_shader_parameter("fog_brightness_variation")) > 0.0, "Mist shader must give the surface fog a restrained brightness variation.")
	_expect("TIME" in shader_material.shader.code and "warped_uv" in shader_material.shader.code, "Mist shader must distort and breathe the pixel-ink fog over time.")
	var shadow := event.get_node("EventVisual/MonsterShadow") as Sprite2D
	_expect(shadow.texture != null and shadow.texture.resource_path == SHADOW_SOURCE_PATHS[variant], "Sea-monster variant %d must retain its matching creature identity beneath the mist." % (variant + 1))
	var shadow_material := shadow.material as ShaderMaterial
	_expect(shadow_material != null and shadow_material.shader.resource_path.ends_with("sea_monster_shadow.gdshader"), "Monster silhouette must be recolored and dissolved as an underwater pixel-ink shadow.")
	_expect("source.a" in shadow_material.shader.code and "pixel_step" in shadow_material.shader.code, "Monster shadow shader must preserve the generated silhouette alpha and retain pixel clusters.")
	var ripple := event.get_node("EventVisual/SurfaceRipple") as ColorRect
	var ripple_material := ripple.material as ShaderMaterial
	_expect(ripple_material != null and ripple_material.shader.resource_path.ends_with("sea_monster_ripple.gdshader"), "Sea-monster event must disturb the sea with animated elliptical ripples.")
	_expect("TIME" in ripple_material.shader.code and "ripple_band" in ripple_material.shader.code, "Sea-monster ripple must expand and fade over time.")
	_expect(event.find_children("*", "Label", true, false).is_empty(), "Suspicious mist must show no identifying map label.")
	return event


func _verify_initial_dialogue(dialogue: Control, player: CharacterBody2D) -> void:
	_expect(dialogue.visible and not player.controls_enabled, "Touching suspicious mist must open dialogue and pause sailing.")
	var speaker := dialogue.get_node("NamePlate/SpeakerLabel") as Label
	var line := dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/DialogueLabel") as Label
	_expect(speaker.text == "水师士兵" and "青灰薄雾" in line.text and "黑影" in line.text, "Initial report must describe surface mist and an unidentified underwater shadow.")
	var option_box := _option_box(dialogue)
	_expect(option_box.get_child_count() == 2, "Suspicious mist must show exactly two initial choices.")
	if option_box.get_child_count() == 2:
		_expect((option_box.get_child(0) as Button).text == "靠近查看  ▶", "First suspicious-mist choice must be 靠近查看.")
		_expect((option_box.get_child(1) as Button).text == "绕行  ▶", "Second suspicious-mist choice must be 绕行.")


func _capture_map_preview(scene: Node, event: Area2D, player: CharacterBody2D, variant: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var was_paused := paused
	paused = true
	(event.get_node("EventVisual") as CanvasItem).modulate.a = 1.0
	var camera := scene.get_node("World/Player/Camera2D") as Camera2D
	var smoothing_was_enabled := camera.position_smoothing_enabled
	camera.position_smoothing_enabled = false
	camera.global_position = event.global_position
	await create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(MAP_PREVIEW_PATHS[variant]) == OK, "Sea-monster mist map preview could not be saved.")
	camera.position = Vector2.ZERO
	camera.position_smoothing_enabled = smoothing_was_enabled
	camera.reset_smoothing()
	paused = was_paused


func _capture_dialogue_preview() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for _frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	_expect(root.get_texture().get_image().save_png(DIALOGUE_PREVIEW_PATH) == OK, "Sea-monster dialogue preview could not be saved.")


func _option_box(dialogue: Control) -> VBoxContainer:
	return dialogue.get_node("FullWidthPaperDialogueBox/DialogueMargin/DialogueStack/OptionBox") as VBoxContainer


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
