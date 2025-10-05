extends RefCounted
class_name MazeLayoutBuilder

const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const MAZE_UTILS := preload("res://scripts/level_generators/MazeUtils.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")
const MAZE_REACHABILITY_JOB: GDScript = preload("res://scripts/level_generators/MazeReachabilityJob.gd")
const WALL_COLOR := Color(0.15, 0.18, 0.28, 1)

var _context

func _init(level_context):
	_context = level_context

func build(
	main_scene,
	player_start_position: Vector2,
	debug_logger,
	player_collision_size: float,
	shadow_color: Color,
	options: Dictionary = {}
) -> Dictionary:
	var dims = LEVEL_UTILS.get_scaled_level_dimensions(_context.current_level_size)
	var level_width: float = float(dims.width)
	var level_height: float = float(dims.height)
	var offset = Vector2(dims.offset_x, dims.offset_y)
	var cell_size = float(options.get("cell_size", _context.MAZE_BASE_CELL_SIZE))
	var cols = int(floor(level_width / cell_size))
	var rows = int(floor(level_height / cell_size))
	cols = max(cols | 1, 5)
	rows = max(rows | 1, 5)
	var maze_width = cols * cell_size
	var maze_height = rows * cell_size
	var maze_offset = offset + Vector2((level_width - maze_width) * 0.5, (level_height - maze_height) * 0.5)
	var start_cell: Vector2i
	if bool(options.get("random_start", false)):
		start_cell = _get_random_maze_cell(cols, rows)
	else:
		start_cell = _choose_start_cell(player_start_position, maze_offset, cell_size, cols, rows)
	var grid = MAZE_UTILS.init_maze_grid(cols, rows)
	MAZE_UTILS.carve_maze(grid, start_cell, cols, rows)
	var connector_chance := clamp(float(options.get("connector_chance", 0.0)), 0.0, 1.0)
	if connector_chance > 0.0:
		_add_extra_connectors(grid, cols, rows, connector_chance)
	var wall_ratio := clamp(float(options.get("wall_ratio", _context.MAZE_WALL_SIZE_RATIO)), 0.02, 0.5)
	_spawn_maze_walls(grid, maze_offset, cell_size, wall_ratio, main_scene)
	_fill_unreachable_areas(main_scene, grid, start_cell, maze_offset, cell_size, player_collision_size, shadow_color, debug_logger)
	var start_world = MAZE_UTILS.maze_cell_to_world(start_cell, maze_offset, cell_size)
	_context.set_player_spawn_override(start_world)
	return {
		"grid": grid,
		"cols": cols,
		"rows": rows,
		"cell_size": cell_size,
		"maze_offset": maze_offset,
		"start_cell": start_cell,
		"start_world": start_world
	}

func _choose_start_cell(player_start_position: Vector2, maze_offset: Vector2, cell_size: float, cols: int, rows: int) -> Vector2i:
	if _context.current_level_size >= 1.2:
		return _get_random_maze_cell(cols, rows)
	var start_cell = MAZE_UTILS.world_to_maze_cell(player_start_position, maze_offset, cell_size)
	return MAZE_UTILS.ensure_odd_cell(start_cell, cols, rows)

func _spawn_maze_walls(grid: Array, offset: Vector2, cell_size: float, wall_ratio: float, main_scene) -> void:
	var rows = grid.size()
	var cols = grid[0].size()
	var thickness = cell_size * wall_ratio
	var half_thickness = thickness * 0.5
	for y in range(rows):
		for x in range(cols):
			if grid[y][x]:
				continue
			var base := offset + Vector2(x * cell_size, y * cell_size)
			if y == 0 or grid[y - 1][x]:
				var top_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(_context.maze_walls.size(), cell_size, thickness, WALL_COLOR)
				top_wall.position = base + Vector2(0.0, -half_thickness)
				_context.maze_walls.append(top_wall)
				_context.add_generated_node(top_wall, main_scene)
			if y == rows - 1 or grid[y + 1][x]:
				var bottom_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(_context.maze_walls.size(), cell_size, thickness, WALL_COLOR)
				bottom_wall.position = base + Vector2(0.0, cell_size - half_thickness)
				_context.maze_walls.append(bottom_wall)
				_context.add_generated_node(bottom_wall, main_scene)
			if x == 0 or grid[y][x - 1]:
				var left_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(_context.maze_walls.size(), thickness, cell_size, WALL_COLOR)
				left_wall.position = base + Vector2(-half_thickness, 0.0)
				_context.maze_walls.append(left_wall)
				_context.add_generated_node(left_wall, main_scene)
			if x == cols - 1 or grid[y][x + 1]:
				var right_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(_context.maze_walls.size(), thickness, cell_size, WALL_COLOR)
				right_wall.position = base + Vector2(cell_size - half_thickness, 0.0)
				_context.maze_walls.append(right_wall)
				_context.add_generated_node(right_wall, main_scene)

func _add_extra_connectors(grid: Array, cols: int, rows: int, chance: float) -> void:
	for y in range(1, rows - 1):
		for x in range(1, cols - 1):
			if not grid[y][x]:
				continue
			var open_dirs: Array = []
			for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx = x + dir.x
				var ny = y + dir.y
				if nx < 0 or nx >= cols or ny < 0 or ny >= rows:
					continue
				if grid[ny][nx]:
					continue
				open_dirs.append(dir)
			if open_dirs.size() != 2:
				continue
			if open_dirs[0] + open_dirs[1] != Vector2i.ZERO:
				continue
			if randf() <= chance:
				grid[y][x] = false

func _fill_unreachable_areas(
	main_scene,
	grid: Array,
	start_cell: Vector2i,
	offset: Vector2,
	cell_size: float,
	player_collision_size: float,
	shadow_color: Color,
	debug_logger
) -> void:
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

func _get_random_maze_cell(cols: int, rows: int) -> Vector2i:
	var attempts = 0
	while attempts < 100:
		var x = randi_range(3, cols - 4) | 1
		var y = randi_range(3, rows - 4) | 1
		var cell = Vector2i(x, y)
		if cell.x >= 3 and cell.x < cols - 3 and cell.y >= 3 and cell.y < rows - 3:
			return cell
		attempts += 1
	return Vector2i(int(cols / 2.0) | 1, int(rows / 2.0) | 1)

