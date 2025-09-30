extends "res://tests/unit/test_utils.gd"

const TimerManager = preload("res://scripts/TimerManager.gd")
const LevelUtils = preload("res://scripts/LevelUtils.gd")

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
