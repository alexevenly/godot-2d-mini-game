class_name LevelController
extends RefCounted

const LOGGER := preload("res://scripts/Logger.gd")
const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const GAME_STATE := preload("res://scripts/GameState.gd")
const LEVEL_OBJECT_BINDER := preload("res://scripts/main/level/LevelObjectBinder.gd")
const LEVEL_GENERATION_SERVICE := preload("res://scripts/main/level/LevelGenerationService.gd")

const LEVEL_TYPE_LABELS := [
	"Obstacles+Coins",
	"Keys",
	"Maze",
	"Maze+Coins",
	"Maze+Keys",
	"Random",
	"Challenge"
]

var main = null
var ui_controller = null
var game_flow_controller = null
var coins: Array[Area2D] = []
var keys: Array[Area2D] = []
var doors: Array = []
var _object_binder = LEVEL_OBJECT_BINDER.new()
var _generation_service = LEVEL_GENERATION_SERVICE.new()

func setup(main_ref, ui_controller_ref) -> void:
	main = main_ref
	ui_controller = ui_controller_ref
	if _object_binder == null:
		_object_binder = LEVEL_OBJECT_BINDER.new()
	_object_binder.setup(main, ui_controller)
	if _generation_service == null:
		_generation_service = LEVEL_GENERATION_SERVICE.new()
	_generation_service.setup(main, ui_controller)

func set_game_flow_controller(controller) -> void:
	game_flow_controller = controller

func generate_new_level() -> void:
	main.level_initializing = true
	if main.game_state.current_level > 7:
		main.game_state.reset_to_start()
		LOGGER.log_game_mode("Level exceeded cap, reset to level %d" % main.game_state.current_level)
	var level_type: int = main.game_state.get_current_level_type()
	var generation_level_size: float = _generation_service.calculate_generation_size(level_type)
	LOGGER.log_generation("Generating level %d (size: %.2f)" % [main.game_state.current_level, generation_level_size])
	_generation_service.reset_runtime_state()
	coins = [] as Array[Area2D]
	keys = [] as Array[Area2D]
	doors = [] as Array
	if game_flow_controller:
		game_flow_controller.handle_timer_for_game_state()
	await main.get_tree().process_frame
	LEVEL_UTILS.update_level_boundaries(generation_level_size, main.play_area, main.boundaries)
	position_player_within_level(generation_level_size)
	_log_level_type(level_type)
	var generation_flags := _generation_service.determine_generation_flags(level_type)
	var generator_success := _generation_service.invoke_level_generator(level_type, generation_level_size, generation_flags)
	if generator_success:
		var binding_result: Dictionary = {}
		if _object_binder:
			binding_result = _object_binder.bind_from_generator(main.level_generator)
		var outcome := _generation_service.apply_generation_outcome(binding_result, level_type)
		coins = outcome.get("coins", [] as Array[Area2D])
		keys = outcome.get("keys", [] as Array[Area2D])
		doors = outcome.get("doors", [] as Array[StaticBody2D])
		
		# Update path indicator for complex maze modes
		if (level_type == GAME_STATE.LevelType.MAZE_COMPLEX or
			level_type == GAME_STATE.LevelType.MAZE_COMPLEX_COINS):
			if main.level_generator.complex_maze_generator:
				var is_multi_path = main.level_generator.complex_maze_generator.get_is_multi_path()
				ui_controller.update_path_indicator(is_multi_path)
		else:
			ui_controller.hide_path_indicator()
	else:
		main.game_time = 30.0
	main.level_initializing = false

func position_player_within_level(level_size: float = -1.0) -> void:
	var size_to_use: float = level_size
	if size_to_use <= 0.0:
		size_to_use = main.game_state.current_level_size
	var dimensions: Dictionary = LEVEL_UTILS.get_scaled_level_dimensions(size_to_use)
	var level_width: float = dimensions.width
	var level_height: float = dimensions.height
	var offset_x: float = dimensions.offset_x
	var offset_y: float = dimensions.offset_y
	var player_x: float = offset_x + (level_width * 0.1)
	var player_y: float = offset_y + (level_height * 0.5)
	player_x = max(player_x, 50)
	player_y = max(player_y, 50)
	if main.player:
		main.player.position = Vector2(player_x, player_y)

func handle_coin_collected(body: Node, coin: Area2D) -> void:
	if body == main.player and main.game_state.is_game_active():
		main.collected_coins += 1
		main.previous_coin_count = main.collected_coins
		if main.player and is_instance_valid(main.player):
			if main.player.has_method("apply_speed_boost"):
				main.player.apply_speed_boost()
		coin.queue_free()
		coins.erase(coin)
	main.exit_active = main.collected_coins >= main.total_coins
	ui_controller.update_coin_display(main.total_coins, main.collected_coins)
	ui_controller.update_exit_state(main.exit_active, main.exit)

func handle_key_collected(door_id: int) -> void:
	if main.total_keys > 0 and main.collected_keys_count >= main.total_keys:
		return
	var current: int = int(main.collected_key_ids.get(door_id, 0))
	main.collected_key_ids[door_id] = current + 1
	if main.collected_keys_count < main.total_keys:
		main.collected_keys_count += 1
	main.collected_keys_count = min(main.collected_keys_count, main.total_keys)
	ui_controller.mark_key_collected(door_id)
	ui_controller.update_key_status_display(main.collected_keys_count)

func handle_door_opened(door_id: int, door_color: Color) -> void:
	if ui_controller:
		ui_controller.mark_door_opened(door_id, door_color)

func clear_level_objects() -> void:
	LOGGER.log_generation("Clearing previously generated objects")
	for child in main.get_children():
		var node_child: Node = child
		var child_name: String = node_child.name
		var should_clear: bool = (
			child_name.begins_with("Obstacle")
			or child_name.begins_with("Coin")
			or child_name == "Exit"
			or child_name.begins_with("Door")
			or child_name.begins_with("Key")
			or child_name.begins_with("MazeWall")
		)
		if should_clear and is_instance_valid(node_child):
			node_child.queue_free()
	if main.level_generator and is_instance_valid(main.level_generator):
		main.level_generator.clear_existing_objects()
		LOGGER.log_generation("LevelGenerator cleared existing objects")
	main.exit = null
	coins = [] as Array[Area2D]
	keys = [] as Array[Area2D]
	doors = [] as Array[StaticBody2D]
	main.total_coins = 0
	main.collected_coins = 0
	main.total_keys = 0
	main.collected_keys_count = 0
	main.collected_key_ids.clear()
	main.exit_active = false
	ui_controller.clear_key_ui()

func get_active_coins() -> Array[Area2D]:
	return coins

func _log_level_type(level_type: int) -> void:
	var label: String = LEVEL_TYPE_LABELS[level_type] if level_type < LEVEL_TYPE_LABELS.size() else str(level_type)
	LOGGER.log_game_mode("Preparing level type: %s" % label)
