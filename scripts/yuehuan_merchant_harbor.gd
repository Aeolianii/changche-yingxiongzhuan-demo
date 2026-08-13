class_name YuehuanMerchantHarbor
extends Node2D

enum State { EXPLORING, DIALOGUE, SHOP, TRANSITIONING }

const FUBO_TRAVEL := preload("res://scripts/fubo_guling/fubo_travel_session.gd")
const FIELD_EVENT_DIALOGUE_SCENE := preload("res://scenes/ui/field_event_dialogue.tscn")
const SEA_SCENE := "res://scenes/sea_overworld/sea_overworld.tscn"

@onready var player: CharacterBody2D = $World/WorldObjects/Player
@onready var prompt_panel: Control = $Interface/PromptPanel
@onready var prompt_label: Label = $Interface/PromptPanel/Prompt
@onready var shop_overlay: Control = $Interface/MerchantShopOverlay
@onready var liang: Node2D = $World/WorldObjects/LiangTrader
@onready var shen: Node2D = $World/WorldObjects/ShenShipwright

var state := State.EXPLORING
var _nearby: Array[Node2D] = []
var _active_merchant: Node2D
var dialogue_panel: FieldEventDialogue
var exploration_hud: Control
var _exploration_ui: Node
var _global_menu_open := false


func _ready() -> void:
	dialogue_panel = FIELD_EVENT_DIALOGUE_SCENE.instantiate() as FieldEventDialogue
	dialogue_panel.name = "MerchantDialogue"
	$Interface.add_child(dialogue_panel)
	dialogue_panel.option_selected.connect(_on_dialogue_option)
	shop_overlay.closed.connect(_on_shop_closed)
	_exploration_ui = get_node_or_null("/root/ExplorationUI")
	if _exploration_ui != null:
		exploration_hud = _exploration_ui.call("acquire", self, &"yuehuan_merchant_island") as Control
		if exploration_hud != null:
			exploration_hud.call("set_exploration_visible", true)
			exploration_hud.call("set_main_task_progress", "游览月环商岛", "与商人交谈，购买图纸或交易造船材料", 1)
		_connect_global_hud_signals()
	$World/WorldObjects/LiangTrader/Interaction.body_entered.connect(_on_merchant_entered.bind(liang))
	$World/WorldObjects/LiangTrader/Interaction.body_exited.connect(_on_merchant_exited.bind(liang))
	$World/WorldObjects/ShenShipwright/Interaction.body_entered.connect(_on_merchant_entered.bind(shen))
	$World/WorldObjects/ShenShipwright/Interaction.body_exited.connect(_on_merchant_exited.bind(shen))
	$World/Triggers/DockReturn.body_entered.connect(_on_dock_entered)
	$World/Triggers/DockReturn.body_exited.connect(_on_dock_exited)
	_refresh_controls()


func _exit_tree() -> void:
	if _exploration_ui == null:
		return
	var callback := Callable(self, "_on_global_menu_visibility_changed")
	if _exploration_ui.is_connected(&"menu_visibility_changed", callback):
		_exploration_ui.disconnect(&"menu_visibility_changed", callback)
	_exploration_ui.call("release", self)


func _connect_global_hud_signals() -> void:
	var callback := Callable(self, "_on_global_menu_visibility_changed")
	if not _exploration_ui.is_connected(&"menu_visibility_changed", callback):
		_exploration_ui.connect(&"menu_visibility_changed", callback)


func _on_global_menu_visibility_changed(is_open: bool) -> void:
	if _exploration_ui.call("current_owner") != self:
		return
	_global_menu_open = is_open
	_refresh_controls()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).echo:
		return
	if event.is_action_pressed("interact"):
		if state == State.EXPLORING:
			_handle_world_interaction()
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
	elif event.is_action_pressed("ui_cancel"):
		if state == State.SHOP:
			shop_overlay.call("close_shop")
		elif state == State.DIALOGUE:
			_close_dialogue()


func _handle_world_interaction() -> void:
	var target := _nearest_target()
	if target == null:
		return
	if target == $World/Triggers/DockReturn:
		_return_to_sea()
	else:
		_open_merchant_dialogue(target)


func _open_merchant_dialogue(merchant: Node2D) -> void:
	_set_merchant_barks_enabled(false)
	_active_merchant = merchant
	state = State.DIALOGUE
	dialogue_panel.present(
		str(merchant.get("display_name")),
		str(merchant.get("dialogue_text")),
		merchant.get("portrait") as Texture2D,
		[
			{"id": &"trade", "text": merchant.call("trade_option_text")},
			{"id": &"leave", "text": "告辞"},
		]
	)
	_refresh_controls()


func _on_dialogue_option(option_id: StringName) -> void:
	if option_id == &"trade" and _active_merchant != null:
		dialogue_panel.hide_dialogue()
		state = State.SHOP
		if exploration_hud != null:
			exploration_hud.call("set_exploration_visible", false)
		shop_overlay.call("open_shop", str(_active_merchant.get("shop_role")), "%s · %s" % [_active_merchant.get("display_name"), "货栈" if _active_merchant.get("shop_role") == "goods" else "船行"])
		_refresh_controls()
	else:
		_close_dialogue()


func _close_dialogue() -> void:
	dialogue_panel.hide_dialogue()
	state = State.EXPLORING
	_active_merchant = null
	_set_merchant_barks_enabled(true)
	_refresh_controls()


func _on_shop_closed() -> void:
	state = State.EXPLORING
	_active_merchant = null
	if exploration_hud != null:
		exploration_hud.call("set_exploration_visible", true)
	_set_merchant_barks_enabled(true)
	_refresh_controls()


func _refresh_controls() -> void:
	player.set("controls_enabled", state == State.EXPLORING and not _global_menu_open)
	_set_merchant_barks_enabled(state == State.EXPLORING and not _global_menu_open)
	prompt_panel.visible = state == State.EXPLORING and not _global_menu_open and not _nearby.is_empty()
	if prompt_panel.visible:
		var target := _nearest_target()
		prompt_label.text = "按 E / 空格　%s" % ("返回海图" if target == $World/Triggers/DockReturn else target.call("interaction_prompt"))


func _nearest_target() -> Node2D:
	var nearest: Node2D
	var best := INF
	for target in _nearby:
		if not is_instance_valid(target):
			continue
		var distance := player.global_position.distance_squared_to(target.global_position)
		if distance < best:
			best = distance
			nearest = target
	return nearest


func _on_merchant_entered(body: Node, merchant: Node2D) -> void:
	if body == player and merchant not in _nearby:
		_nearby.append(merchant)
		_refresh_controls()


func _on_merchant_exited(body: Node, merchant: Node2D) -> void:
	if body == player:
		_nearby.erase(merchant)
		_refresh_controls()


func _on_dock_entered(body: Node) -> void:
	if body == player and $World/Triggers/DockReturn not in _nearby:
		_nearby.append($World/Triggers/DockReturn)
		_refresh_controls()


func _on_dock_exited(body: Node) -> void:
	if body == player:
		_nearby.erase($World/Triggers/DockReturn)
		_refresh_controls()


func _return_to_sea() -> void:
	if state != State.EXPLORING:
		return
	state = State.TRANSITIONING
	_refresh_controls()
	get_tree().root.set_meta(FUBO_TRAVEL.RETURN_REQUEST_META, true)
	get_tree().change_scene_to_file(SEA_SCENE)


func is_shop_open_for_test() -> bool:
	return state == State.SHOP


func open_merchant_dialogue_for_test(merchant_id: String) -> void:
	_open_merchant_dialogue(liang if merchant_id == "liang" else shen)


func choose_trade_for_test() -> void:
	_on_dialogue_option(&"trade")


func close_shop_for_test() -> void:
	shop_overlay.call("close_shop")


func close_dialogue_for_test() -> void:
	_close_dialogue()


func active_shop_role_for_test() -> String:
	return str(shop_overlay.call("active_role"))


func nearest_interaction_id_for_test() -> String:
	var target := _nearest_target()
	if target == null:
		return ""
	if target == $World/Triggers/DockReturn:
		return "dock"
	return str(target.get("merchant_id"))


func _set_merchant_barks_enabled(enabled: bool) -> void:
	for merchant in [liang, shen]:
		if merchant.has_method("set_barks_enabled"):
			merchant.call("set_barks_enabled", enabled)
