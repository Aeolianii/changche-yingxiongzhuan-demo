class_name FuboGuling
extends Node2D

const FISHING_SCENE := preload("res://scenes/fubo_guling/minigames/fubo_fishing_minigame.tscn")
const DRUM_SCENE := preload("res://scenes/fubo_guling/minigames/fubo_drum_minigame.tscn")
const FIELD_EVENT_DIALOGUE_SCENE := preload("res://scenes/ui/field_event_dialogue.tscn")
const KEEPER_PORTRAIT := preload("res://assets/characters/soldier/picture.png")
const LOADING_TRANSITION_SCENE := preload("res://scenes/ui/scene_loading_transition.tscn")
const FUBO_TRAVEL := preload("res://scripts/fubo_guling/fubo_travel_session.gd")
const FUBO_SAVE_STATE := preload("res://scripts/fubo_guling/fubo_save_state.gd")
const SCENE_PATH := "res://scenes/fubo_guling/fubo_guling.tscn"
const TITLE_SCENE_PATH := "res://scenes/ui/title_screen.tscn"

enum Phase {
	ARRIVAL,
	FISHING_AVAILABLE,
	FISHING_ACTIVE,
	DRUM_AVAILABLE,
	DRUM_ACTIVE,
	VIEWPOINT_OPEN,
	COMPLETE,
}

const MAP_SIZE := Vector2i(1536, 1024)
const CAMERA_ZOOM := Vector2(1.15, 1.15)
const KEEPER_POSITION := Vector2(450, 475)
const INTERACTION_RADIUS := 76.0
const DIALOGUE_LINES := [
	"此地名唤伏波古岭。岛上军民感念伏波将军马援南征靖边、开道安民之功，故以伏波为名，世代纪念。",
	"如今伏波岛扼守海道，倭寇时有窥伺；岛上军士昼夜巡哨，校场鼓令也不敢荒废。",
	"你若初来，可先往码头旁海岸垂钓，熟悉潮汐。鱼竿鱼篓已经备好，随时都可下钩。",
	"待收竿之后，再去古校场听令回鼓。边地传令，全凭耳准手稳，切莫误了军机。",
]
const KEEPER_IDLE_LINE := "倭患一日未靖，这伏波岛的烽火便一日不可松懈啊……"

@onready var world: Node2D = $World
@onready var player: CharacterBody2D = $World/WorldObjects/Player
@onready var camera: Camera2D = $World/WorldObjects/Player/Camera2D
@onready var keeper: Node2D = $World/WorldObjects/Keeper
@onready var fishing_station: FuboFishingStation = $World/WorldObjects/FishingStation
@onready var school_barrier: Node2D = $World/WorldObjects/SchoolBarrier
@onready var school_shape: CollisionShape2D = $World/Collision/SchoolBlocker/Shape
@onready var fishing_trigger: Area2D = $World/Triggers/FishingTrigger
@onready var sea_return_trigger: Area2D = $World/Triggers/SeaReturnTrigger
@onready var school_trigger: Area2D = $World/Triggers/SchoolTrigger
@onready var viewpoint_trigger: Area2D = $World/Triggers/ViewpointTrigger
@onready var collision_debug: Node2D = $World/CollisionDebug
@onready var minigame_host: FuboMinigameHost = $Interface/MinigameHost
@onready var hud: Control = $Interface/HUD
@onready var prompt_panel: TextureButton = $Interface/HUD/PromptPanel
@onready var prompt_label: Label = $Interface/HUD/PromptPanel/Prompt
@onready var overlay: ColorRect = $Interface/HUD/Overlay
@onready var overlay_text: Label = $Interface/HUD/Overlay/OverlayText
@onready var completion_cutscene: FuboCompletionCutscene = $Interface/CompletionCutscene

var phase := Phase.FISHING_AVAILABLE
var _keeper_intro_completed := false
var _dialogue_index := -1
var _keeper_focused := false
var _pending_trigger := ""
var _test_mode := false
var _transitioning := false
var _minigame_return_position := Vector2.ZERO
var _fishing_return_phase := Phase.FISHING_AVAILABLE
var _loading_transition: SceneLoadingTransition
var _completion_return_position := Vector2.ZERO
var dialogue_panel: FieldEventDialogue
var exploration_hud: Control
var _exploration_ui: Node


func _ready() -> void:
	_configure_camera()
	_initialize_keeper_dialogue()
	_exploration_ui = get_node_or_null("/root/ExplorationUI")
	if _exploration_ui != null:
		exploration_hud = _exploration_ui.call("acquire", self, &"fubo_guling") as Control
		_connect_global_hud_signals()
	minigame_host.configure(world, exploration_hud if exploration_hud != null else hud, player)
	minigame_host.minigame_finished.connect(_on_minigame_finished)
	minigame_host.minigame_cancelled.connect(_on_minigame_cancelled)
	prompt_panel.pressed.connect(_handle_interaction)
	fishing_trigger.body_entered.connect(_on_fishing_body_entered)
	fishing_trigger.body_exited.connect(_on_trigger_body_exited.bind("fishing"))
	sea_return_trigger.body_entered.connect(_on_sea_return_body_entered)
	sea_return_trigger.body_exited.connect(_on_trigger_body_exited.bind("sea_return"))
	school_trigger.body_entered.connect(_on_school_body_entered)
	school_trigger.body_exited.connect(_on_trigger_body_exited.bind("drum"))
	viewpoint_trigger.body_entered.connect(_on_viewpoint_body_entered)
	prompt_panel.visible = false
	overlay.visible = false
	_loading_transition = LOADING_TRANSITION_SCENE.instantiate() as SceneLoadingTransition
	$Interface.add_child(_loading_transition)
	_build_collision_debug()
	_ensure_fubo_side_quest()
	_restore_saved_scene_state(_consume_saved_scene_state())
	_apply_phase_world_state()
	_refresh_exploration_hud()


func _initialize_keeper_dialogue() -> void:
	var old_panel := get_node_or_null("Interface/HUD/DialoguePanel")
	if old_panel != null:
		old_panel.queue_free()
	dialogue_panel = FIELD_EVENT_DIALOGUE_SCENE.instantiate() as FieldEventDialogue
	dialogue_panel.name = "KeeperDialogue"
	dialogue_panel.z_index = 50
	$Interface.add_child(dialogue_panel)
	dialogue_panel.option_selected.connect(_on_keeper_dialogue_option_selected)


func _present_keeper_dialogue_line() -> void:
	var options: Array[Dictionary] = [{"id": &"continue", "text": "继续  ▶"}]
	dialogue_panel.present("守岭人", DIALOGUE_LINES[_dialogue_index], KEEPER_PORTRAIT, options)


func _on_keeper_dialogue_option_selected(option_id: StringName) -> void:
	if option_id == &"continue":
		_advance_dialogue()
	elif option_id == &"leave":
		_close_keeper_dialogue()


func _exit_tree() -> void:
	if _exploration_ui == null:
		return
	for binding in [
		[&"menu_visibility_changed", Callable(self, "_on_hud_menu_visibility_changed")],
		[&"save_requested", Callable(self, "_on_save_requested")],
		[&"load_requested", Callable(self, "_on_load_requested")],
		[&"return_title_requested", Callable(self, "_on_return_title_requested")],
		[&"side_quest_tracked", Callable(self, "_on_side_quest_tracked")],
	]:
		if _exploration_ui.is_connected(binding[0], binding[1]):
			_exploration_ui.disconnect(binding[0], binding[1])
	_exploration_ui.call("release", self)


func _connect_global_hud_signals() -> void:
	for binding in [
		[&"menu_visibility_changed", Callable(self, "_on_hud_menu_visibility_changed")],
		[&"save_requested", Callable(self, "_on_save_requested")],
		[&"load_requested", Callable(self, "_on_load_requested")],
		[&"return_title_requested", Callable(self, "_on_return_title_requested")],
		[&"side_quest_tracked", Callable(self, "_on_side_quest_tracked")],
	]:
		if not _exploration_ui.is_connected(binding[0], binding[1]):
			_exploration_ui.connect(binding[0], binding[1])


func _on_hud_menu_visibility_changed(is_open: bool) -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	if is_open:
		player.controls_enabled = false
		player.cancel_move_target()
		prompt_panel.visible = false
	else:
		player.controls_enabled = not _transitioning and not dialogue_panel.visible and not overlay.visible and minigame_host.active_minigame == null
	_refresh_exploration_hud()


func _on_save_requested() -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	if not _is_stable_save_state():
		_show_save_message(false, "unstable_scene")
		return
	var game_state := _game_state()
	if game_state == null:
		_show_save_message(false, "write_failed")
		return
	var sea_context := get_tree().root.get_meta(FUBO_TRAVEL.RETURN_CONTEXT_META, {}) as Dictionary
	var snapshot := FUBO_SAVE_STATE.make_snapshot(
		player.global_position,
		str(player.get("facing")),
		phase,
		sea_context,
		_keeper_intro_completed
	)
	if snapshot.is_empty():
		_show_save_message(false, "invalid_scene_state")
		return
	var result: Dictionary = game_state.call("save_game", SCENE_PATH, snapshot)
	_show_save_message(bool(result.get("ok", false)), str(result.get("reason", "")))


func _on_load_requested() -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	var game_state := _game_state()
	if game_state == null:
		_show_save_message(false, "read_failed")
		return
	var result: Dictionary = game_state.call("load_game")
	if not result.get("ok", false):
		_show_save_message(false, str(result.get("reason", "read_failed")))
		return
	var change_error := get_tree().change_scene_to_file(str(result["scene_path"]))
	if change_error != OK:
		game_state.call("clear_pending_scene_state")
		_show_save_message(false, "scene_change_failed")


func _on_return_title_requested() -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	var game_state := _game_state()
	if game_state != null:
		game_state.call("clear_pending_scene_state")
	var change_error := get_tree().change_scene_to_file(TITLE_SCENE_PATH)
	if change_error != OK:
		_show_save_message(false, "scene_change_failed")


func _is_stable_save_state() -> bool:
	return phase in [Phase.ARRIVAL, Phase.FISHING_AVAILABLE, Phase.DRUM_AVAILABLE, Phase.VIEWPOINT_OPEN, Phase.COMPLETE] and not _transitioning and not dialogue_panel.visible and not overlay.visible and minigame_host.active_minigame == null


func _consume_saved_scene_state() -> Dictionary:
	var game_state := _game_state()
	if game_state == null:
		return {}
	return game_state.call("consume_pending_scene_state", SCENE_PATH) as Dictionary


func _restore_saved_scene_state(raw_snapshot: Dictionary) -> void:
	if raw_snapshot.is_empty():
		return
	var snapshot := FUBO_SAVE_STATE.decode_snapshot(raw_snapshot)
	if snapshot.is_empty():
		_show_save_message(false, "invalid_scene_state")
		return
	var saved_position := snapshot["player_position"] as Array
	player.global_position = Vector2(float(saved_position[0]), float(saved_position[1]))
	player.set("facing", str(snapshot["player_facing"]))
	player.call("set_move_direction", Vector2.ZERO)
	phase = int(snapshot["phase"])
	if phase == Phase.ARRIVAL:
		phase = Phase.FISHING_AVAILABLE
	_keeper_intro_completed = bool(snapshot.get("keeper_intro_completed", false))
	_apply_phase_world_state()
	var runtime_context := FUBO_SAVE_STATE.sea_context_for_runtime(snapshot.get("sea_return_context", {}))
	if runtime_context.is_empty():
		if get_tree().root.has_meta(FUBO_TRAVEL.RETURN_CONTEXT_META):
			get_tree().root.remove_meta(FUBO_TRAVEL.RETURN_CONTEXT_META)
	else:
		get_tree().root.set_meta(FUBO_TRAVEL.RETURN_CONTEXT_META, runtime_context)


func _apply_phase_world_state() -> void:
	school_shape.set_deferred("disabled", false)
	school_barrier.visible = true
	_sync_fishing_station()


func _sync_fishing_station() -> void:
	fishing_station.set_available(_is_fishing_available())


func _is_fishing_available() -> bool:
	return phase in [Phase.FISHING_AVAILABLE, Phase.DRUM_AVAILABLE, Phase.VIEWPOINT_OPEN, Phase.COMPLETE]


func _show_save_message(success: bool, reason: String) -> void:
	if exploration_hud == null:
		return
	if success:
		exploration_hud.call("show_toast", "进度已保存")
		return
	var game_state := _game_state()
	var message := "存档操作失败。" if game_state == null else str(game_state.call("error_message", reason))
	exploration_hud.call("show_toast", message)


func _game_state() -> Node:
	return get_node_or_null("/root/GameState")


func _refresh_exploration_hud() -> void:
	if exploration_hud == null:
		return
	var objective := "码头旁鱼竿可随时钓鱼，也可询问守岭人"
	var progress_stage := 0
	match phase:
		Phase.FISHING_AVAILABLE:
			objective = "前往码头旁海岸，在鱼竿处开始钓鱼"
			progress_stage = 1
		Phase.FISHING_ACTIVE:
			objective = "完成海岸摆钩钓鱼"
			progress_stage = 1
		Phase.DRUM_AVAILABLE, Phase.DRUM_ACTIVE:
			objective = "沿山路前往古校场，完成听令回鼓"
			progress_stage = 2
		Phase.VIEWPOINT_OPEN:
			objective = "登上观景台眺望南海"
			progress_stage = 3
		Phase.COMPLETE:
			objective = "伏波古岭行程完成"
			progress_stage = 4
	_sync_fubo_side_quest_progress(progress_stage)
	var game_state := _game_state()
	var fubo_state := {} if game_state == null else game_state.call("get_fubo_side_quest_state") as Dictionary
	var tracked_side_quest := &"fubo_guling" if game_state == null else StringName(game_state.call("get_tracked_side_quest"))
	exploration_hud.call(
		"set_main_task_progress",
		"探索海域，完善海图",
		"巡视伏波古岭，返回海图后继续探索海域",
		0,
		{
			"fubo_side_quest": fubo_state,
			"tracked_side_quest": String(tracked_side_quest),
		}
	)
	var should_show := not _transitioning and not dialogue_panel.visible and not overlay.visible and minigame_host.active_minigame == null
	exploration_hud.call("set_exploration_visible", should_show)


func _ensure_fubo_side_quest() -> void:
	var game_state := _game_state()
	if game_state == null:
		return
	if not bool(game_state.call("has_fubo_side_quest")):
		game_state.call("accept_fubo_side_quest")
	game_state.call("set_tracked_side_quest", &"fubo_guling")


func _sync_fubo_side_quest_progress(progress_stage: int) -> void:
	var game_state := _game_state()
	if game_state != null:
		game_state.call("set_fubo_side_quest_progress", progress_stage, _keeper_intro_completed)


func _on_side_quest_tracked(quest_id: StringName) -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	var game_state := _game_state()
	if game_state != null:
		game_state.call("set_tracked_side_quest", quest_id)


func _configure_camera() -> void:
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = MAP_SIZE.x
	camera.limit_bottom = MAP_SIZE.y
	camera.position = Vector2.ZERO
	camera.zoom = CAMERA_ZOOM
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.reset_smoothing()


func _process(_delta: float) -> void:
	if dialogue_panel.visible or overlay.visible or minigame_host.active_minigame != null or _transitioning:
		_set_keeper_focus(false)
		return
	_set_keeper_focus(player.global_position.distance_to(KEEPER_POSITION) <= INTERACTION_RADIUS)


func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_echo():
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT and player.controls_enabled:
			var world_position := get_viewport().get_canvas_transform().affine_inverse() * mouse_event.position
			player.request_move_to(world_position)
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact"):
		_handle_interaction()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fubo_debug"):
		collision_debug.visible = not collision_debug.visible
		get_viewport().set_input_as_handled()


func _handle_interaction() -> void:
	if _pending_trigger == "sea_return":
		_return_to_sea_overworld()
	elif dialogue_panel.visible:
		_advance_dialogue()
	elif _pending_trigger == "fishing":
		_open_fishing_minigame()
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
	player.controls_enabled = false
	player.cancel_move_target()
	if not _keeper_intro_completed:
		_dialogue_index = 0
		_present_keeper_dialogue_line()
	else:
		_dialogue_index = -1
		dialogue_panel.present(
			"守岭人",
			KEEPER_IDLE_LINE,
			KEEPER_PORTRAIT,
			[{"id": &"leave", "text": "无事"}]
		)
	prompt_panel.visible = false
	_refresh_exploration_hud()


func _advance_dialogue() -> void:
	if _keeper_intro_completed:
		_close_keeper_dialogue()
		return
	_dialogue_index += 1
	if _dialogue_index < DIALOGUE_LINES.size():
		_present_keeper_dialogue_line()
		return
	_keeper_intro_completed = true
	_close_keeper_dialogue()
	_refresh_minigame_interaction.call_deferred()


func _close_keeper_dialogue() -> void:
	dialogue_panel.hide_dialogue()
	player.controls_enabled = true
	_dialogue_index = -1
	_refresh_exploration_hud()


func _on_fishing_body_entered(body: Node) -> void:
	if body == player and _is_fishing_available():
		_pending_trigger = "fishing"
		fishing_station.set_highlighted(true)
		prompt_label.text = "按 E / 空格 开始海岸钓鱼"
		prompt_panel.visible = true


func _on_sea_return_body_entered(body: Node) -> void:
	if body != player or _transitioning:
		return
	_pending_trigger = "sea_return"
	prompt_label.text = "按 E / 空格 乘船返回海图"
	prompt_panel.visible = true


func _on_school_body_entered(body: Node) -> void:
	if body == player and phase == Phase.DRUM_AVAILABLE:
		_pending_trigger = "drum"
		prompt_label.text = "按 E / 空格 进入听令回鼓"
		prompt_panel.visible = true


func _on_trigger_body_exited(body: Node, trigger_id: String) -> void:
	if body == player and _pending_trigger == trigger_id:
		_pending_trigger = ""
		prompt_panel.visible = false
		if trigger_id == "fishing":
			fishing_station.set_highlighted(false)


func _return_to_sea_overworld() -> void:
	if _transitioning:
		return
	_transitioning = true
	_pending_trigger = ""
	prompt_panel.visible = false
	player.controls_enabled = false
	player.cancel_move_target()
	_refresh_exploration_hud()
	var scene_root := get_tree().root
	scene_root.set_meta(FUBO_TRAVEL.RETURN_REQUEST_META, true)
	await _loading_transition.play_loading("正在返回岭南海图")
	var change_error := get_tree().change_scene_to_file(FUBO_TRAVEL.SEA_SCENE_PATH)
	if change_error == OK:
		return
	scene_root.remove_meta(FUBO_TRAVEL.RETURN_REQUEST_META)
	_loading_transition.reset_loading()
	_transitioning = false
	player.controls_enabled = true
	_pending_trigger = "sea_return"
	prompt_label.text = "返回海图失败，请按 E / 空格重试"
	prompt_panel.visible = true
	_refresh_exploration_hud()


func _open_fishing_minigame() -> bool:
	if not _is_fishing_available():
		return false
	var entry_position := player.global_position
	_fishing_return_phase = phase
	_pending_trigger = ""
	prompt_panel.visible = false
	if not minigame_host.open_minigame(FISHING_SCENE, "fishing"):
		return false
	_minigame_return_position = entry_position
	phase = Phase.FISHING_ACTIVE
	_sync_fishing_station()
	_refresh_exploration_hud()
	return true


func _open_drum_minigame() -> bool:
	if phase != Phase.DRUM_AVAILABLE:
		return false
	var entry_position := player.global_position
	_pending_trigger = ""
	prompt_panel.visible = false
	if not minigame_host.open_minigame(DRUM_SCENE, "drum"):
		return false
	_minigame_return_position = entry_position
	phase = Phase.DRUM_ACTIVE
	_refresh_exploration_hud()
	return true


func _on_minigame_finished(result: Dictionary) -> void:
	if not result.get("completed", false):
		return
	match String(result.get("game_id", "")):
		"fishing":
			_complete_fishing(result)
		"drum":
			_complete_drum(result)


func _complete_fishing(result: Dictionary) -> void:
	if phase != Phase.FISHING_ACTIVE:
		return
	var first_completion := _fishing_return_phase in [Phase.ARRIVAL, Phase.FISHING_AVAILABLE]
	phase = Phase.DRUM_AVAILABLE if first_completion else _fishing_return_phase
	_apply_phase_world_state()
	_refresh_exploration_hud()
	if not _test_mode:
		_show_notice("渔获满舱，收竿归岸", 1.8)


func _complete_drum(_result: Dictionary) -> void:
	if phase != Phase.DRUM_ACTIVE:
		return
	phase = Phase.VIEWPOINT_OPEN
	_refresh_exploration_hud()
	if not _test_mode:
		_show_notice("三轮鼓令完成，观景台入口已开放", 1.8)


func _on_minigame_cancelled(game_id: String) -> void:
	var should_restore_position := true
	match game_id:
		"fishing":
			phase = _fishing_return_phase
		"drum":
			phase = Phase.DRUM_AVAILABLE
		_:
			should_restore_position = false
	if should_restore_position:
		player.global_position = _minigame_return_position
		player.velocity = Vector2.ZERO
		player.cancel_move_target()
		player.call("set_move_direction", Vector2.ZERO)
	player.controls_enabled = true
	prompt_panel.visible = false
	_sync_fishing_station()
	_refresh_exploration_hud()
	_refresh_minigame_interaction.call_deferred()


func _refresh_minigame_interaction() -> void:
	if _transitioning or minigame_host.active_minigame != null:
		return
	if _is_fishing_available() and fishing_trigger.overlaps_body(player):
		_on_fishing_body_entered(player)
	elif phase == Phase.DRUM_AVAILABLE and school_trigger.overlaps_body(player):
		_on_school_body_entered(player)


func _on_viewpoint_body_entered(body: Node) -> void:
	if body != player or phase != Phase.VIEWPOINT_OPEN or _transitioning:
		return
	_transitioning = true
	_completion_return_position = player.global_position
	_pending_trigger = ""
	prompt_panel.visible = false
	fishing_station.set_highlighted(false)
	player.controls_enabled = false
	player.cancel_move_target()
	player.velocity = Vector2.ZERO
	_refresh_exploration_hud()
	await completion_cutscene.play()
	player.global_position = _completion_return_position
	player.velocity = Vector2.ZERO
	player.cancel_move_target()
	player.call("set_move_direction", Vector2.ZERO)
	phase = Phase.COMPLETE
	_transitioning = false
	player.controls_enabled = true
	_sync_fishing_station()
	_refresh_exploration_hud()
	_refresh_minigame_interaction.call_deferred()


func _show_notice(text_value: String, duration: float) -> void:
	overlay_text.text = text_value
	overlay.visible = true
	_refresh_exploration_hud()
	await get_tree().create_timer(duration).timeout
	if minigame_host.active_minigame == null:
		overlay.visible = false
		_refresh_exploration_hud()


func _build_collision_debug() -> void:
	for parent in [$World/Collision, $World/Triggers]:
		for physics_node in parent.find_children("*", "CollisionObject2D", true, false):
			for child in physics_node.get_children():
				if child is CollisionShape2D and child.shape != null:
					_add_shape_debug(physics_node, child, parent == $World/Collision)
				elif child is CollisionPolygon2D:
					if child.build_mode == CollisionPolygon2D.BUILD_SEGMENTS:
						var boundary := Line2D.new()
						boundary.points = child.polygon
						boundary.closed = true
						boundary.width = 6.0
						boundary.default_color = Color(1.0, 0.2, 0.12, 0.9)
						boundary.position = physics_node.position + child.position
						collision_debug.add_child(boundary)
					else:
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
	_test_mode = true
	_keeper_intro_completed = true
	_refresh_exploration_hud()


func is_keeper_intro_completed_for_test() -> bool:
	return _keeper_intro_completed


func trigger_fishing_for_test() -> bool:
	return _open_fishing_minigame()


func trigger_drum_for_test() -> bool:
	return _open_drum_minigame()


func get_phase_for_test() -> int:
	return phase


func is_school_locked_for_test() -> bool:
	return not school_shape.disabled
