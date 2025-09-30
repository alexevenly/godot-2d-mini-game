extends Node2D

const Logger = preload("res://scripts/Logger.gd")
const LevelUtils = preload("res://scripts/LevelUtils.gd")
const LevelNodeFactory = preload("res://scripts/level_generators/LevelNodeFactory.gd")
const CoinNavigation = preload("res://scripts/coin/CoinNavigation.gd")
const CoinPlacementValidator = preload("res://scripts/coin/CoinPlacementValidator.gd")

const NAV_CELL_SIZE := 16.0
const PLAYER_DIAMETER := 32.0
const PATH_WIDTH_SCALE := 1.05

var coins: Array = []
var current_level_size: float = 1.0

func generate_coins(level_size: float, obstacles: Array, exit_pos: Vector2, player_start: Vector2, use_full_map_coverage: bool = true, main_scene: Node = null, level: int = 1, preserved_coin_count: int = 0) -> Array:
	Logger.log_generation("CoinSpawner: generating coins (size %.2f, level %d)" % [level_size, level])
	current_level_size = level_size
	clear_coins()

	var base_coin_count: int = randi_range(10, 25)
	var level_multiplier: float = 1.0 + (level - 1) * 0.12
	var coin_count: int = int(base_coin_count * current_level_size * level_multiplier)

	if level == 1:
		coin_count = max(6, coin_count)
	else:
		coin_count = max(preserved_coin_count + randi_range(1, 3), coin_count)

	coin_count = clamp(coin_count, 6, 40)

	Logger.log_generation("CoinSpawner target count %d (mult %.2f, preserved %d)" % [coin_count, level_multiplier, preserved_coin_count])
	if not use_full_map_coverage:
		Logger.log_generation("CoinSpawner using centered coverage grid")

	var navigation_ctx := CoinNavigation.build_navigation_context(current_level_size, obstacles, NAV_CELL_SIZE, PLAYER_DIAMETER, PATH_WIDTH_SCALE)

	var grid_cols: int = use_full_map_coverage ? 8 : 6
	var grid_rows: int = use_full_map_coverage ? 6 : 5

	var max_attempts_total: int = coin_count * 60
	var attempts_total: int = 0

	for i in range(coin_count):
		var placed := false
		var coin_attempts := 0

		while not placed and coin_attempts < 80:
			var relax: float = clamp(float(coin_attempts) / 60.0, 0.0, 1.0)

			var coin := _create_coin(grid_cols, grid_rows)
			if CoinPlacementValidator.is_valid_position(coin.position, coins, obstacles, exit_pos, relax) and CoinNavigation.has_clear_path(navigation_ctx, player_start, coin.position):
				_add_coin(coin, main_scene)
				placed = true
			else:
				coin.queue_free()
				coin_attempts += 1
				attempts_total += 1
				if attempts_total >= max_attempts_total:
					break

		if not placed:
			var coin_fallback := _create_coin(grid_cols, grid_rows)
			if CoinPlacementValidator.is_valid_position(coin_fallback.position, coins, obstacles, exit_pos, 1.0) and CoinNavigation.has_clear_path(navigation_ctx, player_start, coin_fallback.position):
				_add_coin(coin_fallback, main_scene)
			else:
				coin_fallback.queue_free()

		if attempts_total >= max_attempts_total:
			break

	Logger.log_generation("CoinSpawner placed %d coins" % coins.size())
	return coins

func clear_coins():
	for coin in coins:
		if is_instance_valid(coin):
			coin.queue_free()
	coins.clear()

func _create_coin(grid_cols: int, grid_rows: int) -> Area2D:
	var pos := LevelUtils.get_grid_position(current_level_size, grid_cols, grid_rows, 40, 30)
	var coin := LevelNodeFactory.create_coin_node(coins.size(), pos)
	coin.position = pos
	return coin

func _add_coin(coin: Area2D, main_scene) -> void:
	coins.append(coin)
	if main_scene:
		main_scene.call_deferred("add_child", coin)
	else:
		get_tree().current_scene.call_deferred("add_child", coin)
