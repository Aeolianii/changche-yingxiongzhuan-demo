extends SceneTree

const HOST_SCRIPT := preload("res://scripts/fubo_guling/minigames/fubo_minigame_host.gd")
const BASE_SCRIPT := preload("res://scripts/fubo_guling/minigames/fubo_minigame_base.gd")

var _failures: Array[String] = []


class FakeGame extends Control:
	signal completed(result: Dictionary)
	signal exit_requested
	var game_id := "fake"


class FakePlayer extends CharacterBody2D:
	var controls_enabled := true

	func cancel_move_target() -> void:
		velocity = Vector2.ZERO


class StandaloneExitProbe extends FuboMinigameBase:
	var legacy_quit_requested := false
	var requested_scene_path := ""

	func _quit_standalone() -> void:
		legacy_quit_requested = true

	func _change_to_standalone_return_scene(scene_path: String) -> void:
		requested_scene_path = scene_path


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_finish_restores_original_state()
	await _test_cancel_restores_original_state()
	_test_minigame_exit_routes_by_host_presence()
	if not _failures.is_empty():
		for failure in _failures:
			push_error(failure)
		quit(1)
		return
	print("Fubo minigame host verification passed.")
	quit(0)


func _test_finish_restores_original_state() -> void:
	var fixture := _make_fixture()
	var host: Control = fixture.host
	var packed := _pack_fake_game()
	_check(host.open_minigame(packed, "fake"), "First minigame open must succeed.")
	_check(not host.open_minigame(packed, "duplicate"), "Second open must be rejected while active.")
	_check(not fixture.world.visible and not fixture.hud.visible, "Opening must hide world and HUD.")
	_check(not fixture.player.controls_enabled, "Opening must disable player controls.")
	var result := {"game_id": "fake", "completed": true, "rating": "ok", "mistakes": 0, "duration_ms": 10}
	host.active_minigame.completed.emit(result)
	await process_frame
	_check(fixture.world.visible and not fixture.hud.visible, "Finish must restore each node's original visibility.")
	_check(fixture.world.process_mode == Node.PROCESS_MODE_ALWAYS, "Finish must restore original world process mode.")
	_check(fixture.hud.process_mode == Node.PROCESS_MODE_WHEN_PAUSED, "Finish must restore original HUD process mode.")
	_check(fixture.player.controls_enabled, "Finish must restore player controls.")
	fixture.root.queue_free()
	await process_frame


func _test_cancel_restores_original_state() -> void:
	var fixture := _make_fixture()
	var host: Control = fixture.host
	_check(host.open_minigame(_pack_fake_game(), "fake"), "Open before cancel must succeed.")
	host.active_minigame.exit_requested.emit()
	await process_frame
	_check(host.active_minigame == null, "Cancel must clear active minigame.")
	_check(fixture.world.visible and not fixture.hud.visible, "Cancel must restore original visibility.")
	_check(fixture.player.controls_enabled, "Cancel must restore controls.")
	fixture.root.queue_free()
	await process_frame


func _test_minigame_exit_routes_by_host_presence() -> void:
	var hosted := StandaloneExitProbe.new()
	var exit_seen := [0]
	hosted.exit_requested.connect(func(): exit_seen[0] += 1)
	if hosted.has_method("request_exit"):
		hosted.request_exit()
	_check(hosted.has_method("request_exit"), "Minigames need a unified exit entry point.")
	_check(exit_seen[0] == 1 and not hosted.legacy_quit_requested and hosted.requested_scene_path.is_empty(), "Hosted exit must emit once without quitting or replacing the current scene.")
	hosted.free()

	var standalone := StandaloneExitProbe.new()
	var return_path := "res://scenes/fubo_guling/fubo_guling.tscn"
	var has_return_property := standalone.get_property_list().any(func(property: Dictionary): return property.name == "standalone_return_scene_path")
	if has_return_property:
		standalone.set("standalone_return_scene_path", return_path)
	if standalone.has_method("request_exit"):
		standalone.request_exit()
	_check(standalone.has_method("request_exit"), "Standalone minigames must use the unified exit entry point.")
	_check(has_return_property, "Standalone minigames need a configured map-return scene.")
	_check(not standalone.legacy_quit_requested, "Returning to the map must never quit the application.")
	_check(standalone.requested_scene_path == return_path, "An unhosted minigame must change to its configured map scene.")
	standalone.free()


func _make_fixture() -> Dictionary:
	var fixture_root := Node.new()
	root.add_child(fixture_root)
	var world := Node2D.new()
	world.name = "World"
	world.process_mode = Node.PROCESS_MODE_ALWAYS
	fixture_root.add_child(world)
	var hud := Control.new()
	hud.name = "HUD"
	hud.visible = false
	hud.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	fixture_root.add_child(hud)
	var player := FakePlayer.new()
	player.name = "Player"
	fixture_root.add_child(player)
	var host := Control.new()
	host.name = "Host"
	host.set_script(HOST_SCRIPT)
	fixture_root.add_child(host)
	host.configure(world, hud, player)
	return {"root": fixture_root, "world": world, "hud": hud, "player": player, "host": host}


func _pack_fake_game() -> PackedScene:
	var game := FakeGame.new()
	var packed := PackedScene.new()
	packed.pack(game)
	game.free()
	return packed


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
