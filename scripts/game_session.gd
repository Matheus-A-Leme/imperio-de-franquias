extends Node

const GameStateScript = preload("res://scripts/game_state.gd")

const DEFAULT_COMPANY_NAME := "Hamburgueria Império"
const INITIAL_CAPITAL := 10000

var company_name := DEFAULT_COMPANY_NAME
var game_state
var settings := {
	"master_volume": 100.0,
	"fullscreen": false,
	"vsync": true,
	"resolution": Vector2i(1280, 720),
}


func start_new_game(requested_name: String) -> bool:
	var clean_name := requested_name.strip_edges()
	if clean_name.is_empty():
		return false
	company_name = clean_name
	game_state = GameStateScript.new(INITIAL_CAPITAL)
	return true


func get_or_create_game_state():
	if game_state == null:
		game_state = GameStateScript.new(INITIAL_CAPITAL)
	return game_state


func abandon_game() -> void:
	company_name = DEFAULT_COMPANY_NAME
	game_state = null
