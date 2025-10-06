extends RefCounted

class_name KeyLevelGenerator

const LOGGER := preload("res://scripts/Logger.gd")
const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")
const KEY_PLACEMENT := preload("res://scripts/level_generators/key/KeyPlacementUtils.gd")
const KEY_RING_LAYOUT := preload("res://scripts/level_generators/key/KeyRingLayoutPlanner.gd")
const KEY_RING_BARRIERS := preload("res://scripts/level_generators/key/KeyRingBarrierBuilder.gd")
const KEY_RING_DOORS := preload("res://scripts/level_generators/key/KeyRingDoorSpawner.gd")

var context
var obstacle_utils
var _layout_planner
var _barrier_builder
var _door_spawner

func _init(level_context, obstacle_helper):
	context = level_context
	obstacle_utils = obstacle_helper
	_layout_planner = KEY_RING_LAYOUT.new(context)
	_barrier_builder = KEY_RING_BARRIERS.new(context)
	_door_spawner = KEY_RING_DOORS.new(context, obstacle_utils)

func generate(main_scene, level: int, player_start_position: Vector2) -> void:
	var dims = LEVEL_UTILS.get_scaled_level_dimensions(context.current_level_size)
	var level_width: float = float(dims.width)
	var level_height: float = float(dims.height)
	var offset = Vector2(dims.offset_x, dims.offset_y)
	var layout = _layout_planner.create_layout(offset, level_width, level_height, level)
	var rings: Array = layout.get("rings", [])
	if rings.is_empty():
		_generate_legacy_key_level(main_scene, level, player_start_position, offset, level_width, level_height)
		return
	context.exit_spawner.clear_exit()
	context.coins.clear()
	var spawn_override: Vector2 = layout.get("spawn", Vector2(offset.x + 90.0, offset.y + level_height * 0.5))
	_generate_key_level_obstacles(context.current_level_size, main_scene, level, rings, spawn_override)
	var exit_position: Vector2 = layout.get("exit", Vector2(offset.x + level_width - 160.0, offset.y + level_height * 0.5))
	_barrier_builder.spawn(rings, main_scene)
	_door_spawner.spawn(rings, main_scene)
	context.exit_spawner.create_exit_at(exit_position, main_scene)
	var exit_node = context.exit_spawner.get_exit()
	if exit_node:
		context.exit_pos = exit_node.position
	obstacle_utils.clear_around_position(context.exit_pos, 110.0)
	context.set_player_spawn_override(spawn_override)

func _generate_key_level_obstacles(level_size: float, _main_scene, level: int, rings: Array, spawn_override: Vector2) -> void:
	if context.obstacle_spawner == null or not is_instance_valid(context.obstacle_spawner):
		LOGGER.log_error("ObstacleSpawner unavailable for key level")
		return
	context.obstacles = context.obstacle_spawner.generate_obstacles(level_size, true, _main_scene, level)
	if context.obstacles.is_empty():
		return
	var clearance_rects: Array = _layout_planner.build_clearance_rects(rings)
	if not clearance_rects.is_empty():
		obstacle_utils.clear_in_rects(clearance_rects)
	if spawn_override != Vector2.ZERO:
		obstacle_utils.clear_around_position(spawn_override, 140.0)

func _generate_legacy_key_level(main_scene, level: int, player_start_position: Vector2, offset: Vector2, level_width: float, level_height: float) -> void:
	var spawn_y = clamp(player_start_position.y, offset.y + 90.0, offset.y + level_height - 90.0)
	var spawn_override = Vector2(offset.x + 90.0, spawn_y)
	_generate_key_level_obstacles(context.current_level_size, main_scene, level, [], spawn_override)
	context.exit_spawner.clear_exit()
	context.coins.clear()
	var fallback_points := KEY_PLACEMENT.sample_far_points(3, offset, level_width, level_height, 220.0)
	for point in fallback_points:
		var door = LEVEL_NODE_FACTORY.create_door_node(context.doors.size(), 0, true, 140.0, 48.0, context.get_group_color(context.doors.size()))
		door.position = Vector2(point.x - 24.0, point.y - 70.0)
		context.doors.append(door)
		context.add_generated_node(door, main_scene)
	var exit_position = Vector2(offset.x + level_width - 140.0, offset.y + level_height * 0.5)
	context.exit_spawner.create_exit_at(exit_position, main_scene)
	var exit_node = context.exit_spawner.get_exit()
	if exit_node:
		context.exit_pos = exit_node.position
	obstacle_utils.clear_around_position(context.exit_pos, 110.0)
	context.set_player_spawn_override(spawn_override)
