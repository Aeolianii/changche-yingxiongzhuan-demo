class_name FuboGuling
extends Node2D

const CANAL_SCENE := preload("res://scenes/fubo_guling/minigames/fubo_canal_minigame.tscn")
const DRUM_SCENE := preload("res://scenes/fubo_guling/minigames/fubo_drum_minigame.tscn")

enum Phase {
	ARRIVAL,
	CANAL_AVAILABLE,
	CANAL_ACTIVE,
	DRUM_AVAILABLE,
	DRUM_ACTIVE,
	VIEWPOINT_OPEN,
	COMPLETE,
}

const KEEPER_POSITION := Vector2(1150, 1650)
const CANAL_SAFE_POSITION := Vector2(2450, 1330)
const SCHOOL_SAFE_POSITION := Vector2(1700, 790)
const INTERACTION_RADIUS := 76.0
const DIALOGUE_LINES := [
	"年轻人，这古岭的水断了许久。",
	"沿山路去古渠，把三支水量调到石刻所示的数目。",
	"古渠通水后，校场的守军会以三面鼓考验你的耳力。",
]

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $World/WorldObjects/Player
@onready var camera: Camera2D = $World/WorldObjects/Player/Camera2D
@onready var keeper: Node2D = $World/WorldObjects/Keeper
@onready var school_barrier: Node2D = $World/WorldObjects/SchoolBarrier
@onready var viewpoint_barrier: Node2D = $World/WorldObjects/ViewpointBarrier
@onready var school_shape: CollisionShape2D = $World/Collision/SchoolBlocker/Shape
@onready var viewpoint_shape: CollisionShape2D = $World/Collision/ViewpointBlocker/Shape
@onready var canal_trigger: Area2D = $World/Triggers/CanalTrigger
@onready var school_trigger: Area2D = $World/Triggers/SchoolTrigger
@onready var viewpoint_trigger: Area2D = $World/Triggers/ViewpointTrigger
@onready var collision_debug: Node2D = $World/CollisionDebug
@onready var minigame_host: FuboMinigameHost = $Interface/MinigameHost
@onready var hud: Control = $Interface/HUD
@onready var objective_label: Label = $Interface/HUD/TitlePanel/Objective
@onready var prompt_panel: ColorRect = $Interface/HUD/PromptPanel
@onready var prompt_label: Label = $Interface/HUD/PromptPanel/Prompt
@onready var dialogue_panel: ColorRect = $Interface/HUD/DialoguePanel
@onready var speaker_label: Label = $Interface/HUD/DialoguePanel/Speaker
@onready var dialogue_label: Label = $Interface/HUD/DialoguePanel/Dialogue
@onready var overlay: ColorRect = $Interface/HUD/Overlay
@onready var overlay_text: Label = $Interface/HUD/Overlay/OverlayText

var phase := Phase.ARRIVAL
var _dialogue_index := -1
var _keeper_focused := false
var _pending_trigger := ""


func _ready() -> void:
	_configure_camera()
	minigame_host.configure(world, hud, player)
	minigame_host.minigame_finished.connect(_on_minigame_finished)
	minigame_host.minigame_cancelled.connect(_on_minigame_cancelled)
	canal_trigger.body_entered.connect(_on_canal_body_entered)
	canal_trigger.body_exited.connect(_on_trigger_body_exited.bind("canal"))
	school_trigger.body_entered.connect(_on_school_body_entered)
	school_trigger.body_exited.connect(_on_trigger_body_exited.bind("drum"))
	viewpoint_trigger.body_entered.connect(_on_viewpoint_body_entered)
	prompt_panel.visible = false
	dialogue_panel.visible = false
	overlay.visible = false
	$Interface/HUD/CanalPanel.visible = false
	$Interface/HUD/DrumPanel.visible = false
	objective_label.text = "沿山路寻找守岭人"
	_build_collision_debug()


func _configure_camera() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = 3200
	camera.limit_bottom = 2200
	camera.position = Vector2(0, -80)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.reset_smoothing()


func _process(_delta: float) -> void:
	if phase != Phase.ARRIVAL or dialogue_panel.visible or minigame_host.active_minigame != null:
		_set_keeper_focus(false)
		return
	_set_keeper_focus(player.global_position.distance_to(KEEPER_POSITION) <= INTERACTION_RADIUS)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if event.is_action_pressed("interact"):
		_handle_interaction()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fubo_debug"):
		collision_debug.visible = not collision_debug.visible
		get_viewport().set_input_as_handled()


func _handle_interaction() -> void:
	if phase == Phase.COMPLETE:
		get_tree().reload_current_scene()
	elif dialogue_panel.visible:
		_advance_dialogue()
	elif _pending_trigger == "canal":
		_open_canal_minigame()
	elif _pending_trigger == "drum":
		_open_drum_minigame()
	elif _keeper_focused:
		_start_dialogue()


func _set_keeper_focus(enabled: bool) -> void:
	_keeper_focused = enabled
	if keeper.has_method("set_highlighted"):
		keeper.call("set_highlighted", enabled)
	if enabled:
		prompt_label.text = "按 E / 空格 与守岭人交谈"
		prompt_panel.visible = true
	elif _pending_trigger.is_empty():
		prompt_panel.visible = false


func _start_dialogue() -> void:
	_dialogue_index = 0
	player.controls_enabled = false
	player.cancel_move_target()
	speaker_label.text = "守岭人"
	dialogue_label.text = DIALOGUE_LINES[0]
	dialogue_panel.visible = true
	prompt_panel.visible = false


func _advance_dialogue() -> void:
	_dialogue_index += 1
	if _dialogue_index < DIALOGUE_LINES.size():
		dialogue_label.text = DIALOGUE_LINES[_dialogue_index]
		return
	dialogue_panel.visible = false
	player.controls_enabled = true
	_unlock_canal_location()


func _unlock_canal_location() -> void:
	phase = Phase.CANAL_AVAILABLE
	objective_label.text = "前往山腰古渠，靠近石碑开始调水"


func _on_canal_body_entered(body: Node) -> void:
	if body == player and phase == Phase.CANAL_AVAILABLE:
		_pending_trigger = "canal"
		prompt_label.text = "按 E / 空格 调整三渠水量"
		prompt_panel.visible = true


func _on_school_body_entered(body: Node) -> void:
	if body == player and phase == Phase.DRUM_AVAILABLE:
		_pending_trigger = "drum"
		prompt_label.text = "按 E / 空格 接受岭南鼓令"
		prompt_panel.visible = true


func _on_trigger_body_exited(body: Node, trigger_id: String) -> void:
	if body == player and _pending_trigger == trigger_id:
		_pending_trigger = ""
		prompt_panel.visible = false


func _open_canal_minigame() -> bool:
	if phase != Phase.CANAL_AVAILABLE:
		return false
	_pending_trigger = ""
	prompt_panel.visible = false
	if not minigame_host.open_minigame(CANAL_SCENE, "canal"):
		return false
	phase = Phase.CANAL_ACTIVE
	return true


func _open_drum_minigame() -> bool:
	if phase != Phase.DRUM_AVAILABLE:
		return false
	_pending_trigger = ""
	prompt_panel.visible = false
	if not minigame_host.open_minigame(DRUM_SCENE, "drum"):
		return false
	phase = Phase.DRUM_ACTIVE
	return true


func _on_minigame_finished(result: Dictionary) -> void:
	if not result.get("completed", false):
		return
	match String(result.get("game_id", "")):
		"canal":
			_complete_canal(result)
		"drum":
			_complete_drum(result)


func _complete_canal(result: Dictionary) -> void:
	if phase != Phase.CANAL_ACTIVE:
		return
	phase = Phase.DRUM_AVAILABLE
	school_shape.set_deferred("disabled", true)
	school_barrier.visible = false
	objective_label.text = "古渠贯通（%s），沿山路前往古校场" % String(result.get("rating", "完成"))
	_show_notice("古渠贯通\n通往校场的山路已开放", 1.8)


func _complete_drum(_result: Dictionary) -> void:
	if phase != Phase.DRUM_ACTIVE:
		return
	phase = Phase.VIEWPOINT_OPEN
	viewpoint_shape.set_deferred("disabled", true)
	viewpoint_barrier.visible = false
	objective_label.text = "鼓令完成，登上观景台眺望南海"
	_show_notice("三轮鼓令完成\n观景台入口已开放", 1.8)


func _on_minigame_cancelled(game_id: String) -> void:
	match game_id:
		"canal":
			phase = Phase.CANAL_AVAILABLE
			player.global_position = CANAL_SAFE_POSITION
		"drum":
			phase = Phase.DRUM_AVAILABLE
			player.global_position = SCHOOL_SAFE_POSITION
	player.controls_enabled = true
	prompt_panel.visible = false


func _on_viewpoint_body_entered(body: Node) -> void:
	if body != player or phase != Phase.VIEWPOINT_OPEN:
		return
	phase = Phase.COMPLETE
	player.controls_enabled = false
	player.cancel_move_target()
	objective_label.text = "伏波古岭行程完成"
	overlay_text.text = "伏波古岭\n古渠已通，鼓令已成\n\n按 E / 空格 重新开始"
	overlay.visible = true


func _show_notice(text_value: String, duration: float) -> void:
	overlay_text.text = text_value
	overlay.visible = true
	await get_tree().create_timer(duration).timeout
	if phase != Phase.COMPLETE and minigame_host.active_minigame == null:
		overlay.visible = false


func _build_collision_debug() -> void:
	for parent in [$World/Collision, $World/Triggers]:
		for physics_node in parent.find_children("*", "CollisionObject2D", true, false):
			for child in physics_node.get_children():
				if child is CollisionShape2D and child.shape != null:
					_add_shape_debug(physics_node, child, parent == $World/Collision)
				elif child is CollisionPolygon2D:
					var polygon := Polygon2D.new()
					polygon.polygon = child.polygon
					polygon.color = Color(0.95, 0.28, 0.18, 0.22)
					polygon.position = physics_node.position + child.position
					collision_debug.add_child(polygon)


func _add_shape_debug(physics_node: Node2D, shape_node: CollisionShape2D, blocked: bool) -> void:
	var color := Color(0.95, 0.28, 0.18, 0.25) if blocked else Color(0.2, 0.75, 1.0, 0.28)
	if shape_node.shape is RectangleShape2D:
		var half := (shape_node.shape as RectangleShape2D).size * 0.5
		var polygon := Polygon2D.new()
		polygon.polygon = PackedVector2Array([Vector2(-half.x, -half.y), Vector2(half.x, -half.y), Vector2(half.x, half.y), Vector2(-half.x, half.y)])
		polygon.color = color
		polygon.position = physics_node.position + shape_node.position
		collision_debug.add_child(polygon)
	elif shape_node.shape is CircleShape2D:
		var line := Line2D.new()
		var points := PackedVector2Array()
		for index in 25:
			var angle := TAU * index / 24.0
			points.append(Vector2(cos(angle), sin(angle)) * (shape_node.shape as CircleShape2D).radius)
		line.points = points
		line.closed = true
		line.width = 4.0
		line.default_color = color.lightened(0.35)
		line.position = physics_node.position + shape_node.position
		collision_debug.add_child(line)


func finish_keeper_dialogue_for_test() -> void:
	_unlock_canal_location()


func trigger_canal_for_test() -> bool:
	return _open_canal_minigame()


func trigger_drum_for_test() -> bool:
	return _open_drum_minigame()


func get_phase_for_test() -> int:
	return phase


func is_school_locked_for_test() -> bool:
	return not school_shape.disabled


func is_viewpoint_locked_for_test() -> bool:
	return not viewpoint_shape.disabled
