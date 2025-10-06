extends RefCounted

class_name KeyRingDoorSpawner

const SETTINGS := preload("res://scripts/level_generators/key/KeyRingSettings.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")
const KEY_PLACEMENT := preload("res://scripts/level_generators/key/KeyPlacementUtils.gd")

var _context
var _obstacle_utils

func _init(level_context, obstacle_helper):
	_context = level_context
	_obstacle_utils = obstacle_helper

func spawn(rings: Array, main_scene) -> void:
	var used_key_positions: Array = []
	for ring in rings:
		if typeof(ring) != TYPE_DICTIONARY:
			continue
		var doors: Array = ring.get("doors", [])
		for door_index in range(doors.size()):
			var layout: Dictionary = doors[door_index]
			var size: Vector2 = layout.get("size", Vector2(SETTINGS.WALL_THICKNESS, SETTINGS.WALL_THICKNESS))
			var door = LEVEL_NODE_FACTORY.create_door_node(int(layout.get("index", 0)), int(layout.get("keys_needed", 0)), layout.get("initially_open", false), size.y, size.x, layout.get("color", Color.WHITE))
			door.position = layout.get("position", Vector2.ZERO)
			_context.doors.append(door)
			_context.add_generated_node(door, main_scene)
			layout["node"] = door
			doors[door_index] = layout
			_place_keys(ring, layout, used_key_positions, main_scene)
		ring["doors"] = doors

func _place_keys(ring: Dictionary, layout: Dictionary, used_key_positions: Array, main_scene) -> void:
	var door: StaticBody2D = layout.get("node", null)
	if door == null:
		return
	var keys_needed = int(layout.get("keys_needed", 0))
	if keys_needed <= 0:
		door.initially_open = true
		door.required_keys = 0
		return
	var key_positions: Array = _perimeter_positions(ring, layout, keys_needed, used_key_positions)
	if key_positions.is_empty():
		door.initially_open = true
		door.required_keys = 0
		return
	var actual_keys = key_positions.size()
	if actual_keys != keys_needed:
		door.required_keys = actual_keys
	else:
		door.required_keys = keys_needed
	door.initially_open = false
	var key_requirement = max(door.required_keys, 1)
	for pos in key_positions:
		used_key_positions.append(pos)
		var key_node = LEVEL_NODE_FACTORY.create_key_node(_context.key_items.size(), door, pos, key_requirement, layout.get("color", Color.WHITE))
		_context.key_items.append(key_node)
		_context.add_generated_node(key_node, main_scene)
		_obstacle_utils.clear_around_position(pos, 85.0)

func _perimeter_positions(ring: Dictionary, layout: Dictionary, keys_needed: int, used_key_positions: Array) -> Array:
	var positions: Array = []
	var inner_margin: float = float(ring.get("inner_margin", SETTINGS.WALL_THICKNESS + SETTINGS.KEY_WALL_OFFSET))
	var left: float = float(ring.get("left", 0.0)) + inner_margin
	var right: float = float(ring.get("right", 0.0)) - inner_margin
	var top: float = float(ring.get("top", 0.0)) + inner_margin
	var bottom: float = float(ring.get("bottom", 0.0)) - inner_margin
	if right <= left or bottom <= top:
		return positions
	var door_wall = int(layout.get("wall", 0))
	var walls_order = [_opposite_wall(door_wall), (door_wall + 1) % 4, (door_wall + 3) % 4, door_wall]
	var fractions = [0.22, 0.5, 0.78]
	for wall in walls_order:
		if positions.size() >= keys_needed:
			break
		for candidate in _wall_candidates(ring, wall, inner_margin, fractions, layout):
			if positions.size() >= keys_needed:
				break
			if not _is_candidate_valid(candidate, used_key_positions, positions):
				continue
			if KEY_PLACEMENT.is_blocked_by_obstacle(candidate, _context.obstacles):
				continue
			positions.append(candidate)
	if positions.size() < keys_needed:
		for candidate in _wall_candidates(ring, door_wall, inner_margin, [0.12, 0.88], layout):
			if positions.size() >= keys_needed:
				break
			if not _is_candidate_valid(candidate, used_key_positions, positions):
				continue
			if KEY_PLACEMENT.is_blocked_by_obstacle(candidate, _context.obstacles):
				continue
			positions.append(candidate)
	if positions.size() < keys_needed:
		var opposite = _opposite_wall(door_wall)
		for candidate in _wall_candidates(ring, opposite, inner_margin, [0.15, 0.85], layout):
			if positions.size() >= keys_needed:
				break
			if not _is_candidate_valid(candidate, used_key_positions, positions):
				continue
			if KEY_PLACEMENT.is_blocked_by_obstacle(candidate, _context.obstacles):
				continue
			positions.append(candidate)
	if positions.is_empty():
		var fallback = _door_fallback_position(ring, layout)
		if fallback != null and not KEY_PLACEMENT.is_blocked_by_obstacle(fallback, _context.obstacles):
			positions.append(fallback)
	return positions

func _wall_candidates(ring: Dictionary, wall: int, inner_margin: float, fractions: Array, layout: Dictionary) -> Array:
	var positions: Array = []
	var left: float = float(ring.get("left", 0.0))
	var right: float = float(ring.get("right", 0.0))
	var top: float = float(ring.get("top", 0.0))
	var bottom: float = float(ring.get("bottom", 0.0))
	var ring_index := int(ring.get("index", 0))
	var door_wall = int(layout.get("wall", -1))
	var door_pos: Vector2 = layout.get("position", Vector2.ZERO)
	var door_size: Vector2 = layout.get("size", Vector2.ZERO)
	var wall_thickness: float = float(ring.get("wall_thickness", SETTINGS.WALL_THICKNESS))
	var outer_offset := wall_thickness + SETTINGS.KEY_WALL_OFFSET * 0.5
	var use_interior := true
	if wall == 0:
		var start_x = left + inner_margin
		var end_x = right - inner_margin
		var y = top + inner_margin if use_interior else top - outer_offset
		for fraction in fractions:
			var x = lerp(start_x, end_x, clamp(fraction, 0.05, 0.95))
			if door_wall == wall:
				var door_left = door_pos.x
				var door_right = door_pos.x + door_size.x
				if x >= door_left - SETTINGS.KEY_SEPARATION * 0.5 and x <= door_right + SETTINGS.KEY_SEPARATION * 0.5:
					continue
			positions.append(Vector2(x, y))
	elif wall == 1:
		var start_y = top + inner_margin
		var end_y = bottom - inner_margin
		var x_right = right - inner_margin if use_interior else right + outer_offset
		for fraction_right in fractions:
			var y_right = lerp(start_y, end_y, clamp(fraction_right, 0.05, 0.95))
			if door_wall == wall:
				var door_top = door_pos.y
				var door_bottom = door_pos.y + door_size.y
				if y_right >= door_top - SETTINGS.KEY_SEPARATION * 0.5 and y_right <= door_bottom + SETTINGS.KEY_SEPARATION * 0.5:
					continue
			positions.append(Vector2(x_right, y_right))
	elif wall == 2:
		var start_x_bottom = left + inner_margin
		var end_x_bottom = right - inner_margin
		var y_bottom = bottom - inner_margin if use_interior else bottom + outer_offset
		for fraction_bottom in fractions:
			var x_bottom = lerp(start_x_bottom, end_x_bottom, clamp(fraction_bottom, 0.05, 0.95))
			if door_wall == wall:
				var door_left_bottom = door_pos.x
				var door_right_bottom = door_pos.x + door_size.x
				if x_bottom >= door_left_bottom - SETTINGS.KEY_SEPARATION * 0.5 and x_bottom <= door_right_bottom + SETTINGS.KEY_SEPARATION * 0.5:
					continue
			positions.append(Vector2(x_bottom, y_bottom))
	elif wall == 3:
		var start_y_left = top + inner_margin
		var end_y_left = bottom - inner_margin
		var x_left = left + inner_margin if use_interior else left - outer_offset
		for fraction_left in fractions:
			var y_left = lerp(start_y_left, end_y_left, clamp(fraction_left, 0.05, 0.95))
			if door_wall == wall:
				var door_top_left = door_pos.y
				var door_bottom_left = door_pos.y + door_size.y
				if y_left >= door_top_left - SETTINGS.KEY_SEPARATION * 0.5 and y_left <= door_bottom_left + SETTINGS.KEY_SEPARATION * 0.5:
					continue
			positions.append(Vector2(x_left, y_left))
	return positions

func _door_fallback_position(ring: Dictionary, layout: Dictionary):
	var wall = int(layout.get("wall", -1))
	var inner_margin: float = float(ring.get("inner_margin", SETTINGS.WALL_THICKNESS + SETTINGS.KEY_WALL_OFFSET))
	var left: float = float(ring.get("left", 0.0))
	var right: float = float(ring.get("right", 0.0))
	var top: float = float(ring.get("top", 0.0))
	var bottom: float = float(ring.get("bottom", 0.0))
	var center: Vector2 = layout.get("center", layout.get("position", Vector2.ZERO))
	var ring_index := int(ring.get("index", 0))
	var wall_thickness: float = float(ring.get("wall_thickness", SETTINGS.WALL_THICKNESS))
	var outer_offset := wall_thickness + SETTINGS.KEY_WALL_OFFSET * 0.5
	var use_interior := true
	match wall:
		0:
			return Vector2(center.x, top + inner_margin) if use_interior else Vector2(center.x, top - outer_offset)
		1:
			return Vector2(right - inner_margin, center.y) if use_interior else Vector2(right + outer_offset, center.y)
		2:
			return Vector2(center.x, bottom - inner_margin) if use_interior else Vector2(center.x, bottom + outer_offset)
		3:
			return Vector2(left + inner_margin, center.y) if use_interior else Vector2(left - outer_offset, center.y)
	return null

func _is_candidate_valid(candidate: Vector2, used_key_positions: Array, pending: Array) -> bool:
	if _context.exit_pos != Vector2.ZERO and candidate.distance_to(_context.exit_pos) < SETTINGS.EXIT_KEY_CLEARANCE:
		return false
	for pos in used_key_positions:
		if pos.distance_to(candidate) < SETTINGS.KEY_SEPARATION:
			return false
	for queued in pending:
		if queued.distance_to(candidate) < SETTINGS.KEY_SEPARATION:
			return false
	return true

func _opposite_wall(wall: int) -> int:
	return (wall + 2) % 4
