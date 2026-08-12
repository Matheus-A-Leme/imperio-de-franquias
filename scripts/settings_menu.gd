extends Control

signal back_requested

@export var standalone := true

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

@onready var volume_slider: HSlider = $SettingsPanel/VolumeSlider
@onready var volume_value: Label = $SettingsPanel/VolumeValue
@onready var fullscreen_toggle: CheckButton = $SettingsPanel/FullscreenToggle
@onready var vsync_toggle: CheckButton = $SettingsPanel/VSyncToggle
@onready var resolution_option: OptionButton = $SettingsPanel/ResolutionOption


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_resolution_options()
	_load_values()
	volume_slider.value_changed.connect(_set_master_volume)
	fullscreen_toggle.toggled.connect(_set_fullscreen)
	vsync_toggle.toggled.connect(_set_vsync)
	resolution_option.item_selected.connect(_set_resolution)
	$SettingsPanel/BackButton.pressed.connect(_go_back)


func _setup_resolution_options() -> void:
	resolution_option.clear()
	for resolution in RESOLUTIONS:
		resolution_option.add_item("%d x %d" % [resolution.x, resolution.y])
		resolution_option.set_item_metadata(resolution_option.item_count - 1, resolution)


func _load_values() -> void:
	volume_slider.set_value_no_signal(GameSession.settings["master_volume"])
	fullscreen_toggle.set_pressed_no_signal(GameSession.settings["fullscreen"])
	vsync_toggle.set_pressed_no_signal(GameSession.settings["vsync"])
	volume_value.text = "%d%%" % roundi(volume_slider.value)
	var current_resolution: Vector2i = GameSession.settings["resolution"]
	var resolution_index := RESOLUTIONS.find(current_resolution)
	resolution_option.select(maxi(resolution_index, 0))


func _set_master_volume(value: float) -> void:
	GameSession.settings["master_volume"] = value
	volume_value.text = "%d%%" % roundi(value)
	var bus_index := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_mute(bus_index, value <= 0.0)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(maxf(value / 100.0, 0.0001)))


func _set_fullscreen(enabled: bool) -> void:
	GameSession.settings["fullscreen"] = enabled
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED)
	if not enabled:
		DisplayServer.window_set_size(GameSession.settings["resolution"])


func _set_vsync(enabled: bool) -> void:
	GameSession.settings["vsync"] = enabled
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)


func _set_resolution(index: int) -> void:
	var resolution: Vector2i = resolution_option.get_item_metadata(index)
	GameSession.settings["resolution"] = resolution
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(resolution)


func _go_back() -> void:
	if standalone:
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
	else:
		back_requested.emit()
