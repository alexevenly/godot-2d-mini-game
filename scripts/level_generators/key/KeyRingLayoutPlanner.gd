extends RefCounted

class_name KeyRingLayoutPlanner

const SETTINGS := preload("res://scripts/level_generators/key/KeyRingSettings.gd")

var _context

func _init(level_context):
	_context = level_context

func create_layout(offset: Vector2, level_width: float, level_height: float, level: int) -> Dictionary:
	var result := {
		"rings": [],
		"spawn": Vector2.ZERO,
		"exit": Vector2(offset.x + level_width * 0.5, offset.y + level_height * 0.5)
	}
	var rings := _build_rings(offset, level_width, level_height, level)
	if rings.size() <= 1:
		return result
	_plan_ring_doors(rings, level)
	result["rings"] = rings
	result["spawn"] = _compute_spawn(offset, rings)
	result["exit"] = _compute_exit(rings)
	return result

func build_clearance_rects(rings: Array) -> Array:
	var rects: Array = []
	for ring in rings:
		if typeof(ring) != TYPE_DICTIONARY:
			continue
		for rect in _build_ring_clearance_rects(ring):
			rects.append(rect)
	return rects

func _build_rings(offset: Vector2, level_width: float, level_height: float, level: int) -> Array:
	var center = Vector2(offset.x + level_width * 0.5, offset.y + level_height * 0.5)
	var min_dimension: float = min(level_width, level_height)
	var outer_half: float = min_dimension * 0.5 - SETTINGS.RING_OUTER_MARGIN
	if outer_half <= SETTINGS.MIN_INNER_HALF:
		return []
	var desired_rings = clamp(3 + int(floor(level / 4.0)), 2, 5)
	var available_space: float = max(outer_half - SETTINGS.MIN_INNER_HALF, 0.0)
	var max_rings_by_spacing = int(floor(available_space / SETTINGS.MIN_RING_SPACING)) + 1
	desired_rings = clamp(desired_rings, 2, max(max_rings_by_spacing, 2))
	var base_inner_margin: float = SETTINGS.WALL_THICKNESS + SETTINGS.KEY_WALL_OFFSET
	var min_inner_half_requirement: float = max(SETTINGS.MIN_INNER_HALF, base_inner_margin + sqrt(SETTINGS.MIN_INNER_AREA) * 0.5)
	var spacing_target: float = SETTINGS.MIN_RING_SPACING
	while desired_rings > 2 and (outer_half - float(desired_rings - 1) * spacing_target) < min_inner_half_requirement:
		desired_rings -= 1
	var step = max((outer_half - min_inner_half_requirement) / float(max(desired_rings - 1, 1)), SETTINGS.MIN_RING_SPACING * 0.5)
	var min_spacing = min(step, SETTINGS.MIN_RING_SPACING)
	var rings: Array = []
	var current_half: float = outer_half
	for i in range(desired_rings):
		if i > 0:
			var remaining = max(desired_rings - i - 1, 0)
			var min_allowed_half: float = min_inner_half_requirement if remaining == 0 else (min_inner_half_requirement + float(remaining) * min_spacing)
			var target_half: float = current_half - step
			current_half = max(target_half, min_allowed_half)
			var prev_half: float = float(rings[i - 1].get("half", outer_half))
			var max_allowed_half: float = prev_half - min_spacing
			if max_allowed_half < min_allowed_half:
				break
			current_half = clamp(current_half, min_allowed_half, max_allowed_half)
		if current_half <= min_inner_half_requirement * 0.6:
			break
		var ring := {
			"index": i,
			"half": current_half,
			"left": center.x - current_half,
			"right": center.x + current_half,
			"top": center.y - current_half,
			"bottom": center.y + current_half,
			"center": center,
			"wall_thickness": SETTINGS.WALL_THICKNESS,
			"inner_margin": base_inner_margin,
			"doors": []
		}
		ring["width"] = float(ring["right"]) - float(ring["left"])
		ring["height"] = float(ring["bottom"]) - float(ring["top"])
		ring["usable_width"] = max(float(ring["width"]) - 2.0 * float(ring["inner_margin"]), 60.0)
		ring["usable_height"] = max(float(ring["height"]) - 2.0 * float(ring["inner_margin"]), 60.0)
		rings.append(ring)
	return rings

func _compute_spawn(offset: Vector2, rings: Array) -> Vector2:
	if rings.is_empty():
		return Vector2.ZERO
	var outer_ring: Dictionary = rings[0]
	var center: Vector2 = outer_ring.get("center", Vector2.ZERO)
	var spawn_y = clamp(center.y, float(outer_ring.get("top", center.y)) + 120.0, float(outer_ring.get("bottom", center.y)) - 120.0)
	var spawn_x = max(offset.x + 80.0, float(outer_ring.get("left", center.x)) - 200.0)
	return Vector2(spawn_x, spawn_y)

func _compute_exit(rings: Array) -> Vector2:
	var inner_ring: Dictionary = rings[rings.size() - 1]
	var center: Vector2 = inner_ring.get("center", Vector2.ZERO)
	return Vector2(center.x, center.y)

func _build_ring_clearance_rects(ring: Dictionary) -> Array:
	var rects: Array = []
	var wall_thickness: float = float(ring.get("wall_thickness", SETTINGS.WALL_THICKNESS))
	var inner_margin: float = float(ring.get("inner_margin", SETTINGS.WALL_THICKNESS + SETTINGS.KEY_WALL_OFFSET))
	var left: float = float(ring.get("left", 0.0))
	var right: float = float(ring.get("right", 0.0))
	var top: float = float(ring.get("top", 0.0))
	var bottom: float = float(ring.get("bottom", 0.0))
	var horizontal_span: float = right - left
	var vertical_span: float = bottom - top
	var vertical_depth: float = wall_thickness + inner_margin
	var horizontal_depth: float = wall_thickness + inner_margin
	rects.append(Rect2(Vector2(left - wall_thickness, top - wall_thickness), Vector2(horizontal_span + wall_thickness * 2.0, vertical_depth)))
	rects.append(Rect2(Vector2(left - wall_thickness, bottom - inner_margin), Vector2(horizontal_span + wall_thickness * 2.0, vertical_depth)))
	rects.append(Rect2(Vector2(left - wall_thickness, top - wall_thickness), Vector2(horizontal_depth, vertical_span + wall_thickness * 2.0)))
	rects.append(Rect2(Vector2(right - inner_margin, top - wall_thickness), Vector2(horizontal_depth, vertical_span + wall_thickness * 2.0)))
	return rects

func _plan_ring_doors(rings: Array, level: int) -> void:
	var wall_sequence = [1, 2, 3, 0]
	var door_index = _context.doors.size()
	for ring_index in range(rings.size()):
		var ring: Dictionary = rings[ring_index]
		var wall = wall_sequence[ring_index % wall_sequence.size()]
		var color: Color = _context.get_group_color(ring_index)
		var keys_needed = clamp(1 + int(floor(level / 4.0)) + ring_index, 1, 5)
		var capacity = _ring_key_capacity(ring)
		keys_needed = min(keys_needed, capacity)
		var doors_for_ring: Array = []
		var primary = _create_door_layout(ring, wall, randf_range(0.3, 0.7), keys_needed, color, door_index)
		if primary:
			doors_for_ring.append(primary)
			door_index += 1
			if _can_add_second_door(ring, wall) and randf() < SETTINGS.SECOND_DOOR_PROBABILITY:
				var secondary_fraction = 0.72 if float(primary.get("fraction", 0.5)) < 0.5 else 0.28
				var secondary = _create_door_layout(ring, wall, secondary_fraction, keys_needed, color, door_index)
				if secondary:
					doors_for_ring.append(secondary)
					door_index += 1
		if doors_for_ring.is_empty():
			continue
		ring["doors"] = doors_for_ring
		rings[ring_index] = ring

func _ring_key_capacity(ring: Dictionary) -> int:
	var usable_width: float = max(float(ring.get("usable_width", 0.0)), 0.0)
	var usable_height: float = max(float(ring.get("usable_height", 0.0)), 0.0)
	var perimeter: float = (usable_width + usable_height) * 2.0
	var spacing: float = max(SETTINGS.KEY_SEPARATION * 0.9, 1.0)
	var capacity: int = int(floor(perimeter / spacing))
	return max(capacity, 1)

func _can_add_second_door(ring: Dictionary, wall: int) -> bool:
	if wall == 0 or wall == 2:
		return float(ring.get("usable_width", 0.0)) > 260.0
	return float(ring.get("usable_height", 0.0)) > 260.0

func _create_door_layout(ring: Dictionary, wall: int, fraction: float, keys_needed: int, color: Color, door_index: int):
	var inner_margin: float = float(ring.get("inner_margin", SETTINGS.WALL_THICKNESS + SETTINGS.KEY_WALL_OFFSET))
	var wall_thickness: float = float(ring.get("wall_thickness", SETTINGS.WALL_THICKNESS))
	var left: float = float(ring.get("left", 0.0))
	var right: float = float(ring.get("right", 0.0))
	var top: float = float(ring.get("top", 0.0))
	var bottom: float = float(ring.get("bottom", 0.0))
	var usable_width: float = max(float(ring.get("usable_width", 0.0)), 60.0)
	var usable_height: float = max(float(ring.get("usable_height", 0.0)), 60.0)
	var door_width: float = wall_thickness
	var door_height: float = wall_thickness
	var position := Vector2.ZERO
	var center := Vector2.ZERO
	var clamped_fraction = clamp(fraction, 0.18, 0.82)
	match wall:
		0:
			var span_max_x = max(usable_width - 40.0, 48.0)
			var span_min_x = min(span_max_x, 110.0)
			door_width = clamp(usable_width * 0.55, span_min_x, span_max_x)
			var start_x = left + inner_margin
			var end_x = max(start_x, right - inner_margin - door_width)
			var door_left = clamp(start_x + usable_width * clamped_fraction - door_width * 0.5, start_x, end_x)
			position = Vector2(door_left, top - wall_thickness)
			center = Vector2(door_left + door_width * 0.5, top)
		1:
			var span_max_y = max(usable_height - 40.0, 48.0)
			var span_min_y = min(span_max_y, 110.0)
			door_height = clamp(usable_height * 0.55, span_min_y, span_max_y)
			var start_y = top + inner_margin
			var end_y = max(start_y, bottom - inner_margin - door_height)
			var door_top = clamp(start_y + usable_height * clamped_fraction - door_height * 0.5, start_y, end_y)
			position = Vector2(right - wall_thickness, door_top)
			center = Vector2(right, door_top + door_height * 0.5)
		2:
			var span_max_bottom = max(usable_width - 40.0, 48.0)
			var span_min_bottom = min(span_max_bottom, 110.0)
			door_width = clamp(usable_width * 0.55, span_min_bottom, span_max_bottom)
			var start_x_bottom = left + inner_margin
			var end_x_bottom = max(start_x_bottom, right - inner_margin - door_width)
			var bottom_left = clamp(start_x_bottom + usable_width * clamped_fraction - door_width * 0.5, start_x_bottom, end_x_bottom)
			position = Vector2(bottom_left, bottom - wall_thickness)
			center = Vector2(bottom_left + door_width * 0.5, bottom)
		3:
			var span_max_left = max(usable_height - 40.0, 48.0)
			var span_min_left = min(span_max_left, 110.0)
			door_height = clamp(usable_height * 0.55, span_min_left, span_max_left)
			var start_y_left = top + inner_margin
			var end_y_left = max(start_y_left, bottom - inner_margin - door_height)
			var left_top = clamp(start_y_left + usable_height * clamped_fraction - door_height * 0.5, start_y_left, end_y_left)
			position = Vector2(left, left_top)
			center = Vector2(left, left_top + door_height * 0.5)
		_:
			return null
	return {
		"index": door_index,
		"wall": wall,
		"fraction": clamped_fraction,
		"position": position,
		"size": Vector2(door_width, door_height),
		"center": center,
		"keys_needed": keys_needed,
		"initially_open": false,
		"color": color
	}
