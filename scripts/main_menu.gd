extends Control


func _ready() -> void:
	$MenuPanel/Buttons/NewGameButton.pressed.connect(_open_new_game)
	$MenuPanel/Buttons/SettingsButton.pressed.connect(_open_settings)
	$MenuPanel/Buttons/ExitButton.pressed.connect(_exit_game)
	$MenuPanel/Buttons/ContinueButton.disabled = true


func _open_new_game() -> void:
	get_tree().change_scene_to_file("res://scenes/new_game_menu.tscn")


func _open_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")


func _exit_game() -> void:
	get_tree().quit()
