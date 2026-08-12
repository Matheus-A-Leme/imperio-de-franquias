extends SceneTree


func _init() -> void:
	call_deferred("_test_exit_button")


func _test_exit_button() -> void:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu.get_node("MenuPanel/Buttons/ExitButton").pressed.emit()
