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

	var door_count = clamp(3 + int(floor(level / 2.0)), 3, 7)
	var min_spacing = min(level_width, level_height) * 0.22 + 140.0
	var door_centers: Array = _sample_far_points(door_count, offset, level_width, level_height, min_spacing)

	var door_layouts: Array = []
	var closed_indices: Array = []
	for i in range(door_count):
		var center: Vector2 = door_centers[i]
		var door_width = randf_range(44.0, 64.0)
		center.x = clamp(center.x, offset.x + door_width * 0.5 + 45.0, offset.x + level_width - door_width * 0.5 - 45.0)
		var gap_height = clamp(level_height * randf_range(0.32, 0.45), 170.0, level_height - 140.0)
		var door_top = clamp(center.y - gap_height * 0.5, offset.y + 50.0, offset.y + level_height - gap_height - 50.0)
		var door_bottom = door_top + gap_height
		var initially_open = false
		if i % 4 == 3 and randf() < 0.25:
			initially_open = true
		var keys_needed = clamp(1 + int(floor(level / 3.0)) + (i % 3 == 1 ? 1 : 0), 1, 4)
		if initially_open:
			keys_needed = 0
		else:
			closed_indices.append(i)
		door_layouts.append({
			"index": i,
			"center_x": center.x,
			"center_y": center.y,
			"door_top": door_top,
			"door_bottom": door_bottom,
			"door_width": door_width,
			"gap_height": gap_height,
			"keys_needed": keys_needed,
			"initially_open": initially_open,
			"color": context.get_group_color(i)
		})

	if closed_indices.is_empty() and door_layouts.size() > 0:
		var layout: Dictionary = door_layouts[0]
		layout["initially_open"] = false
		layout["keys_needed"] = max(int(layout.get("keys_needed", 0)), 1)
		door_layouts[0] = layout
		closed_indices.append(0)

	var spawn_y = clamp(player_start_position.y, offset.y + 90.0, offset.y + level_height - 90.0)
	var spawn_override = Vector2(offset.x + 90.0, spawn_y)
	_generate_key_level_obstacles(context.current_level_size, main_scene, level, offset, level_width, level_height, door_layouts, spawn_override)

	context.exit_spawner.clear_exit()
	context.coins.clear()
	var used_key_positions: Array = []
	var key_positions: Array = []
	var exit_position = Vector2(offset.x + level_width - 140.0, offset.y + level_height * randf_range(0.35, 0.65))

	var door_index_offset = context.doors.size()
	for layout_index in range(door_layouts.size()):
		var layout: Dictionary = door_layouts[layout_index]
		var center_x = float(layout.get("center_x", offset.x))
		var door_top = float(layout.get("door_top", offset.y))
		var door_bottom = float(layout.get("door_bottom", door_top + 200.0))
		var door_width = float(layout.get("door_width", 48.0))
		var gap_height = float(layout.get("gap_height", door_bottom - door_top))
		var group_color: Color = layout.get("color", context.get_group_color(layout_index))
		var initially_open: bool = layout.get("initially_open", false)
		var keys_needed = int(layout.get("keys_needed", 0))
		if initially_open and keys_needed > 0:
			keys_needed = 0
		var door = LevelNodeFactory.create_door_node(door_index_offset + layout_index, keys_needed, initially_open, gap_height, door_width, group_color)
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

		var door_center = Vector2(center_x, (door_top + door_bottom) * 0.5)
		var assigned_keys: Array = []
		if keys_needed > 0:
			assigned_keys = _pick_keys_for_door(door_center, keys_needed, offset, level_width, level_height, spawn_override, exit_position, used_key_positions)
		var actual_keys = assigned_keys.size()
		if actual_keys != keys_needed:
			door.required_keys = actual_keys
		if actual_keys <= 0:
			door.initially_open = true
			door.required_keys = 0
		var key_requirement = max(door.required_keys, 1)
		for key_pos in assigned_keys:
			key_positions.append(key_pos)
			var key_node = LevelNodeFactory.create_key_node(context.key_items.size(), door, key_pos, key_requirement, group_color)
			context.key_items.append(key_node)
			context.add_generated_node(key_node, main_scene)
		Logger.log_generation("Keys level door %d at %.1f, %.1f requires %d keys" % [door_index_offset + layout_index, center_x, door_center.y, door.required_keys])

	if not key_positions.is_empty():
		obstacle_utils.clear_near_points(key_positions, 90.0)

	context.exit_spawner.create_exit_at(exit_position, main_scene)
	var exit_node = context.exit_spawner.get_exit()
	if exit_node:
		context.exit_pos = exit_node.position
	obstacle_utils.clear_around_position(context.exit_pos, 110.0)

	context.set_player_spawn_override(spawn_override)


func _generate_key_level_obstacles(level_size: float, main_scene, level: int, offset: Vector2, level_width: float, level_height: float, door_layouts: Array, spawn_override: Vector2) -> void:
	if context.obstacle_spawner == null or not is_instance_valid(context.obstacle_spawner):
		Logger.log_error("ObstacleSpawner unavailable for key level")
		return

	context.obstacles = context.obstacle_spawner.generate_obstacles(level_size, true, main_scene, level)
	if context.obstacles.is_empty():
		return

	var door_margin = 70.0
	var clearance_rects: Array = []
	for layout in door_layouts:
		if typeof(layout) != TYPE_DICTIONARY:
			continue
		var center_x = float(layout.get("center_x", offset.x))
		var door_width = float(layout.get("door_width", 48.0))
		var rect_half = door_width * 0.5 + door_margin
		var rect_position = Vector2(center_x - rect_half, offset.y)
		var rect_size = Vector2(door_width + door_margin * 2.0, level_height)
		clearance_rects.append(Rect2(rect_position, rect_size))

	if not clearance_rects.is_empty():
		obstacle_utils.clear_in_rects(clearance_rects)

	if spawn_override != Vector2.ZERO:
		obstacle_utils.clear_around_position(spawn_override, 140.0)

func _sample_far_points(count: int, offset: Vector2, level_width: float, level_height: float, min_distance: float) -> Array:
var points: Array = []
var attempts: int = 0
var spacing: float = min_distance
while points.size() < count and attempts < 400:
var candidate = Vector2(
randf_range(offset.x + 120.0, offset.x + level_width - 120.0),
randf_range(offset.y + 120.0, offset.y + level_height - 120.0)
)
var valid := true
for existing in points:
if existing.distance_to(candidate) < spacing:
valid = false
break
if valid:
points.append(candidate)
else:
attempts += 1
if attempts % 80 == 0 and spacing > 140.0:
spacing *= 0.85
if points.size() < count:
for i in range(count - points.size()):
var t = float(points.size() + i + 1) / float(count + 1)
var fallback = Vector2(
offset.x + level_width * t,
offset.y + level_height * randf_range(0.25, 0.75)
)
points.append(fallback)
return points

func _pick_keys_for_door(
door_center: Vector2,
keys_needed: int,
offset: Vector2,
level_width: float,
level_height: float,
spawn_override: Vector2,
exit_position: Vector2,
used_positions: Array
) -> Array:
var result: Array = []
if keys_needed <= 0:
return result
var min_spacing: float = 150.0
var attempts: int = 0
while result.size() < keys_needed and attempts < 240:
var candidate = Vector2(
randf_range(offset.x + 90.0, offset.x + level_width - 90.0),
randf_range(offset.y + 90.0, offset.y + level_height - 90.0)
)
var score = min(candidate.distance_to(door_center), candidate.distance_to(spawn_override))
score = min(score, candidate.distance_to(exit_position))
for used in used_positions:
score = min(score, candidate.distance_to(used))
for existing in result:
score = min(score, candidate.distance_to(existing))
if score < min_spacing:
attempts += 1
if attempts % 60 == 0 and min_spacing > 90.0:
min_spacing *= 0.9
continue
result.append(candidate)
used_positions.append(candidate)
if result.size() < keys_needed:
while result.size() < keys_needed:
var fallback = Vector2(
offset.x + level_width * randf_range(0.15, 0.85),
offset.y + level_height * randf_range(0.25, 0.75)
)
result.append(fallback)
used_positions.append(fallback)
return result
