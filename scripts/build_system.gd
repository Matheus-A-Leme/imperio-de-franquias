class_name BuildSystem
extends Node2D

const BuildCatalogScript = preload("res://scripts/build_catalog.gd")
const BuildablePlaceholderScript = preload("res://scripts/buildable_placeholder.gd")

signal selection_changed(item_data: Dictionary)
signal purchase_completed(item_data: Dictionary, remaining_money: int)
signal feedback_changed(message: String)

const GRID_SIZE := 24
const GRID_ORIGIN := Vector2i(208, 128)
const GRID_CELL_COUNT := Vector2i(36, 21)

const INITIAL_OCCUPIED_RECTS: Array[Rect2i] = [
	Rect2i(0, 0, 36, 6),
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

	_clear_ghost()
	selected_item = item
	ghost = BuildablePlaceholderScript.new()
	ghost.name = "PlacementGhost"
	ghost.z_index = 20
	ghost.configure(selected_item, true)
	add_child(ghost)
	selection_changed.emit(selected_item)
	feedback_changed.emit("Posicione %s no grid · ESC cancela" % selected_item["display_name"])
	queue_redraw()
	return true


func cancel_selection() -> void:
	if selected_item.is_empty():
		return
	selected_item = {}
	_clear_ghost()
	selection_changed.emit({})
	feedback_changed.emit("")
	queue_redraw()


func is_position_valid(item_id: StringName, cell: Vector2i) -> bool:
	var item: Dictionary = BuildCatalogScript.get_item(item_id)
	if item.is_empty():
		return false

	var footprint: Vector2i = item["footprint"]
	if not _footprint_is_inside(cell, footprint):
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
		feedback_changed.emit("Posição inválida ou ocupada")
		return false

	var price: int = selected_item["price"]
	if not game_state.try_spend(price):
		feedback_changed.emit("Dinheiro insuficiente para %s" % selected_item["display_name"])
		return false

	_place_item(selected_item, cell)
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
	var can_afford: bool = game_state != null and game_state.can_afford(selected_item["price"])
	ghost.set_placement_valid(position_valid and can_afford)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cancel_selection()
		get_viewport().set_input_as_handled()
		return

	if selected_item.is_empty():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		try_place_at_cell(world_to_cell(get_global_mouse_position()))
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if selected_item.is_empty():
		return

	var origin := Vector2(GRID_ORIGIN)
	var grid_size := Vector2(GRID_CELL_COUNT * GRID_SIZE)
	draw_rect(Rect2(origin, grid_size), Color(0.35, 0.9, 0.72, 0.08), true)
	for x in range(GRID_CELL_COUNT.x + 1):
		var line_x := origin.x + x * GRID_SIZE
		draw_line(Vector2(line_x, origin.y), Vector2(line_x, origin.y + grid_size.y), Color(0.4, 0.92, 0.76, 0.28), 1.0)
	for y in range(GRID_CELL_COUNT.y + 1):
		var line_y := origin.y + y * GRID_SIZE
		draw_line(Vector2(origin.x, line_y), Vector2(origin.x + grid_size.x, line_y), Color(0.4, 0.92, 0.76, 0.28), 1.0)


func _place_item(item_data: Dictionary, cell: Vector2i) -> void:
	var built_item = BuildablePlaceholderScript.new()
	built_item.name = "%s_%d" % [item_data["display_name"], built_items.get_child_count() + 1]
	built_item.position = cell_to_world(cell)
	built_item.configure(item_data)
	built_items.add_child(built_item)
	_mark_occupied(cell, item_data["footprint"])


func _footprint_is_inside(cell: Vector2i, footprint: Vector2i) -> bool:
	return (
		cell.x >= 0
		and cell.y >= 0
		and cell.x + footprint.x <= GRID_CELL_COUNT.x
		and cell.y + footprint.y <= GRID_CELL_COUNT.y
	)


func _mark_occupied(start_cell: Vector2i, footprint: Vector2i) -> void:
	for y in range(start_cell.y, start_cell.y + footprint.y):
		for x in range(start_cell.x, start_cell.x + footprint.x):
			occupied_cells[Vector2i(x, y)] = true


func _mark_occupied_rect(occupied_rect: Rect2i) -> void:
	_mark_occupied(occupied_rect.position, occupied_rect.size)


func _clear_ghost() -> void:
	if ghost != null:
		ghost.queue_free()
		ghost = null
