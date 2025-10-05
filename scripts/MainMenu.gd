extends Control

@onready var practice_button = $VBoxContainer/PracticeButton
@onready var challenge_button = $VBoxContainer/ChallengeButton
@onready var exit_button = $VBoxContainer/ExitButton
@onready var difficulty_slider = $VBoxContainer/DifficultySlider
@onready var difficulty_label = $VBoxContainer/DifficultyLabel
@onready var level_type_label = $VBoxContainer/LevelTypeLabel
@onready var level_type_option = $VBoxContainer/LevelTypeOption
@onready var limited_field_of_view_checkbox = $VBoxContainer/LimitedFieldOfViewCheckBox

var difficulty_names = ["child", "regular", "hard", "challenge"]
var current_difficulty_index = 1 # Start with "regular"
var level_type_options = [
	{"name": "Obstacles + Coins", "type": GameState.LevelType.OBSTACLES_COINS},
	{"name": "Keys", "type": GameState.LevelType.KEYS},
	{"name": "Maze", "type": GameState.LevelType.MAZE},
	{"name": "Maze + Coins", "type": GameState.LevelType.MAZE_COINS},
	{"name": "Maze + Keys", "type": GameState.LevelType.MAZE_KEYS},
	{"name": "Maze complex", "type": GameState.LevelType.MAZE_COMPLEX},
	{"name": "Maze complex + Coins", "type": GameState.LevelType.MAZE_COMPLEX_COINS},
	{"name": "Maze complex + Keys", "type": GameState.LevelType.MAZE_COMPLEX_KEYS},
	{"name": "Random", "type": GameState.LevelType.RANDOM},
]
var current_level_type_index = 0

func _ready():
	# Connect signals
	practice_button.pressed.connect(_on_practice_pressed)
	challenge_button.pressed.connect(_on_challenge_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	difficulty_slider.value_changed.connect(_on_difficulty_changed)
	level_type_option.item_selected.connect(_on_level_type_changed)

	# Setup difficulty slider
	difficulty_slider.min_value = 0
	difficulty_slider.max_value = difficulty_names.size() - 1
	difficulty_slider.step = 1
	difficulty_slider.value = current_difficulty_index
	difficulty_slider.ticks_on_borders = true

	for i in range(level_type_options.size()):
		var option = level_type_options[i]
		level_type_option.add_item(option["name"], i)
		level_type_option.set_item_metadata(i, option["type"])
	level_type_option.selected = current_level_type_index
	_update_level_type_label()

	# Update difficulty label
	_update_difficulty_label()

	if Engine.has_meta("limited_field_of_view"):
		limited_field_of_view_checkbox.button_pressed = bool(Engine.get_meta("limited_field_of_view"))
	else:
		Engine.set_meta("limited_field_of_view", limited_field_of_view_checkbox.button_pressed)

func _on_practice_pressed():
	var metadata = level_type_option.get_item_metadata(level_type_option.selected)
	if metadata == null:
		metadata = level_type_options[current_level_type_index]["type"]
	_start_game_with_mode(int(metadata))

func _on_challenge_pressed():
	_start_game_with_mode(GameState.LevelType.CHALLENGE)

func _on_exit_pressed():
	get_tree().quit()

func _on_difficulty_changed(value: float):
	current_difficulty_index = int(value)
	_update_difficulty_label()

func _update_difficulty_label():
	var difficulty_name = difficulty_names[current_difficulty_index]
	difficulty_label.text = "Difficulty: " + difficulty_name.capitalize()

func _on_level_type_changed(index: int) -> void:
	current_level_type_index = index
	_update_level_type_label()

func _update_level_type_label() -> void:
	var option = level_type_options[current_level_type_index]
	level_type_label.text = "Level Type: " + option["name"]

func _start_game_with_mode(level_type: int) -> void:
	var timer_manager = get_node_or_null("/root/Main/TimerManager")
	if timer_manager:
		timer_manager.set_difficulty(difficulty_names[current_difficulty_index])
	var game_state = get_node_or_null("/root/Main/GameState")
	Engine.set_meta("level_type_selection", level_type)
	Engine.set_meta("limited_field_of_view", limited_field_of_view_checkbox.button_pressed)
	if game_state:
		game_state.set_level_type(level_type)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
