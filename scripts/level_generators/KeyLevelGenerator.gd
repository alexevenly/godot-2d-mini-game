extends RefCounted
class_name KeyLevelGenerator

const Logger = preload("res://scripts/Logger.gd")
const LevelUtils = preload("res://scripts/LevelUtils.gd")
const LevelNodeFactory = preload("res://scripts/level_generators/LevelNodeFactory.gd")

const BARRIER_COLOR := Color(0.18, 0.21, 0.32, 1)

var context
var obstacle_utils

func _init(level_context, obstacle_helper):
	context = level_context
	obstacle_utils = obstacle_helper

func generate(main_scene, level: int, player_start_position: Vector2) -> void:
	var dims = LevelUtils.get_scaled_level_dimensions(context.current_level_size)
	var level_width: float = float(dims.width)
	var level_height: float = float(dims.height)
	var offset = Vector2(dims.offset_x, dims.offset_y)

	var max_doors = clamp(1 + int(ceil(level / 2.0)), 1, 3)
	var door_count = randi_range(1, max_doors)
	var door_width = 48.0
	var max_gap_height = max(level_height - 200.0, 140.0)
	var door_gap_height = clamp(level_height * 0.35, 140.0, max_gap_height)
	var segment_width = level_width / float(door_count + 1)

	var door_states: Array = []
	for i in range(door_count):
		door_states.append(true)
	if door_count > 1 and randi_range(0, 100) < 35:
		var open_index = randi_range(0, door_count - 1)
		door_states[open_index] = false

	var closed_indices: Array = []
	for i in range(door_count):
		if door_states[i]:
			closed_indices.append(i)
	if closed_indices.is_empty():
		door_states[0] = true
		closed_indices.append(0)

	var min_keys = max(2, closed_indices.size())
	var max_keys = 6
	var key_total = randi_range(min_keys, max_keys)
	var keys_per_door := {}
	for i in range(door_count):
		keys_per_door[i] = 0
	var remaining = key_total
	for idx in closed_indices:
		keys_per_door[idx] = 1
		remaining -= 1
	while remaining > 0 and closed_indices.size() > 0:
		var idx = closed_indices[randi() % closed_indices.size()]
		keys_per_door[idx] += 1
		remaining -= 1

	var door_layouts: Array = []
	for i in range(door_count):
		var center_x = offset.x + segment_width * float(i + 1)
		var min_center_y = offset.y + door_gap_height * 0.5 + 60.0
		var max_center_y = offset.y + level_height - door_gap_height * 0.5 - 60.0
		if max_center_y <= min_center_y:
			min_center_y = offset.y + level_height * 0.5
			max_center_y = min_center_y
		var door_center_y = randf_range(min_center_y, max_center_y)
		var door_top = door_center_y - door_gap_height * 0.5
		var layout := {
			"index": i,
			"center_x": center_x,
			"door_top": door_top,
			"door_bottom": door_top + door_gap_height,
			"keys_needed": int(keys_per_door[i]),
			"initially_open": not door_states[i],
			"color": context.get_group_color(i)
		}
		door_layouts.append(layout)

	var spawn_y = clamp(player_start_position.y, offset.y + 80.0, offset.y + level_height - 80.0)
	var spawn_override = Vector2(offset.x + 80.0, spawn_y)
	_generate_key_level_obstacles(context.current_level_size, main_scene, level, offset, level_width, level_height, door_layouts, door_width, spawn_override)

	context.exit_spawner.clear_exit()
	context.coins.clear()
	var door_positions: Array = []
	var key_positions: Array = []
	var door_group_colors: Array = []
	for layout in door_layouts:
		var i = int(layout.get("index", 0))
		var center_x = float(layout.get("center_x", offset.x))
		door_positions.append(center_x)
		var door_top = float(layout.get("door_top", offset.y))
		var door_bottom = float(layout.get("door_bottom", door_top + door_gap_height))
		var group_color: Color = layout.get("color", context.get_group_color(i))
		door_group_colors.append(group_color)
		var initially_open = layout.get("initially_open", false)
		var door = LevelNodeFactory.create_door_node(i, int(layout.get("keys_needed", 0)), initially_open, door_gap_height, door_width, group_color)
		door.position = Vector2(center_x - door_width * 0.5, door_top)
		context.doors.append(door)
		context.add_generated_node(door, main_scene)

		var top_segment_height = max(door_top - offset.y, 0.0)
		if top_segment_height > 0.0:
			var top_segment = LevelNodeFactory.create_barrier_segment(context.key_barriers.size(), door_width, top_segment_height, BARRIER_COLOR)
			top_segment.position = Vector2(center_x - door_width * 0.5, offset.y)
			context.key_barriers.append(top_segment)
			context.add_generated_node(top_segment, main_scene)

		var bottom_segment_height = max(offset.y + level_height - door_bottom, 0.0)
		if bottom_segment_height > 0.0:
			var bottom_segment = LevelNodeFactory.create_barrier_segment(context.key_barriers.size(), door_width, bottom_segment_height, BARRIER_COLOR)
			bottom_segment.position = Vector2(center_x - door_width * 0.5, door_bottom)
			context.key_barriers.append(bottom_segment)
			context.add_generated_node(bottom_segment, main_scene)

		var keys_needed = int(layout.get("keys_needed", 0))
		if keys_needed <= 0:
			continue

		var segment_left: float
		if i == 0:
			segment_left = offset.x + 60.0
		else:
			segment_left = door_positions[i - 1] + door_width * 0.5 + 60.0
		var segment_right = center_x - door_width * 0.5 - 60.0
		if segment_right <= segment_left:
			segment_right = segment_left + 40.0
		var min_y = offset.y + 80.0
		var max_y = offset.y + level_height - 80.0

		for j in range(keys_needed):
			var attempts = 0
			var key_pos = Vector2.ZERO
			var placed = false
			while attempts < 40 and not placed:
				key_pos = Vector2(randf_range(segment_left, segment_right), randf_range(min_y, max_y))
				var too_close = false
				for existing in key_positions:
					if existing.distance_to(key_pos) < 50.0:
						too_close = true
						break
				if not too_close:
					placed = true
				else:
					attempts += 1
			if not placed:
				key_pos = Vector2((segment_left + segment_right) * 0.5, offset.y + level_height * 0.5)
			key_positions.append(key_pos)
			var key_color = door_group_colors[i] if i < door_group_colors.size() else context.get_group_color(i)
			var key_node = LevelNodeFactory.create_key_node(context.key_items.size(), door, key_pos, keys_needed, key_color)
			context.key_items.append(key_node)
			context.add_generated_node(key_node, main_scene)

	obstacle_utils.clear_near_points(key_positions, 70.0)

	var exit_position = Vector2(offset.x + level_width - 120.0, offset.y + level_height * 0.5)
	context.exit_spawner.create_exit_at(exit_position, main_scene)
	var exit_node = context.exit_spawner.get_exit()
	if exit_node:
		context.exit_pos = exit_node.position
		obstacle_utils.clear_around_position(context.exit_pos, 100.0)

	context.set_player_spawn_override(spawn_override)

func _generate_key_level_obstacles(level_size: float, main_scene, level: int, offset: Vector2, level_width: float, level_height: float, door_layouts: Array, door_width: float, spawn_override: Vector2) -> void:
	if context.obstacle_spawner == null or not is_instance_valid(context.obstacle_spawner):
		Logger.log_error("ObstacleSpawner unavailable for key level")
		return

	context.obstacles = context.obstacle_spawner.generate_obstacles(level_size, true, main_scene, level)
	if context.obstacles.is_empty():
		return

	var door_margin = 60.0
	var clearance_rects: Array = []
	for layout in door_layouts:
		if typeof(layout) != TYPE_DICTIONARY:
			continue
		var center_x = float(layout.get("center_x", offset.x))
		var rect_position = Vector2(center_x - (door_width * 0.5 + door_margin), offset.y)
		var rect_size = Vector2(door_width + door_margin * 2.0, level_height)
		clearance_rects.append(Rect2(rect_position, rect_size))

	if not clearance_rects.is_empty():
		obstacle_utils.clear_in_rects(clearance_rects)

	if spawn_override != Vector2.ZERO:
		obstacle_utils.clear_around_position(spawn_override, 140.0)
