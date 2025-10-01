class_name LevelGenerator
extends Node2D

const Logger = preload("res://scripts/Logger.gd")
const MazeGenerator = preload("res://scripts/level_generators/MazeGenerator.gd")
const LevelUtils = preload("res://scripts/LevelUtils.gd")
const GameState = preload("res://scripts/GameState.gd")
const ObstacleUtilities = preload("res://scripts/level_generators/ObstacleUtilities.gd")
const KeyLevelGenerator = preload("res://scripts/level_generators/KeyLevelGenerator.gd")

const DOOR_GROUP_COLORS := [
	Color(0.95, 0.49, 0.38, 1.0),
	Color(0.41, 0.68, 0.95, 1.0),
	Color(0.55, 0.83, 0.42, 1.0),
	Color(0.95, 0.75, 0.35, 1.0),
	Color(0.74, 0.56, 0.95, 1.0),
	Color(0.37, 0.82, 0.74, 1.0)
]

const MAZE_BASE_CELL_SIZE := 64.0
const MAZE_WALL_SIZE_RATIO := 0.18

var obstacles: Array = []
var coins: Array[Area2D] = []
var exit_pos: Vector2 = Vector2.ZERO
var current_level_size: float = 1.0

var doors: Array = []
var key_items: Array[Area2D] = []
var maze_walls: Array = []
var key_barriers: Array = []
var player_spawn_override: Vector2 = Vector2.ZERO
var has_player_spawn_override: bool = false
var last_maze_path_length: float = 0.0

@onready var obstacle_spawner = $ObstacleSpawner
@onready var coin_spawner = $CoinSpawner
@onready var exit_spawner = $ExitSpawner

var maze_generator
var key_level_generator
var obstacle_utils

func _ready():
	_ensure_helpers()

func _ensure_helpers() -> void:
	if obstacle_utils == null:
		obstacle_utils = ObstacleUtilities.new(self)
	if maze_generator == null:
		maze_generator = MazeGenerator.new(self, obstacle_utils)
	if key_level_generator == null:
		key_level_generator = KeyLevelGenerator.new(self, obstacle_utils)

func generate_level(level_size := 1.0, generate_obstacles := true, generate_coins := true, min_exit_distance_ratio := 0.4, use_full_map_coverage := true, main_scene: Node = null, level := 1, preserved_coin_count := 0, player_start_position: Vector2 = LevelUtils.PLAYER_START, level_type: int = GameState.LevelType.OBSTACLES_COINS):
	Logger.log_generation("LevelGenerator starting (size %.2f, type %d)" % [level_size, level_type])
	current_level_size = level_size
	exit_pos = Vector2.ZERO
	last_maze_path_length = 0.0
	_ensure_helpers()
	clear_existing_objects()
	match level_type:
		GameState.LevelType.KEYS:
			key_level_generator.generate(main_scene, level, player_start_position)
		GameState.LevelType.MAZE:
			maze_generator.generate_maze_level(false, main_scene, player_start_position)
		GameState.LevelType.MAZE_COINS:
			maze_generator.generate_maze_level(true, main_scene, player_start_position)
		GameState.LevelType.MAZE_KEYS:
			maze_generator.generate_maze_keys_level(main_scene, level, player_start_position)
		_:
			_generate_standard_level(level_size, generate_obstacles, generate_coins, min_exit_distance_ratio, use_full_map_coverage, main_scene, level, preserved_coin_count, player_start_position)
	return 0

func _generate_standard_level(level_size: float, generate_obstacles: bool, generate_coins_flag: bool, min_exit_distance_ratio: float, use_full_map_coverage: bool, main_scene, level: int, preserved_coin_count: int, player_start_position: Vector2) -> void:
	if generate_obstacles:
		if obstacle_spawner and is_instance_valid(obstacle_spawner):
			obstacles = obstacle_spawner.generate_obstacles(level_size, use_full_map_coverage, main_scene, level)
			Logger.log_generation("LevelGenerator received %d obstacles" % obstacles.size())
		else:
			Logger.log_error("ObstacleSpawner unavailable; recreating instance")
			obstacle_spawner = preload("res://scripts/ObstacleSpawner.gd").new()
			obstacle_spawner.name = "ObstacleSpawner"
			add_child(obstacle_spawner)
			obstacles = obstacle_spawner.generate_obstacles(level_size, use_full_map_coverage, main_scene, level)
	else:
		Logger.log_generation("Obstacle generation disabled for this level")

	if exit_spawner and is_instance_valid(exit_spawner):
		var exit_node = exit_spawner.generate_exit(level_size, obstacles, min_exit_distance_ratio, main_scene)
		if exit_node:
			exit_pos = exit_node.position
		else:
			Logger.log_error("ExitSpawner failed to create exit")
	else:
		Logger.log_error("ExitSpawner reference missing")

	if generate_coins_flag:
		if coin_spawner and is_instance_valid(coin_spawner):
			coins = coin_spawner.generate_coins(level_size, obstacles, exit_pos, player_start_position, use_full_map_coverage, main_scene, level, preserved_coin_count)
			Logger.log_generation("LevelGenerator received %d coins" % coins.size())
		else:
			Logger.log_error("CoinSpawner unavailable; recreating instance")
			coin_spawner = preload("res://scripts/CoinSpawner.gd").new()
			coin_spawner.name = "CoinSpawner"
			add_child(coin_spawner)
			coins = coin_spawner.generate_coins(level_size, obstacles, exit_pos, player_start_position, use_full_map_coverage, main_scene, level, preserved_coin_count)
	else:
		Logger.log_generation("Coin generation disabled for this level")

func get_generated_coins():
	return coins

func get_generated_keys():
	return key_items

func get_generated_exit():
	if exit_spawner:
		return exit_spawner.get_exit()
	return null

func get_player_spawn_override():
	if has_player_spawn_override:
		return player_spawn_override
	return null

func get_last_maze_path_length() -> float:
	return last_maze_path_length

func is_exit_position_valid(pos, level_width, level_height):
	var margin = 32
	return pos.x >= margin and pos.x <= level_width - margin and pos.y >= margin and pos.y <= level_height - margin

func clear_existing_objects():
	for node in doors:
		if is_instance_valid(node):
			node.queue_free()
	doors.clear()
	for node in key_barriers:
		if is_instance_valid(node):
			node.queue_free()
	key_barriers.clear()
	for node in key_items:
		if is_instance_valid(node):
			node.queue_free()
	key_items.clear()
	for node in maze_walls:
		if is_instance_valid(node):
			node.queue_free()
	maze_walls.clear()

	if obstacle_spawner and is_instance_valid(obstacle_spawner):
		obstacle_spawner.clear_obstacles()
	if coin_spawner and is_instance_valid(coin_spawner):
		coin_spawner.clear_coins()
	if exit_spawner and is_instance_valid(exit_spawner):
		exit_spawner.clear_exit()

	for obstacle in obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	obstacles.clear()
	for coin in coins:
		if is_instance_valid(coin):
			coin.queue_free()
	coins.clear()
	exit_pos = Vector2.ZERO
	has_player_spawn_override = false
	player_spawn_override = Vector2.ZERO

func set_player_spawn_override(pos: Vector2) -> void:
	has_player_spawn_override = true
	player_spawn_override = pos

func add_generated_node(node: Node, main_scene) -> void:
	if node == null:
		return
	if main_scene:
		main_scene.call_deferred("add_child", node)
	else:
		call_deferred("add_child", node)

func get_group_color(index: int) -> Color:
	if DOOR_GROUP_COLORS.is_empty():
		return Color(0.9, 0.9, 0.2, 1.0)
	return DOOR_GROUP_COLORS[index % DOOR_GROUP_COLORS.size()]
