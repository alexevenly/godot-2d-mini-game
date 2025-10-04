extends RefCounted
class_name KeyDoorPlanner

const LOGGER := preload("res://scripts/Logger.gd")
const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")

var _context

func _init(level_context):
	_context = level_context

func sample_far_points(count: int, offset: Vector2, level_width: float, level_height: float, min_distance: float) -> Array:
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

func enforce_spacing(door_layouts: Array, offset: Vector2, level_width: float, min_gap: float, edge_margin: float) -> void:
	if door_layouts.size() <= 1:
		return
	var sorted := door_layouts.duplicate()
	sorted.sort_custom(func(a, b):
		return float(a.get("center_x", 0.0)) < float(b.get("center_x", 0.0)))
	var left_bound := offset.x + edge_margin
	var right_bound := offset.x + level_width - edge_margin
	var widths: Array[float] = []
	var total_width := 0.0
	for layout in sorted:
		var width := float(layout.get("door_width", 48.0))
		widths.append(width)
		total_width += width
	var desired_gap: float = min_gap
	var separators: int = max(sorted.size() - 1, 0)
	if separators > 0:
		var available_span: float = max(right_bound - left_bound, 0.0)
		var required_span: float = total_width + desired_gap * float(separators)
		if required_span > available_span and available_span > total_width:
			desired_gap = max(min_gap * 0.6, (available_span - total_width) / float(separators))
			LOGGER.log_generation("Compressed door spacing from %.1f to %.1f to fit width" % [min_gap, desired_gap])
	var total_spacing: float = desired_gap * float(separators)
	var available_width: float = max(right_bound - left_bound, 0.0)
	var start_offset: float = 0.0
	if available_width > (total_width + total_spacing):
		start_offset = (available_width - (total_width + total_spacing)) * 0.5
	var cursor: float = left_bound + start_offset
	for i in range(sorted.size()):
		var layout: Dictionary = sorted[i]
		var width: float = widths[i]
		var half: float = width * 0.5
		cursor = max(cursor, left_bound)
		var center: float = clamp(cursor + half, left_bound + half, right_bound - half)
		layout["center_x"] = center
		cursor = center + half + desired_gap
	for layout in sorted:
		var original_index := int(layout.get("index", -1))
		if original_index >= 0 and original_index < door_layouts.size():
			var target: Dictionary = door_layouts[original_index]
			target["center_x"] = layout["center_x"]
			door_layouts[original_index] = target

func pick_keys_for_door(
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
	var accessible_x_max = door_center.x - 50.0
	var accessible_x_min = offset.x + 90.0
	while result.size() < keys_needed and attempts < 240:
		var candidate = Vector2(
			randf_range(accessible_x_min, accessible_x_max),
			randf_range(offset.y + 90.0, offset.y + level_height - 90.0)
		)
		if candidate.x >= door_center.x - 30.0:
			attempts += 1
			continue
		var collides_with_obstacle = false
		for obstacle in _context.obstacles:
			if obstacle and is_instance_valid(obstacle):
				var obstacle_rect = LEVEL_UTILS.get_obstacle_rect(obstacle)
				if obstacle_rect.has_point(candidate):
					collides_with_obstacle = true
					break
		if collides_with_obstacle:
			attempts += 1
			continue
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
				randf_range(accessible_x_min, accessible_x_max),
				offset.y + level_height * randf_range(0.25, 0.75)
			)
			result.append(fallback)
			used_positions.append(fallback)
	return result
