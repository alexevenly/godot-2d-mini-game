extends RefCounted

class_name KeyRingBarrierBuilder

const SETTINGS := preload("res://scripts/level_generators/key/KeyRingSettings.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")

var _context

func _init(level_context):
	_context = level_context

func spawn(rings: Array, main_scene) -> void:
	for ring in rings:
		if typeof(ring) != TYPE_DICTIONARY:
			continue
		for wall in range(4):
			var door_spans: Array = []
			for door_layout in ring.get("doors", []):
				if typeof(door_layout) != TYPE_DICTIONARY:
					continue
				if int(door_layout.get("wall", -1)) == wall:
					door_spans.append(door_layout)
			_spawn_for_wall(ring, wall, door_spans, main_scene)

func _spawn_for_wall(ring: Dictionary, wall: int, door_spans: Array, main_scene) -> void:
	var wall_thickness: float = float(ring.get("wall_thickness", SETTINGS.WALL_THICKNESS))
	var left: float = float(ring.get("left", 0.0))
	var right: float = float(ring.get("right", 0.0))
	var top: float = float(ring.get("top", 0.0))
	var bottom: float = float(ring.get("bottom", 0.0))
	var sorted = door_spans.duplicate()
	sorted.sort_custom(func(a, b):
		if wall == 0 or wall == 2:
			return float(a.get("position", Vector2.ZERO).x) < float(b.get("position", Vector2.ZERO).x)
		return float(a.get("position", Vector2.ZERO).y) < float(b.get("position", Vector2.ZERO).y))
	match wall:
		0:
			var cursor = left
			var wall_y = top - wall_thickness
			for span in sorted:
				var door_pos: Vector2 = span.get("position", Vector2.ZERO)
				var door_width: float = float(span.get("size", Vector2.ZERO).x)
				if door_pos.x > cursor:
					_spawn_segment(Vector2(cursor, wall_y), door_pos.x - cursor, wall_thickness, main_scene)
				cursor = max(cursor, door_pos.x + door_width)
			if right - cursor > 1.0:
				_spawn_segment(Vector2(cursor, wall_y), right - cursor, wall_thickness, main_scene)
		1:
			var cursor_y = top
			var wall_x = right - wall_thickness
			for span_right in sorted:
				var door_pos_right: Vector2 = span_right.get("position", Vector2.ZERO)
				var door_height: float = float(span_right.get("size", Vector2.ZERO).y)
				if door_pos_right.y > cursor_y:
					_spawn_segment(Vector2(wall_x, cursor_y), wall_thickness, door_pos_right.y - cursor_y, main_scene)
				cursor_y = max(cursor_y, door_pos_right.y + door_height)
			if bottom - cursor_y > 1.0:
				_spawn_segment(Vector2(wall_x, cursor_y), wall_thickness, bottom - cursor_y, main_scene)
		2:
			var bottom_cursor = left
			var bottom_y = bottom - wall_thickness
			for span_bottom in sorted:
				var bottom_pos: Vector2 = span_bottom.get("position", Vector2.ZERO)
				var bottom_width: float = float(span_bottom.get("size", Vector2.ZERO).x)
				if bottom_pos.x > bottom_cursor:
					_spawn_segment(Vector2(bottom_cursor, bottom_y), bottom_pos.x - bottom_cursor, wall_thickness, main_scene)
				bottom_cursor = max(bottom_cursor, bottom_pos.x + bottom_width)
			if right - bottom_cursor > 1.0:
				_spawn_segment(Vector2(bottom_cursor, bottom_y), right - bottom_cursor, wall_thickness, main_scene)
		3:
			var left_cursor = top
			var left_x = left
			for span_left in sorted:
				var left_pos: Vector2 = span_left.get("position", Vector2.ZERO)
				var left_height: float = float(span_left.get("size", Vector2.ZERO).y)
				if left_pos.y > left_cursor:
					_spawn_segment(Vector2(left_x, left_cursor), wall_thickness, left_pos.y - left_cursor, main_scene)
				left_cursor = max(left_cursor, left_pos.y + left_height)
			if bottom - left_cursor > 1.0:
				_spawn_segment(Vector2(left_x, left_cursor), wall_thickness, bottom - left_cursor, main_scene)

func _spawn_segment(position: Vector2, width: float, height: float, main_scene) -> void:
	if width <= 0.0 or height <= 0.0:
		return
	var barrier = LEVEL_NODE_FACTORY.create_barrier_segment(_context.key_barriers.size(), width, height, SETTINGS.BARRIER_COLOR)
	barrier.position = position
	_context.key_barriers.append(barrier)
	_context.add_generated_node(barrier, main_scene)
