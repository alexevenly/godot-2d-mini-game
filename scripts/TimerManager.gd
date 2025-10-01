class_name TimerManager
extends Node2D

const GameState = preload("res://scripts/GameState.gd")
const LevelUtils = preload("res://scripts/LevelUtils.gd")

# ---- ПРЕСЕТЫ (ужаты под твои данные) ----
const DIFFICULTY_PRESETS := {
	"child": {
		"mult_max": 1.45, "mult_min": 1.05, "half_life": 3.0,
		"min_time": 15.0, "speed": 250.0, "per_coin_sec": 0.12, "global_scale": 1.00,
		"buf_cap_start": 9.0, "buf_cap_end": 3.5, "cap_half_life": 3.0
	},
	"regular": {
		# было 1.35→1.25; cap 10→7, 2.5→1.8
		"mult_max": 1.25, "mult_min": 1.00, "half_life": 2.3,
		"min_time": 12.0, "speed": 300.0, "per_coin_sec": 0.06, "global_scale": 0.94,
		"buf_cap_start": 7.0, "buf_cap_end": 1.8, "cap_half_life": 2.3
	},
	"hard": {
		"mult_max": 1.18, "mult_min": 1.00, "half_life": 2.0,
		"min_time": 10.0, "speed": 320.0, "per_coin_sec": 0.04, "global_scale": 0.90,
		"buf_cap_start": 5.5, "buf_cap_end": 1.6, "cap_half_life": 2.0
	},
	"challenge": {
		"mult_max": 1.10, "mult_min": 1.00, "half_life": 1.8,
		"min_time": 8.0, "speed": 360.0, "per_coin_sec": 0.00, "global_scale": 0.88,
		"buf_cap_start": 4.0, "buf_cap_end": 1.3, "cap_half_life": 1.8
	}
}

const LEVEL_TYPE_TUNING := {
        GameState.LevelType.OBSTACLES_COINS: {
                "scale_start": 0.78,
                "scale_end": 0.48,
                "buffer_bias": -0.45,
                "flat_bonus": -1.8,
                "route_trim": 0.82,
                "trim_ramp": 4.0
        },
        GameState.LevelType.MAZE: {
                "scale_start": 1.05,
                "scale_end": 0.82,
                "buffer_bias": 0.12,
                "flat_bonus": 1.6,
                "maze_slack_curve": Vector2(3.5, 7.5),
                "maze_path_scale": 0.55,
                "maze_path_cap": 7.0,
                "maze_base_scale": 0.52,
                "maze_fallback_slack": 4.5,
                "maze_ratio_span": 2.0,
                "maze_path_floor": 1.05,
                "maze_fallback_factor": 1.18
        },
        GameState.LevelType.MAZE_COINS: {
                "scale_start": 1.08,
                "scale_end": 0.86,
                "buffer_bias": 0.18,
                "flat_bonus": 2.2,
                "maze_slack_curve": Vector2(4.0, 8.5),
                "maze_path_scale": 0.60,
                "maze_path_cap": 7.5,
                "maze_base_scale": 0.58,
                "maze_fallback_slack": 5.0,
                "maze_ratio_span": 2.2,
                "maze_path_floor": 1.08,
                "maze_fallback_factor": 1.22
        },
        GameState.LevelType.MAZE_KEYS: {
                "scale_start": 1.12,
                "scale_end": 0.90,
                "buffer_bias": 0.24,
                "flat_bonus": 2.8,
                "maze_slack_curve": Vector2(4.5, 9.5),
                "maze_path_scale": 0.65,
                "maze_path_cap": 8.0,
                "maze_base_scale": 0.62,
                "maze_fallback_slack": 5.5,
                "maze_ratio_span": 2.4,
                "maze_path_floor": 1.12,
                "maze_fallback_factor": 1.28
        },
        GameState.LevelType.KEYS: {
                "scale_start": 1.08,
                "scale_end": 0.96,
                "buffer_bias": 0.05,
                "flat_bonus": 0.6
        }
}


const BASE_TIME_PER_LEVEL := 22.0
var _difficulty: StringName = &"regular"

# ---- Автокалибровка по реальному запасу времени ----
const SURPLUS_WINDOW := 8
const SURPLUS_GAIN := 0.65
var _recent_surplus: Array[float] = []

func set_difficulty(level: String) -> void:
	if DIFFICULTY_PRESETS.has(level):
		_difficulty = level
	else:
		push_warning("Unknown difficulty '%s', keeping '%s'." % [level, _difficulty])

func _get_preset() -> Dictionary:
	return DIFFICULTY_PRESETS[_difficulty]

func _level_multiplier(level: int) -> float:
	var p := _get_preset()
	var mult_max: float = float(p["mult_max"])
	var mult_min: float = float(p["mult_min"])
	var half_life: float = max(float(p["half_life"]), 0.0001)
	var decay: float = pow(0.5, float(max(level, 1) - 1) / half_life)
	return mult_min + (mult_max - mult_min) * decay

func _buffer_cap_sec(level: int) -> float:
	var p := _get_preset()
	var start: float = float(p["buf_cap_start"])
	var endv: float = float(p["buf_cap_end"])
	var half_life: float = max(float(p["cap_half_life"]), 0.0001)
	var decay: float = pow(0.5, float(max(level, 1) - 1) / half_life)
	return endv + (start - endv) * decay

func _target_surplus_sec(level: int) -> float:
	var t: float = clamp((float(level) - 1.0) / 6.0, 0.0, 1.0)
	return lerp(6.0, 2.0, t)

func _route_detour_factor(coin_count: int) -> float:
	var n: float = float(max(coin_count, 0))
	var detour: float = log(1.0 + n) / log(2.0)
	return 1.0 + 0.05 * detour

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


func calculate_level_time(level: int, coins: Array, exit_pos: Vector2, player_start: Vector2 = LevelUtils.PLAYER_START, level_type: int = GameState.LevelType.OBSTACLES_COINS, maze_path_length: float = 0.0) -> float:
	var p := _get_preset()
	var total_distance: float = 0.0
	var current_pos: Vector2 = player_start
	if coins.size() > 0:
		for coin in coins:
			total_distance += current_pos.distance_to(coin.position)
			current_pos = coin.position
	total_distance += current_pos.distance_to(exit_pos)

	var speed: float = float(p["speed"])
	var type_profile = _get_type_profile(level_type)
	var maze_overhead = _maze_overhead(level_type, maze_path_length, player_start, exit_pos, speed)
	var base_path: float = float(maze_overhead.get("base_path", 0.0))
	if base_path > 0.0:
		total_distance = max(total_distance, base_path)
	if level_type == GameState.LevelType.OBSTACLES_COINS and level > 2:
		var trim = clamp(float(type_profile.get("route_trim", 1.0)), 0.5, 1.0)
		var ramp = max(float(type_profile.get("trim_ramp", 3.0)), 0.001)
		var trim_t = clamp((float(level) - 2.0) / ramp, 0.0, 1.0)
		total_distance *= lerp(1.0, trim, trim_t)
	total_distance *= float(maze_overhead["factor"])

	var base_time: float = (total_distance / speed) * _route_detour_factor(coins.size())
	var per_coin_sec: float = float(p["per_coin_sec"])
	var pickup_time: float = float(coins.size()) * per_coin_sec
	var mult: float = _level_multiplier(level)
	var preset_scale: float = float(p["global_scale"])
	var min_time: float = float(p["min_time"])

	var multiplicative_buffer: float = base_time * max(mult - 1.0, 0.0)
	var cap_sec: float = _buffer_cap_sec(level)
	var capped_buffer: float = min(multiplicative_buffer, cap_sec)
	var buffer_bias: float = float(type_profile.get("buffer_bias", 0.0))
	if buffer_bias < 0.0:
		capped_buffer = max(capped_buffer * (1.0 + buffer_bias), 0.0)
	elif buffer_bias > 0.0:
		capped_buffer = min(capped_buffer * (1.0 + buffer_bias), cap_sec * (1.0 + buffer_bias))

	var planned: float = (base_time + pickup_time + capped_buffer) * preset_scale
	planned += float(type_profile.get("flat_bonus", 0.0))
	planned += float(maze_overhead.get("slack", 0.0))

	var type_scale = _level_type_scale(level_type, level)
	planned *= type_scale

	var avg_surplus = _avg_surplus()
	if avg_surplus > 0.0:
		var target = _target_surplus_sec(level)
		var over: float = max(avg_surplus - target, 0.0)
		var max_cut: float = max(0.4 * planned, cap_sec * 1.5)
		var cut: float = clamp(over * SURPLUS_GAIN, 0.0, max_cut)
		planned = max(planned - cut, min_time)

	var result: float = max(planned, min_time)
	if result <= min_time + 0.0001:
		var distance_time: float = total_distance / max(speed, 0.0001)
		result = min_time + distance_time + pickup_time
	return result

func get_time_for_level(level: int, level_type: int = GameState.LevelType.OBSTACLES_COINS) -> float:
	var p := _get_preset()
	var mult: float = _level_multiplier(level)
	var preset_scale: float = float(p["global_scale"])
	var min_time: float = float(p["min_time"])
	var approx: float = BASE_TIME_PER_LEVEL * mult * preset_scale * _level_type_scale(level_type, level)
	var avg_surplus = _avg_surplus()
	if avg_surplus > 0.0:
		var target = _target_surplus_sec(level)
		var over: float = max(avg_surplus - target, 0.0)
		var cut: float = clamp(over * 0.5, 0.0, 0.4 * approx)
		approx = max(approx - cut, min_time)
	return max(approx, min_time)

func _level_type_scale(level_type: int, level: int) -> float:
	var profile = _get_type_profile(level_type)
	var start: float = float(profile.get("scale_start", 1.0))
	var endv: float = float(profile.get("scale_end", start))
	var t = clamp((float(level) - 1.0) / 8.0, 0.0, 1.0)
	return lerp(start, endv, t)

func _get_type_profile(level_type: int) -> Dictionary:
	if LEVEL_TYPE_TUNING.has(level_type):
		return LEVEL_TYPE_TUNING[level_type]
	return {
		"scale_start": 1.0,
		"scale_end": 1.0,
		"buffer_bias": 0.0,
		"flat_bonus": 0.0
	}

func _maze_overhead(level_type: int, maze_path_length: float, player_start: Vector2, exit_pos: Vector2, speed: float) -> Dictionary:
	var is_maze = level_type == GameState.LevelType.MAZE or level_type == GameState.LevelType.MAZE_COINS or level_type == GameState.LevelType.MAZE_KEYS
	if not is_maze:
		return {"factor": 1.0, "slack": 0.0, "base_path": 0.0}
	var straight: float = player_start.distance_to(exit_pos)
	var profile = _get_type_profile(level_type)
	var fallback_factor: float = float(profile.get("maze_fallback_factor", 1.35))
	var base_path: float = 0.0
	if straight > 0.0:
		base_path = straight * fallback_factor
	if maze_path_length > 0.0:
		var floor_scale: float = float(profile.get("maze_path_floor", 1.0))
		base_path = max(maze_path_length, straight * floor_scale)
		var ratio = clamp(maze_path_length / max(straight, 1.0), 1.0, 4.5)
		var base_scale: float = float(profile.get("maze_base_scale", 0.6))
		var factor = 1.0 + (ratio - 1.0) * base_scale
		var ratio_span: float = max(float(profile.get("maze_ratio_span", 2.5)), 0.5)
		var ratio_t = clamp((ratio - 1.0) / ratio_span, 0.0, 1.0)
		var slack_curve: Vector2 = profile.get("maze_slack_curve", Vector2.ZERO)
		var slack = 0.0
		if slack_curve != Vector2.ZERO:
			slack += lerp(slack_curve.x, slack_curve.y, ratio_t)
		var path_scale: float = float(profile.get("maze_path_scale", 0.8))
		var path_cap: float = float(profile.get("maze_path_cap", 8.0))
		var path_bonus = clamp((maze_path_length - straight) / max(speed, 1.0), 0.0, path_cap)
		slack += path_bonus * path_scale
		return {"factor": factor, "slack": slack, "base_path": base_path}
	var fallback_slack: float = float(profile.get("maze_fallback_slack", 5.0))
	return {"factor": fallback_factor, "slack": fallback_slack, "base_path": base_path}
