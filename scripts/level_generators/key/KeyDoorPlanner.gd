extends RefCounted
class_name KeyDoorPlanner

const LOGGER = preload("res://scripts/Logger.gd")
const LEVEL_UTILS = preload("res://scripts/LevelUtils.gd")

const KEY_SIZE = 24.0
const KEY_CLEARANCE = 36.0
const LEVEL_MARGIN = 90.0
const ACCESSIBLE_MARGIN_FALLBACK = 40.0

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
		var valid = true
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
	var sorted = door_layouts.duplicate()
	sorted.sort_custom(func(a, b):
		return float(a.get("center_x", 0.0)) < float(b.get("center_x", 0.0)))
	var left_bound = offset.x + edge_margin
	var right_bound = offset.x + level_width - edge_margin
	var widths: Array[float] = []
	var total_width = 0.0
	for layout in sorted:
		var width = float(layout.get("door_width", 48.0))
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
		var original_index = int(layout.get("index", -1))
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
	var vertical_min = offset.y + LEVEL_MARGIN
	var vertical_max = offset.y + level_height - LEVEL_MARGIN
	var horizontal_min = offset.x + LEVEL_MARGIN
	var horizontal_max = door_center.x - (KEY_CLEARANCE + KEY_SIZE)
	var level_right_limit = offset.x + level_width - LEVEL_MARGIN
	horizontal_max = min(horizontal_max, level_right_limit)
	if horizontal_max <= horizontal_min:
		horizontal_min = max(offset.x + ACCESSIBLE_MARGIN_FALLBACK, horizontal_max - 120.0)
		horizontal_max = max(horizontal_min + 16.0, horizontal_max)
	var evaluated_spacing_failures = 0
	while result.size() < keys_needed and attempts < 260:
		var candidate = _random_key_position(horizontal_min, horizontal_max, vertical_min, vertical_max)
		if not _is_candidate_within_bounds(candidate, door_center, horizontal_min, horizontal_max):
			attempts += 1
			continue
		if _is_blocked_by_obstacle(candidate):
			attempts += 1
			continue
		var score = _spacing_score(candidate, door_center, spawn_override, exit_position, used_positions, result)
		if score < min_spacing:
			attempts += 1
			evaluated_spacing_failures += 1
			if evaluated_spacing_failures % 60 == 0 and min_spacing > 90.0:
				min_spacing *= 0.9
			continue
		result.append(candidate)
		used_positions.append(candidate)
	if result.size() < keys_needed:
		var relaxed_spacing = min(min_spacing, 110.0)
		var fallback_attempts = 0
		while result.size() < keys_needed and fallback_attempts < 220:
			var candidate = _random_key_position(horizontal_min, horizontal_max, vertical_min, vertical_max)
			fallback_attempts += 1
			if not _is_candidate_within_bounds(candidate, door_center, horizontal_min, horizontal_max):
				continue
			if _is_blocked_by_obstacle(candidate):
				continue
			var score = _spacing_score(candidate, door_center, spawn_override, exit_position, used_positions, result)
			if score < relaxed_spacing:
				continue
			result.append(candidate)
			used_positions.append(candidate)
	if result.size() < keys_needed:
		for i in range(keys_needed - result.size()):
			var anchor_x = clamp(door_center.x - (KEY_CLEARANCE + KEY_SIZE) - float(i) * (KEY_SIZE + 10.0), horizontal_min, horizontal_max)
			var anchor_y = clamp(vertical_min + float(i) * 40.0, vertical_min, vertical_max)
			var fallback = Vector2(anchor_x, anchor_y)
			if _is_blocked_by_obstacle(fallback):
				fallback.y = clamp(fallback.y + 45.0, vertical_min, vertical_max)
			result.append(fallback)
			used_positions.append(fallback)
	return result

func _random_key_position(min_x: float, max_x: float, min_y: float, max_y: float) -> Vector2:
	return Vector2(
		randf_range(min_x, max_x),
		randf_range(min_y, max_y)
	)

func _is_candidate_within_bounds(candidate: Vector2, door_center: Vector2, min_x: float, max_x: float) -> bool:
	if candidate.x < min_x or candidate.x > max_x:
		return false
	var right_edge = candidate.x + KEY_SIZE
	return right_edge <= door_center.x - KEY_CLEARANCE

func _is_blocked_by_obstacle(candidate: Vector2) -> bool:
	for obstacle in _context.obstacles:
		if obstacle and is_instance_valid(obstacle):
			var obstacle_rect = LEVEL_UTILS.get_obstacle_rect(obstacle)
			if obstacle_rect.has_point(candidate):
				return true
	return false

func _spacing_score(
	candidate: Vector2,
	door_center: Vector2,
	spawn_override: Vector2,
	exit_position: Vector2,
	used_positions: Array,
	existing: Array
) -> float:
	var score = candidate.distance_to(door_center)
	if spawn_override != Vector2.ZERO:
		score = min(score, candidate.distance_to(spawn_override))
	if exit_position != Vector2.ZERO:
		score = min(score, candidate.distance_to(exit_position))
	for used in used_positions:
		score = min(score, candidate.distance_to(used))
	for current in existing:
		score = min(score, candidate.distance_to(current))
	return score
