extends Control

@onready var company_name_input: LineEdit = $FormPanel/CompanyNameInput
@onready var validation_label: Label = $FormPanel/ValidationLabel


func _ready() -> void:
	company_name_input.text = GameSession.DEFAULT_COMPANY_NAME
	$FormPanel/StartButton.pressed.connect(_start_game)
	$FormPanel/BackButton.pressed.connect(_go_back)
	company_name_input.text_submitted.connect(_on_name_submitted)
	validation_label.hide()


func _start_game() -> void:
	if not GameSession.start_new_game(company_name_input.text):
		validation_label.text = "Informe um nome para a empresa."
		validation_label.show()
		company_name_input.grab_focus()
		return
	get_tree().change_scene_to_file("res://main.tscn")


func _on_name_submitted(_new_text: String) -> void:
	_start_game()


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_go_back()
