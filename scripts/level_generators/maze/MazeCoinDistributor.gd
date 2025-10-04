extends RefCounted
class_name MazeCoinDistributor

const MAZE_UTILS := preload("res://scripts/level_generators/MazeUtils.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")

var _context

func _init(level_context):
	_context = level_context

func populate(grid: Array, start_cell: Vector2i, exit_cell: Vector2i, offset: Vector2, cell_size: float, main_scene) -> void:
	var rows = grid.size()
	if rows <= 0:
		return
	var cols = grid[0].size()
	var candidates: Array = []
	for y in range(rows):
		for x in range(cols):
			if grid[y][x]:
				continue
			var cell = Vector2i(x, y)
			if cell == start_cell or cell == exit_cell:
				continue
			if (abs(cell.x - start_cell.x) + abs(cell.y - start_cell.y)) < 3:
				continue
			candidates.append(cell)
	candidates.shuffle()
	var desired = clamp(int(candidates.size() / 8.0), 5, 20)
	for i in range(min(desired, candidates.size())):
		var cell = candidates[i]
		var world_pos = MAZE_UTILS.maze_cell_to_world(cell, offset, cell_size)
		var coin = LEVEL_NODE_FACTORY.create_coin_node(_context.coins.size(), world_pos)
		_context.coins.append(coin)
		_context.add_generated_node(coin, main_scene)
