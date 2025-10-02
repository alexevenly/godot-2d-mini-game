extends "res://tests/unit/test_utils.gd"

const CoinPlacementValidator = preload("res://scripts/coin/CoinPlacementValidator.gd")
const CoinNavigation = preload("res://scripts/coin/CoinNavigation.gd")
const LevelUtils = preload("res://scripts/LevelUtils.gd")

func get_suite_name() -> String:
	return "CoinSystems"

func test_coin_validator_rejects_conflicts_and_accepts_clear() -> void:
	var obstacle := _make_obstacle(Vector2(80, 80), Vector2(320, 280))
	var obstacles := [obstacle]
	var existing_coins: Array = []
	var exit_pos := Vector2(500, 320)
	var near_player := LevelUtils.PLAYER_START + Vector2(30, 0)
	assert_false(CoinPlacementValidator.is_valid_position(near_player, existing_coins, obstacles, exit_pos, 0.0))
	var near_obstacle := obstacle.position + Vector2(10, 0)
	assert_false(CoinPlacementValidator.is_valid_position(near_obstacle, existing_coins, obstacles, exit_pos, 0.0))
	var existing_coin := _make_coin(Vector2(420, 400))
	existing_coins.append(existing_coin)
	var near_coin := existing_coin.position + Vector2(20, 0)
	assert_false(CoinPlacementValidator.is_valid_position(near_coin, existing_coins, obstacles, exit_pos, 0.0))
	var near_exit := exit_pos + Vector2(10, 0)
	assert_false(CoinPlacementValidator.is_valid_position(near_exit, existing_coins, obstacles, exit_pos, 0.0))
	var clear_position := Vector2(720, 420)
	assert_true(CoinPlacementValidator.is_valid_position(clear_position, existing_coins, obstacles, exit_pos, 0.0))

func test_coin_validator_relaxation_reduces_thresholds() -> void:
	var position := LevelUtils.PLAYER_START + Vector2(50, 0)
	assert_false(CoinPlacementValidator.is_valid_position(position, [], [], Vector2.ZERO, 0.0))
	assert_true(CoinPlacementValidator.is_valid_position(position, [], [], Vector2.ZERO, 1.0))

func test_navigation_build_blocks_obstacles() -> void:
	var obstacle := _make_obstacle(Vector2(60, 60), Vector2(300, 300))
	var ctx := CoinNavigation.build_navigation_context(1.0, [obstacle], 40.0, 32.0, 1.0)
	var cell := CoinNavigation._world_to_cell(ctx, obstacle.position)
	assert_true(ctx["blocked"][cell.y][cell.x])

func test_navigation_clear_path_detects_barrier() -> void:
	var barrier := _make_obstacle(Vector2(620, 60), Vector2(520, LevelUtils.PLAYER_START.y))
	var ctx := CoinNavigation.build_navigation_context(1.0, [barrier], 40.0, 32.0, 1.0)
	var start := LevelUtils.PLAYER_START
	var goal := start + Vector2(700, 0)
	assert_false(CoinNavigation.has_clear_path(ctx, start, goal))
	var clear_ctx := CoinNavigation.build_navigation_context(1.0, [], 40.0, 32.0, 1.0)
	assert_true(CoinNavigation.has_clear_path(clear_ctx, start, goal))

func test_navigation_rejects_out_of_bounds_positions() -> void:
	var ctx := CoinNavigation.build_navigation_context(1.0, [], 40.0, 32.0, 1.0)
	var start := Vector2(-50, 0)
	var goal := LevelUtils.PLAYER_START
	assert_false(CoinNavigation.has_clear_path(ctx, start, goal))

func _make_obstacle(size: Vector2, position: Vector2) -> Node2D:
	var obstacle := Node2D.new()
	obstacle.position = position
	var body := ColorRect.new()
	body.name = "ObstacleBody"
	body.offset_right = size.x
	body.offset_bottom = size.y
	obstacle.add_child(body)
	return obstacle

func _make_coin(position: Vector2) -> Area2D:
	var coin := Area2D.new()
	coin.position = position
	return coin
