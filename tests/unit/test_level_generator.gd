extends "res://tests/unit/test_utils.gd"

const LevelGenerator = preload("res://scripts/LevelGenerator.gd")
const GameState = preload("res://scripts/GameState.gd")

class DispatchLevelGenerator extends LevelGenerator:
	var standard_called := false

	func _ensure_helpers() -> void:
		pass

	func _generate_standard_level(level_size: float, generate_obstacles: bool, generate_coins_flag: bool, min_exit_distance_ratio: float, use_full_map_coverage: bool, main_scene, level: int, preserved_coin_count: int, player_start_position: Vector2) -> void:
		standard_called = true

class MazeGeneratorStub extends RefCounted:
	var last_include_coins := false
	var last_scene: Variant = null
	var last_spawn := Vector2.ZERO
	var keys_call_count := 0
	var last_key_level := 0

	func generate_maze_level(include_coins: bool, main_scene, player_start_position: Vector2) -> void:
		last_include_coins = include_coins
		last_scene = main_scene
		last_spawn = player_start_position

	func generate_maze_keys_level(main_scene, level: int, player_start_position: Vector2) -> void:
		keys_call_count += 1
		last_scene = main_scene
		last_key_level = level
		last_spawn = player_start_position

class KeyGeneratorStub extends RefCounted:
	var call_count := 0
	var last_scene: Variant = null
	var last_level := 0
	var last_spawn := Vector2.ZERO

	func generate(main_scene, level: int, player_start_position: Vector2) -> void:
		call_count += 1
		last_scene = main_scene
		last_level = level
		last_spawn = player_start_position

class DummyObstacleSpawner extends Node:
	var cleared := false

	func clear_obstacles() -> void:
		cleared = true

class DummyCoinSpawner extends Node:
	var cleared := false

	func clear_coins() -> void:
		cleared = true

class DummyExitSpawner extends Node:
	var cleared := false

	func clear_exit() -> void:
		cleared = true

func get_suite_name() -> String:
	return "LevelGenerator"

func _dispatch_generate(generator: LevelGenerator, level: int, spawn: Vector2, level_type: int) -> void:
	generator.generate_level(1.0, true, true, 0.4, true, null, level, 0, spawn, level_type)

func test_generate_level_dispatches_to_branch_generators() -> void:
	var generator := DispatchLevelGenerator.new()
	var key_stub := KeyGeneratorStub.new()
	var maze_stub := MazeGeneratorStub.new()
	generator.key_level_generator = key_stub
	generator.maze_generator = maze_stub

	_dispatch_generate(generator, 1, Vector2.ZERO, GameState.LevelType.OBSTACLES_COINS)
	assert_true(generator.standard_called)

	generator.standard_called = false
	_dispatch_generate(generator, 3, Vector2(10, 12), GameState.LevelType.KEYS)
	assert_eq(key_stub.call_count, 1)
	assert_eq(key_stub.last_level, 3)
	assert_vector_near(key_stub.last_spawn, Vector2(10, 12), 0.0001)
	assert_false(generator.standard_called)

	_dispatch_generate(generator, 1, Vector2(42, 24), GameState.LevelType.MAZE)
	assert_eq(maze_stub.last_include_coins, false)
	assert_vector_near(maze_stub.last_spawn, Vector2(42, 24), 0.0001)

	_dispatch_generate(generator, 1, Vector2(42, 24), GameState.LevelType.MAZE_COINS)
	assert_eq(maze_stub.last_include_coins, true)

	_dispatch_generate(generator, 5, Vector2.ZERO, GameState.LevelType.MAZE_KEYS)
	assert_eq(maze_stub.keys_call_count, 1)
	assert_eq(maze_stub.last_key_level, 5)

func test_clear_existing_objects_resets_state_and_notifies_spawners() -> void:
	var generator := LevelGenerator.new()
	generator.obstacles = [Node2D.new()]
	generator.coins = [Area2D.new()]
	generator.doors = [Node2D.new()]
	generator.key_barriers = [Node2D.new()]
	generator.key_items = [Area2D.new()]
	generator.maze_walls = [Node2D.new()]
	generator.exit_pos = Vector2(120, 75)
	generator.has_player_spawn_override = true
	generator.player_spawn_override = Vector2(8, 9)

	var obstacle_spawner := DummyObstacleSpawner.new()
	var coin_spawner := DummyCoinSpawner.new()
	var exit_spawner := DummyExitSpawner.new()
	generator.obstacle_spawner = obstacle_spawner
	generator.coin_spawner = coin_spawner
	generator.exit_spawner = exit_spawner

	generator.clear_existing_objects()

	assert_true(generator.obstacles.is_empty())
	assert_true(generator.coins.is_empty())
	assert_true(generator.doors.is_empty())
	assert_true(generator.key_barriers.is_empty())
	assert_true(generator.key_items.is_empty())
	assert_true(generator.maze_walls.is_empty())
	assert_vector_near(generator.exit_pos, Vector2.ZERO, 0.0001)
	assert_false(generator.has_player_spawn_override)
	assert_vector_near(generator.player_spawn_override, Vector2.ZERO, 0.0001)
	assert_true(obstacle_spawner.cleared)
	assert_true(coin_spawner.cleared)
	assert_true(exit_spawner.cleared)

func test_get_group_color_cycles_palette() -> void:
	var generator := LevelGenerator.new()
	var colors := []
	for i in range(8):
		colors.append(generator.get_group_color(i))
	assert_eq(colors[0], colors[6 % LevelGenerator.DOOR_GROUP_COLORS.size()])
	assert_eq(colors[1], colors[7 % LevelGenerator.DOOR_GROUP_COLORS.size()])

func test_is_exit_position_valid_enforces_margin() -> void:
	var generator := LevelGenerator.new()
	var width := 400
	var height := 320
	assert_true(generator.is_exit_position_valid(Vector2(32, 32), width, height))
	assert_false(generator.is_exit_position_valid(Vector2(20, 60), width, height))
	assert_false(generator.is_exit_position_valid(Vector2(width - 16, 100), width, height))
