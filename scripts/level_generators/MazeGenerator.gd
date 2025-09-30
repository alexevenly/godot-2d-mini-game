extends RefCounted
class_name MazeGenerator

const Logger = preload("res://scripts/Logger.gd")
const LevelUtils = preload("res://scripts/LevelUtils.gd")
const MazeUtils = preload("res://scripts/level_generators/MazeUtils.gd")
const LevelNodeFactory = preload("res://scripts/level_generators/LevelNodeFactory.gd")

const WALL_COLOR := Color(0.15, 0.18, 0.28, 1)

var context
func _init(level_context, _obstacle_helper):
	context = level_context

func generate_maze_level(include_coins: bool, main_scene, player_start_position: Vector2) -> void:
	var dims = LevelUtils.get_scaled_level_dimensions(context.current_level_size)
	var level_width: float = float(dims.width)
	var level_height: float = float(dims.height)
	var offset = Vector2(dims.offset_x, dims.offset_y)

	var cell_size = context.MAZE_BASE_CELL_SIZE
	var cols = int(floor(level_width / cell_size))
	var rows = int(floor(level_height / cell_size))
	cols = max(cols | 1, 5)
	rows = max(rows | 1, 5)
	var maze_width = cols * cell_size
	var maze_height = rows * cell_size
	var maze_offset = offset + Vector2((level_width - maze_width) * 0.5, (level_height - maze_height) * 0.5)

	var start_cell = MazeUtils.world_to_maze_cell(player_start_position, maze_offset, cell_size)
	start_cell = MazeUtils.ensure_odd_cell(start_cell, cols, rows)

	var grid = MazeUtils.init_maze_grid(cols, rows)
	MazeUtils.carve_maze(grid, start_cell, cols, rows)
	_spawn_maze_walls(grid, maze_offset, cell_size, main_scene)

	var farthest_data = MazeUtils.find_farthest_cell(grid, start_cell, cols, rows)
	var farthest: Vector2i = farthest_data["cell"]
	var path_steps: int = farthest_data["distance"]
	context.last_maze_path_length = float(max(path_steps, 1)) * cell_size
	var exit_position = MazeUtils.maze_cell_to_world(farthest, maze_offset, cell_size)
	context.exit_spawner.clear_exit()
	context.exit_spawner.create_exit_at(exit_position, main_scene)
	var exit_node = context.exit_spawner.get_exit()
	if exit_node:
		context.exit_pos = exit_node.position

	context.set_player_spawn_override(MazeUtils.maze_cell_to_world(start_cell, maze_offset, cell_size))

	context.coins.clear()
	if include_coins:
		_generate_maze_coins(grid, start_cell, farthest, maze_offset, cell_size, main_scene)

func generate_maze_keys_level(main_scene, level: int, player_start_position: Vector2) -> void:
	var dims = LevelUtils.get_scaled_level_dimensions(context.current_level_size)
	var level_width: float = float(dims.width)
	var level_height: float = float(dims.height)
	var offset = Vector2(dims.offset_x, dims.offset_y)

	var cell_size = context.MAZE_BASE_CELL_SIZE
	var cols = int(floor(level_width / cell_size))
	var rows = int(floor(level_height / cell_size))
	cols = max(cols | 1, 5)
	rows = max(rows | 1, 5)
	var maze_width = cols * cell_size
	var maze_height = rows * cell_size
	var maze_offset = offset + Vector2((level_width - maze_width) * 0.5, (level_height - maze_height) * 0.5)

	var start_cell = MazeUtils.world_to_maze_cell(player_start_position, maze_offset, cell_size)
	start_cell = MazeUtils.ensure_odd_cell(start_cell, cols, rows)

	var grid = MazeUtils.init_maze_grid(cols, rows)
	MazeUtils.carve_maze(grid, start_cell, cols, rows)
	_spawn_maze_walls(grid, maze_offset, cell_size, main_scene)

	var farthest_data = MazeUtils.find_farthest_cell(grid, start_cell, cols, rows)
	var exit_cell: Vector2i = farthest_data["cell"]
	var path_steps: int = farthest_data["distance"]
	context.last_maze_path_length = float(max(path_steps, 1)) * cell_size

	var path: Array = MazeUtils.reconstruct_maze_path(grid, start_cell, exit_cell, cols, rows)

	context.coins.clear()
	context.exit_spawner.clear_exit()

	var exit_position = MazeUtils.maze_cell_to_world(exit_cell, maze_offset, cell_size)
	context.exit_spawner.create_exit_at(exit_position, main_scene)
	var exit_node = context.exit_spawner.get_exit()
	if exit_node:
		context.exit_pos = exit_node.position

	var door_cell = exit_cell
	if path.size() >= 2:
		door_cell = path[path.size() - 2]
	if door_cell == exit_cell and path.size() >= 3:
		door_cell = path[path.size() - 3]

	var desired_keys = clamp(2 + int(floor(level / 2.0)), 2, 6)
	var key_cells: Array = MazeUtils.pick_maze_key_cells(grid, path, start_cell, door_cell, exit_cell, desired_keys)
	var actual_keys = key_cells.size()
	var door_required = actual_keys
	var door_color = context.get_group_color(0)
	var door_initially_open = door_required <= 0

	var door = LevelNodeFactory.create_door_node(0, door_required, door_initially_open, cell_size, cell_size, door_color)
	door.position = maze_offset + Vector2(door_cell.x * cell_size, door_cell.y * cell_size)
	context.doors.append(door)
	context.add_generated_node(door, main_scene)

	if actual_keys > 0:
		for cell in key_cells:
			var key_pos = MazeUtils.maze_cell_to_world(cell, maze_offset, cell_size)
			var key_node = LevelNodeFactory.create_key_node(context.key_items.size(), door, key_pos, door_required, door_color)
			context.key_items.append(key_node)
			context.add_generated_node(key_node, main_scene)

	Logger.log_generation("Maze+Keys door at %s with %d keys" % [str(door_cell), actual_keys])
	context.set_player_spawn_override(MazeUtils.maze_cell_to_world(start_cell, maze_offset, cell_size))

func _generate_maze_coins(grid: Array, start: Vector2i, exit_cell: Vector2i, offset: Vector2, cell_size: float, main_scene) -> void:
	var rows = grid.size()
	var cols = grid[0].size()
	var candidates: Array = []
	for y in range(rows):
		for x in range(cols):
			if grid[y][x]:
				continue
			var cell = Vector2i(x, y)
			if cell == start or cell == exit_cell:
				continue
			if (abs(cell.x - start.x) + abs(cell.y - start.y)) < 3:
				continue
			candidates.append(cell)
	candidates.shuffle()
	var desired = clamp(int(candidates.size() / 8.0), 5, 20)
	for i in range(min(desired, candidates.size())):
		var cell = candidates[i]
		var world_pos = MazeUtils.maze_cell_to_world(cell, offset, cell_size)
		var coin = LevelNodeFactory.create_coin_node(context.coins.size(), world_pos)
		context.coins.append(coin)
		context.add_generated_node(coin, main_scene)

func _spawn_maze_walls(grid: Array, offset: Vector2, cell_size: float, main_scene) -> void:
	var rows = grid.size()
	var cols = grid[0].size()
	for y in range(rows):
		for x in range(cols):
			if grid[y][x]:
				var wall = LevelNodeFactory.create_maze_wall(context.maze_walls.size(), cell_size, WALL_COLOR, context.MAZE_WALL_SIZE_RATIO)
				wall.position = offset + Vector2(x * cell_size, y * cell_size)
				context.maze_walls.append(wall)
				context.add_generated_node(wall, main_scene)
