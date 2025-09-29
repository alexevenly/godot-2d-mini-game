extends Node2D

const Logger = preload("res://scripts/Logger.gd")

@onready var player = $Player
@onready var timer = $Timer
@onready var timer_label = $UI/TimerLabel
@onready var coin_label = $UI/CoinLabel
@onready var level_progress_label = $UI/LevelProgressLabel
@onready var game_over_label = $UI/GameOverLabel
@onready var win_label = $UI/WinLabel
@onready var restart_button = $UI/RestartButton
@onready var menu_button = $UI/MenuButton
@onready var key_container = $UI/KeyContainer
@onready var key_status_container = $UI/KeyContainer/KeyStatus
@onready var level_generator = $LevelGenerator
@onready var timer_manager = $TimerManager
@onready var play_area = $PlayArea
@onready var boundaries = $Boundaries
@onready var game_state = $GameState

var game_time = 30.0
var total_coins = 0
var collected_coins = 0
var previous_coin_count = 0 # Preserve coin count between levels
var keys = []
var total_keys = 0
var collected_keys_count = 0
var key_checkbox_nodes: Array = []
var key_colors: Array = []
var exit_active = false
var exit = null
var coins = []
var prevent_game_over = false # Flag to prevent game over calls
var level_start_time = 0.0 # Time when level started
var statistics_file = null # File handle for statistics logging
var level_initializing = false # Guard to pause gameplay ticks during regeneration

func _ready():
	# Connect signals
	timer.timeout.connect(_on_timer_timeout)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)

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

	# Create statistics log file
	var timestamp = Time.get_datetime_string_from_system()
	var filename = "logs/statistics_" + timestamp.replace(":", "-") + ".log"
	statistics_file = FileAccess.open(filename, FileAccess.WRITE)

	if statistics_file:
		statistics_file.store_line("Level,Size,MapWidth,MapHeight,CoinsTotal,CoinsCollected,TimeGiven,TimeUsed,TimeLeft,Distance,CompletionRate")
		statistics_file.flush()
	else:
		Logger.log_error("Could not create statistics file", [filename])

func _log_level_statistics():
	if statistics_file == null:
		Logger.log_error("Statistics file was null while logging level statistics")
		return

	var distance = 0.0
	var completion_time = Time.get_ticks_msec() / 1000.0 - level_start_time
	var time_left = game_time

	# Calculate distance from player to exit
	if player and exit:
		distance = player.global_position.distance_to(exit.global_position)

	# Calculate completion rate (coins collected / total coins)
	var coin_total := coins.size()
	var completion_rate = 1.0 if coin_total == 0 else float(collected_coins) / float(max(coin_total, 1))

	# Create statistics line
	var stats_line = str(game_state.current_level) + "," + \
		str(game_state.current_level_size) + "," + \
		str(play_area.size.x) + "," + \
		str(play_area.size.y) + "," + \
		str(coin_total) + "," + \
		str(collected_coins) + "," + \
		str(timer.wait_time) + "," + \
		str(completion_time) + "," + \
		str(time_left) + "," + \
		str(distance) + "," + \
		str(completion_rate)

	statistics_file.store_line(stats_line)
	statistics_file.flush()

	# Register level result with TimerManager
	if timer_manager:
		timer_manager.register_level_result(time_left)
	else:
		Logger.log_error("TimerManager not found while logging statistics")

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
		Logger.log_game_mode("Level exceeded cap, reset to level", [game_state.current_level])

	Logger.log_generation("Generating level %d (size: %.2f)" % [game_state.current_level, game_state.current_level_size])

	# Record level start time
	level_start_time = Time.get_ticks_msec() / 1000.0

	# Reset state first
	collected_coins = previous_coin_count # Use preserved coin count
	exit_active = false
	exit = null
	coins = []
	keys = []
	game_state.set_state(GameState.GameStateType.PLAYING)

	# Ensure we're in playing state
	if game_state.current_state != GameState.GameStateType.PLAYING:
		Logger.log_game_mode("Game state corrected to PLAYING before generation")
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
	Logger.log_game_mode("Preparing level type: %s" % level_type_label)

	var generate_obstacles = true
	var generate_coins = true

	# Generate new level and get optimal time
	if level_generator and is_instance_valid(level_generator):
		generate_obstacles = game_state.generate_obstacles
		generate_coins = game_state.generate_coins
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
	keys = level_generator.get_generated_keys()
	var spawn_override = level_generator.get_player_spawn_override()

	if exit:
		Logger.log_generation("Exit generated at %s" % [exit.position])
	else:
		Logger.log_generation("No exit generated")
	Logger.log_generation("Coins generated: %d" % coins.size())
	Logger.log_generation("Keys generated: %d" % keys.size())

	# Calculate time using timer manager
	if timer_manager:
		var timer_start_position = spawn_override if spawn_override != null else (player.global_position if player else LevelUtils.PLAYER_START)
		game_time = timer_manager.calculate_level_time(game_state.current_level, coins, exit.position if exit else Vector2(), timer_start_position)
	else:
		game_time = 30.0 # Fallback

	# Connect coin signals safely
	for coin in coins:
		if coin and is_instance_valid(coin):
			if not coin.body_entered.is_connected(_on_coin_collected):
				coin.body_entered.connect(_on_coin_collected.bind(coin))

	total_coins = coins.size()
	collected_coins = 0
	if total_coins == 0:
		previous_coin_count = 0

	# Connect exit signal safely
	if exit and is_instance_valid(exit):
		if not exit.body_entered.is_connected(_on_exit_entered):
			exit.body_entered.connect(_on_exit_entered)

	# Connect key signals safely
	collected_keys_count = 0
	total_keys = keys.size()
	for key in keys:
		if key and is_instance_valid(key):
			if not key.key_collected.is_connected(_on_key_collected):
				key.key_collected.connect(_on_key_collected)

	# Start timer
	timer.wait_time = game_time
	# Ensure timer is stopped before starting
	timer.stop()
	timer.start()

	# Update displays
	_update_coin_display()
	_setup_key_ui(keys)
	_update_exit_state()

	if spawn_override != null and player and is_instance_valid(player):
		player.global_position = spawn_override
		player.position = spawn_override
		player.rotation = 0.0
		Logger.log_generation("Level ready: time %.2f, coins %d" % [game_time, total_coins])
	else:
		Logger.log_generation("Level ready: time %.2f, coins %d (default spawn)" % [game_time, total_coins])

	level_initializing = false

func _update_timer_display():
	timer_label.text = "Time: " + "%.2f" % game_time

func _update_coin_display():
	coin_label.visible = total_coins > 0
	if coin_label.visible:
		coin_label.text = "Coins: " + str(collected_coins) + "/" + str(total_coins)
	else:
		coin_label.text = ""

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
		Logger.log_game_mode("Timer halted because state is %s" % [_get_state_label(game_state.current_state)])

func _update_exit_state():
	exit_active = (collected_coins >= total_coins)
	if exit and exit.get_node("ExitBody"):
		if exit_active:
			exit.get_node("ExitBody").color = Color(0.2, 0.8, 0.2, 1) # Green when active
		else:
			exit.get_node("ExitBody").color = Color(0.4, 0.4, 0.4, 1) # Gray when inactive

func _on_coin_collected(body, coin):
	if body == player and game_state.is_game_active():
		collected_coins += 1
		previous_coin_count = collected_coins # Preserve coin count
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

func _on_key_collected(_door_id):
	collected_keys_count += 1
	collected_keys_count = min(collected_keys_count, total_keys)
	_update_key_status_display()

func _on_timer_timeout():
	# Prevent timer timeout if game is not in playing state
	if game_state.current_state != GameState.GameStateType.PLAYING:
		Logger.log_game_mode("Timer timeout ignored; state is %s" % [_get_state_label(game_state.current_state)])
		# Force stop timer completely
		timer.stop()
		timer.wait_time = 999999
		# Disconnect timer to prevent further calls
		if timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.disconnect(_on_timer_timeout)
		return

	# Additional check to prevent multiple game over calls
	if not game_state.is_game_active():
		Logger.log_game_mode("Timer timeout ignored; game inactive")
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

	Logger.log_game_mode("Game over on level %d (size %.2f)" % [game_state.current_level, game_state.current_level_size])
	game_state.set_state(GameState.GameStateType.LOST)
	game_over_label.visible = true
	restart_button.visible = true
	menu_button.visible = true
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

	# Update button text
	restart_button.text = "Restart"

	# Update level progress display
	_update_level_progress()

func _win_game():
	# Prevent multiple calls
	if not game_state.is_game_active():
		return

	Logger.log_game_mode("Level %d completed (size %.2f)" % [game_state.current_level, game_state.current_level_size])
	game_state.set_state(GameState.GameStateType.WON)
	win_label.visible = true
	restart_button.visible = true
	menu_button.visible = true
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
		Logger.log_game_mode("All 7 levels completed; awaiting restart")
		# Set flag to prevent game over calls
		prevent_game_over = true
		# Don't advance level here - just show victory
		return
	else:
		# Normal level completion
		restart_button.text = "Continue"
		Logger.log_game_mode("Continue to next level when ready")

	# Don't update level progress here - it will be updated after level advancement

func _on_restart_pressed():
	Logger.log_game_mode("Restart requested on level %d (size %.2f)" % [game_state.current_level, game_state.current_level_size])

	# Reset game state
	collected_coins = previous_coin_count # Use preserved coin count
	exit_active = false
	# Don't reset prevent_game_over flag here - it should stay true if all levels completed

	# Hide game over/win labels
	game_over_label.visible = false
	win_label.visible = false
	menu_button.visible = false

	# Handle timer based on game state
	_handle_timer_for_game_state()

	# Check if we're starting a completely new game after completing all levels
	if prevent_game_over and game_state.current_state == GameState.GameStateType.WON:
		Logger.log_game_mode("Restarting fresh run after completing all levels")
		# Reset everything for a fresh start
		prevent_game_over = false
		game_state.reset_to_start()
		Logger.log_game_mode("Reset to level 1; prevent_game_over cleared")
		# Continue to generate new level below

	# Advance level if we just won (check BEFORE resetting state)
	elif game_state.current_state == GameState.GameStateType.WON:
		Logger.log_game_mode("Advancing from level %d" % game_state.current_level)
		var completed_all_levels = game_state.advance_level()
		Logger.log_game_mode("Advanced to level %d (size %.2f)" % [game_state.current_level, game_state.current_level_size])

		# Update button text based on level
		if completed_all_levels:
			restart_button.text = "Start all over again?"
			Logger.log_game_mode("All levels complete; waiting for full restart")
			# Set flag to prevent game over calls
			prevent_game_over = true
			# Completely reset the timer
			timer.stop()
		timer.wait_time = 999999 # Set to a very long time
		# Disconnect timer timeout to prevent further calls
		if timer.timeout.is_connected(_on_timer_timeout):
			timer.timeout.disconnect(_on_timer_timeout)
		# Force timer to stop completely
		timer.stop()
		# Don't generate new level when all levels are completed
		# Just show the button and wait for user to click "Start all over again?"
		if completed_all_levels:
			return
		else:
			restart_button.text = "Continue"
			Logger.log_game_mode("Next level %d prepared (size %.2f)" % [game_state.current_level, game_state.current_level_size])
	elif game_state.current_state == GameState.GameStateType.LOST:
		# If we lost, reset prevent_game_over flag
		prevent_game_over = false
		Logger.log_game_mode("Prevent game over flag cleared after loss")
	else:
		restart_button.text = "Continue"
		Logger.log_game_mode("Next level %d prepared (size %.2f)" % [game_state.current_level, game_state.current_level_size])
		# Reset prevent_game_over flag for normal level progression
		prevent_game_over = false
	# Reset game state to playing (after level advancement)
	game_state.set_state(GameState.GameStateType.PLAYING)

	# Update level progress display after level advancement
	_update_level_progress()

	# Stop any running timer first
	timer.stop()

	# Reconnect timer if it was disconnected (only if not all levels completed)
	if not prevent_game_over and not timer.timeout.is_connected(_on_timer_timeout):
		timer.timeout.connect(_on_timer_timeout)
	elif prevent_game_over:
		Logger.log_game_mode("Timer left disconnected; all levels completed")

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
	menu_button.visible = false

	# Clear existing level objects first
	clear_level_objects()

	# Wait a frame for cleanup
	await get_tree().process_frame

	# Ensure level is properly reset before generating
	if game_state.current_level > 7:
		game_state.reset_to_start()
		Logger.log_game_mode("Level exceeded cap during restart; reset to %d" % game_state.current_level)

	# Generate new level (only if not all levels completed)
	if not prevent_game_over:
		generate_new_level()
	else:
		Logger.log_game_mode("Generation skipped because campaign is complete")

func position_player_within_level():
	# Get scaled level dimensions
	var dimensions = LevelUtils.get_scaled_level_dimensions(game_state.current_level_size)
	var level_width = dimensions.width
	var level_height = dimensions.height
	var offset_x = dimensions.offset_x
	var offset_y = dimensions.offset_y

	# Position player at the start position within the scaled level
	# Use a percentage of the level size to position the player
	var player_x = offset_x + (level_width * 0.1) # 10% from left edge
	var player_y = offset_y + (level_height * 0.5) # 50% from top (middle vertically)

	# Ensure player is within reasonable bounds
	player_x = max(player_x, 50) # Minimum 50px from left
	player_y = max(player_y, 50) # Minimum 50px from top

	player.position = Vector2(player_x, player_y)

func _find_all_timers(node: Node, timers: Array):
	if node is Timer:
		timers.append(node)
	for child in node.get_children():
		_find_all_timers(child, timers)

func clear_level_objects():
	Logger.log_generation("Clearing previously generated objects")

	# Clear all generated objects safely
	for child in get_children():
		if child.name.begins_with("Obstacle") or child.name.begins_with("Coin") or child.name == "Exit" or child.name.begins_with("Door") or child.name.begins_with("Key") or child.name.begins_with("MazeWall"):
			if is_instance_valid(child):
				child.queue_free()

	# Clear level generator objects
	if level_generator and is_instance_valid(level_generator):
		level_generator.clear_existing_objects()
		Logger.log_generation("LevelGenerator cleared existing objects")

	# Reset references
	exit = null
	coins = []
	keys = []
	total_coins = 0
	collected_coins = 0
	total_keys = 0
	collected_keys_count = 0
	exit_active = false
	_clear_key_ui()

func _get_state_label(state: int) -> String:
	match state:
		GameState.GameStateType.PLAYING:
			return "PLAYING"
		GameState.GameStateType.WON:
			return "WON"
		GameState.GameStateType.LOST:
			return "LOST"
	return str(state)

func _clear_key_ui():
	key_checkbox_nodes.clear()
	key_colors.clear()
	if key_status_container:
		for child in key_status_container.get_children():
			if is_instance_valid(child):
				child.queue_free()
	if key_container:
		key_container.visible = false

func _setup_key_ui(key_nodes: Array):
	_clear_key_ui()
	if key_nodes == null:
		key_nodes = []
	total_keys = key_nodes.size()
	collected_keys_count = 0
	if total_keys <= 0 or key_status_container == null:
		return
	if key_container:
		key_container.visible = true
	for i in range(total_keys):
		var checkbox := CheckBox.new()
		checkbox.disabled = true
		checkbox.focus_mode = Control.FOCUS_NONE
		checkbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		checkbox.button_pressed = false

		var key_node = key_nodes[i] if i < key_nodes.size() else null
		var color := Color(0.9, 0.9, 0.2, 1.0)
		if key_node and key_node.has_meta("group_color"):
			color = key_node.get_meta("group_color")
		key_colors.append(color)
		checkbox.modulate = color

		key_status_container.add_child(checkbox)
		key_checkbox_nodes.append(checkbox)
	_update_key_status_display()

func _update_key_status_display():
	for i in range(key_checkbox_nodes.size()):
		var checkbox = key_checkbox_nodes[i]
		if not is_instance_valid(checkbox):
			continue
		var is_collected = i < collected_keys_count
		checkbox.button_pressed = is_collected
		var base_color := key_colors[i] if i < key_colors.size() else Color(0.9, 0.9, 0.2, 1.0)
		if is_collected:
			var highlight := base_color.lightened(0.35)
			highlight.a = base_color.a
			checkbox.modulate = highlight
		else:
			checkbox.modulate = base_color
	if key_container:
		key_container.visible = key_checkbox_nodes.size() > 0

func _on_menu_pressed():
	prevent_game_over = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
