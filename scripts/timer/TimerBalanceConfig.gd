class_name TimerBalanceConfig
extends RefCounted

const GAME_STATE := preload("res://scripts/GameState.gd")

const DEFAULT_PROFILE := {
	"scale_start": 1.0,
	"scale_end": 1.0,
	"buffer_bias": 0.0,
	"flat_bonus": 0.0
}

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
	GAME_STATE.LevelType.OBSTACLES_COINS: {
		"scale_start": 0.78,
		"scale_end": 0.48,
		"buffer_bias": -0.45,
		"flat_bonus": -1.8,
		"route_trim": 0.82,
		"trim_ramp": 4.0
	},
	GAME_STATE.LevelType.MAZE: {
		"scale_start": 0.95, # Reduced from 1.05
		"scale_end": 0.75, # Reduced from 0.82
		"buffer_bias": 0.05, # Reduced from 0.12
		"flat_bonus": 0.8, # Reduced from 1.6
		"maze_slack_curve": Vector2(2.5, 5.5), # Reduced from 3.5, 7.5
		"maze_path_scale": 0.45, # Reduced from 0.55
		"maze_path_cap": 5.5, # Reduced from 7.0
		"maze_base_scale": 0.42, # Reduced from 0.52
		"maze_fallback_slack": 3.0, # Reduced from 4.5
		"maze_ratio_span": 1.8, # Reduced from 2.0
		"maze_path_floor": 0.95, # Reduced from 1.05
		"maze_fallback_factor": 1.12 # Reduced from 1.18
	},
	GAME_STATE.LevelType.MAZE_COINS: {
		"scale_start": 0.98, # Reduced from 1.08
		"scale_end": 0.78, # Reduced from 0.86
		"buffer_bias": 0.08, # Reduced from 0.18
		"flat_bonus": 1.4, # Reduced from 2.2
		"maze_slack_curve": Vector2(3.0, 6.5), # Reduced from 4.0, 8.5
		"maze_path_scale": 0.50, # Reduced from 0.60
		"maze_path_cap": 6.0, # Reduced from 7.5
		"maze_base_scale": 0.48, # Reduced from 0.58
		"maze_fallback_slack": 3.5, # Reduced from 5.0
		"maze_ratio_span": 2.0, # Reduced from 2.2
		"maze_path_floor": 0.98, # Reduced from 1.08
		"maze_fallback_factor": 1.15 # Reduced from 1.22
	},
GAME_STATE.LevelType.MAZE_KEYS: {
"scale_start": 1.02, # Reduced from 1.12
"scale_end": 0.82, # Reduced from 0.90
"buffer_bias": 0.14, # Reduced from 0.24
"flat_bonus": 2.0, # Reduced from 2.8
"maze_slack_curve": Vector2(3.5, 7.5), # Reduced from 4.5, 9.5
"maze_path_scale": 0.55, # Reduced from 0.65
"maze_path_cap": 6.5, # Reduced from 8.0
"maze_base_scale": 0.52, # Reduced from 0.62
"maze_fallback_slack": 4.0, # Reduced from 5.5
"maze_ratio_span": 2.2, # Reduced from 2.4
"maze_path_floor": 1.02, # Reduced from 1.12
"maze_fallback_factor": 1.18 # Reduced from 1.28
},
GAME_STATE.LevelType.MAZE_COMPLEX: {
"scale_start": 1.05,
"scale_end": 0.85,
"buffer_bias": 0.15,
"flat_bonus": 1.6,
"maze_slack_curve": Vector2(3.4, 6.8),
"maze_path_scale": 0.52,
"maze_path_cap": 6.5,
"maze_base_scale": 0.46,
"maze_fallback_slack": 3.6,
"maze_ratio_span": 2.1,
"maze_path_floor": 1.02,
"maze_fallback_factor": 1.16
},
GAME_STATE.LevelType.MAZE_COMPLEX_COINS: {
"scale_start": 1.08,
"scale_end": 0.88,
"buffer_bias": 0.18,
"flat_bonus": 2.2,
"maze_slack_curve": Vector2(3.9, 7.4),
"maze_path_scale": 0.57,
"maze_path_cap": 7.0,
"maze_base_scale": 0.5,
"maze_fallback_slack": 4.0,
"maze_ratio_span": 2.3,
"maze_path_floor": 1.05,
"maze_fallback_factor": 1.19
},
GAME_STATE.LevelType.MAZE_COMPLEX_KEYS: {
"scale_start": 1.12,
"scale_end": 0.9,
"buffer_bias": 0.22,
"flat_bonus": 2.6,
"maze_slack_curve": Vector2(4.2, 8.2),
"maze_path_scale": 0.6,
"maze_path_cap": 7.4,
"maze_base_scale": 0.55,
"maze_fallback_slack": 4.5,
"maze_ratio_span": 2.4,
"maze_path_floor": 1.08,
"maze_fallback_factor": 1.22
},
GAME_STATE.LevelType.KEYS: {
"scale_start": 2.7, # x2.5 time multiplier
		"scale_end": 2.4, # x2.5 time multiplier
"buffer_bias": 0.15, # Increased buffer
		"flat_bonus": 3.0 # Increased flat bonus for no coins
	}
}

const BASE_TIME_PER_LEVEL := 22.0

static func has_difficulty(name: StringName) -> bool:
	return DIFFICULTY_PRESETS.has(name)

static func get_difficulty(name: StringName) -> Dictionary:
	return DIFFICULTY_PRESETS.get(name, DIFFICULTY_PRESETS["regular"])

static func get_type_profile(level_type: int) -> Dictionary:
	return LEVEL_TYPE_TUNING.get(level_type, DEFAULT_PROFILE)

static func get_default_profile() -> Dictionary:
	return DEFAULT_PROFILE.duplicate(true)
