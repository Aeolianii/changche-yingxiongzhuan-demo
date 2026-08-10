extends SceneTree

const HOST_SCRIPT := preload("res://scripts/fubo_guling/minigames/fubo_minigame_host.gd")

var _failures: Array[String] = []


class FakeGame extends Control:
	signal completed(result: Dictionary)
	signal exit_requested
	var game_id := "fake"


class FakePlayer extends CharacterBody2D:
	var controls_enabled := true

	func cancel_move_target() -> void:
		velocity = Vector2.ZERO


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	await _test_finish_restores_original_state()
	await _test_cancel_restores_original_state()
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
