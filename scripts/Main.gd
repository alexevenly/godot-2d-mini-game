extends Node2D

@onready var player = $Player
@onready var timer = $Timer
@onready var timer_label = $UI/TimerLabel
@onready var coin_label = $UI/CoinLabel
@onready var level_progress_label = $UI/LevelProgressLabel
@onready var game_over_label = $UI/GameOverLabel
@onready var win_label = $UI/WinLabel
@onready var restart_button = $UI/RestartButton
@onready var level_generator = $LevelGenerator
@onready var timer_manager = $TimerManager
@onready var play_area = $PlayArea
@onready var boundaries = $Boundaries
@onready var game_state = $GameState

var game_time = 30.0
var total_coins = 0
var collected_coins = 0
var previous_coin_count = 0  # Preserve coin count between levels
var exit_active = false
var exit = null
var coins = []
var prevent_game_over = false  # Flag to prevent game over calls
var level_start_time = 0.0  # Time when level started
var statistics_file = null  # File handle for statistics logging
var level_initializing = false  # Guard to pause gameplay ticks during regeneration

func _ready():
	# Connect signals
	timer.timeout.connect(_on_timer_timeout)
	restart_button.pressed.connect(_on_restart_pressed)
	
	# Initialize statistics logging
	_init_statistics_logging()
	
	# Generate level
	generate_new_level()
	
	# Set initial displays
	_update_timer_display()
	_update_coin_display()
	_update_exit_state()
	_update_level_progress()

func _init_statistics_logging():
	# Create logs directory if it doesn't exist
	var logs_dir = "logs"
	if not DirAccess.dir_exists_absolute(logs_dir):
		DirAccess.make_dir_recursive_absolute(logs_dir)
		print("Created logs directory: ", logs_dir)
	
	# Create statistics log file
	var timestamp = Time.get_datetime_string_from_system()
	var filename = "logs/statistics_" + timestamp.replace(":", "-") + ".log"
	statistics_file = FileAccess.open(filename, FileAccess.WRITE)
	
	if statistics_file:
		statistics_file.store_line("Level,Size,MapWidth,MapHeight,CoinsTotal,CoinsCollected,TimeGiven,TimeUsed,TimeLeft,Distance,CompletionRate")
		statistics_file.flush()
		print("Statistics file created: ", filename)
	else:
		print("ERROR: Could not create statistics file: ", filename)

func _log_level_statistics():
	print("DEBUG: _log_level_statistics called")
	if statistics_file:
		var completion_time = Time.get_ticks_msec() / 1000.0 - level_start_time
		var time_left = game_time
		var distance = 0.0
		
		# Calculate distance from player to exit
		if player and exit:
			distance = player.global_position.distance_to(exit.global_position)
		
		# Calculate completion rate (coins collected / total coins)
		var completion_rate = 0.0
		if coins.size() > 0:
			completion_rate = float(collected_coins) / float(coins.size())
		
		# Create statistics line
		var stats_line = str(game_state.current_level) + "," + \
						str(game_state.current_level_size) + "," + \
						str(play_area.size.x) + "," + \
						str(play_area.size.y) + "," + \
						str(coins.size()) + "," + \
						str(collected_coins) + "," + \
						str(timer.wait_time) + "," + \
						str(completion_time) + "," + \
						str(time_left) + "," + \
						str(distance) + "," + \
						str(completion_rate)
		
		statistics_file.store_line(stats_line)
		statistics_file.flush()
		print("Statistics logged: ", stats_line)
		
		# Register level result with TimerManager
		if timer_manager:
			timer_manager.register_level_result(time_left)
			print("TimerManager registered time_left: ", time_left)
		else:
			print("ERROR: TimerManager not found!")
	else:
		print("ERROR: Statistics file is null!")

func _process(delta):
	# Handle Esc key to quit to menu
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")

	if not game_state.is_game_active():
		return

	if level_initializing:
		return
		
	# Update timer
	game_time -= delta
	_update_timer_display()
	
	# Check if time ran out
	if game_time <= 0:
		_game_over()

func generate_new_level():
	level_initializing = true
	# Ensure level is not > 7
	if game_state.current_level > 7:
		game_state.reset_to_start()
		print("Level was > 7 in generate_new_level, reset to: ", game_state.current_level)
	
	print("=== GENERATING LEVEL ", game_state.current_level, " (size: ", game_state.current_level_size, ") ===")
	
	# Record level start time
	level_start_time = Time.get_ticks_msec() / 1000.0
	
	# Reset state first
	collected_coins = previous_coin_count  # Use preserved coin count
	exit_active = false
	exit = null
	coins = []
	game_state.set_state(GameState.GameStateType.PLAYING)
	
	# Ensure we're in playing state
	if game_state.current_state != GameState.GameStateType.PLAYING:
		print("Warning: Game state was not PLAYING, resetting to PLAYING")
		game_state.set_state(GameState.GameStateType.PLAYING)
	
	# Stop timer if game is not in playing state
	_handle_timer_for_game_state()
	
	# Wait for objects to be properly freed
	await get_tree().process_frame
	
	# Update level boundaries first
	LevelUtils.update_level_boundaries(game_state.current_level_size, play_area, boundaries)

	# Position player within the scaled level
	position_player_within_level()

	var level_type = game_state.get_current_level_type()
	var level_type_names = ["Obstacles+Coins", "Keys", "Maze", "Maze+Coins", "Random"]
	var level_type_label = level_type_names[level_type] if level_type < level_type_names.size() else str(level_type)
	print("LevelGenerator: Preparing level type -> ", level_type_label)

	# Generate new level and get optimal time
	if level_generator and is_instance_valid(level_generator):
		print("LevelGenerator is valid, checking spawners...")
		print("ObstacleSpawner: ", level_generator.obstacle_spawner, " (valid: ", is_instance_valid(level_generator.obstacle_spawner), ")")
		print("CoinSpawner: ", level_generator.coin_spawner, " (valid: ", is_instance_valid(level_generator.coin_spawner), ")")
		print("ExitSpawner: ", level_generator.exit_spawner, " (valid: ", is_instance_valid(level_generator.exit_spawner), ")")
		var generate_obstacles = game_state.generate_obstacles
		var generate_coins = game_state.generate_coins
		if level_type == GameState.LevelType.KEYS:
			generate_obstacles = false
			generate_coins = false
		elif level_type == GameState.LevelType.MAZE or level_type == GameState.LevelType.MAZE_COINS:
			generate_obstacles = false
			generate_coins = false
		level_generator.generate_level(
			game_state.current_level_size,
			generate_obstacles,
			generate_coins,
			game_state.min_exit_distance_ratio,
			game_state.use_full_map_coverage,
			self,
			game_state.current_level,
			previous_coin_count,
			player.global_position if player else LevelUtils.PLAYER_START,
			level_type
		)
		
		# Get references to generated objects from LevelGenerator
		exit = level_generator.get_generated_exit()
		coins = level_generator.get_generated_coins()
		var spawn_override = level_generator.get_player_spawn_override()
		
		print("Generated objects:")
		print("- Exit: ", exit != null, " at ", exit.position if exit else "null")
		print("- Coins: ", coins.size())
		print("- Total children in scene: ", get_tree().get_nodes_in_group("").size())
		
		# Calculate time using timer manager
		if timer_manager:
			var timer_start_position = spawn_override if spawn_override != null else (player.global_position if player else LevelUtils.PLAYER_START)
			game_time = timer_manager.calculate_level_time(game_state.current_level, coins, exit.position if exit else Vector2(), timer_start_position)
		else:
			game_time = 30.0  # Fallback
		
		# Connect coin signals safely
		for coin in coins:
			if coin and is_instance_valid(coin):
				if not coin.body_entered.is_connected(_on_coin_collected):
					coin.body_entered.connect(_on_coin_collected.bind(coin))
		
		total_coins = coins.size()
		collected_coins = 0
		
		# Connect exit signal safely
		if exit and is_instance_valid(exit):
			if not exit.body_entered.is_connected(_on_exit_entered):
				exit.body_entered.connect(_on_exit_entered)
		
		# Start timer
		timer.wait_time = game_time
		# Ensure timer is stopped before starting
		timer.stop()
		timer.start()
		
		# Update displays
		_update_coin_display()
		_update_exit_state()

		if spawn_override != null and player and is_instance_valid(player):
			player.global_position = spawn_override
			player.position = spawn_override
			player.rotation = 0.0
		print("Level initialization complete: game_time=", game_time, " coins=", total_coins, " exit=", exit)
	else:
		print("ERROR: LevelGenerator is null!")

	level_initializing = false
	print("level_initializing reset to false")

func _update_timer_display():
	timer_label.text = "Time: " + "%.2f" % game_time

func _update_coin_display():
	coin_label.text = "Coins: " + str(collected_coins) + "/" + str(total_coins)

func _update_level_progress():
	level_progress_label.text = game_state.get_level_progress_text()

func _handle_timer_for_game_state():
	# Stop timer if game is not in playing state
	if game_state.current_state != GameState.GameStateType.PLAYING:
		# Disconnect timer first
		if timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.disconnect(_on_timer_timeout)
		# Force timer to stop completely
		timer.wait_time = 999999
		timer.stop()
		print("Timer stopped due to game state: ", game_state.current_state)

func _update_exit_state():
	exit_active = (collected_coins >= total_coins)
	if exit and exit.get_node("ExitBody"):
		if exit_active:
			exit.get_node("ExitBody").color = Color(0.2, 0.8, 0.2, 1)  # Green when active
		else:
			exit.get_node("ExitBody").color = Color(0.4, 0.4, 0.4, 1)  # Gray when inactive

func _on_coin_collected(body, coin):
	if body == player and game_state.is_game_active():
		collected_coins += 1
		previous_coin_count = collected_coins  # Preserve coin count
		# Apply speed boost when collecting coin
		if player and is_instance_valid(player):
			player.apply_speed_boost()
		# Hide the coin
		coin.queue_free()
		coins.erase(coin)
		_update_coin_display()
		_update_exit_state()
		
		# Check if this was the last coin - the exit collision will be handled by _on_exit_entered
		# No need to manually check collision here since Area2D handles it via signals

func _on_timer_timeout():
	# Prevent timer timeout if game is not in playing state
	if game_state.current_state != GameState.GameStateType.PLAYING:
		print("Timer timeout ignored - game state: ", game_state.current_state)
		# Force stop timer completely
		timer.stop()
		timer.wait_time = 999999
		# Disconnect timer to prevent further calls
		if timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.disconnect(_on_timer_timeout)
		return
	
	# Additional check to prevent multiple game over calls
	if not game_state.is_game_active():
		print("Timer timeout ignored - game not active")
		# Force stop timer completely
		timer.stop()
		timer.wait_time = 999999
		return
	
	_game_over()

func _on_exit_entered(body):
	if body == player and game_state.is_game_active() and exit_active:
		_win_game()

func _game_over():
	# Prevent multiple calls
	if not game_state.is_game_active():
		return
	
	# Prevent game over if flag is set
	if prevent_game_over:
		return
		
	print("=== GAME OVER ===")
	print("Level: ", game_state.current_level, " Size: ", game_state.current_level_size)
	game_state.set_state(GameState.GameStateType.LOST)
	game_over_label.visible = true
	restart_button.visible = true
	# Stop player movement
	player.set_physics_process(false)
	
	# Stop the timer to prevent repeated calls
	timer.stop()
	# Disconnect timer immediately to prevent queued signals
	if timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.disconnect(_on_timer_timeout)
	
	# Force timer to stop completely
	timer.wait_time = 999999
	timer.stop()
	
	# Don't reset level on loss - only reset on complete restart
	# game_state.reset_to_start()  # REMOVED - this was causing level to reset to 1
	
	# Ensure timer is completely stopped
	print("Timer stopped in _game_over()")
	
	# Update button text
	restart_button.text = "Restart"
	
	# Update level progress display
	_update_level_progress()

func _win_game():
	# Prevent multiple calls
	if not game_state.is_game_active():
		return
		
	print("=== LEVEL COMPLETED ===")
	print("Completed level: ", game_state.current_level, " Size: ", game_state.current_level_size)
	game_state.set_state(GameState.GameStateType.WON)
	win_label.visible = true
	restart_button.visible = true
	# Stop player movement
	player.set_physics_process(false)
	
	# Stop the timer to prevent repeated calls
	timer.stop()
	# Disconnect timer immediately to prevent queued signals
	if timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.disconnect(_on_timer_timeout)
	
	# Log level statistics
	_log_level_statistics()
	
	# Check if this is level 7 completion
	if game_state.current_level >= 7:
		# Level 7 completed - show victory message
		restart_button.text = "Start all over again?"
		print("All 7 levels completed! Victory!")
		# Set flag to prevent game over calls
		prevent_game_over = true
		# Don't advance level here - just show victory
		return
	else:
		# Normal level completion
		restart_button.text = "Continue"
		print("Level completed! Click Continue to proceed to next level")
	
	# Don't update level progress here - it will be updated after level advancement

func _on_restart_pressed():
	print("=== RESTART PRESSED ===")
	print("Current level: ", game_state.current_level, " Size: ", game_state.current_level_size)
	
	# Reset game state
	collected_coins = previous_coin_count  # Use preserved coin count
	exit_active = false
	# Don't reset prevent_game_over flag here - it should stay true if all levels completed
	
	# Hide game over/win labels
	game_over_label.visible = false
	win_label.visible = false
	
	# Handle timer based on game state
	_handle_timer_for_game_state()
	
	# Check if we're starting a completely new game after completing all levels
	if prevent_game_over and game_state.current_state == GameState.GameStateType.WON:
		print("Starting completely new game after completing all levels")
		# Reset everything for a fresh start
		prevent_game_over = false
		game_state.reset_to_start()
		print("Reset to level 1, prevent_game_over = false")
		# Continue to generate new level below
	
	# Advance level if we just won (check BEFORE resetting state)
	elif game_state.current_state == GameState.GameStateType.WON:
		print("DEBUG: Advancing level from ", game_state.current_level)
		var completed_all_levels = game_state.advance_level()
		print("DEBUG: After advancement - level: ", game_state.current_level, " completed_all_levels: ", completed_all_levels)
		print("DEBUG: Level size after advancement: ", game_state.current_level_size)
		
		# Update button text based on level
		if completed_all_levels:
			restart_button.text = "Start all over again?"
			print("All 7 levels completed! Starting over from level 1")
			# Set flag to prevent game over calls
			prevent_game_over = true
			# Completely reset the timer
			timer.stop()
			timer.wait_time = 999999  # Set to a very long time
			# Disconnect timer timeout to prevent further calls
			if timer.timeout.is_connected(_on_timer_timeout):
				timer.timeout.disconnect(_on_timer_timeout)
			# Force timer to stop completely
			timer.stop()
			print("Timer stopped after level 7 completion")
			# Don't generate new level when all levels are completed
			# Just show the button and wait for user to click "Start all over again?"
			return
		else:
			restart_button.text = "Continue"
			print("Next level: ", game_state.current_level, " Size: ", game_state.current_level_size)
			# Reset prevent_game_over flag for normal level progression
			prevent_game_over = false
	elif game_state.current_state == GameState.GameStateType.LOST:
		# If we lost, reset prevent_game_over flag
		prevent_game_over = false
		print("Game over - resetting prevent_game_over flag")
	
	# Reset game state to playing (after level advancement)
	game_state.set_state(GameState.GameStateType.PLAYING)
	
	# Update level progress display after level advancement
	_update_level_progress()
	print("DEBUG: Level progress updated - current level: ", game_state.current_level)
	
	# Stop any running timer first
	timer.stop()
	
	# Reconnect timer if it was disconnected (only if not all levels completed)
	if not prevent_game_over and not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
		print("Timer reconnected for level: ", game_state.current_level)
	elif prevent_game_over:
		print("Timer NOT reconnected - all levels completed")
	
	# Ensure timer is completely stopped before reconnecting
	timer.stop()
	
	# Reset player position within scaled level boundaries
	if player and is_instance_valid(player):
		position_player_within_level()
		# Set player z-index to be above all other objects
		player.z_index = 100
		# Re-enable player movement
		player.set_physics_process(true)
	
	# Hide UI elements
	game_over_label.visible = false
	win_label.visible = false
	restart_button.visible = false
	
	# Clear existing level objects first
	clear_level_objects()
	
	# Wait a frame for cleanup
	await get_tree().process_frame
	
	# Ensure level is properly reset before generating
	if game_state.current_level > 7:
		game_state.reset_to_start()
		print("Level was > 7, reset to: ", game_state.current_level)
	
	# Generate new level (only if not all levels completed)
	if not prevent_game_over:
		generate_new_level()
	else:
		print("All levels completed - not generating new level")

func position_player_within_level():
	# Get scaled level dimensions
	var dimensions = LevelUtils.get_scaled_level_dimensions(game_state.current_level_size)
	var level_width = dimensions.width
	var level_height = dimensions.height
	var offset_x = dimensions.offset_x
	var offset_y = dimensions.offset_y
	
	# Position player at the start position within the scaled level
	# Use a percentage of the level size to position the player
	var player_x = offset_x + (level_width * 0.1)  # 10% from left edge
	var player_y = offset_y + (level_height * 0.5)  # 50% from top (middle vertically)
	
	# Ensure player is within reasonable bounds
	player_x = max(player_x, 50)  # Minimum 50px from left
	player_y = max(player_y, 50)  # Minimum 50px from top
	
	player.position = Vector2(player_x, player_y)
	print("Player positioned at: ", player.position, " (level size: ", game_state.current_level_size, ")")
	print("Level dimensions: width=", level_width, " height=", level_height, " offset_x=", offset_x, " offset_y=", offset_y)

func _find_all_timers(node: Node, timers: Array):
	if node is Timer:
		timers.append(node)
	for child in node.get_children():
		_find_all_timers(child, timers)

func clear_level_objects():
	print("Main: Clearing level objects...")
	print("Main: LevelGenerator before clear: ", level_generator, " (valid: ", is_instance_valid(level_generator), ")")
	
	# Clear all generated objects safely
	for child in get_children():
		if child.name.begins_with("Obstacle") or child.name.begins_with("Coin") or child.name == "Exit" or child.name.begins_with("Door") or child.name.begins_with("Key") or child.name.begins_with("MazeWall"):
			if is_instance_valid(child):
				child.queue_free()
	
	# Clear level generator objects
	if level_generator and is_instance_valid(level_generator):
		print("Main: Calling level_generator.clear_existing_objects()")
		level_generator.clear_existing_objects()
		print("Main: After clear - LevelGenerator: ", level_generator, " (valid: ", is_instance_valid(level_generator), ")")
	
	# Reset references
	exit = null
	coins = []
	total_coins = 0
	collected_coins = 0
	exit_active = false
