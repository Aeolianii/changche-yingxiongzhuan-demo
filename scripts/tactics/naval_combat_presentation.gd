class_name NavalCombatPresentation
extends Node2D

const FRAME_COUNTS := {"water": 9, "small": 8, "large": 10}
const WATER_TEXTURE = preload("res://assets/sprites/naval_tactics/fx/water_splash.png")
const SMALL_TEXTURE = preload("res://assets/sprites/naval_tactics/fx/explosion_small.png")
const LARGE_TEXTURE = preload("res://assets/sprites/naval_tactics/fx/explosion_large.png")
const CANNON_FIRE = preload("res://assets/audio/battle_at_sea/cannon_fire.ogg")
const CANNON_HIT = preload("res://assets/audio/battle_at_sea/cannon_hit_ship_short.ogg")
const SHIP_DESTROYED = preload("res://assets/audio/battle_at_sea/ship_destroyed_short.ogg")

const HULL_COLOR := Color("ff6f61")
const SAIL_COLOR := Color("66d8e6")
const RUDDER_COLOR := Color("f5b85b")
const EVENT_COLOR := Color("fff0b0")

var presentation_speed := 1.0
var last_sequence := ""
var last_callouts: Array[String] = []
var sequence_history: Array[String] = []
var _transient: Array[Node] = []
var _audio_players: Array[AudioStreamPlayer] = []
var _audio_cursor := 0


func _ready() -> void:
	for _index in 4:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_audio_players.append(player)


func build_frames(texture: Texture2D, frame_count: int) -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("play")
	frames.set_animation_loop("play", false)
	frames.set_animation_speed("play", 18.0)
	if texture == null or frame_count <= 0:
		return frames
	var frame_width := float(texture.get_width()) / float(frame_count)
	for frame_index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(frame_width * frame_index, 0.0, frame_width, texture.get_height())
		frames.add_frame("play", atlas)
	return frames


func active_effect_count() -> int:
	_transient = _transient.filter(func(node: Node) -> bool: return is_instance_valid(node) and not node.is_queued_for_deletion())
	return _transient.size()


func play_sail(ship_sprite: Sprite2D, path_centers: Array, final_rotation: float, reverse: bool) -> void:
	_begin_sequence("sail_reverse" if reverse else "sail")
	if not is_instance_valid(ship_sprite):
		return
	for center_value in path_centers:
		var center := Vector2(center_value)
		await _tween_property(ship_sprite, "position", center, 0.18)
	ship_sprite.rotation = final_rotation
	await _play_sheet("water", ship_sprite.position, 0.34)


func play_turn(ship_sprite: Sprite2D, final_rotation: float) -> void:
	_begin_sequence("turn")
	if not is_instance_valid(ship_sprite):
		return
	await _tween_property(ship_sprite, "rotation", final_rotation, 0.24)
	await _play_sheet("water", ship_sprite.position, 0.28)


func play_broadside(attacker_sprite: Sprite2D, target_sprite: Sprite2D, firing_side: String, result_view: Dictionary) -> void:
	_begin_sequence("broadside")
	_collect_damage_callouts(result_view)
	var coordinated_bonus := int(result_view.get("synergy_bonus", result_view.get("coordinated_bonus", 0)))
	if result_view.get("consumed_destabilized", false) or coordinated_bonus > 0:
		last_callouts.push_front("协同齐射 +%d" % coordinated_bonus)
	_play_audio(CANNON_FIRE)
	if is_instance_valid(attacker_sprite) and is_instance_valid(target_sprite):
		var side_sign := -1.0 if firing_side == "port" else 1.0
		var side_offset := Vector2.UP.rotated(attacker_sprite.rotation) * 9.0 * side_sign
		await _play_projectile_volley(attacker_sprite.position + side_offset, target_sprite.position, 3, Color("28343c"))
		await _shake(target_sprite, 5.0)
		_spawn_callouts(target_sprite.position)
		await _play_sheet("large", target_sprite.position, 0.38)
	_play_audio(CANNON_HIT)


func play_disrupt(attacker_sprite: Sprite2D, target_sprite: Sprite2D, result_view: Dictionary) -> void:
	_begin_sequence("disrupt")
	_collect_damage_callouts(result_view)
	if result_view.get("destabilized_applied", result_view.get("applied_destabilized", false)):
		last_callouts.append("失衡")
	_play_audio(CANNON_FIRE)
	if is_instance_valid(attacker_sprite) and is_instance_valid(target_sprite):
		await _play_projectile_volley(attacker_sprite.position, target_sprite.position, 2, Color("202b32"))
		await _shake(target_sprite, 3.0)
		_spawn_callouts(target_sprite.position)
		await _play_sheet("small", target_sprite.position, 0.34)
	_play_audio(CANNON_HIT)


func play_ram(attacker_sprite: Sprite2D, target_sprite: Sprite2D, movement_view: Dictionary, result_view: Dictionary) -> void:
	_begin_sequence("ram")
	_collect_damage_callouts(result_view)
	var collision_label: String = str({"open": "目标被推开", "obstacle": "触礁", "edge": "撞岸", "ship": "连环碰撞"}.get(str(result_view.get("collision", "open")), "冲撞"))
	last_callouts.push_front(collision_label)
	if result_view.get("destabilized_applied", result_view.get("applied_destabilized", false)):
		last_callouts.append("失衡")
	if is_instance_valid(attacker_sprite):
		await _tween_property(attacker_sprite, "position", Vector2(movement_view.get("attacker_position", attacker_sprite.position)), 0.22)
	if is_instance_valid(target_sprite):
		await _tween_property(target_sprite, "position", Vector2(movement_view.get("target_position", target_sprite.position)), 0.16)
		await _shake(target_sprite, 6.0)
		_spawn_callouts(target_sprite.position)
		await _play_sheet("water", target_sprite.position, 0.36)
		await _play_sheet("large", target_sprite.position, 0.40)
	_play_audio(CANNON_HIT)


func play_sink(target_sprite: Sprite2D) -> void:
	_begin_sequence("sink")
	_play_audio(SHIP_DESTROYED)
	if not is_instance_valid(target_sprite):
		return
	await _play_sheet("large", target_sprite.position, 0.48)
	if presentation_speed <= 0.0:
		target_sprite.modulate = Color(0.20, 0.25, 0.28, 0.0)
		target_sprite.scale *= 0.82
		return
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(target_sprite, "modulate", Color(0.20, 0.25, 0.28, 0.0), 0.36 * presentation_speed)
	tween.tween_property(target_sprite, "scale", target_sprite.scale * 0.82, 0.36 * presentation_speed)
	await tween.finished


func _begin_sequence(sequence_name: String) -> void:
	last_sequence = sequence_name
	last_callouts.clear()
	sequence_history.append(sequence_name)


func _collect_damage_callouts(result_view: Dictionary) -> void:
	var damage := int(result_view.get("damage", result_view.get("target_damage", 0)))
	if damage > 0:
		last_callouts.append("耐久 -%d" % damage)
	if int(result_view.get("stern_bonus", 0)) > 0:
		last_callouts.append("船尾命中 +%d" % int(result_view["stern_bonus"]))
	if result_view.get("applied_suppression", false):
		last_callouts.append("压制航标")


func _play_projectile_volley(start: Vector2, finish: Vector2, count: int, color: Color) -> void:
	var projectiles: Array[Polygon2D] = []
	var tween := create_tween()
	tween.set_parallel(true)
	for projectile_index in count:
		var normal := (finish - start).normalized().orthogonal()
		var offset := normal * float(projectile_index - (count - 1) * 0.5) * 5.0
		var projectile := Polygon2D.new()
		projectile.polygon = PackedVector2Array([Vector2(-4.0, -3.0), Vector2(4.0, -3.0), Vector2(4.0, 3.0), Vector2(-4.0, 3.0)])
		projectile.color = color
		projectile.position = start + offset
		projectile.z_index = 20
		_add_transient(projectile)
		projectiles.append(projectile)
		if presentation_speed <= 0.0:
			projectile.position = finish + offset
		else:
			tween.tween_property(projectile, "position", finish + offset, (0.28 + projectile_index * 0.05) * presentation_speed).set_delay(projectile_index * 0.04 * presentation_speed)
	if presentation_speed > 0.0:
		await tween.finished
	else:
		tween.kill()
	for projectile in projectiles:
		_free_transient(projectile)


func _play_sheet(effect_id: String, position_value: Vector2, scale_value: float) -> void:
	var texture: Texture2D = {"water": WATER_TEXTURE, "small": SMALL_TEXTURE, "large": LARGE_TEXTURE}.get(effect_id)
	var frame_count := int(FRAME_COUNTS.get(effect_id, 1))
	if texture == null:
		await _play_fallback_ring(position_value)
		return
	var effect := AnimatedSprite2D.new()
	effect.sprite_frames = build_frames(texture, frame_count)
	effect.animation = "play"
	effect.position = position_value
	effect.scale = Vector2.ONE * scale_value
	effect.z_index = 18
	_add_transient(effect)
	if presentation_speed <= 0.0:
		effect.frame = frame_count - 1
		_free_transient(effect)
		return
	effect.speed_scale = 1.0 / presentation_speed
	effect.play("play")
	await effect.animation_finished
	_free_transient(effect)


func _play_fallback_ring(position_value: Vector2) -> void:
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = EVENT_COLOR
	var points := PackedVector2Array()
	for point_index in 25:
		points.append(Vector2.RIGHT.rotated(TAU * point_index / 24.0) * 20.0)
	ring.points = points
	ring.position = position_value
	ring.z_index = 18
	_add_transient(ring)
	if presentation_speed > 0.0:
		await _tween_property(ring, "modulate:a", 0.0, 0.18)
	_free_transient(ring)


func _shake(target_sprite: Sprite2D, distance: float) -> void:
	if not is_instance_valid(target_sprite) or presentation_speed <= 0.0:
		return
	var origin := target_sprite.position
	var tween := create_tween()
	tween.tween_property(target_sprite, "position", origin + Vector2(distance, 0.0), 0.04 * presentation_speed)
	tween.tween_property(target_sprite, "position", origin - Vector2(distance, 0.0), 0.06 * presentation_speed)
	tween.tween_property(target_sprite, "position", origin, 0.05 * presentation_speed)
	await tween.finished


func _spawn_callouts(origin: Vector2) -> void:
	for index in last_callouts.size():
		var text := last_callouts[index]
		var label := Label.new()
		label.text = text
		label.position = origin + Vector2(-42.0, -42.0 - index * 20.0)
		label.z_index = 24
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", _callout_color(text))
		_add_transient(label)
		if presentation_speed <= 0.0:
			_free_transient(label)
			continue
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(label, "position:y", label.position.y - 22.0, 0.55 * presentation_speed)
		tween.tween_property(label, "modulate:a", 0.0, 0.55 * presentation_speed)
		tween.chain().tween_callback(_free_transient.bind(label))


func _callout_color(text: String) -> Color:
	if "耐久" in text:
		return HULL_COLOR
	if "船尾" in text:
		return RUDDER_COLOR
	return EVENT_COLOR


func _tween_property(object: Object, property: StringName, final_value: Variant, duration: float) -> void:
	if not is_instance_valid(object):
		return
	if presentation_speed <= 0.0:
		object.set(property, final_value)
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(object, NodePath(property), final_value, duration * presentation_speed)
	await tween.finished


func _add_transient(node: Node) -> void:
	add_child(node)
	_transient.append(node)


func _free_transient(node: Node) -> void:
	if not is_instance_valid(node):
		return
	_transient.erase(node)
	node.queue_free()


func _play_audio(stream: AudioStream) -> void:
	if presentation_speed <= 0.0 or stream == null or _audio_players.is_empty():
		return
	var player := _audio_players[_audio_cursor]
	_audio_cursor = (_audio_cursor + 1) % _audio_players.size()
	player.stream = stream
	player.play()
