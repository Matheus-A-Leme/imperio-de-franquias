class_name BuildablePlaceholder
extends Node2D

const GRID_SIZE := 24

var item_id: StringName
var footprint := Vector2i.ONE
var base_color := Color.WHITE
var is_preview := false


func configure(item_data: Dictionary, preview: bool = false) -> void:
	item_id = item_data.get("id", &"")
	footprint = item_data.get("footprint", Vector2i.ONE)
	base_color = item_data.get("base_color", Color.WHITE)
	is_preview = preview
	queue_redraw()


func set_placement_valid(is_valid: bool) -> void:
	if not is_preview:
		return
	modulate = Color(0.55, 1.0, 0.62, 0.72) if is_valid else Color(1.0, 0.38, 0.38, 0.72)


func set_selected(selected: bool) -> void:
	z_index = 12 if selected else 0
	modulate = Color(1.18, 1.12, 0.72, 1.0) if selected else Color.WHITE


func _draw() -> void:
	var size := Vector2(footprint * GRID_SIZE)
	var body_rect := Rect2(Vector2.ZERO, size)

	draw_rect(Rect2(Vector2(4, 5), size), Color(0.12, 0.1, 0.09, 0.28), true)
	draw_rect(body_rect, base_color, true)
	draw_rect(body_rect, Color("33464a"), false, 3.0)

	match item_id:
		&"griddle":
			_draw_griddle(size)
		&"refrigerator":
			_draw_refrigerator(size)
		&"table":
			_draw_table(size)


func _draw_griddle(size: Vector2) -> void:
	var plate := Rect2(Vector2(7, 7), size - Vector2(14, 20))
	draw_rect(plate, Color("202527"), true)
	for x in range(16, int(size.x) - 8, 14):
		draw_line(Vector2(x, 11), Vector2(x, size.y - 17), Color("8c4931"), 2.0)
	for x in range(14, int(size.x) - 7, 18):
		draw_circle(Vector2(x, size.y - 7), 3.0, Color("f29b32"))


func _draw_refrigerator(size: Vector2) -> void:
	draw_line(Vector2(2, size.y * 0.35), Vector2(size.x - 2, size.y * 0.35), Color("769092"), 2.0)
	draw_line(Vector2(size.x - 10, 9), Vector2(size.x - 10, size.y * 0.28), Color("4d6466"), 3.0)
	draw_line(Vector2(size.x - 10, size.y * 0.47), Vector2(size.x - 10, size.y - 10), Color("4d6466"), 3.0)
	draw_rect(Rect2(Vector2(7, 7), Vector2(size.x - 22, 5)), Color(1, 1, 1, 0.42), true)


func _draw_table(size: Vector2) -> void:
	draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), Color("d98245"), true)
	draw_line(Vector2(size.x * 0.5, 8), Vector2(size.x * 0.5, size.y - 8), Color("9c4e2d"), 2.0)
	draw_circle(Vector2(size.x * 0.28, size.y * 0.5), 5.0, Color("f4e4bd"))
	draw_circle(Vector2(size.x * 0.72, size.y * 0.5), 5.0, Color("f4e4bd"))
