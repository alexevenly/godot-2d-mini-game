extends SceneTree

var _failures: Array = []
var _current_failures: Array = []
var _test_count: int = 0

func _init():
        randomize()
        _run_test("GameState reset_to_start resets progression", Callable(self, "_test_game_state_reset"))
        _run_test("GameState advance_level increments correctly", Callable(self, "_test_game_state_advance"))
        _run_test("GameState advance_level caps at level seven", Callable(self, "_test_game_state_completion"))
        _run_test("GameState set_level_type updates selection", Callable(self, "_test_game_state_level_type"))
        _run_test("TimerManager returns minimum time floor", Callable(self, "_test_timer_manager_min_time"))
        _run_test("TimerManager reacts to distance and pickups", Callable(self, "_test_timer_manager_scaling"))
        _run_test("TimerManager surplus feedback reduces planned time", Callable(self, "_test_timer_manager_surplus_feedback"))
        _run_test("LevelUtils scales dimensions around base level", Callable(self, "_test_level_utils_dimensions"))
        _run_test("LevelUtils grid positions stay within bounds", Callable(self, "_test_level_utils_grid_bounds"))

        if _failures.is_empty():
                print("\nAll %d tests passed" % _test_count)
                quit()
        else:
                print("\n%d tests failed" % _failures.size())
                for failure in _failures:
                        print(" - %s" % failure.name)
                        for message in failure.messages:
                                print("    %s" % message)
                quit(1)

func _run_test(name: String, callable: Callable) -> void:
        _current_failures = []
        _test_count += 1
        callable.call()
        if _current_failures.is_empty():
                        print("[PASS] %s" % name)
        else:
                        print("[FAIL] %s" % name)
                        _failures.append({"name": name, "messages": _current_failures.duplicate()})

func _expect(condition: bool, message: String) -> void:
        if not condition:
                _current_failures.append(message)

func _test_game_state_reset() -> void:
        var game_state := GameState.new()
        game_state._ready()
        game_state.current_level = 4
        game_state.victories = 2
        game_state.current_state = GameState.GameStateType.WON
        game_state.current_level_size = 1.2

        game_state.reset_to_start()

        _expect(game_state.current_level == 1, "Level should reset to 1")
        _expect(game_state.victories == 0, "Victories should reset to 0")
        _expect(game_state.current_state == GameState.GameStateType.PLAYING, "State should reset to PLAYING")
        _expect(is_equal_approx(game_state.current_level_size, 0.75), "Level size should reset to base scale")

func _test_game_state_advance() -> void:
        var game_state := GameState.new()
        game_state._ready()
        var previous_size := game_state.current_level_size

        var completed_all := game_state.advance_level()

        _expect(not completed_all, "Early levels should not report completion")
        _expect(game_state.current_level == 2, "Level should advance to 2")
        _expect(game_state.victories == 1, "Victories should increment")
        _expect(game_state.current_level_size > previous_size, "Level size should increase")

func _test_game_state_completion() -> void:
        var game_state := GameState.new()
        game_state._ready()
        game_state.current_level = 7
        game_state.victories = 6

        var completed_all := game_state.advance_level()

        _expect(completed_all, "Advancing past level seven should report completion")
        _expect(game_state.current_level == 1, "Level should wrap to 1 after completion")
        _expect(game_state.victories == 0, "Victories should reset after completion")
        _expect(game_state.current_state == GameState.GameStateType.PLAYING, "State should reset to PLAYING")

func _test_game_state_level_type() -> void:
        var game_state := GameState.new()
        game_state._ready()
        game_state.set_level_type(GameState.LevelType.MAZE)

        _expect(game_state.selected_level_type == GameState.LevelType.MAZE, "Selected level type should match request")
        _expect(game_state.get_current_level_type() == GameState.LevelType.MAZE, "Current level type should follow selection")

        game_state.set_level_type(GameState.LevelType.RANDOM)
        _expect(game_state.get_current_level_type() != GameState.LevelType.RANDOM,
                "Random level type selection should resolve to a concrete type")

func _make_coin(position: Vector2) -> Node2D:
        var coin := Node2D.new()
        coin.position = position
        return coin

func _test_timer_manager_min_time() -> void:
        var manager := TimerManager.new()
        manager.set_difficulty("regular")
        var exit_pos := LevelUtils.PLAYER_START
        var time := manager.calculate_level_time(1, [], exit_pos)

        _expect(is_equal_approx(time, 12.0), "When no distance is covered the minimum time should apply")

func _test_timer_manager_scaling() -> void:
        var manager := TimerManager.new()
        manager.set_difficulty("regular")
        var exit_far := Vector2(LevelUtils.PLAYER_START.x + 5000, LevelUtils.PLAYER_START.y)
        var base_time := manager.calculate_level_time(1, [], exit_far)

        var coins := [
                _make_coin(Vector2(LevelUtils.PLAYER_START.x + 1000, LevelUtils.PLAYER_START.y)),
                _make_coin(Vector2(LevelUtils.PLAYER_START.x + 2000, LevelUtils.PLAYER_START.y))
        ]
        var with_coins := manager.calculate_level_time(1, coins, exit_far)

        _expect(base_time > 12.0, "Large travel distance should exceed minimum time")
        _expect(with_coins >= base_time, "Collecting coins should not reduce planned time")

func _test_timer_manager_surplus_feedback() -> void:
        var manager := TimerManager.new()
        manager.set_difficulty("regular")
        var exit_far := Vector2(LevelUtils.PLAYER_START.x + 5000, LevelUtils.PLAYER_START.y)
        var baseline := manager.calculate_level_time(1, [], exit_far)

        for i in range(8):
                manager.register_level_result(40.0)

        var adjusted := manager.calculate_level_time(1, [], exit_far)

        _expect(adjusted <= baseline, "Surplus history should reduce planned time when consistently high")
        _expect(adjusted >= 12.0, "Adjusted time should respect the minimum bound")

func _test_level_utils_dimensions() -> void:
        var full := LevelUtils.get_scaled_level_dimensions(1.0)
        _expect(full.width == LevelUtils.BASE_LEVEL_WIDTH, "Full scale width should match base width")
        _expect(full.height == LevelUtils.BASE_LEVEL_HEIGHT, "Full scale height should match base height")
        _expect(is_equal_approx(full.offset_x, 0.0), "Full scale should have zero horizontal offset")
        _expect(is_equal_approx(full.offset_y, 0.0), "Full scale should have zero vertical offset")

        var half := LevelUtils.get_scaled_level_dimensions(0.5)
        _expect(half.width == int(LevelUtils.BASE_LEVEL_WIDTH * 0.5), "Half scale width should halve the base width")
        _expect(half.height == int(LevelUtils.BASE_LEVEL_HEIGHT * 0.5), "Half scale height should halve the base height")
        _expect(is_equal_approx(half.offset_x, (LevelUtils.BASE_LEVEL_WIDTH - half.width) / 2.0),
                "Half scale offset should center the play area horizontally")
        _expect(is_equal_approx(half.offset_y, (LevelUtils.BASE_LEVEL_HEIGHT - half.height) / 2.0),
                "Half scale offset should center the play area vertically")

func _test_level_utils_grid_bounds() -> void:
        var level_size := 0.8
        var grid_cols := 4
        var grid_rows := 3
        var margin := 50
        var random_offset := 10
        for i in range(10):
                var pos := LevelUtils.get_grid_position(level_size, grid_cols, grid_rows, margin, random_offset)
                var dims := LevelUtils.get_scaled_level_dimensions(level_size)
                var min_x := margin + dims.offset_x
                var max_x := dims.width - margin + dims.offset_x
                var min_y := margin + dims.offset_y
                var max_y := dims.height - margin + dims.offset_y
                _expect(pos.x >= min_x and pos.x <= max_x, "Grid position should respect horizontal bounds")
                _expect(pos.y >= min_y and pos.y <= max_y, "Grid position should respect vertical bounds")
