extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const BuildSystemScript = preload("res://scripts/build_system.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await _test_interface()
	await _test_zones_and_lifecycle()

	if failures.is_empty():
		print("MISSION_003_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_interface() -> void:
	var main_scene: PackedScene = load("res://main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	_expect(main.get_node("HUD/BuildPanel/GriddleButton").text == "Chapa — R$ 800", "Painel deve carregar Chapa")
	_expect(main.has_node("HUD/ItemActions/MoveButton"), "Interface deve oferecer Mover")
	_expect(main.has_node("HUD/ItemActions/SellButton"), "Interface deve oferecer Vender")
	main.queue_free()
	await process_frame


func _test_zones_and_lifecycle() -> void:
	var state = GameStateScript.new(10000)
	var build_system = BuildSystemScript.new()
	root.add_child(build_system)
	build_system.setup(state)

	var kitchen_fridge_cell := Vector2i(0, 6)
	var dining_cell := Vector2i(0, 10)
	var kitchen_table_cell := Vector2i(33, 6)
	var entrance_cell := Vector2i(14, 18)

	_expect(build_system.is_position_valid(&"refrigerator", kitchen_fridge_cell), "Geladeira na cozinha deve ser permitida")
	_expect(not build_system.is_position_valid(&"refrigerator", dining_cell), "Geladeira no salão deve ser bloqueada")
	_expect(build_system.is_position_valid(&"table", dining_cell), "Mesa no salão deve ser permitida")
	_expect(not build_system.is_position_valid(&"table", kitchen_table_cell), "Mesa na cozinha deve ser bloqueada")
	_expect(not build_system.is_position_valid(&"table", entrance_cell), "Entrada deve permanecer reservada")
	_expect(not build_system.is_position_valid(&"refrigerator", Vector2i(0, 0)), "Objeto decorativo existente deve bloquear construção")

	build_system.select_item(&"refrigerator")
	_expect(build_system.try_place_at_cell(kitchen_fridge_cell), "Construir Geladeira na cozinha")
	_expect(state.money == 8800, "Geladeira deve descontar R$ 1.200")
	_expect(not build_system.is_position_valid(&"refrigerator", kitchen_fridge_cell), "Construção sobre equipamento deve ser bloqueada")
	build_system.cancel_selection()

	build_system.select_item(&"table")
	_expect(build_system.try_place_at_cell(dining_cell), "Construir Mesa no salão")
	_expect(state.money == 8500, "Mesa deve descontar R$ 300")
	build_system.cancel_selection()

	_expect(build_system.select_built_item_at_cell(dining_cell), "Clicar em objeto construído deve selecioná-lo")
	_expect(build_system.get_selected_refund() == 210, "Venda da Mesa deve valer 70%: R$ 210")
	var selected_table = build_system.selected_built_item

	var moved_cell := Vector2i(11, 10)
	_expect(build_system.start_move_selected(), "Mover deve iniciar reposicionamento")
	_expect(build_system.is_position_valid(&"table", moved_cell), "Nova posição da Mesa deve ser válida")
	_expect(build_system.try_place_at_cell(moved_cell), "Mover deve confirmar em posição válida")
	_expect(state.money == 8500, "Mover não deve cobrar novamente")
	_expect(build_system.built_records[selected_table]["cell"] == moved_cell, "Registro deve guardar nova posição")

	_expect(build_system.start_move_selected(), "Mover novamente para testar ESC")
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	build_system._unhandled_input(escape_event)
	_expect(not build_system.moving_item, "ESC deve cancelar movimentação")
	_expect(selected_table.visible, "ESC deve devolver equipamento à cena")
	_expect(build_system.built_records[selected_table]["cell"] == moved_cell, "ESC deve restaurar posição anterior")
	_expect(not build_system.is_position_valid(&"table", moved_cell), "Posição restaurada deve voltar a ficar ocupada")

	_expect(build_system.sell_selected(), "Vender equipamento selecionado")
	_expect(state.money == 8710, "Venda deve creditar 70% do preço: R$ 210")
	_expect(not build_system.built_records.has(selected_table), "Equipamento vendido deve sair dos registros")

	build_system.queue_free()
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
