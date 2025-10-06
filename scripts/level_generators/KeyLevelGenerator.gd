extends RefCounted

class_name KeyLevelGenerator

const LOGGER := preload("res://scripts/Logger.gd")
const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")
const KEY_PLACEMENT := preload("res://scripts/level_generators/key/KeyPlacementUtils.gd")
const KEY_RING_LAYOUT := preload("res://scripts/level_generators/key/KeyRingLayoutPlanner.gd")
const KEY_RING_BARRIERS := preload("res://scripts/level_generators/key/KeyRingBarrierBuilder.gd")
const KEY_RING_DOORS := preload("res://scripts/level_generators/key/KeyRingDoorSpawner.gd")
const KEY_RING_SETTINGS := preload("res://scripts/level_generators/key/KeyRingSettings.gd")

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
	_spawn_ring_wall_obstacles(rings, main_scene)
	var exit_position: Vector2 = layout.get("exit", Vector2(offset.x + level_width - 160.0, offset.y + level_height * 0.5))
	context.exit_pos = exit_position
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

func _spawn_ring_wall_obstacles(rings: Array, main_scene) -> void:
	var created: int = context.obstacles.size()
	for entry in rings:
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var ring: Dictionary = entry
		var door_layouts: Array = ring.get("doors", [])
		var blocked_walls: Array = []
		for layout in door_layouts:
			var wall_index: int = int(layout.get("wall", -1))
			if wall_index >= 0 and not blocked_walls.has(wall_index):
				blocked_walls.append(wall_index)
		var inner_margin: float = max(float(ring.get("inner_margin", KEY_RING_SETTINGS.WALL_THICKNESS + KEY_RING_SETTINGS.KEY_WALL_OFFSET)), 12.0)
		var wall_thickness: float = float(ring.get("wall_thickness", KEY_RING_SETTINGS.WALL_THICKNESS))
		var center: Vector2 = ring.get("center", Vector2.ZERO)
		var top: float = float(ring.get("top", center.y))
		var bottom: float = float(ring.get("bottom", center.y))
		var left: float = float(ring.get("left", center.x))
		var right: float = float(ring.get("right", center.x))
		var usable_width: float = max(float(ring.get("usable_width", 0.0)), 0.0)
		var usable_height: float = max(float(ring.get("usable_height", 0.0)), 0.0)
		if usable_width < 40.0 or usable_height < 40.0:
			continue
		var ring_width: float = float(ring.get("width", right - left))
		var ring_height: float = float(ring.get("height", bottom - top))
		var horizontal_width: float = _compute_overlap_length(usable_width, ring_width, wall_thickness)
		var horizontal_height: float = max(wall_thickness * 0.75, 48.0)
		var vertical_height: float = _compute_overlap_length(usable_height, ring_height, wall_thickness)
		var vertical_width: float = max(wall_thickness * 0.75, 48.0)
		if not blocked_walls.has(0):
			created += 1
			var top_center = Vector2(center.x, top + inner_margin * 0.35)
			_create_wall_overlap_obstacle(created, top_center, Vector2(horizontal_width, horizontal_height), main_scene)
		if not blocked_walls.has(2):
			created += 1
			var bottom_center = Vector2(center.x, bottom - inner_margin * 0.35)
			_create_wall_overlap_obstacle(created, bottom_center, Vector2(horizontal_width, horizontal_height), main_scene)
		if not blocked_walls.has(1):
			created += 1
			var right_center = Vector2(right - inner_margin * 0.35, center.y)
			_create_wall_overlap_obstacle(created, right_center, Vector2(vertical_width, vertical_height), main_scene)
		if not blocked_walls.has(3):
			created += 1
			var left_center = Vector2(left + inner_margin * 0.35, center.y)
			_create_wall_overlap_obstacle(created, left_center, Vector2(vertical_width, vertical_height), main_scene)

func _compute_overlap_length(usable_span: float, total_span: float, wall_thickness: float) -> float:
	var base: float = max(usable_span * 0.6, min(usable_span, 120.0))
	var span: float = base + wall_thickness * 0.5
	var max_span: float = max(total_span - wall_thickness * 0.1, 72.0)
	return clamp(span, 72.0, max_span)

func _create_wall_overlap_obstacle(index: int, center: Vector2, size: Vector2, main_scene) -> void:
	var obstacle := StaticBody2D.new()
	obstacle.name = "KeyWallObstacle%d" % index
	obstacle.position = center - size * 0.5
	var body := ColorRect.new()
	body.name = "ObstacleBody"
	body.offset_right = size.x
	body.offset_bottom = size.y
	body.color = KEY_RING_SETTINGS.WALL_OBSTACLE_COLOR
	obstacle.add_child(body)
	var collision := CollisionShape2D.new()
	collision.name = "ObstacleCollision"
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	collision.position = size * 0.5
	obstacle.add_child(collision)
	context.obstacles.append(obstacle)
	context.add_generated_node(obstacle, main_scene)

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
