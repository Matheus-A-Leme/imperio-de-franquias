extends Node2D

const GameStateScript = preload("res://scripts/game_state.gd")
const BuildCatalogScript = preload("res://scripts/build_catalog.gd")

var game_state = GameStateScript.new(10000)

@onready var build_system = $BuildSystem
@onready var money_label: Label = $HUD/TopBar/Money/Label
@onready var build_button: Button = $HUD/TopBar/BuildButton
@onready var build_panel: Panel = $HUD/BuildPanel
@onready var close_build_panel_button: Button = $HUD/BuildPanel/CloseButton
@onready var build_hint: Label = $HUD/BuildHint


func _ready() -> void:
	build_system.setup(game_state)
	game_state.money_changed.connect(_update_money)
	build_system.feedback_changed.connect(_update_build_hint)
	build_button.pressed.connect(_toggle_build_panel)
	close_build_panel_button.pressed.connect(_close_build_panel)

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

	_update_money(game_state.money)
	build_panel.hide()
	build_hint.hide()


func _toggle_build_panel() -> void:
	var should_open := not build_panel.visible
	build_system.cancel_selection()
	build_panel.visible = should_open


func _close_build_panel() -> void:
	build_panel.hide()
	build_system.cancel_selection()


func _select_build_item(item_id: StringName) -> void:
	if build_system.select_item(item_id):
		build_panel.hide()


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
