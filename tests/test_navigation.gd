extends SceneTree

var failures: Array[String] = []
var session


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	session = root.get_node("GameSession")
	await _test_main_menu()
	await _test_new_game_and_gameplay()
	await _test_pause_and_settings()
	await _test_return_to_menu()

	if failures.is_empty():
		print("MISSION_004_TESTS_OK")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)


func _test_main_menu() -> void:
	var menu = load("res://scenes/main_menu.tscn").instantiate()
	_expect(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/main_menu.tscn", "Projeto deve iniciar no menu principal")
	root.add_child(menu)
	await process_frame
	_expect_concept_art(menu, "res://assets/references/ui/main_menu_concept_v01.png")
	_expect(menu.get_node("MenuPanel/Buttons/ContinueButton").disabled, "Continuar deve permanecer desabilitado")
	_expect(menu.has_node("MenuPanel/Buttons/ExitButton"), "Menu deve possuir botão Sair")
	menu.queue_free()
	await process_frame


func _test_new_game_and_gameplay() -> void:
	var new_game = load("res://scenes/new_game_menu.tscn").instantiate()
	root.add_child(new_game)
	await process_frame
	_expect_concept_art(new_game, "res://assets/references/ui/new_game_concept_v01.png")
	var input: LineEdit = new_game.get_node("FormPanel/CompanyNameInput")
	_expect(input.text == "Hamburgueria Império", "Novo Jogo deve usar nome padrão")
	input.text = "Lanchonete do Leme"
	new_game._start_game()
	await process_frame
	await process_frame

	var gameplay = current_scene
	_expect(gameplay != null and gameplay.name == "Main", "Começar deve carregar a hamburgueria")
	_expect(gameplay.get_node("World/Shop/StoreSign/Label").text == "LANCHONETE DO LEME", "Gameplay deve exibir o nome escolhido")
	_expect(gameplay.get_node("HUD/TopBar/Money/Label").text == "R$ 10.000", "Novo jogo deve iniciar com R$ 10.000")


func _test_pause_and_settings() -> void:
	var gameplay = current_scene
	var pause_menu = gameplay.pause_menu
	var escape_event := InputEventKey.new()
	escape_event.keycode = KEY_ESCAPE
	escape_event.pressed = true
	gameplay._unhandled_input(escape_event)
	_expect(paused, "Abrir pause deve pausar a árvore")
	_expect(pause_menu.visible, "Menu de pause deve ficar visível")
	_expect_concept_art(pause_menu.get_node("Overlay"), "res://assets/references/ui/pause_menu_concept_v04.png")
	pause_menu.continue_game()
	_expect(not paused, "Continuar deve retomar o jogo")

	pause_menu.open_pause()
	pause_menu._open_settings()
	await process_frame
	var settings = pause_menu.settings_overlay
	_expect(settings != null, "Configurações devem abrir dentro do pause")
	_expect_concept_art(settings, "res://assets/references/ui/settings_concept_v01.png")
	settings._set_master_volume(35.0)
	_expect(is_equal_approx(session.settings["master_volume"], 35.0), "Volume deve ser armazenado")
	settings._set_fullscreen(true)
	_expect(session.settings["fullscreen"], "Fullscreen deve ser ativado")
	settings._set_fullscreen(false)
	_expect(not session.settings["fullscreen"], "Fullscreen deve voltar ao modo janela")
	settings._set_vsync(false)
	_expect(not session.settings["vsync"], "VSync deve ser desligado")
	settings._set_vsync(true)
	_expect(session.settings["vsync"], "VSync deve ser ligado")
	settings._set_resolution(1)
	_expect(session.settings["resolution"] == Vector2i(1600, 900), "Resolução deve mudar para 1600x900")
	settings._go_back()
	await process_frame
	_expect(pause_menu.settings_overlay == null, "Voltar deve fechar configurações e retornar ao pause")
	pause_menu.continue_game()


func _test_return_to_menu() -> void:
	var gameplay = current_scene
	var pause_menu = gameplay.pause_menu
	pause_menu.open_pause()
	pause_menu._show_confirmation()
	_expect(pause_menu.get_node("Overlay/ConfirmationPanel").visible, "Retorno deve pedir confirmação")
	pause_menu._return_to_main_menu()
	await process_frame
	await process_frame
	_expect(not paused, "Retornar ao menu deve remover o pause")
	_expect(current_scene != null and current_scene.name == "MainMenu", "Confirmação deve voltar ao menu principal")
	_expect(session.game_state == null, "Retorno ao menu deve abandonar a sessão sem save")


func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _expect_concept_art(parent: Node, expected_path: String) -> void:
	var concept_art := parent.get_node_or_null("ConceptArt") as TextureRect
	_expect(concept_art != null, "Cena deve possuir a concept art em TextureRect")
	if concept_art != null:
		_expect(concept_art.texture != null and concept_art.texture.resource_path == expected_path, "Cena deve usar a concept art correta: %s" % expected_path)
		_expect(concept_art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "Concept art deve preservar proporção e cobrir a tela")
