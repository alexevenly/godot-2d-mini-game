extends RefCounted
class_name ComplexMazeWallSpawner

const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")
const WALL_COLOR := Color(0.15, 0.18, 0.28, 1)

var _context

func _init(level_context):
	_context = level_context

func spawn(grid: Array, offset: Vector2, cell_size: float, main_scene) -> void:
	var rows = grid.size()
	if rows <= 0:
		return
	var cols = grid[0].size()
	var thickness = cell_size * _context.MAZE_WALL_SIZE_RATIO
	var half = thickness * 0.5
	for y in range(rows + 1):
		var x := 0
		while x < cols:
			while x < cols and not _needs_horizontal_wall(grid, y, x):
				x += 1
			if x >= cols:
				break
			var start = x
			while x < cols and _needs_horizontal_wall(grid, y, x):
				x += 1
			var span = x - start
			if span <= 0:
				continue
			var width = float(span) * cell_size
			var wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(_context.maze_walls.size(), width, thickness, WALL_COLOR)
			wall.position = offset + Vector2(start * cell_size, y * cell_size - half)
			_context.maze_walls.append(wall)
			_context.add_generated_node(wall, main_scene)
	for column in range(cols + 1):
		var y := 0
		while y < rows:
			while y < rows and not _needs_vertical_wall(grid, column, y):
				y += 1
			if y >= rows:
				break
			var start = y
			while y < rows and _needs_vertical_wall(grid, column, y):
				y += 1
			var span = y - start
			if span <= 0:
				continue
			var height = float(span) * cell_size
			var wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(_context.maze_walls.size(), thickness, height, WALL_COLOR)
			wall.position = offset + Vector2(column * cell_size - half, start * cell_size)
			_context.maze_walls.append(wall)
			_context.add_generated_node(wall, main_scene)

func _needs_horizontal_wall(grid: Array, y: int, x: int) -> bool:
	var rows = grid.size()
	if rows <= 0:
		return false
	var cols = grid[0].size()
	if x < 0 or x >= cols:
		return false
	if y <= 0:
		return not grid[0][x]
	if y >= rows:
		return not grid[rows - 1][x]
	return grid[y - 1][x] != grid[y][x]

func _needs_vertical_wall(grid: Array, x: int, y: int) -> bool:
	var rows = grid.size()
	if rows <= 0:
		return false
	var cols = grid[0].size()
	if y < 0 or y >= rows:
		return false
	if x <= 0:
		return not grid[y][0]
	if x >= cols:
		return not grid[y][cols - 1]
	return grid[y][x - 1] != grid[y][x]
