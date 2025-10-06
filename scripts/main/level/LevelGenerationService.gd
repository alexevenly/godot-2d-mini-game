extends RefCounted

class_name LevelGenerationService

const LOGGER := preload("res://scripts/Logger.gd")
const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const GAME_STATE := preload("res://scripts/GameState.gd")
const DEFAULT_DOOR_COLOR := Color(0.35, 0.35, 0.75, 1.0)
const KEY_SETTINGS := preload("res://scripts/level_generators/key/KeyRingSettings.gd")

var main
var ui_controller

func setup(main_ref, ui_controller_ref) -> void:
	main = main_ref
	ui_controller = ui_controller_ref

func calculate_generation_size(level_type: int) -> float:
	var generation_level_size: float = main.game_state.current_level_size
	if level_type == GAME_STATE.LevelType.KEYS:
		generation_level_size = min(
			generation_level_size + 0.35,
			main.game_state.max_level_size + 0.25
		)
		generation_level_size = min(
			generation_level_size * KEY_SETTINGS.LEVEL_SIZE_MULTIPLIER,
			main.game_state.max_level_size
		)
	return generation_level_size

func reset_runtime_state() -> void:
	main.level_start_time = Time.get_ticks_msec() / 1000.0
	main.collected_coins = main.previous_coin_count
	main.exit_active = false
	main.exit = null
	main.total_coins = 0
	main.total_keys = 0
	main.collected_keys_count = 0
	main.collected_key_ids.clear()
	main.game_state.set_state(GAME_STATE.GameStateType.PLAYING)
	if main.game_state.current_state != GAME_STATE.GameStateType.PLAYING:
		LOGGER.log_game_mode("Game state corrected to PLAYING before generation")
		main.game_state.set_state(GAME_STATE.GameStateType.PLAYING)

func determine_generation_flags(level_type: int) -> Dictionary:
	var generate_obstacles: bool = main.game_state.generate_obstacles
	var generate_coins: bool = main.game_state.generate_coins
	if level_type == GAME_STATE.LevelType.KEYS:
		generate_obstacles = false
		generate_coins = false
	elif (
		level_type == GAME_STATE.LevelType.MAZE
		or level_type == GAME_STATE.LevelType.MAZE_COINS
		or level_type == GAME_STATE.LevelType.MAZE_KEYS
	):
		generate_obstacles = false
		generate_coins = false
	return {
		"generate_obstacles": generate_obstacles,
		"generate_coins": generate_coins
	}

func invoke_level_generator(level_type: int, generation_level_size: float, flags: Dictionary) -> bool:
	if main.level_generator and is_instance_valid(main.level_generator):
		main.level_generator.generate_level(
			generation_level_size,
			flags.get("generate_obstacles", true),
			flags.get("generate_coins", true),
			main.game_state.min_exit_distance_ratio,
			main.game_state.use_full_map_coverage,
			main,
			main.game_state.current_level,
			main.previous_coin_count,
			main.player.global_position if main.player else LEVEL_UTILS.PLAYER_START,
			level_type
		)
		return true
	LOGGER.log_error("LevelGenerator missing when attempting to generate level")
	return false

func apply_generation_outcome(binding_result: Dictionary, level_type: int) -> Dictionary:
	var has_spawn_override: bool = bool(binding_result.get("has_spawn_override", false))
	var spawn_override: Vector2 = binding_result.get("spawn_override", Vector2.ZERO)
	var generated_exit = binding_result.get("exit")
	var generated_coins = binding_result.get("coins", [] as Array[Area2D])
	var generated_keys = binding_result.get("keys", [] as Array[Area2D])
	var generated_doors = binding_result.get("doors", [] as Array[StaticBody2D])
	main.exit = generated_exit if generated_exit and is_instance_valid(generated_exit) else null
	var coins: Array[Area2D] = generated_coins if typeof(generated_coins) == TYPE_ARRAY else [] as Array[Area2D]
	var keys: Array[Area2D] = generated_keys if typeof(generated_keys) == TYPE_ARRAY else [] as Array[Area2D]
	var doors: Array = generated_doors if typeof(generated_doors) == TYPE_ARRAY else [] as Array[StaticBody2D]
	if main.exit:
		LOGGER.log_generation("Exit generated at %s" % [main.exit.position])
	else:
		LOGGER.log_generation("No exit generated")
	LOGGER.log_generation("Coins generated: %d" % coins.size())
	LOGGER.log_generation("Keys generated: %d" % keys.size())
	if main.timer_manager:
		var timer_start_position: Vector2 = spawn_override if has_spawn_override else (
			main.player.global_position if main.player else LEVEL_UTILS.PLAYER_START
		)
		var maze_path_length: float = 0.0
		if main.level_generator and is_instance_valid(main.level_generator):
			maze_path_length = main.level_generator.get_last_maze_path_length()
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
	main.total_coins = coins.size()
	main.collected_coins = 0
	if main.total_coins == 0:
		main.previous_coin_count = 0
	main.total_keys = keys.size()
	main.collected_keys_count = 0
	main.collected_key_ids.clear()
	main.exit_active = main.collected_coins >= main.total_coins
	if main.timer and is_instance_valid(main.timer):
		main.timer.wait_time = main.game_time
		main.timer.stop()
		main.timer.start()
	if ui_controller:
		ui_controller.update_coin_display(main.total_coins, main.collected_coins)
		ui_controller.setup_door_ui(doors)
		ui_controller.setup_key_ui(keys)
		ui_controller.update_exit_state(main.exit_active, main.exit)
		ui_controller.update_timer_display(main.game_time)
		ui_controller.update_level_progress(main.game_state.get_level_progress_text())
		_apply_initial_door_state(doors)
	if has_spawn_override and main.player and is_instance_valid(main.player):
		main.player.global_position = spawn_override
		main.player.position = spawn_override
		main.player.rotation = 0.0
		LOGGER.log_generation("Level ready: time %.2f, coins %d" % [main.game_time, main.total_coins])
	else:
		LOGGER.log_generation("Level ready: time %.2f, coins %d (default spawn)" % [main.game_time, main.total_coins])
	return {
		"coins": coins,
		"keys": keys,
		"doors": doors
	}

func _apply_initial_door_state(doors: Array) -> void:
	if ui_controller == null:
		return
	for door in doors:
		var door_body: StaticBody2D = door
		if door_body == null or not is_instance_valid(door_body):
			continue
		if not door_body.has_method("is_open") or not door_body.is_open():
			continue
		var door_id: int = 0
		if door_body.has_method("get"):
			var door_id_value = door_body.get("door_id")
			if door_id_value != null:
				door_id = int(door_id_value)
		var door_color: Color = DEFAULT_DOOR_COLOR
		if door_body.has_method("get_door_color"):
			door_color = door_body.get_door_color()
		elif door_body.has_meta("group_color"):
			door_color = door_body.get_meta("group_color")
		elif door_body.has_method("get"):
			var door_color_value = door_body.get("door_color")
			if typeof(door_color_value) == TYPE_COLOR:
				door_color = door_color_value
		ui_controller.mark_door_opened(door_id, door_color)
