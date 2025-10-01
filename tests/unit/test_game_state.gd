extends "res://tests/unit/test_utils.gd"

const GameState = preload("res://scripts/GameState.gd")

func get_suite_name() -> String:
	return "GameState"

func _make_state() -> GameState:
	var state := GameState.new()
	state._ready()
	return state

func test_reset_to_start_restores_defaults() -> void:
	var state := _make_state()
	state.current_level = 4
	state.victories = 2
	state.current_state = GameState.GameStateType.WON
	state.current_level_size = 1.5
	state.set_level_type(GameState.LevelType.MAZE)
	state.reset_to_start()
	assert_eq(state.current_level, 1, "level")
	assert_eq(state.victories, 0, "victories")
	assert_eq(state.current_state, GameState.GameStateType.PLAYING, "state")
	assert_near(state.current_level_size, 0.75, 0.0001, "level size")
	assert_eq(state.get_level_progress_text(), "Level: 1/7")
	state.free()

func test_advance_level_increments_until_reset() -> void:
	var state := _make_state()
	for expected_level in range(2, 7):
		var finished: bool = state.advance_level()
		assert_false(finished, "advance should not finish campaign early")
		assert_eq(state.current_level, expected_level)
		assert_eq(state.victories, expected_level - 1)
	assert_near(state.current_level_size, 0.75 + (state.victories * state.level_size_increment), 0.0001)
	state.free()

func test_advance_level_wraps_after_final_stage() -> void:
	var state := _make_state()
	state.current_level = 7
	state.victories = 6
	var finished: bool = state.advance_level()
	assert_true(finished)
	assert_eq(state.current_level, 1)
	assert_eq(state.victories, 0)
	assert_near(state.current_level_size, 0.75, 0.0001)
	state.free()

func test_drop_progress_on_loss_clears_progress() -> void:
	var state := _make_state()
	state.current_level = 3
	state.victories = 2
	state.current_level_size = 1.1
	state.drop_progress_on_loss()
	assert_eq(state.current_level, 1)
	assert_eq(state.victories, 0)
	assert_near(state.current_level_size, 0.75, 0.0001)
	state.free()

func test_set_level_type_updates_current() -> void:
	var state := _make_state()
	state.set_level_type(GameState.LevelType.KEYS)
	assert_eq(state.selected_level_type, GameState.LevelType.KEYS)
	assert_eq(state.get_current_level_type(), GameState.LevelType.KEYS)
	state.free()

func test_get_next_level_size_handles_final_level() -> void:
	var state := _make_state()
	state.current_level = 7
	var next_size := state.get_next_level_size()
	assert_near(next_size, 0.75, 0.0001)
	state.free()

func test_challenge_sequence_cycles_modes() -> void:
	var state := _make_state()
	state.set_level_type(GameState.LevelType.CHALLENGE)
	assert_eq(state.selected_level_type, GameState.LevelType.CHALLENGE)
	assert_eq(state.challenge_sequence.size(), 7)
	var allowed := [GameState.LevelType.OBSTACLES_COINS, GameState.LevelType.KEYS, GameState.LevelType.MAZE, GameState.LevelType.MAZE_COINS, GameState.LevelType.MAZE_KEYS]
	for mode in state.challenge_sequence:
		assert_true(allowed.has(mode))
	var first_mode := state.get_current_level_type()
	state.advance_level()
	var next_mode := state.get_current_level_type()
	assert_true(allowed.has(first_mode))
	assert_true(allowed.has(next_mode))
	state.free()
