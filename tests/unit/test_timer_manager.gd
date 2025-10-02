extends "res://tests/unit/test_utils.gd"

const TimerManager = preload("res://scripts/TimerManager.gd")
const LevelUtils = preload("res://scripts/LevelUtils.gd")
const GameState = preload("res://scripts/GameState.gd")

func get_suite_name() -> String:
	return "TimerManager"

func _new_timer() -> TimerManager:
	return TimerManager.new()

func test_level_multiplier_decays_with_levels() -> void:
	var tm: TimerManager = _new_timer()
	var level1 := tm._level_multiplier(1)
	var level5 := tm._level_multiplier(5)
	assert_true(level1 >= level5)
	tm.free()

func test_buffer_cap_reduces_with_level_progress() -> void:
	var tm: TimerManager = _new_timer()
	var early := tm._buffer_cap_sec(1)
	var later := tm._buffer_cap_sec(6)
	assert_true(early >= later)
	tm.free()

func test_route_detour_factor_increases_with_coins() -> void:
	var tm: TimerManager = _new_timer()
	var base := tm._route_detour_factor(0)
	var more := tm._route_detour_factor(10)
	assert_true(more > base)
	assert_near(base, 1.0, 0.0001)
	tm.free()

func test_register_level_result_clamps_and_limits_history() -> void:
	var tm: TimerManager = _new_timer()
	for i in range(12):
		tm.register_level_result(float(i - 2))
	assert_eq(tm._recent_surplus.size(), TimerManager.SURPLUS_WINDOW)
	assert_near(tm._recent_surplus[tm._recent_surplus.size() - 1], float(11 - 2), 0.0001)
	var tm2: TimerManager = _new_timer()
	tm2.register_level_result(-5.0)
	assert_near(tm2._recent_surplus[tm2._recent_surplus.size() - 1], 0.0, 0.0001)
	tm.free()
	tm2.free()

func test_calculate_level_time_scales_with_distance() -> void:
	var tm: TimerManager = _new_timer()
	var exit_near := LevelUtils.PLAYER_START + Vector2(20, 0)
	var exit_far := LevelUtils.PLAYER_START + Vector2(600, 0)
	var near_time = tm.calculate_level_time(1, [], exit_near)
	var far_time = tm.calculate_level_time(1, [], exit_far)
	assert_true(far_time > near_time)
	tm.free()

func test_calculate_level_time_accounts_for_coins() -> void:
	var tm: TimerManager = _new_timer()
	var coin := Node2D.new()
	coin.position = LevelUtils.PLAYER_START + Vector2(80, 0)
	var exit_pos := LevelUtils.PLAYER_START + Vector2(120, 0)
	var without_coins = tm.calculate_level_time(1, [], exit_pos)
	var with_coin = tm.calculate_level_time(1, [coin], exit_pos)
	assert_true(with_coin > without_coins)
	coin.free()
	tm.free()

func test_set_difficulty_keeps_known_and_ignores_unknown() -> void:
	var tm: TimerManager = _new_timer()
	tm.set_difficulty("child")
	var child_preset := TimerManager.DIFFICULTY_PRESETS["child"]
	assert_eq(tm._get_preset(), child_preset)
	tm.set_difficulty("impossible-mode")
	assert_eq(tm._get_preset(), child_preset)
	tm.free()

func test_level_type_scale_interpolates_and_defaults() -> void:
	var tm: TimerManager = _new_timer()
	var start_scale := tm._level_type_scale(GameState.LevelType.MAZE, 1)
	var end_scale := tm._level_type_scale(GameState.LevelType.MAZE, 9)
	assert_true(start_scale > end_scale)
	assert_near(end_scale, 0.82, 0.05)
	var unknown_scale := tm._level_type_scale(9999, 3)
	assert_near(unknown_scale, 1.0, 0.0001)
	tm.free()

func test_get_type_profile_returns_defaults_for_unknown() -> void:
	var tm: TimerManager = _new_timer()
	var profile := tm._get_type_profile(12345)
	assert_eq(profile["scale_start"], 1.0)
	assert_eq(profile["scale_end"], 1.0)
	assert_eq(profile["buffer_bias"], 0.0)
	assert_eq(profile["flat_bonus"], 0.0)
	tm.free()

func test_maze_overhead_handles_non_maze_types() -> void:
	var tm: TimerManager = _new_timer()
	var result := tm._maze_overhead(GameState.LevelType.KEYS, 0.0, Vector2.ZERO, Vector2.ZERO, 300.0)
	assert_near(result["factor"], 1.0, 0.0001)
	assert_near(result["slack"], 0.0, 0.0001)
	assert_near(result["base_path"], 0.0, 0.0001)
	tm.free()

func test_maze_overhead_uses_path_statistics() -> void:
	var tm: TimerManager = _new_timer()
	var start := Vector2.ZERO
	var exit := Vector2(100, 0)
	var info := tm._maze_overhead(GameState.LevelType.MAZE, 300.0, start, exit, 300.0)
	assert_true(info["factor"] > 1.0)
	assert_true(info["slack"] > 0.0)
	assert_near(info["base_path"], 300.0, 0.0001)
	tm.free()
func test_maze_overhead_uses_fallback_slack_when_no_path() -> void:
	var tm: TimerManager = _new_timer()
	var start := LevelUtils.PLAYER_START
	var exit := LevelUtils.PLAYER_START + Vector2(180, 45)
	var info := tm._maze_overhead(GameState.LevelType.MAZE, 0.0, start, exit, 320.0)
	var profile := tm._get_type_profile(GameState.LevelType.MAZE)
	var fallback_factor := float(profile.get("maze_fallback_factor", 1.0))
	assert_true(info["slack"] > 0.0)
	assert_near(info["factor"], fallback_factor, 0.0001)
	var straight := start.distance_to(exit)
	assert_near(info["base_path"], straight * fallback_factor, 0.0001)
	tm.free()
func test_maze_overhead_scales_with_ratio_and_path_bonus() -> void:
	var tm: TimerManager = _new_timer()
	var start := Vector2.ZERO
	var exit := Vector2(100, 0)
	var maze_length := 300.0
	var info := tm._maze_overhead(GameState.LevelType.MAZE, maze_length, start, exit, 300.0)
	var straight := start.distance_to(exit)
	var profile := tm._get_type_profile(GameState.LevelType.MAZE)
	var ratio: float = maze_length / max(straight, 1.0)
	var base_scale: float = float(profile.get("maze_base_scale", 0.0))
	var expected_factor: float = 1.0 + (ratio - 1.0) * base_scale
	assert_near(float(info["factor"]), expected_factor, 0.0001)
	var ratio_span: float = max(float(profile.get("maze_ratio_span", 1.0)), 0.0001)
	var ratio_t: float = clamp((ratio - 1.0) / ratio_span, 0.0, 1.0)
	var slack_curve: Vector2 = profile.get("maze_slack_curve", Vector2.ZERO)
	var expected_slack: float = lerp(slack_curve.x, slack_curve.y, ratio_t)
	var path_cap: float = float(profile.get("maze_path_cap", 0.0))
	var path_bonus: float = clamp((maze_length - straight) / 300.0, 0.0, path_cap)
	var path_scale: float = float(profile.get("maze_path_scale", 0.0))
	var total_expected_slack: float = expected_slack + path_bonus * path_scale
	assert_near(float(info["slack"]), total_expected_slack, 0.0001)
	assert_near(float(info["base_path"]), maze_length, 0.0001)
	tm.free()
func test_maze_overhead_enforces_path_floor_and_curve() -> void:
	var tm: TimerManager = _new_timer()
	var start := Vector2.ZERO
	var exit := Vector2(200, 0)
	var maze_length := 150.0
	var straight := start.distance_to(exit)
	var info := tm._maze_overhead(GameState.LevelType.MAZE, maze_length, start, exit, 300.0)
	var profile := tm._get_type_profile(GameState.LevelType.MAZE)
	var floor_scale := float(profile.get("maze_path_floor", 1.0))
	assert_near(float(info["base_path"]), straight * floor_scale, 0.0001)
	assert_near(float(info["factor"]), 1.0, 0.0001)
	var slack_curve: Vector2 = profile.get("maze_slack_curve", Vector2.ZERO)
	assert_near(float(info["slack"]), slack_curve.x, 0.0001)
	tm.free()
func test_calculate_level_time_extends_minimum_for_pickups() -> void:
	var tm: TimerManager = _new_timer()
	var coin := Node2D.new()
	coin.position = LevelUtils.PLAYER_START
	var exit_pos := LevelUtils.PLAYER_START
	var time := tm.calculate_level_time(1, [coin], exit_pos)
	assert_true(time > float(tm._get_preset()["min_time"]))
	coin.free()
	tm.free()

func test_get_time_for_level_reacts_to_surplus_history() -> void:
	var tm: TimerManager = _new_timer()
	var baseline := tm.get_time_for_level(3)
	for i in range(TimerManager.SURPLUS_WINDOW):
		tm.register_level_result(30.0)
	var adjusted := tm.get_time_for_level(3)
	var min_time := float(tm._get_preset()["min_time"])
	assert_true(adjusted <= baseline)
	assert_true(adjusted >= min_time)
	tm.free()

func test_calculate_level_time_grows_with_maze_path_length() -> void:
	var tm: TimerManager = _new_timer()
	var exit := LevelUtils.PLAYER_START + Vector2(280, 0)
	var short_time := tm.calculate_level_time(2, [], exit, LevelUtils.PLAYER_START, GameState.LevelType.MAZE, 0.0)
	var long_time := tm.calculate_level_time(2, [], exit, LevelUtils.PLAYER_START, GameState.LevelType.MAZE, 1100.0)
	assert_true(long_time > short_time)
	tm.free()
