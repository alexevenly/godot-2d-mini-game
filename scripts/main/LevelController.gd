class_name LevelController
extends RefCounted

const Logger = preload("res://scripts/Logger.gd")
const LevelUtils = preload("res://scripts/LevelUtils.gd")

var main: Main = null
var ui_controller: UIController = null
var game_flow_controller: GameFlowController = null
var coins: Array[Area2D] = []
var keys: Array[Area2D] = []

func setup(main_ref: Main, ui_controller_ref: UIController) -> void:
	main = main_ref
	ui_controller = ui_controller_ref

func set_game_flow_controller(controller: GameFlowController) -> void:
	game_flow_controller = controller

func generate_new_level() -> void:
	main.level_initializing = true
	if main.game_state.current_level > 7:
		main.game_state.reset_to_start()
		Logger.log_game_mode("Level exceeded cap, reset to level", [main.game_state.current_level])

	var generation_level_size: float = main.game_state.current_level_size
	Logger.log_generation("Generating level %d (size: %.2f)" % [main.game_state.current_level, generation_level_size])
	main.level_start_time = Time.get_ticks_msec() / 1000.0
	main.collected_coins = main.previous_coin_count
	main.exit_active = false
	main.exit = null
	coins = [] as Array[Area2D]
	keys = [] as Array[Area2D]
	main.game_state.set_state(GameState.GameStateType.PLAYING)
	if main.game_state.current_state != GameState.GameStateType.PLAYING:
		Logger.log_game_mode("Game state corrected to PLAYING before generation")
		main.game_state.set_state(GameState.GameStateType.PLAYING)
	if game_flow_controller:
		game_flow_controller.handle_timer_for_game_state()
	await main.get_tree().process_frame

	var level_type: int = main.game_state.get_current_level_type()
	if level_type == GameState.LevelType.KEYS:
		generation_level_size = min(generation_level_size + 0.35, main.game_state.max_level_size + 0.25)
	LevelUtils.update_level_boundaries(generation_level_size, main.play_area, main.boundaries)
	position_player_within_level(generation_level_size)

	var level_type_names: Array[String] = ["Obstacles+Coins", "Keys", "Maze", "Maze+Coins", "Maze+Keys", "Random", "Challenge"]
	var level_type_label: String = level_type_names[level_type] if level_type < level_type_names.size() else str(level_type)
	Logger.log_game_mode("Preparing level type: %s" % level_type_label)

	var generate_obstacles: bool = true
	var generate_coins: bool = true
	if main.level_generator and is_instance_valid(main.level_generator):
		generate_obstacles = main.game_state.generate_obstacles
		generate_coins = main.game_state.generate_coins
		if level_type == GameState.LevelType.KEYS:
			generate_obstacles = false
			generate_coins = false
		elif level_type == GameState.LevelType.MAZE or level_type == GameState.LevelType.MAZE_COINS or level_type == GameState.LevelType.MAZE_KEYS:
			generate_obstacles = false
			generate_coins = false
	else:
		if level_type == GameState.LevelType.MAZE or level_type == GameState.LevelType.MAZE_COINS or level_type == GameState.LevelType.MAZE_KEYS:
			generate_obstacles = false
			generate_coins = false

	main.level_generator.generate_level(
		generation_level_size,
		generate_obstacles,
		generate_coins,
		main.game_state.min_exit_distance_ratio,
		main.game_state.use_full_map_coverage,
		main,
		main.game_state.current_level,
		main.previous_coin_count,
		main.player.global_position if main.player else LevelUtils.PLAYER_START,
		level_type
	)

	main.exit = main.level_generator.get_generated_exit()
	coins = main.level_generator.get_generated_coins() as Array[Area2D]
	keys = main.level_generator.get_generated_keys() as Array[Area2D]
	var spawn_override_variant: Variant = main.level_generator.get_player_spawn_override()
	var has_spawn_override: bool = typeof(spawn_override_variant) == TYPE_VECTOR2
	var spawn_override: Vector2 = spawn_override_variant if has_spawn_override else Vector2.ZERO
	if main.exit:
		Logger.log_generation("Exit generated at %s" % [main.exit.position])
	else:
		Logger.log_generation("No exit generated")
	Logger.log_generation("Coins generated: %d" % coins.size())
	Logger.log_generation("Keys generated: %d" % keys.size())
	if main.timer_manager:
		var timer_start_position: Vector2 = spawn_override if has_spawn_override else (main.player.global_position if main.player else LevelUtils.PLAYER_START)
		var maze_path_length: float = main.level_generator.get_last_maze_path_length() if main.level_generator else 0.0
		main.game_time = main.timer_manager.calculate_level_time(
			main.game_state.current_level,
			coins,
			main.exit.position if main.exit else Vector2(),
			timer_start_position,
			level_type,
			maze_path_length
		)
	else:
		main.game_time = 30.0

	for coin in coins:
		var coin_area: Area2D = coin
		if coin_area and is_instance_valid(coin_area):
			var coin_callable: Callable = Callable(main, "_on_coin_collected").bind(coin_area)
			if not coin_area.body_entered.is_connected(coin_callable):
				coin_area.body_entered.connect(coin_callable)
	main.total_coins = coins.size()
	main.collected_coins = 0
	if main.total_coins == 0:
		main.previous_coin_count = 0

	if main.exit and is_instance_valid(main.exit):
		var exit_callable: Callable = Callable(main, "_on_exit_entered")
		if not main.exit.body_entered.is_connected(exit_callable):
			main.exit.body_entered.connect(exit_callable)

	main.collected_keys_count = 0
	main.total_keys = keys.size()
	for key in keys:
		var key_node: Area2D = key
		if key_node and is_instance_valid(key_node) and key_node.has_signal("key_collected"):
			var key_callable: Callable = Callable(main, "_on_key_collected")
			if not key_node.is_connected("key_collected", key_callable):
				key_node.connect("key_collected", key_callable)

	main.timer.wait_time = main.game_time
	main.timer.stop()
	main.timer.start()
	ui_controller.update_coin_display(main.total_coins, main.collected_coins)
	ui_controller.setup_key_ui(keys)
	main.exit_active = main.collected_coins >= main.total_coins
	ui_controller.update_exit_state(main.exit_active, main.exit)
	ui_controller.update_timer_display(main.game_time)
	ui_controller.update_level_progress(main.game_state.get_level_progress_text())
	if has_spawn_override and main.player and is_instance_valid(main.player):
		main.player.global_position = spawn_override
		main.player.position = spawn_override
		main.player.rotation = 0.0
		Logger.log_generation("Level ready: time %.2f, coins %d" % [main.game_time, main.total_coins])
	else:
		Logger.log_generation("Level ready: time %.2f, coins %d (default spawn)" % [main.game_time, main.total_coins])
	main.level_initializing = false

func position_player_within_level(level_size: float = -1.0) -> void:
	var size_to_use: float = level_size
	if size_to_use <= 0.0:
		size_to_use = main.game_state.current_level_size
	var dimensions: Dictionary = LevelUtils.get_scaled_level_dimensions(size_to_use)
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

func handle_key_collected() -> void:
	main.collected_keys_count += 1
	main.collected_keys_count = min(main.collected_keys_count, main.total_keys)
	ui_controller.update_key_status_display(main.collected_keys_count)

func clear_level_objects() -> void:
	Logger.log_generation("Clearing previously generated objects")
	for child in main.get_children():
		var node_child: Node = child
		var child_name: String = node_child.name
		var should_clear: bool = child_name.begins_with("Obstacle") or child_name.begins_with("Coin") or child_name == "Exit" or child_name.begins_with("Door") or child_name.begins_with("Key") or child_name.begins_with("MazeWall")
		if should_clear and is_instance_valid(node_child):
			node_child.queue_free()
	if main.level_generator and is_instance_valid(main.level_generator):
		main.level_generator.clear_existing_objects()
		Logger.log_generation("LevelGenerator cleared existing objects")
	main.exit = null
	coins = [] as Array[Area2D]
	keys = [] as Array[Area2D]
	main.total_coins = 0
	main.collected_coins = 0
	main.total_keys = 0
	main.collected_keys_count = 0
	main.exit_active = false
	ui_controller.clear_key_ui()

func get_active_coins() -> Array[Area2D]:
	return coins
