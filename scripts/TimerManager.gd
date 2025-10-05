class_name TimerManager
extends Node2D

const GAME_STATE := preload("res://scripts/GameState.gd")
const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const TIMER_CONFIG := preload("res://scripts/timer/TimerBalanceConfig.gd")
const TIMER_CALC := preload("res://scripts/timer/TimerBalanceCalculator.gd")

const SURPLUS_WINDOW := 8
const SURPLUS_GAIN := 0.65

var _difficulty: StringName = &"regular"
var _recent_surplus: Array[float] = []

func set_difficulty(level: String) -> void:
	if TIMER_CONFIG.has_difficulty(level):
		_difficulty = level
	else:
		push_warning("Unknown difficulty '%s', keeping '%s'." % [level, _difficulty])

func _get_preset() -> Dictionary:
	return TIMER_CONFIG.get_difficulty(_difficulty)

func _avg_surplus() -> float:
	if _recent_surplus.is_empty():
		return 0.0
	var s := 0.0
	for v in _recent_surplus:
		s += v
	return s / float(_recent_surplus.size())

func register_level_result(time_left_sec: float) -> void:
	_recent_surplus.append(max(time_left_sec, 0.0))
	if _recent_surplus.size() > SURPLUS_WINDOW:
		_recent_surplus.pop_front()

func calculate_level_time(level: int, coins: Array, exit_pos: Vector2, player_start: Vector2 = LEVEL_UTILS.PLAYER_START, level_type: int = GAME_STATE.LevelType.OBSTACLES_COINS, maze_path_length: float = 0.0) -> float:
	var preset := _get_preset()
	var total_distance: float = 0.0
	var current_pos: Vector2 = player_start
	if coins.size() > 0:
		for coin in coins:
			total_distance += current_pos.distance_to(coin.position)
			current_pos = coin.position
	total_distance += current_pos.distance_to(exit_pos)

	var speed: float = float(preset["speed"])
	var type_profile := TIMER_CONFIG.get_type_profile(level_type)
	var is_maze := (
		level_type == GAME_STATE.LevelType.MAZE or
		level_type == GAME_STATE.LevelType.MAZE_COINS or
		level_type == GAME_STATE.LevelType.MAZE_KEYS or
		level_type == GAME_STATE.LevelType.MAZE_COMPLEX or
		level_type == GAME_STATE.LevelType.MAZE_COMPLEX_COINS
	)
	var maze_overhead := TIMER_CALC.maze_overhead(is_maze, type_profile, maze_path_length, player_start, exit_pos, speed)
	var base_path: float = float(maze_overhead.get("base_path", 0.0))
	if base_path > 0.0:
		total_distance = max(total_distance, base_path)
	if level_type == GAME_STATE.LevelType.OBSTACLES_COINS and level > 2:
		var trim = clamp(float(type_profile.get("route_trim", 1.0)), 0.5, 1.0)
		var ramp = max(float(type_profile.get("trim_ramp", 3.0)), 0.001)
		var trim_t = clamp((float(level) - 2.0) / ramp, 0.0, 1.0)
		total_distance *= lerp(1.0, trim, trim_t)
	total_distance *= float(maze_overhead["factor"])

	var base_time: float = (total_distance / speed) * TIMER_CALC.route_detour_factor(coins.size())
	var per_coin_sec: float = float(preset["per_coin_sec"])
	var pickup_time: float = float(coins.size()) * per_coin_sec

	if level_type == GAME_STATE.LevelType.KEYS and coins.size() == 0:
		base_time *= 1.5

	if level_type == GAME_STATE.LevelType.KEYS:
		var key_bonus = 1.5
		var estimated_key_count = max(3, level)
		base_time += estimated_key_count * key_bonus

	var mult: float = TIMER_CALC.level_multiplier(level, preset)
	var preset_scale: float = float(preset["global_scale"])
	var min_time: float = float(preset["min_time"])

	var multiplicative_buffer: float = base_time * max(mult - 1.0, 0.0)
	var cap_sec: float = TIMER_CALC.buffer_cap_sec(level, preset)
	var capped_buffer: float = min(multiplicative_buffer, cap_sec)
	var buffer_bias: float = float(type_profile.get("buffer_bias", 0.0))
	if buffer_bias < 0.0:
		capped_buffer = max(capped_buffer * (1.0 + buffer_bias), 0.0)
	elif buffer_bias > 0.0:
		capped_buffer = min(capped_buffer * (1.0 + buffer_bias), cap_sec * (1.0 + buffer_bias))

	var planned: float = (base_time + pickup_time + capped_buffer) * preset_scale
	planned += float(type_profile.get("flat_bonus", 0.0))
	planned += float(maze_overhead.get("slack", 0.0))

	var type_scale = TIMER_CALC.level_type_scale(type_profile, level)
	planned *= type_scale
	
	# Apply limited field of view bonus for complex mazes
	if (level_type == GAME_STATE.LevelType.MAZE_COMPLEX or
		level_type == GAME_STATE.LevelType.MAZE_COMPLEX_COINS):
		if Engine.has_meta("limited_field_of_view") and bool(Engine.get_meta("limited_field_of_view")):
			planned *= 1.75 # 75% more time for limited FOV

	var avg_surplus = _avg_surplus()
	if avg_surplus > 0.0:
		var target = TIMER_CALC.target_surplus_sec(level)
		var over: float = max(avg_surplus - target, 0.0)
		var max_cut: float = max(0.4 * planned, cap_sec * 1.5)
		var cut: float = clamp(over * SURPLUS_GAIN, 0.0, max_cut)
		planned = max(planned - cut, min_time)

	var result: float = max(planned, min_time)
	if result <= min_time + 0.0001:
		var distance_time: float = total_distance / max(speed, 0.0001)
		result = min_time + distance_time + pickup_time
	return result

func get_time_for_level(level: int, level_type: int = GAME_STATE.LevelType.OBSTACLES_COINS) -> float:
	var preset := _get_preset()
	var mult: float = TIMER_CALC.level_multiplier(level, preset)
	var preset_scale: float = float(preset["global_scale"])
	var min_time: float = float(preset["min_time"])
	var type_profile := TIMER_CONFIG.get_type_profile(level_type)
	var approx: float = TIMER_CONFIG.BASE_TIME_PER_LEVEL * mult * preset_scale * TIMER_CALC.level_type_scale(type_profile, level)
	var avg_surplus = _avg_surplus()
	if avg_surplus > 0.0:
		var target = TIMER_CALC.target_surplus_sec(level)
		var over: float = max(avg_surplus - target, 0.0)
		var cut: float = clamp(over * 0.5, 0.0, 0.4 * approx)
		approx = max(approx - cut, min_time)
	return max(approx, min_time)
