extends RefCounted

class_name KeyLevelGenerator

const LOGGER := preload("res://scripts/Logger.gd")
const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")

const MIN_GRID_SIZE := 12
const MAX_GRID_SIZE := 20
const MAX_GENERATION_ATTEMPTS := 32
const OBSTACLE_RATIO := 0.12
const COLORS := ["R", "Y", "B", "P"]
const OUTER_OBSTACLE_COLOR := Color(0.36, 0.17, 0.08, 1.0)
const INNER_OBSTACLE_COLOR := Color(0.55, 0.55, 0.55, 1.0)

var context
var obstacle_utils
var last_generated_grid: Array = []

var _rng := RandomNumberGenerator.new()
var _use_custom_seed := false
var _seed_value := 0

func _init(level_context, obstacle_helper):
	context = level_context
	obstacle_utils = obstacle_helper
	_rng.randomize()

func set_seed(value: int) -> void:
	_use_custom_seed = true
	_seed_value = value

func get_last_generated_grid() -> Array:
	return last_generated_grid

func generate(main_scene, level: int, player_start_position: Vector2) -> void:
	var dims: Dictionary = LEVEL_UTILS.get_scaled_level_dimensions(context.current_level_size)
	_reset_rng(level)
	var layout: Dictionary = _build_level_layout(level)
	if layout.is_empty():
		LOGGER.log_error("KeyLevelGenerator failed to build solvable layout")
		return
	last_generated_grid = layout.get("grid", [])
	_spawn_from_grid(layout, dims, main_scene)

func _reset_rng(level: int) -> void:
	if _use_custom_seed:
		_rng.seed = _seed_value
	else:
		_rng.seed = hash([Time.get_ticks_usec(), level, randi()])

func _build_level_layout(level: int) -> Dictionary:
	for attempt in range(MAX_GENERATION_ATTEMPTS):
		var width: int = _rng.randi_range(MIN_GRID_SIZE, MAX_GRID_SIZE)
		var height: int = _rng.randi_range(MIN_GRID_SIZE, MAX_GRID_SIZE)
		var grid: Array = _create_empty_grid(width, height)
		var start: Vector2i = Vector2i(width / 2, height / 2)
		var exit_cell: Variant = _choose_exit_cell(width, height, start)
		if exit_cell == null:
			continue
		_place_outer_walls(grid)
		if not _place_internal_obstacles(grid, start, exit_cell):
			continue
		var path: Array = _find_path(grid, start, exit_cell)
		if path.is_empty():
			continue
		var door_count: int = _select_door_count(path.size())
		if door_count < 2:
			continue
		var door_infos: Array = _place_doors_on_path(grid, path, door_count)
		if door_infos.is_empty():
			continue
		var key_infos: Array = _place_keys(grid, start, door_infos, path, exit_cell)
		if key_infos.is_empty() or key_infos.size() != door_infos.size():
			continue
		grid[start.y][start.x] = "S"
		grid[exit_cell.y][exit_cell.x] = "E"
		if not _validate_map(grid, start, exit_cell, door_infos, key_infos):
			continue
		return {
			"grid": grid,
			"start": start,
			"exit": exit_cell,
			"doors": door_infos,
			"keys": key_infos
		}
	return {}

func _select_door_count(path_length: int) -> int:
	var max_pairs: int = min(COLORS.size(), 4)
	var min_pairs: int = 2
	var span: int = max(path_length - 6, 1)
	var target: int = clamp(int(floor(span / 6)), min_pairs, max_pairs)
	return clamp(_rng.randi_range(min_pairs, max_pairs), min_pairs, target)

func _create_empty_grid(width: int, height: int) -> Array:
	var result: Array = []
	for _y in range(height):
		var row: Array = []
		for _x in range(width):
			row.append(".")
		result.append(row)
	return result

func _place_outer_walls(grid: Array) -> void:
	var height: int = grid.size()
	var width: int = grid[0].size()
	for x in range(width):
		grid[0][x] = "#"
		grid[height - 1][x] = "#"
	for y in range(height):
		grid[y][0] = "#"
		grid[y][width - 1] = "#"

func _choose_exit_cell(width: int, height: int, start: Vector2i) -> Variant:
	var candidates: Array = []
	for x in range(2, width - 2):
		candidates.append(Vector2i(x, 1))
		candidates.append(Vector2i(x, height - 2))
	for y in range(2, height - 2):
		candidates.append(Vector2i(1, y))
		candidates.append(Vector2i(width - 2, y))
	while not candidates.is_empty():
		var index: int = _rng.randi_range(0, candidates.size() - 1)
		var cell: Vector2i = candidates[index]
		candidates.remove_at(index)
		if cell == start:
			continue
		return cell
	return null

func _place_internal_obstacles(grid: Array, start: Vector2i, exit_cell: Vector2i) -> bool:
	var height: int = grid.size()
	var width: int = grid[0].size()
	var interior: Array = []
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var cell: Vector2i = Vector2i(x, y)
			if cell == start or cell == exit_cell:
				continue
			interior.append(cell)
	var desired: int = int(ceil(interior.size() * OBSTACLE_RATIO))
	var attempts: int = 0
	while attempts < interior.size() and desired > 0:
		var index: int = _rng.randi_range(0, interior.size() - 1)
		var cell: Vector2i = interior[index]
		interior.remove_at(index)
		var prev: String = String(grid[cell.y][cell.x])
		grid[cell.y][cell.x] = "#"
		if _has_path(grid, start, exit_cell):
			desired -= 1
		else:
			grid[cell.y][cell.x] = prev
		attempts += 1
	return _has_path(grid, start, exit_cell)

func _has_path(grid: Array, start: Vector2i, goal: Vector2i) -> bool:
	return not _find_path(grid, start, goal).is_empty()

func _find_path(grid: Array, start: Vector2i, goal: Vector2i) -> Array:
	var width: int = grid[0].size()
	var height: int = grid.size()
	var queue: Array = [start]
	var came_from: Dictionary = {}
	came_from[start] = start
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal:
			return _reconstruct_path(came_from, start, goal)
		for neighbor in _neighbors(cell, width, height):
			if came_from.has(neighbor):
				continue
			var tile: String = grid[neighbor.y][neighbor.x]
			if tile == "#":
				continue
			came_from[neighbor] = cell
			queue.append(neighbor)
	return []

func _reconstruct_path(came_from: Dictionary, start: Vector2i, goal: Vector2i) -> Array:
	var path: Array = []
	var current: Vector2i = goal
	while current != start:
		path.push_front(current)
		current = came_from.get(current, start)
	path.push_front(start)
	return path

func _neighbors(cell: Vector2i, width: int, height: int) -> Array:
	var result: Array = []
	var deltas: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for delta in deltas:
		var next: Vector2i = cell + delta
		if next.x < 0 or next.x >= width or next.y < 0 or next.y >= height:
			continue
		result.append(next)
	return result

func _place_doors_on_path(grid: Array, path: Array, door_count: int) -> Array:
	var door_infos: Array = []
	var step: int = max(2, int(floor(path.size() / float(door_count + 1))))
	var last_index: int = 1
	for i in range(door_count):
		var min_index: int = last_index + 1
		var max_index: int = path.size() - (door_count - i) * 2
		if min_index >= max_index:
			return []
		var index: int = clamp(int(round(float(i + 1) * float(step))), min_index, max_index)
		var cell: Vector2i = path[index]
		var after_cell: Vector2i = path[index + 1]
		var color_code: String = COLORS[i % COLORS.size()]
		grid[cell.y][cell.x] = "D_%s" % color_code
		door_infos.append({
			"cell": cell,
			"after": after_cell,
			"color": color_code,
			"tile": "D_%s" % color_code
		})
		last_index = index
	return door_infos

func _place_keys(grid: Array, start: Vector2i, door_infos: Array, path: Array, exit_cell: Vector2i) -> Array:
	var key_infos: Array = []
	var collected: Dictionary = {}
	var path_lookup: Dictionary = {}
	for cell in path:
		path_lookup[cell] = true
	var current_start: Vector2i = start
	for door_info in door_infos:
		var reachable: Dictionary = _flood_fill_with_keys(grid, current_start, collected)
		var candidates: Array = []
		for cell in reachable.keys():
			if cell == start or cell == exit_cell:
				continue
			if path_lookup.has(cell) and _rng.randf() < 0.6:
				continue
			var blocked: bool = false
			for existing in key_infos:
				if existing.get("cell", Vector2i(-1, -1)) == cell:
					blocked = true
					break
			if blocked:
				continue
			if grid[cell.y][cell.x] == "#":
				continue
			candidates.append(cell)
		if candidates.is_empty():
			candidates = reachable.keys()
		if candidates.is_empty():
			return []
		var chosen: Vector2i = candidates[_rng.randi_range(0, candidates.size() - 1)]
		var color_code: String = door_info.get("color", "R")
		collected[color_code] = true
		key_infos.append({
			"cell": chosen,
			"color": color_code,
			"tile": "K_%s" % color_code
		})
		grid[chosen.y][chosen.x] = "K_%s" % color_code
		var reachable_after: Dictionary = _flood_fill_with_keys(grid, current_start, collected)
		var after_cell: Vector2i = door_info.get("after", current_start)
		if not reachable_after.has(after_cell):
			return []
		current_start = after_cell
	return key_infos

func _flood_fill_with_keys(grid: Array, start: Vector2i, collected: Dictionary) -> Dictionary:
	var width: int = grid[0].size()
	var height: int = grid.size()
	var visited: Dictionary = {}
	var queue: Array = []
	if not _is_walkable(grid, start, collected):
		return visited
	visited[start] = true
	queue.append(start)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for neighbor in _neighbors(cell, width, height):
			if visited.has(neighbor):
				continue
			if not _is_walkable(grid, neighbor, collected):
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return visited

func _is_walkable(grid: Array, cell: Vector2i, collected: Dictionary) -> bool:
	var tile: String = grid[cell.y][cell.x]
	if tile == "#":
		return false
	if tile.begins_with("D_"):
		var color_code: String = tile.substr(2, tile.length() - 2)
		return collected.has(color_code)
	return true

func _validate_map(grid: Array, start: Vector2i, exit_cell: Vector2i, door_infos: Array, key_infos: Array) -> bool:
	var collected: Dictionary = {}
	var key_lookup: Dictionary = {}
	for key_info in key_infos:
		key_lookup[key_info.get("color", "R")] = key_info.get("cell", Vector2i(-1, -1))
	var current_start: Vector2i = start
	for door_info in door_infos:
		var reachable: Dictionary = _flood_fill_with_keys(grid, current_start, collected)
		var key_cell: Vector2i = key_lookup.get(door_info.get("color", "R"), Vector2i(-1, -1))
		if not reachable.has(key_cell):
			return false
		var color_code: String = door_info.get("color", "R")
		collected[color_code] = true
		var reachable_after: Dictionary = _flood_fill_with_keys(grid, current_start, collected)
		var after_cell: Vector2i = door_info.get("after", current_start)
		if not reachable_after.has(after_cell):
			return false
		current_start = after_cell
	var final_reachable: Dictionary = _flood_fill_with_keys(grid, current_start, collected)
	return final_reachable.has(exit_cell)


func _spawn_from_grid(layout: Dictionary, dims: Dictionary, main_scene) -> void:
	if context == null:
		return
	context.obstacles = []
	context.doors = []
	context.key_items.clear()
	context.key_barriers = []
	context.coins.clear()
	var grid: Array = layout.get("grid", [])
	if grid.is_empty():
		return
	var rows: int = grid.size()
	var cols: int = grid[0].size()
	var cell_size: float = min(dims.width / float(cols), dims.height / float(rows))
	var offset_x: float = dims.offset_x + (dims.width - cell_size * cols) * 0.5
	var offset_y: float = dims.offset_y + (dims.height - cell_size * rows) * 0.5
	var door_nodes: Dictionary = {}
	var door_index: int = 0
	var pending_keys: Array = []
	if context.exit_spawner and is_instance_valid(context.exit_spawner):
		context.exit_spawner.clear_exit()
	for y in range(rows):
		for x in range(cols):
			var tile: String = grid[y][x]
			var cell: Vector2i = Vector2i(x, y)
			var world_center: Vector2 = _cell_to_world(cell, cell_size, offset_x, offset_y)
			if tile == "#":
				var color: Color = OUTER_OBSTACLE_COLOR if _is_outer_wall(cell, cols, rows) else INNER_OBSTACLE_COLOR
				var obstacle: StaticBody2D = _create_wall_obstacle(context.obstacles.size(), world_center, cell_size, color)
				context.obstacles.append(obstacle)
				context.add_generated_node(obstacle, main_scene)
			elif tile == "S":
				context.set_player_spawn_override(world_center)
			elif tile == "E":
				context.exit_pos = world_center
				if context.exit_spawner and is_instance_valid(context.exit_spawner):
					var exit_size: int = 64
					var exit_position: Vector2 = world_center - Vector2(exit_size * 0.5, exit_size * 0.5)
					context.exit_spawner.create_exit_at(exit_position, main_scene)
					var exit_node: Node = context.exit_spawner.get_exit()
					if exit_node:
						context.exit_pos = exit_node.position + Vector2(exit_size * 0.5, exit_size * 0.5)
			elif tile.begins_with("D_"):
				var color_code: String = tile.substr(2, tile.length() - 2)
				var door_color: Color = context.get_group_color(door_index)
				var door: StaticBody2D = LEVEL_NODE_FACTORY.create_door_node(door_index, 1, false, cell_size, cell_size, door_color)
				door.position = world_center - Vector2(cell_size * 0.5, cell_size * 0.5)
				context.doors.append(door)
				context.add_generated_node(door, main_scene)
				door_nodes[color_code] = door
				door_index += 1
			elif tile.begins_with("K_"):
				pending_keys.append({
					"code": tile.substr(2, tile.length() - 2),
					"center": world_center
				})
	for key_data in pending_keys:
		var color_code: String = key_data.get("code", "R")
		var door_ref: StaticBody2D = door_nodes.get(color_code, null)
		if door_ref == null:
			continue
		door_ref.initially_open = false
		var key_center: Vector2 = key_data.get("center", Vector2.ZERO)
		var key_position: Vector2 = key_center - Vector2(12, 12)
		var key_node: Area2D = LEVEL_NODE_FACTORY.create_key_node(context.key_items.size(), door_ref, key_position, 1, door_ref.door_color)
		context.key_items.append(key_node)
		context.add_generated_node(key_node, main_scene)
		obstacle_utils.clear_around_position(key_center, cell_size * 0.6)

func _cell_to_world(cell: Vector2i, cell_size: float, offset_x: float, offset_y: float) -> Vector2:
	return Vector2(offset_x + cell_size * (cell.x + 0.5), offset_y + cell_size * (cell.y + 0.5))

func _create_wall_obstacle(index: int, center: Vector2, cell_size: float, color: Color) -> StaticBody2D:
	var obstacle := StaticBody2D.new()
	obstacle.name = "KeyLevelObstacle%d" % index
	obstacle.position = center - Vector2(cell_size * 0.5, cell_size * 0.5)
	var body := ColorRect.new()
	body.name = "ObstacleBody"
	body.offset_right = cell_size
	body.offset_bottom = cell_size
	body.color = color
	obstacle.add_child(body)
	var collision := CollisionShape2D.new()
	collision.name = "ObstacleCollision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cell_size, cell_size)
	collision.shape = shape
	collision.position = Vector2(cell_size * 0.5, cell_size * 0.5)
	obstacle.add_child(collision)
	return obstacle

func _is_outer_wall(cell: Vector2i, cols: int, rows: int) -> bool:
	return cell.x == 0 or cell.y == 0 or cell.x == cols - 1 or cell.y == rows - 1
