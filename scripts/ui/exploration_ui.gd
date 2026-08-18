extends CanvasLayer

const HUD_SCENE := preload("res://scenes/ui/exploration_hud.tscn")

signal menu_visibility_changed(is_open: bool)
signal save_requested
signal load_requested
signal return_title_requested
signal side_quest_tracked(quest_id: StringName)

var _hud: Control
var _owner_ref: WeakRef
var _context_id := &""


func _ready() -> void:
	layer = 90
	_hud = HUD_SCENE.instantiate() as Control
	if _hud == null:
		push_error("ExplorationUI could not instantiate the shared HUD.")
		return
	_hud.name = "HUD"
	_hud.add_to_group("exploration_hud")
	add_child(_hud)
	_hud.menu_visibility_changed.connect(_on_hud_menu_visibility_changed)
	_hud.save_requested.connect(_on_hud_save_requested)
	_hud.load_requested.connect(_on_hud_load_requested)
	_hud.return_title_requested.connect(_on_hud_return_title_requested)
	_hud.side_quest_tracked.connect(_on_hud_side_quest_tracked)
	_hud.call("set_exploration_visible", false)


func acquire(owner: Node, context_id: StringName) -> Control:
	if _hud == null:
		return null
	_owner_ref = weakref(owner)
	_context_id = context_id
	if _hud.has_method("reset_context"):
		_hud.call("reset_context", context_id)
	else:
		_hud.call("set_exploration_visible", false)
	return _hud


func release(owner: Node) -> void:
	if current_owner() != owner:
		return
	if _hud != null:
		_hud.call("set_exploration_visible", false)
	_owner_ref = null
	_context_id = &""


func current_owner() -> Node:
	if _owner_ref == null:
		return null
	return _owner_ref.get_ref() as Node


func current_context() -> StringName:
	return _context_id


func get_hud() -> Control:
	return _hud


func _has_current_owner() -> bool:
	return current_owner() != null


func _on_hud_menu_visibility_changed(is_open: bool) -> void:
	if _has_current_owner():
		menu_visibility_changed.emit(is_open)


func _on_hud_save_requested() -> void:
	if _has_current_owner():
		save_requested.emit()


func _on_hud_load_requested() -> void:
	if _has_current_owner():
		load_requested.emit()


func _on_hud_return_title_requested() -> void:
	if _has_current_owner():
		return_title_requested.emit()


func _on_hud_side_quest_tracked(quest_id: StringName) -> void:
	if _has_current_owner():
		side_quest_tracked.emit(quest_id)
