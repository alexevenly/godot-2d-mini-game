class_name LevelGenerator
extends Node2D

const LOGGER := preload("res://scripts/Logger.gd")
const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const GAME_STATE := preload("res://scripts/GameState.gd")
const OBSTACLE_UTILITIES := preload("res://scripts/level_generators/ObstacleUtilities.gd")
const KEY_LEVEL_GENERATOR := preload("res://scripts/level_generators/KeyLevelGenerator.gd")
const MAZE_GENERATOR := preload("res://scripts/level_generators/MazeGenerator.gd")
const COMPLEX_MAZE_GENERATOR := preload("res://scripts/level_generators/ComplexMazeGenerator.gd")

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
var maze_shadows: Array = []
var key_barriers: Array = []
var player_spawn_override: Vector2 = Vector2.ZERO
var has_player_spawn_override: bool = false
var last_maze_path_length: float = 0.0
var complex_maze_exit: Node = null

# Optional overrides for maze rendering parameters (per-mode)
var _maze_cell_size_override: float = -1.0
var _maze_wall_ratio_override: float = -1.0
var _maze_full_cover_override: bool = false

func get_maze_cell_size() -> float:
	return _maze_cell_size_override if _maze_cell_size_override > 0.0 else MAZE_BASE_CELL_SIZE

func get_maze_wall_size_ratio() -> float:
	return _maze_wall_ratio_override if _maze_wall_ratio_override > 0.0 else MAZE_WALL_SIZE_RATIO

func is_maze_full_cover() -> bool:
	return _maze_full_cover_override

@onready var obstacle_spawner = $ObstacleSpawner
@onready var coin_spawner = $CoinSpawner
@onready var exit_spawner = $ExitSpawner

var maze_generator
var key_level_generator
var obstacle_utils
var complex_maze_generator

func _ready():
	_ensure_helpers()

func _ensure_helpers() -> void:
	if obstacle_utils == null:
		obstacle_utils = OBSTACLE_UTILITIES.new(self)
	if maze_generator == null:
		maze_generator = MAZE_GENERATOR.new(self, obstacle_utils)
	if key_level_generator == null:
			key_level_generator = KEY_LEVEL_GENERATOR.new()
			add_child(key_level_generator)
	if complex_maze_generator == null:
		complex_maze_generator = COMPLEX_MAZE_GENERATOR.new(self)

func generate_level(level_size := 1.0, generate_obstacles := true, generate_coins := true, min_exit_distance_ratio := 0.4, use_full_map_coverage := true, main_scene: Node = null, level := 1, preserved_coin_count := 0, player_start_position: Vector2 = LEVEL_UTILS.PLAYER_START, level_type: int = GAME_STATE.LevelType.OBSTACLES_COINS):
	LOGGER.log_generation("LevelGenerator starting (size %.2f, type %d)" % [level_size, level_type])
	current_level_size = level_size
	exit_pos = Vector2.ZERO
	last_maze_path_length = 0.0
	_ensure_helpers()
	clear_existing_objects()
	match level_type:
		GAME_STATE.LevelType.KEYS:
			_generate_keys_level(main_scene, level, player_start_position)
		GAME_STATE.LevelType.MAZE:
			maze_generator.generate_maze_level(false, main_scene, player_start_position)
			_clear_non_maze_obstacles(main_scene)
		GAME_STATE.LevelType.MAZE_COINS:
			maze_generator.generate_maze_level(true, main_scene, player_start_position)
			_clear_non_maze_obstacles(main_scene)
		GAME_STATE.LevelType.MAZE_KEYS:
			maze_generator.generate_maze_keys_level(main_scene, level, player_start_position)
			_clear_non_maze_obstacles(main_scene)
		GAME_STATE.LevelType.MAZE_COMPLEX:
			complex_maze_generator.generate_complex_maze(false, false, main_scene, level, player_start_position)
			_clear_non_maze_obstacles(main_scene)
		GAME_STATE.LevelType.MAZE_COMPLEX_COINS:
			complex_maze_generator.generate_complex_maze(true, false, main_scene, level, player_start_position)
			_clear_non_maze_obstacles(main_scene)
		_:
			_generate_standard_level(level_size, generate_obstacles, generate_coins, min_exit_distance_ratio, use_full_map_coverage, main_scene, level, preserved_coin_count, player_start_position)
	return 0

func _generate_keys_level(main_scene, level: int, player_start_position: Vector2) -> void:
	if key_level_generator == null:
		return
	if not (key_level_generator is Node):
		if key_level_generator.has_method("generate"):
			key_level_generator.generate(main_scene, level, player_start_position)
		return
	var dims = LEVEL_UTILS.get_scaled_level_dimensions(current_level_size)
	var generated_level = key_level_generator.generate(level)
	if generated_level == null:
		LOGGER.log_error("KeysGenerator failed to produce a layout")
		return
	var cell_width := float(dims.width) / float(generated_level.width)
	var cell_height := float(dims.height) / float(generated_level.height)
	var computed_cell: float = max(1.0, min(cell_width, cell_height))
	key_level_generator.cell_size = int(floor(computed_cell))
	if key_level_generator.cell_size <= 0:
		key_level_generator.cell_size = 1
	var origin := Vector2(
		dims.offset_x + (dims.width - float(key_level_generator.cell_size * generated_level.width)) / 2.0,
		dims.offset_y + (dims.height - float(key_level_generator.cell_size * generated_level.height)) / 2.0
	)
	key_level_generator.origin_offset = origin
	var parent_node = main_scene if main_scene else self
	key_level_generator.render(generated_level, parent_node)
	var render_data = key_level_generator.get_render_data()
	var door_bodies = render_data.get("door_bodies", [])
	doors.clear()
	for body in door_bodies:
		doors.append(body)
	var door_lines = render_data.get("door_lines", [])
	key_barriers.clear()
	for line in door_lines:
		key_barriers.append(line)
	var wall_lines = render_data.get("wall_lines", [])
	maze_walls.clear()
	for wall_line in wall_lines:
		maze_walls.append(wall_line)
	var wall_bodies = render_data.get("wall_bodies", [])
	for wall_body in wall_bodies:
		maze_walls.append(wall_body)
	var container_node = render_data.get("container", null)
	if container_node != null:
		maze_walls.append(container_node)
	var key_nodes = render_data.get("keys", [])
	key_items.clear()
	for key_node in key_nodes:
		key_items.append(key_node)
	var exit_node = render_data.get("exit", null)
	if exit_node:
		maze_walls.append(exit_node)
		exit_pos = key_level_generator.cell_to_world(generated_level.exit)
		complex_maze_exit = exit_node
	set_player_spawn_override(key_level_generator.cell_to_world(generated_level.start))

func _apply_complex_maze_overrides() -> void:
	# Higher-density maze with thinner borders (thin wall lines)
	# Ensure passages are wider than player (player collision ~32)
	# Choose cell size >= 40 and thin lines ~5% of cell
	_maze_cell_size_override = max(40.0, MAZE_BASE_CELL_SIZE * 0.625)
	_maze_wall_ratio_override = 0.05
	_maze_full_cover_override = true

func _clear_complex_maze_overrides() -> void:
	_maze_cell_size_override = -1.0
	_maze_wall_ratio_override = -1.0
	_maze_full_cover_override = false
	if exit_spawner and is_instance_valid(exit_spawner):
		exit_spawner.set_exit_size(64)

func _generate_standard_level(level_size: float, generate_obstacles: bool, generate_coins_flag: bool, min_exit_distance_ratio: float, use_full_map_coverage: bool, main_scene, level: int, preserved_coin_count: int, player_start_position: Vector2) -> void:
	if generate_obstacles:
		if obstacle_spawner and is_instance_valid(obstacle_spawner):
			obstacles = obstacle_spawner.generate_obstacles(level_size, use_full_map_coverage, main_scene, level)
			LOGGER.log_generation("LevelGenerator received %d obstacles" % obstacles.size())
		else:
			LOGGER.log_error("ObstacleSpawner unavailable; recreating instance")
			obstacle_spawner = preload("res://scripts/ObstacleSpawner.gd").new()
			obstacle_spawner.name = "ObstacleSpawner"
			add_child(obstacle_spawner)
			obstacles = obstacle_spawner.generate_obstacles(level_size, use_full_map_coverage, main_scene, level)
	else:
		LOGGER.log_generation("Obstacle generation disabled for this level")

	if exit_spawner and is_instance_valid(exit_spawner):
		var exit_node = exit_spawner.generate_exit(level_size, obstacles, min_exit_distance_ratio, main_scene)
		if exit_node:
			exit_pos = exit_node.position
		else:
			LOGGER.log_error("ExitSpawner failed to create exit")
	else:
		LOGGER.log_error("ExitSpawner reference missing")

	if generate_coins_flag:
		if coin_spawner and is_instance_valid(coin_spawner):
			coins = coin_spawner.generate_coins(level_size, obstacles, exit_pos, player_start_position, use_full_map_coverage, main_scene, level, preserved_coin_count)
			LOGGER.log_generation("LevelGenerator received %d coins" % coins.size())
		else:
			LOGGER.log_error("CoinSpawner unavailable; recreating instance")
			coin_spawner = preload("res://scripts/CoinSpawner.gd").new()
			coin_spawner.name = "CoinSpawner"
			add_child(coin_spawner)
			coins = coin_spawner.generate_coins(level_size, obstacles, exit_pos, player_start_position, use_full_map_coverage, main_scene, level, preserved_coin_count)
	else:
		LOGGER.log_generation("Coin generation disabled for this level")

func get_generated_coins():
	return coins

func get_generated_keys():
	return key_items

func get_generated_doors():
	return doors

func get_generated_exit():
	# Return complex maze exit if available, otherwise use exit spawner
	if complex_maze_exit and is_instance_valid(complex_maze_exit):
		return complex_maze_exit
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

func _queue_free_nodes(nodes: Array) -> void:
	for node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	nodes.clear()

func _clear_non_maze_obstacles(main_scene) -> void:
	if not obstacles.is_empty():
		_queue_free_nodes(obstacles)
	obstacles.clear()
	_clear_named_children(self, ["Obstacle"])
	if main_scene and main_scene is Node:
		_clear_named_children(main_scene, ["Obstacle"])

func _clear_named_children(root: Node, prefixes: Array[String]) -> void:
	if root == null:
		return
	var pending: Array = []
	for child in root.get_children():
		var node_child: Node = child
		var name: String = node_child.name
		for prefix in prefixes:
			if name.begins_with(prefix):
				pending.append(node_child)
				break
	for node in pending:
		if is_instance_valid(node):
			node.queue_free()

func _clear_spawner(spawner: Node, method_name: String) -> void:
	if spawner and is_instance_valid(spawner) and spawner.has_method(method_name):
		spawner.call(method_name)

func clear_existing_objects():
	_queue_free_nodes(doors)
	_queue_free_nodes(key_barriers)
	_queue_free_nodes(key_items)
	_queue_free_nodes(maze_walls)
	_queue_free_nodes(maze_shadows)

	_clear_spawner(obstacle_spawner, "clear_obstacles")
	_clear_spawner(coin_spawner, "clear_coins")
	_clear_spawner(exit_spawner, "clear_exit")

	_queue_free_nodes(obstacles)
	_queue_free_nodes(coins)
	exit_pos = Vector2.ZERO
	has_player_spawn_override = false
	player_spawn_override = Vector2.ZERO
	complex_maze_exit = null

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

func set_exit_reference(exit_node: Node) -> void:
	complex_maze_exit = exit_node
