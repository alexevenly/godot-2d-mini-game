extends RefCounted
class_name ComplexMazeLayoutBuilder

const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const MAZE_UTILS := preload("res://scripts/level_generators/MazeUtils.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")
const MAZE_REACHABILITY_JOB: GDScript = preload("res://scripts/level_generators/MazeReachabilityJob.gd")
const WALL_COLOR := Color(0.15, 0.18, 0.28, 1)

var _context

var _maze_columns := 0
var _maze_rows := 0
var _all_cells: Dictionary = {}
var _unvisited: Array = []
var _stack: Array = []
var _centre_cells: Array = []
var _start_cell: Cell = null

const LEFT := 1
const RIGHT := 2
const UP := 3
const DOWN := 4

class Cell:
	var grid_pos: Vector2i
	var wall_left := true
	var wall_right := true
	var wall_up := true
	var wall_down := true

	func _init(pos: Vector2i):
		grid_pos = pos

func _init(level_context):
	_context = level_context

func build(main_scene, player_start_position: Vector2, debug_logger, player_collision_size: float, shadow_color: Color) -> Dictionary:
	var dims = LEVEL_UTILS.get_scaled_level_dimensions(_context.current_level_size)
	var level_width: float = float(dims.width)
	var level_height: float = float(dims.height)
	var offset = Vector2(dims.offset_x, dims.offset_y)
	var cell_size = _context.MAZE_BASE_CELL_SIZE
	var max_grid_cols = int(floor(level_width / cell_size))
	var max_grid_rows = int(floor(level_height / cell_size))
	max_grid_cols = max(max_grid_cols | 1, 5)
	max_grid_rows = max(max_grid_rows | 1, 5)
	var cell_cols = int((max_grid_cols - 1) / 2)
	var cell_rows = int((max_grid_rows - 1) / 2)
	if cell_cols % 2 != 0:
		cell_cols = max(cell_cols - 1, 2)
	if cell_rows % 2 != 0:
		cell_rows = max(cell_rows - 1, 2)
	cell_cols = max(cell_cols, 2)
	cell_rows = max(cell_rows, 2)
	_maze_columns = cell_cols
	_maze_rows = cell_rows
	var grid_cols = _maze_columns * 2 + 1
	var grid_rows = _maze_rows * 2 + 1
	var maze_width = float(grid_cols) * cell_size
	var maze_height = float(grid_rows) * cell_size
	var maze_offset = offset + Vector2((level_width - maze_width) * 0.5, (level_height - maze_height) * 0.5)
	_init_collections()
	_create_cells()
	_create_centre()
	_run_algorithm()
	var exit_data = _make_exit()
	var grid = _build_grid()
	_spawn_maze_walls(grid, maze_offset, cell_size, main_scene)
	_fill_unreachable_areas(main_scene, grid, exit_data.start_cell, maze_offset, cell_size, player_collision_size, shadow_color, debug_logger)
	var start_grid = _cell_to_grid_coords(_start_cell.grid_pos)
	var start_world = MAZE_UTILS.maze_cell_to_world(start_grid, maze_offset, cell_size)
	return {
		"grid": grid,
		"cols": grid_cols,
		"rows": grid_rows,
		"cell_size": cell_size,
		"maze_offset": maze_offset,
		"start_cell": start_grid,
		"start_world": start_world,
		"exit_cell": exit_data.exit_cell
	}

func _init_collections() -> void:
	_all_cells.clear()
	_unvisited.clear()
	_stack.clear()
	_centre_cells.clear()
	_start_cell = null

func _create_cells() -> void:
	for x in range(_maze_columns):
		for y in range(_maze_rows):
			var cell = Cell.new(Vector2i(x, y))
			_all_cells[cell.grid_pos] = cell
			_unvisited.append(cell)

func _create_centre() -> void:
	var left = int(_maze_columns / 2) - 1
	var right = int(_maze_columns / 2)
	var top = int(_maze_rows / 2) - 1
	var bottom = int(_maze_rows / 2)
	_centre_cells = [
		_all_cells.get(Vector2i(left, top)),
		_all_cells.get(Vector2i(right, top)),
		_all_cells.get(Vector2i(left, bottom)),
		_all_cells.get(Vector2i(right, bottom))
	]
	for i in range(_centre_cells.size()):
		if _centre_cells[i] == null:
			continue
	for cell in _centre_cells:
		if cell == null:
			continue
		if cell.grid_pos.x == left:
			_remove_wall(cell, RIGHT)
		else:
			_remove_wall(cell, LEFT)
		if cell.grid_pos.y == top:
			_remove_wall(cell, DOWN)
		else:
			_remove_wall(cell, UP)
	var indices = [0, 1, 2, 3]
	indices.shuffle()
	var start_index = indices.pop_front()
	_start_cell = _centre_cells[start_index]
	_current_remove_from_unvisited(_start_cell)
	for idx in indices:
		var centre = _centre_cells[idx]
		_current_remove_from_unvisited(centre)

func _current_remove_from_unvisited(cell: Cell) -> void:
	if cell == null:
		return
	if _unvisited.has(cell):
		_unvisited.erase(cell)

func _run_algorithm() -> void:
	if _start_cell == null:
		return
	var current = _start_cell
var wait_target = max(_unvisited.size() - 1, 0)
	while _unvisited.size() > 0:
		var neighbours = _get_unvisited_neighbours(current)
		if neighbours.size() > 0:
			var next_cell: Cell = neighbours[randi() % neighbours.size()]
			_stack.append(current)
			_compare_walls(current, next_cell)
			current = next_cell
			_current_remove_from_unvisited(current)
		else:
			if _stack.size() <= 0:
				break
			current = _stack.pop_back()

func _get_unvisited_neighbours(cell: Cell) -> Array:
	var result: Array = []
	if cell == null:
		return result
	var pos = cell.grid_pos
	var offsets = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for offset in offsets:
		var candidate_pos = pos + offset
		if not _all_cells.has(candidate_pos):
			continue
		var candidate: Cell = _all_cells[candidate_pos]
		if candidate == null:
			continue
		if _unvisited.has(candidate):
			result.append(candidate)
	return result

func _compare_walls(current: Cell, neighbour: Cell) -> void:
	if current == null or neighbour == null:
		return
	if neighbour.grid_pos.x < current.grid_pos.x:
		_remove_wall(neighbour, RIGHT)
		_remove_wall(current, LEFT)
	elif neighbour.grid_pos.x > current.grid_pos.x:
		_remove_wall(neighbour, LEFT)
		_remove_wall(current, RIGHT)
	elif neighbour.grid_pos.y > current.grid_pos.y:
		_remove_wall(neighbour, UP)
		_remove_wall(current, DOWN)
	else:
		_remove_wall(neighbour, DOWN)
		_remove_wall(current, UP)

func _remove_wall(cell: Cell, direction: int) -> void:
	if cell == null:
		return
	match direction:
		LEFT:
			cell.wall_left = false
		RIGHT:
			cell.wall_right = false
		UP:
			cell.wall_up = false
		DOWN:
			cell.wall_down = false

func _make_exit() -> Dictionary:
	var edge_cells: Array = []
	for cell in _all_cells.values():
		var typed_cell: Cell = cell
		if typed_cell == null:
			continue
		var pos = typed_cell.grid_pos
		if pos.x == 0 or pos.x == _maze_columns - 1 or pos.y == 0 or pos.y == _maze_rows - 1:
			edge_cells.append(typed_cell)
	var distances = _compute_distances(_start_cell)
	var best_cell: Cell = _start_cell
	var best_distance := -1
	for cell in edge_cells:
		var dist = int(distances.get(cell, -1))
		if dist > best_distance:
			best_distance = dist
			best_cell = cell
	var exit_cell = _make_exit_in_cell(best_cell)
	return {
		"exit_cell": exit_cell,
		"start_cell": _cell_to_grid_coords(_start_cell.grid_pos)
	}

func _compute_distances(start_cell: Cell) -> Dictionary:
	var distances: Dictionary = {}
	if start_cell == null:
		return distances
	var queue: Array = []
	queue.append(start_cell)
	distances[start_cell] = 0
	while queue.size() > 0:
		var current: Cell = queue.pop_front()
		var base_distance = int(distances.get(current, 0))
		for neighbour in _get_connected_neighbours(current):
			if distances.has(neighbour):
				continue
			distances[neighbour] = base_distance + 1
			queue.append(neighbour)
	return distances

func _get_connected_neighbours(cell: Cell) -> Array:
	var result: Array = []
	if cell == null:
		return result
	var pos = cell.grid_pos
	if pos.x > 0:
		var left_cell: Cell = _all_cells.get(Vector2i(pos.x - 1, pos.y))
		if left_cell and not cell.wall_left and not left_cell.wall_right:
			result.append(left_cell)
	if pos.x < _maze_columns - 1:
		var right_cell: Cell = _all_cells.get(Vector2i(pos.x + 1, pos.y))
		if right_cell and not cell.wall_right and not right_cell.wall_left:
			result.append(right_cell)
	if pos.y > 0:
		var up_cell: Cell = _all_cells.get(Vector2i(pos.x, pos.y - 1))
		if up_cell and not cell.wall_up and not up_cell.wall_down:
			result.append(up_cell)
	if pos.y < _maze_rows - 1:
		var down_cell: Cell = _all_cells.get(Vector2i(pos.x, pos.y + 1))
		if down_cell and not cell.wall_down and not down_cell.wall_up:
			result.append(down_cell)
	return result

func _make_exit_in_cell(cell: Cell) -> Vector2i:
	if cell == null:
		return Vector2i.ZERO
	var grid_coords = _cell_to_grid_coords(cell.grid_pos)
	var exit_coords = grid_coords
	if cell.grid_pos.x == 0:
		_remove_wall(cell, LEFT)
		exit_coords = Vector2i(grid_coords.x - 1, grid_coords.y)
	elif cell.grid_pos.x == _maze_columns - 1:
		_remove_wall(cell, RIGHT)
		exit_coords = Vector2i(grid_coords.x + 1, grid_coords.y)
	elif cell.grid_pos.y == _maze_rows - 1:
		_remove_wall(cell, DOWN)
		exit_coords = Vector2i(grid_coords.x, grid_coords.y + 1)
	else:
		_remove_wall(cell, UP)
		exit_coords = Vector2i(grid_coords.x, grid_coords.y - 1)
	return exit_coords

func _cell_to_grid_coords(pos: Vector2i) -> Vector2i:
	return Vector2i(pos.x * 2 + 1, pos.y * 2 + 1)

func _build_grid() -> Array:
	var rows = _maze_rows * 2 + 1
	var cols = _maze_columns * 2 + 1
	var grid: Array = []
	for y in range(rows):
		var row := []
		row.resize(cols)
		for x in range(cols):
			row[x] = true
		grid.append(row)
	for cell in _all_cells.values():
		var typed: Cell = cell
		if typed == null:
			continue
		var grid_pos = _cell_to_grid_coords(typed.grid_pos)
		grid[grid_pos.y][grid_pos.x] = false
		if not typed.wall_left:
			grid[grid_pos.y][grid_pos.x - 1] = false
		if not typed.wall_right:
			grid[grid_pos.y][grid_pos.x + 1] = false
		if not typed.wall_up:
			grid[grid_pos.y - 1][grid_pos.x] = false
		if not typed.wall_down:
			grid[grid_pos.y + 1][grid_pos.x] = false
	return grid

func _spawn_maze_walls(grid: Array, offset: Vector2, cell_size: float, main_scene) -> void:
	var rows = grid.size()
	if rows <= 0:
		return
	var cols = grid[0].size()
	var thickness = cell_size * _context.MAZE_WALL_SIZE_RATIO
	var half_thickness = thickness * 0.5
	for y in range(rows):
		for x in range(cols):
			if not grid[y][x]:
				continue
			var base := offset + Vector2(x * cell_size, y * cell_size)
			if y == 0 or not grid[y - 1][x]:
				var top_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(_context.maze_walls.size(), cell_size, thickness, WALL_COLOR)
				top_wall.position = base + Vector2(0.0, -half_thickness)
				_context.maze_walls.append(top_wall)
				_context.add_generated_node(top_wall, main_scene)
			if y == rows - 1 or not grid[y + 1][x]:
				var bottom_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(_context.maze_walls.size(), cell_size, thickness, WALL_COLOR)
				bottom_wall.position = base + Vector2(0.0, cell_size - half_thickness)
				_context.maze_walls.append(bottom_wall)
				_context.add_generated_node(bottom_wall, main_scene)
			if x == 0 or not grid[y][x - 1]:
				var left_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(_context.maze_walls.size(), thickness, cell_size, WALL_COLOR)
				left_wall.position = base + Vector2(-half_thickness, 0.0)
				_context.maze_walls.append(left_wall)
				_context.add_generated_node(left_wall, main_scene)
			if x == cols - 1 or not grid[y][x + 1]:
				var right_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(_context.maze_walls.size(), thickness, cell_size, WALL_COLOR)
				right_wall.position = base + Vector2(cell_size - half_thickness, 0.0)
				_context.maze_walls.append(right_wall)
				_context.add_generated_node(right_wall, main_scene)

func _fill_unreachable_areas(main_scene, grid: Array, start_cell: Vector2i, offset: Vector2, cell_size: float, player_collision_size: float, shadow_color: Color, debug_logger) -> void:
	var job = MAZE_REACHABILITY_JOB.new()
	var logger_callable := Callable()
	var debug_enabled: bool = debug_logger and debug_logger.is_enabled()
	if debug_enabled:
		logger_callable = Callable(debug_logger, "log")
	job.setup(
		_context,
		main_scene,
		grid.duplicate(true),
		start_cell,
		offset,
		cell_size,
		player_collision_size,
		shadow_color,
		debug_enabled,
		logger_callable
	)
	if _context and _context is Node:
		_context.add_child(job)
	elif main_scene and is_instance_valid(main_scene):
		main_scene.call_deferred("add_child", job)
	else:
		job.queue_free()
