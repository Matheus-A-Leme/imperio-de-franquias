extends Node2D

const BuildCatalogScript = preload("res://scripts/build_catalog.gd")
const PauseMenuScene = preload("res://scenes/pause_menu.tscn")

var game_state
var pause_menu

@onready var build_system = $BuildSystem
@onready var company_sign_label: Label = $World/Shop/StoreSign/Label
@onready var money_label: Label = $HUD/TopBar/Money/Label
@onready var build_button: Button = $HUD/TopBar/BuildButton
@onready var build_panel: Panel = $HUD/BuildPanel
@onready var close_build_panel_button: Button = $HUD/BuildPanel/CloseButton
@onready var build_hint: Label = $HUD/BuildHint
@onready var item_actions: Panel = $HUD/ItemActions
@onready var selected_item_label: Label = $HUD/ItemActions/SelectedItemLabel
@onready var move_button: Button = $HUD/ItemActions/MoveButton
@onready var sell_button: Button = $HUD/ItemActions/SellButton


func _ready() -> void:
	game_state = GameSession.get_or_create_game_state()
	company_sign_label.text = GameSession.company_name.to_upper()
	build_system.setup(game_state)
	game_state.money_changed.connect(_update_money)
	build_system.feedback_changed.connect(_update_build_hint)
	build_system.built_item_selected.connect(_update_item_actions)
	build_button.pressed.connect(_toggle_build_panel)
	close_build_panel_button.pressed.connect(_close_build_panel)
	move_button.pressed.connect(_move_selected_item)
	sell_button.pressed.connect(_sell_selected_item)

	var catalog_buttons: Dictionary = {
		&"griddle": $HUD/BuildPanel/GriddleButton,
		&"refrigerator": $HUD/BuildPanel/RefrigeratorButton,
		&"table": $HUD/BuildPanel/TableButton,
	}
	for item_id in BuildCatalogScript.ITEM_IDS:
		var item: Dictionary = BuildCatalogScript.get_item(item_id)
		var item_button: Button = catalog_buttons[item_id]
		item_button.text = "%s — %s" % [item["display_name"], _format_money(item["price"])]
		item_button.pressed.connect(_select_build_item.bind(item_id))

	pause_menu = PauseMenuScene.instantiate()
	add_child(pause_menu)
	_update_money(game_state.money)
	build_panel.hide()
	build_hint.hide()
	item_actions.hide()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if build_system.has_active_interaction():
			return
		pause_menu.open_pause()
		get_viewport().set_input_as_handled()


func _toggle_build_panel() -> void:
	var should_open := not build_panel.visible
	build_system.cancel_selection()
	build_system.clear_built_selection()
	item_actions.hide()
	build_panel.visible = should_open


func _close_build_panel() -> void:
	build_panel.hide()
	build_system.cancel_selection()


func _select_build_item(item_id: StringName) -> void:
	if build_system.select_item(item_id):
		build_panel.hide()


func _move_selected_item() -> void:
	if build_system.start_move_selected():
		item_actions.hide()


func _sell_selected_item() -> void:
	build_system.sell_selected()


func _update_item_actions(item_data: Dictionary, refund_amount: int) -> void:
	if item_data.is_empty():
		item_actions.hide()
		return
	selected_item_label.text = item_data["display_name"]
	sell_button.text = "Vender · %s" % _format_money(refund_amount)
	item_actions.show()


func _update_money(new_amount: int) -> void:
	money_label.text = _format_money(new_amount)


func _update_build_hint(message: String) -> void:
	build_hint.text = message
	build_hint.visible = not message.is_empty()


func _format_money(amount: int) -> String:
	var digits := str(amount)
	var formatted := ""
	var group_count := 0
	for index in range(digits.length() - 1, -1, -1):
		if group_count > 0 and group_count % 3 == 0:
			formatted = "." + formatted
		formatted = digits[index] + formatted
		group_count += 1
	return "R$ " + formatted
