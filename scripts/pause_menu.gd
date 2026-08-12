extends CanvasLayer

const SettingsMenuScene = preload("res://scenes/settings_menu.tscn")

var settings_overlay


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	$Overlay/PausePanel/ContinueButton.pressed.connect(continue_game)
	$Overlay/PausePanel/SettingsButton.pressed.connect(_open_settings)
	$Overlay/PausePanel/MainMenuButton.pressed.connect(_show_confirmation)
	$Overlay/ConfirmationPanel/YesButton.pressed.connect(_return_to_main_menu)
	$Overlay/ConfirmationPanel/NoButton.pressed.connect(_hide_confirmation)
	$Overlay/ConfirmationPanel.hide()
	hide()


func open_pause() -> void:
	show()
	$Overlay/PausePanel.show()
	$Overlay/ConfirmationPanel.hide()
	get_tree().paused = true


func continue_game() -> void:
	if settings_overlay != null:
		settings_overlay.queue_free()
		settings_overlay = null
	hide()
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or settings_overlay != null:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if $Overlay/ConfirmationPanel.visible:
			_hide_confirmation()
		else:
			continue_game()
		get_viewport().set_input_as_handled()


func _open_settings() -> void:
	$Overlay/PausePanel.hide()
	settings_overlay = SettingsMenuScene.instantiate()
	settings_overlay.standalone = false
	settings_overlay.back_requested.connect(_close_settings)
	add_child(settings_overlay)


func _close_settings() -> void:
	if settings_overlay != null:
		settings_overlay.queue_free()
		settings_overlay = null
	$Overlay/PausePanel.show()


func _show_confirmation() -> void:
	$Overlay/PausePanel.hide()
	$Overlay/ConfirmationPanel.show()


func _hide_confirmation() -> void:
	$Overlay/ConfirmationPanel.hide()
	$Overlay/PausePanel.show()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	GameSession.abandon_game()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
