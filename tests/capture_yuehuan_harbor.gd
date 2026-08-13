extends SceneTree

const HARBOR := preload("res://scenes/yuehuan_merchant_harbor/yuehuan_merchant_harbor.tscn")


func _initialize() -> void:
	run.call_deferred()


func run() -> void:
	var scene := HARBOR.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await process_frame
	(scene.get_node("World/WorldObjects/LiangTrader") as Node).call("show_bark_for_test")
	await RenderingServer.frame_post_draw
	var exploration_error := root.get_texture().get_image().save_png("res://.godot/yuehuan_merchant_island_exploration.png")
	scene.call("open_merchant_dialogue_for_test", "liang")
	scene.call("choose_trade_for_test")
	await process_frame
	await RenderingServer.frame_post_draw
	var goods_error := root.get_texture().get_image().save_png("res://.godot/yuehuan_merchant_island_goods.png")
	scene.call("close_shop_for_test")
	scene.call("open_merchant_dialogue_for_test", "shen")
	scene.call("choose_trade_for_test")
	await process_frame
	await RenderingServer.frame_post_draw
	var shipyard_error := root.get_texture().get_image().save_png("res://.godot/yuehuan_merchant_island_shipyard.png")
	print("Yuehuan captures: ", exploration_error, ", ", goods_error, ", ", shipyard_error)
	quit(0 if exploration_error == OK and goods_error == OK and shipyard_error == OK else 1)
