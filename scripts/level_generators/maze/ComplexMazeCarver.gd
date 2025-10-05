extends RefCounted
class_name ComplexMazeCarver

const LEFT := 1
const RIGHT := 2
const UP := 3
const DOWN := 4

const GRAPH := preload("res://scripts/level_generators/maze/ComplexMazeGraph.gd")

const EXTRA_CONNECTION_RATIO := 0.22

class Cell:
	var grid_pos: Vector2i
	var wall_left := true
	var wall_right := true
	var wall_up := true
	var wall_down := true
	func _init(pos: Vector2i):
		grid_pos = pos

var _columns := 0
var _rows := 0
var _cells: Dictionary = {}
var _unvisited: Array = []
var _stack: Array = []
var _start_cell: Cell = null

func generate(columns: int, rows: int, allow_multiple_paths := true) -> Dictionary:
	_columns = max(columns, 1)
	_rows = max(rows, 1)
	_init_collections()
	_create_cells()
	_select_start_cell()
	_run_algorithm()
	if allow_multiple_paths:
		_add_extra_connections()
	var exit_cell := GRAPH.pick_exit_cell(_cells, _columns, _rows, _start_cell)
	var exit_grid := _make_exit_in_cell(exit_cell)
	return {
		"grid": _build_grid(),
		"start_cell": _cell_to_grid_coords(_start_cell.grid_pos) if _start_cell else Vector2i.ZERO,
		"exit_cell": exit_grid,
		"grid_cols": _columns * 2 + 1,
		"grid_rows": _rows * 2 + 1
	}

func _init_collections() -> void:
	_cells.clear()
	_unvisited.clear()
	_stack.clear()
	_start_cell = null

func _create_cells() -> void:
	for x in range(_columns):
		for y in range(_rows):
			var cell = Cell.new(Vector2i(x, y))
			_cells[cell.grid_pos] = cell
			_unvisited.append(cell)

func _select_start_cell() -> void:
	if _cells.is_empty():
		return
	var center = Vector2i(_columns / 2, _rows / 2)
	_start_cell = _cells.get(center)
	if _start_cell == null:
		var values: Array = _cells.values()
		if values.size() > 0:
			values.shuffle()
			_start_cell = values[0]
	if _start_cell:
		_remove_from_unvisited(_start_cell)

func _run_algorithm() -> void:
	if _start_cell == null:
		return
	var current = _start_cell
	while _unvisited.size() > 0:
		var neighbours = _get_unvisited_neighbours(current)
		if neighbours.size() > 0:
			var next_cell: Cell = neighbours[randi() % neighbours.size()]
			_stack.append(current)
			_compare_walls(current, next_cell)
			current = next_cell
			_remove_from_unvisited(current)
		elif _stack.size() > 0:
			current = _stack.pop_back()
		else:
			break

func _get_unvisited_neighbours(cell: Cell) -> Array:
	var result: Array = []
	if cell == null:
		return result
	var pos = cell.grid_pos
	for offset in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var candidate: Cell = _cells.get(pos + offset)
		if candidate and _unvisited.has(candidate):
			result.append(candidate)
	return result

func _remove_from_unvisited(cell: Cell) -> void:
	if cell and _unvisited.has(cell):
		_unvisited.erase(cell)

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

func _add_extra_connections() -> void:
	var candidates = _collect_closed_edges()
	if candidates.is_empty():
		return
	candidates.shuffle()
	var target = int(round(candidates.size() * EXTRA_CONNECTION_RATIO))
	target = clamp(target, 1, candidates.size())
	for i in range(target):
		var entry: Dictionary = candidates[i]
		var first: Cell = entry.get("cell")
		var second: Cell = entry.get("neighbour")
		var direction: int = entry.get("direction", LEFT)
		if first == null or second == null:
			continue
		_remove_wall(first, direction)
		_remove_wall(second, _opposite_direction(direction))

func _collect_closed_edges() -> Array:
	var edges: Array = []
	for value in _cells.values():
		var cell: Cell = value
		if cell == null:
			continue
		var pos: Vector2i = cell.grid_pos
		if pos.x > 0:
			var left = _cells.get(Vector2i(pos.x - 1, pos.y))
			if left and cell.wall_left and left.wall_right:
				edges.append({
					"cell": cell,
					"neighbour": left,
					"direction": LEFT
				})
		if pos.y > 0:
			var up = _cells.get(Vector2i(pos.x, pos.y - 1))
			if up and cell.wall_up and up.wall_down:
				edges.append({
					"cell": cell,
					"neighbour": up,
					"direction": UP
				})
	return edges

func _opposite_direction(direction: int) -> int:
	match direction:
		LEFT:
			return RIGHT
		RIGHT:
			return LEFT
		UP:
			return DOWN
		DOWN:
			return UP
	return LEFT

func _make_exit_in_cell(cell: Cell) -> Vector2i:
	if cell == null:
		return Vector2i.ZERO
	var grid_coords = _cell_to_grid_coords(cell.grid_pos)
	var exit_coords = grid_coords
	if cell.grid_pos.x == 0:
		_remove_wall(cell, LEFT)
		exit_coords = Vector2i(grid_coords.x - 1, grid_coords.y)
	elif cell.grid_pos.x == _columns - 1:
		_remove_wall(cell, RIGHT)
		exit_coords = Vector2i(grid_coords.x + 1, grid_coords.y)
	elif cell.grid_pos.y == _rows - 1:
		_remove_wall(cell, DOWN)
		exit_coords = Vector2i(grid_coords.x, grid_coords.y + 1)
	else:
		_remove_wall(cell, UP)
		exit_coords = Vector2i(grid_coords.x, grid_coords.y - 1)
	return exit_coords

func _cell_to_grid_coords(pos: Vector2i) -> Vector2i:
	return Vector2i(pos.x * 2 + 1, pos.y * 2 + 1)

func _build_grid() -> Array:
	var rows = _rows * 2 + 1
	var cols = _columns * 2 + 1
	var grid: Array = []
	for y in range(rows):
		var row := []
		row.resize(cols)
		for x in range(cols):
			row[x] = true
		grid.append(row)
	for cell in _cells.values():
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
