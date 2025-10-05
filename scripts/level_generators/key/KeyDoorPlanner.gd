extends RefCounted
class_name KeyDoorPlanner

const KEY_PLACEMENT = preload("res://scripts/level_generators/key/KeyPlacementUtils.gd")

const KEY_SIZE = 24.0
const KEY_CLEARANCE = 36.0
const LEVEL_MARGIN = 90.0
const ACCESSIBLE_MARGIN_FALLBACK = 40.0

var _context

func _init(level_context):
	_context = level_context

func sample_far_points(count: int, offset: Vector2, level_width: float, level_height: float, min_distance: float) -> Array:
	return KEY_PLACEMENT.sample_far_points(count, offset, level_width, level_height, min_distance)

func enforce_spacing(door_layouts: Array, offset: Vector2, level_width: float, min_gap: float, edge_margin: float) -> void:
	KEY_PLACEMENT.enforce_spacing(door_layouts, offset, level_width, min_gap, edge_margin)

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
	var bounds := KEY_PLACEMENT.compute_key_bounds(offset, level_width, level_height, door_center.x, KEY_CLEARANCE, KEY_SIZE, LEVEL_MARGIN, ACCESSIBLE_MARGIN_FALLBACK)
	var horizontal_min: float = bounds["min_x"]
	var horizontal_max: float = bounds["max_x"]
	var vertical_min: float = bounds["min_y"]
	var vertical_max: float = bounds["max_y"]
	var evaluated_spacing_failures = 0
	while result.size() < keys_needed and attempts < 260:
		var candidate = KEY_PLACEMENT.random_key_position(horizontal_min, horizontal_max, vertical_min, vertical_max)
		var evaluation = KEY_PLACEMENT.evaluate_candidate(candidate, door_center, bounds, spawn_override, exit_position, used_positions, result, KEY_CLEARANCE, KEY_SIZE, _context.obstacles)
		if evaluation.valid:
			if evaluation.score >= min_spacing:
				result.append(candidate)
				used_positions.append(candidate)
				continue
			attempts += 1
			evaluated_spacing_failures += 1
			if evaluated_spacing_failures % 60 == 0 and min_spacing > 90.0:
				min_spacing *= 0.9
		else:
			attempts += 1
	if result.size() < keys_needed:
		var relaxed_spacing = min(min_spacing, 110.0)
		var fallback_attempts = 0
		while result.size() < keys_needed and fallback_attempts < 220:
			var candidate = KEY_PLACEMENT.random_key_position(horizontal_min, horizontal_max, vertical_min, vertical_max)
			fallback_attempts += 1
			var evaluation = KEY_PLACEMENT.evaluate_candidate(candidate, door_center, bounds, spawn_override, exit_position, used_positions, result, KEY_CLEARANCE, KEY_SIZE, _context.obstacles)
			if not evaluation.valid:
				continue
			if evaluation.score < relaxed_spacing:
				continue
			result.append(candidate)
			used_positions.append(candidate)
	if result.size() < keys_needed:
		var remaining: int = keys_needed - result.size()
		var door_clearance_limit: float = door_center.x - (KEY_CLEARANCE + KEY_SIZE)
		var fallback_max_x: float = min(horizontal_max, door_clearance_limit)
		var fallback_min_x: float = min(horizontal_min, fallback_max_x)
		fallback_min_x = max(offset.x + 4.0, fallback_min_x)
		if fallback_max_x < fallback_min_x:
			fallback_max_x = fallback_min_x
		for i in range(remaining):
			var anchor_x_target: float = door_clearance_limit - float(i) * (KEY_SIZE + 10.0)
			var anchor_x: float = clamp(anchor_x_target, fallback_min_x, fallback_max_x)
			var anchor_y: float = clamp(vertical_min + float(i) * 40.0, vertical_min, vertical_max)
			var fallback: Vector2 = Vector2(anchor_x, anchor_y)
			if not KEY_PLACEMENT.is_candidate_within_bounds(fallback, door_center, fallback_min_x, fallback_max_x, KEY_CLEARANCE, KEY_SIZE):
				var adjusted_x: float = clamp(door_clearance_limit, fallback_min_x, fallback_max_x)
				fallback.x = adjusted_x
				if not KEY_PLACEMENT.is_candidate_within_bounds(fallback, door_center, fallback_min_x, fallback_max_x, KEY_CLEARANCE, KEY_SIZE):
					continue
			if KEY_PLACEMENT.is_blocked_by_obstacle(fallback, _context.obstacles):
				var shifted_y: float = fallback.y
				var adjustment_attempts: int = 0
				while adjustment_attempts < 3 and KEY_PLACEMENT.is_blocked_by_obstacle(fallback, _context.obstacles):
					shifted_y = clamp(shifted_y + 45.0, vertical_min, vertical_max)
					fallback.y = shifted_y
					adjustment_attempts += 1
				if KEY_PLACEMENT.is_blocked_by_obstacle(fallback, _context.obstacles):
					continue
			result.append(fallback)
			used_positions.append(fallback)
	return result
