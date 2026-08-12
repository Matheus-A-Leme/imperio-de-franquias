extends SceneTree

const GameStateScript = preload("res://scripts/game_state.gd")
const BuildSystemScript = preload("res://scripts/build_system.gd")

var failures: Array[String] = []


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var main_scene: PackedScene = load("res://main.tscn")
	var main = main_scene.instantiate()
	root.add_child(main)
	await process_frame

	_expect(main.get_node("HUD/BuildPanel/GriddleButton").text == "Chapa — R$ 800", "Painel deve carregar Chapa e preço do catálogo")
	_expect(main.get_node("HUD/BuildPanel/RefrigeratorButton").text == "Geladeira — R$ 1.200", "Painel deve carregar Geladeira e preço do catálogo")
	_expect(main.get_node("HUD/BuildPanel/TableButton").text == "Mesa — R$ 300", "Painel deve carregar Mesa e preço do catálogo")
	main.queue_free()
	await process_frame

	var state = GameStateScript.new(10000)
	var build_system = BuildSystemScript.new()
	root.add_child(build_system)
	build_system.setup(state)

	_expect(build_system.select_item(&"griddle"), "Selecionar Chapa")
	var valid_cell := Vector2i(0, 18)
	_expect(build_system.is_position_valid(&"griddle", valid_cell), "Chapa deve caber em célula livre")
	_expect(build_system.try_place_at_cell(valid_cell), "Comprar e posicionar Chapa")
	_expect(state.money == 9200, "Saldo deve cair de 10.000 para 9.200")
	_expect(not build_system.is_position_valid(&"griddle", valid_cell), "Posição construída deve ficar ocupada")
	_expect(not build_system.try_place_at_cell(valid_cell), "Não permitir sobreposição")
	_expect(state.money == 9200, "Compra inválida não deve descontar dinheiro")
	_expect(not build_system.is_position_valid(&"griddle", Vector2i(-1, 18)), "Não permitir fora da loja")

	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	build_system._unhandled_input(escape_event)
	_expect(build_system.selected_item.is_empty(), "Cancelar deve limpar a seleção")
	_expect(build_system.ghost == null, "Cancelar deve remover o ghost")

	var poor_state = GameStateScript.new(799)
	var poor_build_system = BuildSystemScript.new()
	root.add_child(poor_build_system)
	poor_build_system.setup(poor_state)
	poor_build_system.select_item(&"griddle")
	_expect(not poor_build_system.try_place_at_cell(Vector2i(3, 18)), "Não comprar Chapa sem dinheiro suficiente")
	_expect(poor_state.money == 799, "Saldo insuficiente deve permanecer intacto")

	if failures.is_empty():
		print("MISSION_002_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
