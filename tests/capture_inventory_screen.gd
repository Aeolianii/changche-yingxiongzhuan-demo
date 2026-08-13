extends SceneTree
const HUD := preload("res://scenes/ui/exploration_hud.tscn")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var hud := HUD.instantiate(); root.add_child(hud); hud.call("set_exploration_visible", true)
	await process_frame
	(hud.find_child("InventoryButton", true, false) as Button).pressed.emit()
	await process_frame; await process_frame; await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://.godot/inventory_screen_preview.png")
	print("Inventory capture saved: ", error)
	quit(0 if error == OK else 1)
