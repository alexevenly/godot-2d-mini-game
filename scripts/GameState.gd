class_name GameState
extends Node

const GameLogger = preload("res://scripts/Logger.gd")

# Game state management
enum GameStateType {PLAYING, WON, LOST}
enum LevelType {OBSTACLES_COINS, KEYS, MAZE, MAZE_COINS, MAZE_KEYS, MAZE_COMPLEX, MAZE_COMPLEX_COINS, RANDOM, CHALLENGE}
var current_state = GameStateType.PLAYING

# Progressive level scaling
var current_level = 1
var victories = 0
var current_level_size = 0.85 # Start at 85% of full size
var max_level_size = 2.0 # 200% of base size
var level_size_increment = 0.0

# Game configuration
@export var generate_obstacles = true
@export var generate_coins = true
@export var min_exit_distance_ratio = 0.4 # 40% of level diagonal
@export var use_full_map_coverage = true # Populate whole map instead of just center

# Tug of war configuration
@export var tug_of_war_enabled = false
var tug_of_war_force = 0.0 # -1.0 to 1.0, negative pulls left, positive pulls right
var tug_of_war_strength = 50.0 # Force strength

var selected_level_type: LevelType = LevelType.OBSTACLES_COINS
var current_level_type: LevelType = LevelType.OBSTACLES_COINS
var challenge_sequence: Array = []
var challenge_stage_index: int = 0
var challenge_lfov_flags: Array = []

func _ready():
	# Calculate level size increment
	level_size_increment = (max_level_size - current_level_size) / 7.0
	if Engine.has_meta("level_type_selection"):
		var stored_type = int(Engine.get_meta("level_type_selection"))
		if stored_type >= 0 and stored_type <= LevelType.CHALLENGE:
			selected_level_type = LevelType.values()[stored_type]
	_refresh_level_type(true)

func reset_to_start():
	current_level = 1
	victories = 0
	current_state = GameStateType.PLAYING
	current_level_size = 0.85
	challenge_stage_index = 0
	_refresh_level_type(true)

func advance_level():
	# Check if we've completed all levels BEFORE incrementing
	if current_level >= 7:
		reset_to_start()
		return true # Indicates we've completed all levels

	current_level += 1
	victories += 1

	# Update level size
	current_level_size = 0.85 + (victories * level_size_increment)
	current_level_size = min(current_level_size, max_level_size)
	if selected_level_type == LevelType.CHALLENGE:
		challenge_stage_index = clamp(current_level - 1, 0, 6)
	_refresh_level_type(true)

	return false

func drop_progress_on_loss():
	current_level = 1
	victories = 0
	current_level_size = 0.85
	challenge_stage_index = 0
	_refresh_level_type(true)

func get_level_progress_text() -> String:
	return "Level: " + str(current_level) + "/7"

func get_next_level_size() -> float:
	if current_level >= 7:
		return 0.85 # Reset to start
	return 0.85 + (victories * level_size_increment)

func is_game_active() -> bool:
	return current_state == GameStateType.PLAYING

func set_state(new_state: GameStateType):
	current_state = new_state

func get_state() -> GameStateType:
	return current_state

func set_level_type(new_type: LevelType):
	selected_level_type = new_type
	if selected_level_type == LevelType.CHALLENGE:
		_generate_challenge_sequence()
		challenge_stage_index = 0
	_refresh_level_type(true)
	GameLogger.log_game_mode("Level type selection updated to %s" % _get_level_type_label(selected_level_type))

func get_current_level_type() -> LevelType:
	return current_level_type

func set_tug_of_war_enabled(enabled: bool) -> void:
	tug_of_war_enabled = enabled
	if not enabled:
		tug_of_war_force = 0.0

func update_tug_of_war_force(delta: float) -> void:
	if not tug_of_war_enabled:
		return
	
	# Simple tug of war: gradually shift force based on player position
	# This is a simplified implementation - in a real game you'd have more complex logic
	var random_factor = randf_range(-0.1, 0.1)
	tug_of_war_force += random_factor * delta
	tug_of_war_force = clamp(tug_of_war_force, -1.0, 1.0)
	
	# Gradually return to center
	tug_of_war_force *= 0.95

func get_tug_of_war_force() -> Vector2:
	if not tug_of_war_enabled:
		return Vector2.ZERO
	return Vector2(tug_of_war_force * tug_of_war_strength, 0.0)

func _refresh_level_type(force_new: bool = false):
	var previous_type = current_level_type
	if selected_level_type == LevelType.CHALLENGE:
		if force_new or challenge_sequence.is_empty():
			_generate_challenge_sequence()
		challenge_stage_index = clamp(current_level - 1, 0, challenge_sequence.size() - 1)
		if challenge_sequence.is_empty():
			current_level_type = LevelType.OBSTACLES_COINS
		else:
			current_level_type = challenge_sequence[challenge_stage_index]
		# Enforce LFOV per challenge stage regardless of main menu setting
		if challenge_lfov_flags.size() == challenge_sequence.size():
			var lfov: bool = bool(challenge_lfov_flags[challenge_stage_index])
			Engine.set_meta("limited_field_of_view", lfov)
	elif selected_level_type == LevelType.RANDOM:
		if force_new or current_level_type == LevelType.RANDOM:
			current_level_type = _pick_random_level_type()
	else:
		current_level_type = selected_level_type
	if previous_type != current_level_type:
		GameLogger.log_game_mode("Current level type set to %s" % _get_level_type_label(current_level_type))

func _pick_random_level_type() -> LevelType:
	var options: Array = [LevelType.OBSTACLES_COINS, LevelType.KEYS, LevelType.MAZE, LevelType.MAZE_COINS, LevelType.MAZE_KEYS, LevelType.MAZE_COMPLEX, LevelType.MAZE_COMPLEX_COINS]
	if options.is_empty():
		return LevelType.OBSTACLES_COINS
	return options[randi() % options.size()]

func _get_level_type_label(level_type: LevelType) -> String:
	match level_type:
		LevelType.OBSTACLES_COINS:
			return "Obstacles + Coins"
		LevelType.KEYS:
			return "Keys"
		LevelType.MAZE:
			return "Maze"
		LevelType.MAZE_COINS:
			return "Maze + Coins"
		LevelType.MAZE_KEYS:
			return "Maze + Keys"
		LevelType.MAZE_COMPLEX:
			return "Maze complex"
		LevelType.MAZE_COMPLEX_COINS:
			return "Maze complex + Coins"
		LevelType.RANDOM:
			return "Random"
		LevelType.CHALLENGE:
			return "Challenge"
	return str(level_type)

func _generate_challenge_sequence() -> void:
	# Define 7 stages and whether each should use LFOV (true) during challenge
	var types: Array = [
		LevelType.KEYS, # no LFOV
		LevelType.MAZE, # LFOV
		LevelType.MAZE_COINS, # LFOV
		LevelType.MAZE_KEYS, # LFOV
		LevelType.MAZE_COMPLEX, # no LFOV
		LevelType.MAZE_COMPLEX, # LFOV enforced
		LevelType.MAZE_COMPLEX_COINS # no LFOV
	]
	var lfov: Array = [
		false,
		true,
		true,
		true,
		false,
		true,
		false
	]
	# Shuffle indices to keep pairing between type and LFOV
	var indices: Array = []
	for i in range(types.size()):
		indices.append(i)
	indices.shuffle()
	var seq: Array = []
	var flags: Array = []
	for i in indices:
		seq.append(types[i])
		flags.append(lfov[i])
	challenge_sequence = seq
	challenge_lfov_flags = flags

func get_current_challenge_lfov() -> bool:
	if selected_level_type != LevelType.CHALLENGE:
		return Engine.has_meta("limited_field_of_view") and bool(Engine.get_meta("limited_field_of_view"))
	if challenge_lfov_flags.size() != challenge_sequence.size():
		return Engine.has_meta("limited_field_of_view") and bool(Engine.get_meta("limited_field_of_view"))
	var idx = clamp(current_level - 1, 0, challenge_lfov_flags.size() - 1)
	return bool(challenge_lfov_flags[idx])
