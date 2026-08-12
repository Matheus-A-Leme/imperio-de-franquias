class_name BuildSystem
extends Node2D

const BuildCatalogScript = preload("res://scripts/build_catalog.gd")
const BuildablePlaceholderScript = preload("res://scripts/buildable_placeholder.gd")

signal selection_changed(item_data: Dictionary)
signal built_item_selected(item_data: Dictionary, refund_amount: int)
signal purchase_completed(item_data: Dictionary, remaining_money: int)
signal feedback_changed(message: String)

const GRID_SIZE := 24
const GRID_ORIGIN := Vector2i(208, 128)
const GRID_CELL_COUNT := Vector2i(36, 21)

const ZONE_RECTS: Dictionary = {
	&"kitchen": Rect2i(0, 0, 36, 10),
	&"dining": Rect2i(0, 10, 36, 11),
}

const ENTRANCE_RESERVED_RECT := Rect2i(14, 17, 8, 4)

const INITIAL_OCCUPIED_RECTS: Array[Rect2i] = [
	Rect2i(0, 0, 5, 6),
	Rect2i(6, 1, 6, 4),
	Rect2i(13, 1, 7, 4),
	Rect2i(21, 1, 14, 4),
	Rect2i(3, 6, 30, 4),
	Rect2i(3, 11, 8, 7),
	Rect2i(14, 11, 8, 7),
	Rect2i(25, 11, 8, 7),
]

var game_state
var selected_item: Dictionary = {}
var occupied_cells: Dictionary = {}
var ghost
var built_items: Node2D
var built_records: Dictionary = {}
var selected_built_item
var moving_item = false
var move_original_cell := Vector2i.ZERO


func _ready() -> void:
	built_items = Node2D.new()
	built_items.name = "BuiltItems"
	add_child(built_items)
	for occupied_rect in INITIAL_OCCUPIED_RECTS:
		_mark_occupied_rect(occupied_rect)
	set_process(true)


func setup(state) -> void:
	game_state = state


func select_item(item_id: StringName) -> bool:
	var item: Dictionary = BuildCatalogScript.get_item(item_id)
	if item.is_empty():
		return false

	cancel_selection()
	clear_built_selection()
	selected_item = item
	_create_ghost()
	selection_changed.emit(selected_item)
	feedback_changed.emit("Posicione %s no grid · ESC cancela" % selected_item["display_name"])
	queue_redraw()
	return true



func has_active_interaction() -> bool:
	return not selected_item.is_empty() or selected_built_item != null or moving_item

func cancel_selection() -> void:
	if moving_item:
		_restore_moving_item()
		return
	if selected_item.is_empty():
		return
	selected_item = {}
	_clear_ghost()
	selection_changed.emit({})
	feedback_changed.emit("")
	queue_redraw()


func clear_built_selection() -> void:
	if selected_built_item == null:
		return
	selected_built_item.set_selected(false)
	selected_built_item = null
	built_item_selected.emit({}, 0)


func select_built_item_at_cell(cell: Vector2i) -> bool:
	if not selected_item.is_empty():
		return false
	var built_item = _find_built_item_at_cell(cell)
	if built_item == null:
		clear_built_selection()
		return false

	clear_built_selection()
	selected_built_item = built_item
	selected_built_item.set_selected(true)
	var record: Dictionary = built_records[selected_built_item]
	var item_data: Dictionary = record["item"]
	built_item_selected.emit(item_data, get_selected_refund())
	feedback_changed.emit("%s selecionada" % item_data["display_name"])
	return true


func start_move_selected() -> bool:
	if selected_built_item == null or moving_item:
		return false

	var record: Dictionary = built_records[selected_built_item]
	selected_item = record["item"]
	move_original_cell = record["cell"]
	_unmark_occupied(move_original_cell, selected_item["footprint"])
	selected_built_item.visible = false
	selected_built_item.set_selected(false)
	moving_item = true
	_create_ghost()
	selection_changed.emit(selected_item)
	built_item_selected.emit({}, 0)
	feedback_changed.emit("Mova %s · ESC restaura" % selected_item["display_name"])
	queue_redraw()
	return true


func sell_selected() -> bool:
	if selected_built_item == null or moving_item or game_state == null:
		return false

	var record: Dictionary = built_records[selected_built_item]
	var item_data: Dictionary = record["item"]
	var refund := get_selected_refund()
	_unmark_occupied(record["cell"], item_data["footprint"])
	built_records.erase(selected_built_item)
	selected_built_item.queue_free()
	selected_built_item = null
	game_state.add_money(refund)
	built_item_selected.emit({}, 0)
	feedback_changed.emit("%s vendida por R$ %d" % [item_data["display_name"], refund])
	return true


func get_selected_refund() -> int:
	if selected_built_item == null or not built_records.has(selected_built_item):
		return 0
	var item_data: Dictionary = built_records[selected_built_item]["item"]
	return roundi(item_data["price"] * BuildCatalogScript.SELL_REFUND_RATE)


func get_zone_at_cell(cell: Vector2i) -> StringName:
	for zone_id in ZONE_RECTS:
		var zone_rect: Rect2i = ZONE_RECTS[zone_id]
		if zone_rect.has_point(cell):
			return zone_id
	return &""


func is_position_valid(item_id: StringName, cell: Vector2i) -> bool:
	var item: Dictionary = BuildCatalogScript.get_item(item_id)
	if item.is_empty():
		return false

	var footprint: Vector2i = item["footprint"]
	if not _footprint_is_inside(cell, footprint):
		return false
	if not _footprint_is_in_allowed_zone(cell, footprint, item["allowed_zones"]):
		return false
	if _footprint_overlaps_rect(cell, footprint, ENTRANCE_RESERVED_RECT):
		return false

	for y in range(cell.y, cell.y + footprint.y):
		for x in range(cell.x, cell.x + footprint.x):
			if occupied_cells.has(Vector2i(x, y)):
				return false
	return true


func try_place_at_cell(cell: Vector2i) -> bool:
	if selected_item.is_empty() or game_state == null:
		return false

	var item_id: StringName = selected_item["id"]
	if not is_position_valid(item_id, cell):
		feedback_changed.emit("Posição inválida, ocupada ou em zona incorreta")
		return false

	if moving_item:
		_confirm_move(cell)
		return true

	var price: int = selected_item["price"]
	if not game_state.try_spend(price):
		feedback_changed.emit("Dinheiro insuficiente para %s" % selected_item["display_name"])
		return false

	_place_new_item(selected_item, cell)
	purchase_completed.emit(selected_item, game_state.money)
	feedback_changed.emit("%s construída · ESC cancela" % selected_item["display_name"])
	return true


func world_to_cell(world_position: Vector2) -> Vector2i:
	return Vector2i(floori((world_position.x - GRID_ORIGIN.x) / GRID_SIZE), floori((world_position.y - GRID_ORIGIN.y) / GRID_SIZE))


func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(GRID_ORIGIN + cell * GRID_SIZE)


func _process(_delta: float) -> void:
	if ghost == null or selected_item.is_empty():
		return

	var cell := world_to_cell(get_global_mouse_position())
	ghost.position = cell_to_world(cell)
	var position_valid := is_position_valid(selected_item["id"], cell)
	var can_afford: bool = moving_item or (game_state != null and game_state.can_afford(selected_item["price"]))
	ghost.set_placement_valid(position_valid and can_afford)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if selected_item.is_empty() and selected_built_item == null:
			return
		if not selected_item.is_empty():
			cancel_selection()
		else:
			clear_built_selection()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cell := world_to_cell(get_global_mouse_position())
		if not selected_item.is_empty():
			try_place_at_cell(cell)
		else:
			select_built_item_at_cell(cell)
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if selected_item.is_empty():
		return

	_draw_zone_grid(ZONE_RECTS[&"kitchen"], Color(0.34, 0.75, 0.82, 0.12), Color(0.42, 0.83, 0.88, 0.28))
	_draw_zone_grid(ZONE_RECTS[&"dining"], Color(0.94, 0.68, 0.3, 0.08), Color(0.95, 0.72, 0.36, 0.22))
	var entrance_rect := Rect2(cell_to_world(ENTRANCE_RESERVED_RECT.position), Vector2(ENTRANCE_RESERVED_RECT.size * GRID_SIZE))
	draw_rect(entrance_rect, Color(0.9, 0.28, 0.25, 0.16), true)
	draw_rect(entrance_rect, Color(0.95, 0.4, 0.35, 0.5), false, 2.0)


func _draw_zone_grid(zone_rect: Rect2i, fill_color: Color, line_color: Color) -> void:
	var origin := cell_to_world(zone_rect.position)
	var size := Vector2(zone_rect.size * GRID_SIZE)
	draw_rect(Rect2(origin, size), fill_color, true)
	for x in range(zone_rect.size.x + 1):
		var line_x := origin.x + x * GRID_SIZE
		draw_line(Vector2(line_x, origin.y), Vector2(line_x, origin.y + size.y), line_color, 1.0)
	for y in range(zone_rect.size.y + 1):
		var line_y := origin.y + y * GRID_SIZE
		draw_line(Vector2(origin.x, line_y), Vector2(origin.x + size.x, line_y), line_color, 1.0)


func _place_new_item(item_data: Dictionary, cell: Vector2i) -> void:
	var built_item = BuildablePlaceholderScript.new()
	built_item.name = "%s_%d" % [item_data["display_name"], built_items.get_child_count() + 1]
	built_item.position = cell_to_world(cell)
	built_item.configure(item_data)
	built_items.add_child(built_item)
	built_records[built_item] = {"item": item_data.duplicate(true), "cell": cell}
	_mark_occupied(cell, item_data["footprint"])


func _confirm_move(cell: Vector2i) -> void:
	selected_built_item.position = cell_to_world(cell)
	selected_built_item.visible = true
	built_records[selected_built_item]["cell"] = cell
	_mark_occupied(cell, selected_item["footprint"])
	moving_item = false
	selected_item = {}
	_clear_ghost()
	selected_built_item.set_selected(true)
	var record: Dictionary = built_records[selected_built_item]
	built_item_selected.emit(record["item"], get_selected_refund())
	selection_changed.emit({})
	feedback_changed.emit("Equipamento movido")
	queue_redraw()


func _restore_moving_item() -> void:
	selected_built_item.position = cell_to_world(move_original_cell)
	selected_built_item.visible = true
	_mark_occupied(move_original_cell, selected_item["footprint"])
	moving_item = false
	selected_item = {}
	_clear_ghost()
	selected_built_item.set_selected(true)
	var record: Dictionary = built_records[selected_built_item]
	built_item_selected.emit(record["item"], get_selected_refund())
	selection_changed.emit({})
	feedback_changed.emit("Movimentação cancelada")
	queue_redraw()


func _create_ghost() -> void:
	_clear_ghost()
	ghost = BuildablePlaceholderScript.new()
	ghost.name = "PlacementGhost"
	ghost.z_index = 20
	ghost.configure(selected_item, true)
	add_child(ghost)


func _find_built_item_at_cell(cell: Vector2i):
	for built_item in built_records:
		var record: Dictionary = built_records[built_item]
		var item_data: Dictionary = record["item"]
		var item_rect := Rect2i(record["cell"], item_data["footprint"])
		if item_rect.has_point(cell):
			return built_item
	return null


func _footprint_is_inside(cell: Vector2i, footprint: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x + footprint.x <= GRID_CELL_COUNT.x and cell.y + footprint.y <= GRID_CELL_COUNT.y


func _footprint_is_in_allowed_zone(cell: Vector2i, footprint: Vector2i, allowed_zones: Array) -> bool:
	for y in range(cell.y, cell.y + footprint.y):
		for x in range(cell.x, cell.x + footprint.x):
			if not allowed_zones.has(get_zone_at_cell(Vector2i(x, y))):
				return false
	return true


func _footprint_overlaps_rect(cell: Vector2i, footprint: Vector2i, reserved_rect: Rect2i) -> bool:
	return Rect2i(cell, footprint).intersects(reserved_rect)


func _mark_occupied(start_cell: Vector2i, footprint: Vector2i) -> void:
	for y in range(start_cell.y, start_cell.y + footprint.y):
		for x in range(start_cell.x, start_cell.x + footprint.x):
			occupied_cells[Vector2i(x, y)] = true


func _unmark_occupied(start_cell: Vector2i, footprint: Vector2i) -> void:
	for y in range(start_cell.y, start_cell.y + footprint.y):
		for x in range(start_cell.x, start_cell.x + footprint.x):
			occupied_cells.erase(Vector2i(x, y))


func _mark_occupied_rect(occupied_rect: Rect2i) -> void:
	_mark_occupied(occupied_rect.position, occupied_rect.size)


func _clear_ghost() -> void:
	if ghost != null:
		ghost.queue_free()
		ghost = null
