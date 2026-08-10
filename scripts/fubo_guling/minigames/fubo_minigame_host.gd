class_name FuboMinigameHost
extends Control

signal minigame_opened(game_id: String)
signal minigame_finished(result: Dictionary)
signal minigame_cancelled(game_id: String)

var active_minigame: Control

var _world: CanvasItem
var _hud: CanvasItem
var _player: Node
var _game_id := ""
var _world_visible := true
var _hud_visible := true
var _world_process_mode := Node.PROCESS_MODE_INHERIT
var _hud_process_mode := Node.PROCESS_MODE_INHERIT
var _player_controls_enabled := true


func configure(world: CanvasItem, hud: CanvasItem, player: Node) -> void:
	_world = world
	_hud = hud
	_player = player


func open_minigame(scene: PackedScene, game_id: String) -> bool:
	if active_minigame != null or scene == null or _world == null or _hud == null or _player == null:
		return false
	var instance := scene.instantiate() as Control
	if instance == null or not instance.has_signal("completed") or not instance.has_signal("exit_requested"):
		if instance != null:
			instance.free()
		return false
	_game_id = game_id
	active_minigame = instance
	_store_map_state()
	_world.visible = false
	_hud.visible = false
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_hud.process_mode = Node.PROCESS_MODE_DISABLED
	_player.set("controls_enabled", false)
	if _player.has_method("cancel_move_target"):
		_player.call("cancel_move_target")
	add_child(instance)
	instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	instance.connect("completed", _on_completed, CONNECT_ONE_SHOT)
	instance.connect("exit_requested", _on_exit_requested, CONNECT_ONE_SHOT)
	minigame_opened.emit(game_id)
	return true


func _store_map_state() -> void:
	_world_visible = _world.visible
	_hud_visible = _hud.visible
	_world_process_mode = _world.process_mode
	_hud_process_mode = _hud.process_mode
	_player_controls_enabled = bool(_player.get("controls_enabled"))


func _on_completed(result: Dictionary) -> void:
	_restore_map()
	minigame_finished.emit(result)


func _on_exit_requested() -> void:
	var cancelled_id := _game_id
	_restore_map()
	minigame_cancelled.emit(cancelled_id)


func _restore_map() -> void:
	if active_minigame != null:
		active_minigame.queue_free()
	active_minigame = null
	_game_id = ""
	_world.visible = _world_visible
	_hud.visible = _hud_visible
	_world.process_mode = _world_process_mode
	_hud.process_mode = _hud_process_mode
	_player.set("controls_enabled", _player_controls_enabled)
