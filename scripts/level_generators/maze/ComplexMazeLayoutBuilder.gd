extends RefCounted
class_name ComplexMazeLayoutBuilder

const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const MAZE_UTILS := preload("res://scripts/level_generators/MazeUtils.gd")
const REACHABILITY := preload("res://scripts/level_generators/maze/MazeReachabilityHelper.gd")
const CARVER := preload("res://scripts/level_generators/maze/ComplexMazeCarver.gd")
const WALL_SPAWNER := preload("res://scripts/level_generators/maze/ComplexMazeWallSpawner.gd")

var _context
var _carver: ComplexMazeCarver
var _wall_spawner: ComplexMazeWallSpawner

func _init(level_context):
	_context = level_context
	_carver = CARVER.new()
	_wall_spawner = WALL_SPAWNER.new(_context)

func build(
	main_scene,
	player_start_position: Vector2,
	debug_logger,
	player_collision_size: float,
	shadow_color: Color
) -> Dictionary:
	var dims = LEVEL_UTILS.get_scaled_level_dimensions(_context.current_level_size)
	var level_width: float = float(dims.width)
	var level_height: float = float(dims.height)
	var offset = Vector2(dims.offset_x, dims.offset_y)
	var base_cell_size = _context.MAZE_BASE_CELL_SIZE * 0.5
	var grid_cols = int(floor(level_width / base_cell_size))
	var grid_rows = int(floor(level_height / base_cell_size))
	if grid_cols < 3:
		grid_cols = 3
	if grid_rows < 3:
		grid_rows = 3
	if (grid_cols & 1) == 0:
		grid_cols -= 1
	if (grid_rows & 1) == 0:
		grid_rows -= 1
	var cell_cols = max(int((grid_cols - 1) / 2), 1)
	var cell_rows = max(int((grid_rows - 1) / 2), 1)
	var allow_multiple_paths := true
	if _context and _context.has_method("get"):
		var flag = _context.get("complex_maze_allow_multiple_paths")
		if flag != null:
			allow_multiple_paths = bool(flag)
	var carve_data = _carver.generate(cell_cols, cell_rows, allow_multiple_paths)
	if carve_data.is_empty():
		return {}
	var grid: Array = carve_data.get("grid", [])
	if grid.is_empty():
		return {}
	var maze_rows = grid.size()
	var maze_cols = grid[0].size()
	var safe_cols = max(maze_cols, 1)
	var safe_rows = max(maze_rows, 1)
	var cell_size = min(
		level_width / float(safe_cols),
		level_height / float(safe_rows)
	)
	if cell_size <= 0.0:
		cell_size = 8.0
	var maze_width = float(maze_cols) * cell_size
	var maze_height = float(maze_rows) * cell_size
	var maze_offset = offset + Vector2((level_width - maze_width) * 0.5, (level_height - maze_height) * 0.5)
	var start_cell: Vector2i = carve_data.get("start_cell", Vector2i.ZERO)
	var exit_cell: Vector2i = carve_data.get("exit_cell", Vector2i.ZERO)
	_wall_spawner.spawn(grid, maze_offset, cell_size, main_scene)
	REACHABILITY.spawn_job(
		_context,
		main_scene,
		grid,
		start_cell,
		maze_offset,
		cell_size,
		player_collision_size,
		shadow_color,
		debug_logger
	)
	var start_world = MAZE_UTILS.maze_cell_to_world(start_cell, maze_offset, cell_size)
	if _context and _context.has_method("set_player_spawn_override"):
		_context.set_player_spawn_override(start_world)
	return {
		"grid": grid,
		"cols": maze_cols,
		"rows": maze_rows,
		"cell_size": cell_size,
		"maze_offset": maze_offset,
		"start_cell": start_cell,
		"start_world": start_world,
		"exit_cell": exit_cell
	}
