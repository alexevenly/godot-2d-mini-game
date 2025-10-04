extends Object
class_name MazeGenerator

const LOGGER := preload("res://scripts/Logger.gd")
const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const MAZE_UTILS := preload("res://scripts/level_generators/MazeUtils.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")
const MAZE_REACHABILITY_JOB: GDScript = preload("res://scripts/level_generators/MazeReachabilityJob.gd")

const WALL_COLOR := Color(0.15, 0.18, 0.28, 1)
const PLAYER_COLLISION_SIZE := 32.0
const BLACK_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 1.0)
const DEBUG_LOG_DIR := "user://logs"
const DEBUG_LOG_FILE := "maze_debug.log"

var context
var _debug_logging := false
var _debug_file: FileAccess = null

func _init(level_context, _obstacle_helper):
	context = level_context

func _setup_debug_logging() -> void:
	_debug_logging = true
	if Engine.has_meta("maze_debug_logging"):
		_debug_logging = bool(Engine.get_meta("maze_debug_logging"))
		if _debug_logging:
			_open_debug_file()

func _open_debug_file() -> void:
	if _debug_file:
		return
	DirAccess.make_dir_recursive_absolute(DEBUG_LOG_DIR)
	var path := "%s/%s" % [DEBUG_LOG_DIR, DEBUG_LOG_FILE]
	_debug_file = FileAccess.open(path, FileAccess.WRITE)
	if _debug_file:
		_debug_file.store_line("MazeGenerator debug log started")
		_debug_file.flush()

func _log_debug(message: String) -> void:
	if not _debug_logging:
		return
	if _debug_file == null:
		_open_debug_file()
	if _debug_file:
		_debug_file.store_line(message)
		_debug_file.flush()

func generate_maze_level(include_coins: bool, main_scene, player_start_position: Vector2) -> void:
	_setup_debug_logging()
	var dims = LEVEL_UTILS.get_scaled_level_dimensions(context.current_level_size)
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

	var start_cell: Vector2i
	# For larger levels (1.2+), place player in random spot
	if context.current_level_size >= 1.2:
		start_cell = _get_random_maze_cell(cols, rows)
	else:
		start_cell = MAZE_UTILS.world_to_maze_cell(player_start_position, maze_offset, cell_size)
		start_cell = MAZE_UTILS.ensure_odd_cell(start_cell, cols, rows)

	var grid = MAZE_UTILS.init_maze_grid(cols, rows)
	MAZE_UTILS.carve_maze(grid, start_cell, cols, rows)
	_spawn_maze_walls(grid, maze_offset, cell_size, main_scene)
	_fill_unreachable_areas(grid, start_cell, maze_offset, cell_size, main_scene)

	var farthest_data = MAZE_UTILS.find_farthest_cell(grid, start_cell, cols, rows)
	var farthest: Vector2i = farthest_data["cell"]
	var path_steps: int = farthest_data["distance"]
	context.last_maze_path_length = float(max(path_steps, 1)) * cell_size
	var exit_position = MAZE_UTILS.maze_cell_to_world(farthest, maze_offset, cell_size)
	context.exit_spawner.clear_exit()
	context.exit_spawner.create_exit_at(exit_position, main_scene)
	var exit_node = context.exit_spawner.get_exit()
	if exit_node:
		context.exit_pos = exit_node.position

	context.set_player_spawn_override(MAZE_UTILS.maze_cell_to_world(start_cell, maze_offset, cell_size))

	context.coins.clear()
	if include_coins:
		_generate_maze_coins(grid, start_cell, farthest, maze_offset, cell_size, main_scene)

func generate_maze_keys_level(main_scene, level: int, player_start_position: Vector2) -> void:
	_setup_debug_logging()
	var dims = LEVEL_UTILS.get_scaled_level_dimensions(context.current_level_size)
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

	var start_cell: Vector2i
	# For larger levels (1.2+), place player in random spot
	if context.current_level_size >= 1.2:
		start_cell = _get_random_maze_cell(cols, rows)
	else:
		start_cell = MAZE_UTILS.world_to_maze_cell(player_start_position, maze_offset, cell_size)
		start_cell = MAZE_UTILS.ensure_odd_cell(start_cell, cols, rows)

	var grid = MAZE_UTILS.init_maze_grid(cols, rows)
	MAZE_UTILS.carve_maze(grid, start_cell, cols, rows)
	_spawn_maze_walls(grid, maze_offset, cell_size, main_scene)
	_fill_unreachable_areas(grid, start_cell, maze_offset, cell_size, main_scene)

	var farthest_data = MAZE_UTILS.find_farthest_cell(grid, start_cell, cols, rows)
	var exit_cell: Vector2i = farthest_data["cell"]
	var path_steps: int = farthest_data["distance"]
	context.last_maze_path_length = float(max(path_steps, 1)) * cell_size

	var path: Array = MAZE_UTILS.reconstruct_maze_path(grid, start_cell, exit_cell, cols, rows)
	var path_index := {}
	for i in range(path.size()):
		var path_cell: Vector2i = path[i]
		path_index[path_cell] = i

	context.coins.clear()
	context.exit_spawner.clear_exit()

	var exit_position = MAZE_UTILS.maze_cell_to_world(exit_cell, maze_offset, cell_size)
	context.exit_spawner.create_exit_at(exit_position, main_scene)
	var exit_node = context.exit_spawner.get_exit()
	if exit_node:
		context.exit_pos = exit_node.position

	var desired_door_count = clamp(2 + int(floor(level / 3.0)), 2, 5)
	var door_cells: Array = _select_maze_door_cells(path, start_cell, exit_cell, maze_offset, cell_size, desired_door_count)
	if door_cells.is_empty():
		door_cells.append(exit_cell)
	else:
		door_cells.sort_custom(func(a, b):
			var ia: int = int(path_index.get(a, 0))
			var ib: int = int(path_index.get(b, 0))
			return ia < ib)
	var start_world = MAZE_UTILS.maze_cell_to_world(start_cell, maze_offset, cell_size)
	var exit_world = MAZE_UTILS.maze_cell_to_world(exit_cell, maze_offset, cell_size)
	var door_worlds: Array[Vector2] = []
	for door_cell in door_cells:
		door_worlds.append(MAZE_UTILS.maze_cell_to_world(door_cell, maze_offset, cell_size))
	var key_world_positions: Array[Vector2] = []
	var taken_cells: Array = []
	var door_data: Array = []
	for i in range(door_cells.size()):
		var door_cell: Vector2i = door_cells[i]
		var blocked: Array = []
		for j in range(i, door_cells.size()):
			blocked.append(door_cells[j])
		var reachable_cells: Array = _collect_reachable_cells_before_door(grid, start_cell, blocked)
		var keys_target = clamp(1 + int(floor(level / 4.0)) + (i % 2), 1, 4)
		var key_cells: Array = _select_maze_key_cells(
			reachable_cells,
			keys_target,
			maze_offset,
			cell_size,
			door_cell,
			start_cell,
			exit_cell,
			taken_cells,
			door_worlds,
			key_world_positions,
			start_world,
			exit_world
		)
		if key_cells.is_empty() and keys_target > 0:
			var fallback_cell: Vector2i = door_cell
			var fallback_score: float = - INF
			var door_world = door_worlds[i]
			for variant in reachable_cells:
				var candidate: Vector2i = variant
				if candidate == start_cell or candidate == exit_cell or candidate == door_cell:
					continue
				if taken_cells.has(candidate):
					continue
				var world = MAZE_UTILS.maze_cell_to_world(candidate, maze_offset, cell_size)
				var score = min(world.distance_to(door_world), world.distance_to(start_world))
				score = min(score, world.distance_to(exit_world))
				for existing_world in key_world_positions:
					score = min(score, world.distance_to(existing_world))
				if score > fallback_score:
					fallback_score = score
					fallback_cell = candidate
			if fallback_cell != door_cell:
				key_cells.append(fallback_cell)
				var fallback_world = MAZE_UTILS.maze_cell_to_world(fallback_cell, maze_offset, cell_size)
				key_world_positions.append(fallback_world)
		for cell in key_cells:
			taken_cells.append(cell)
		var color = context.get_group_color(i)
		door_data.append({
			"cell": door_cell,
			"keys": key_cells,
			"color": color
		})

	var door_index_offset = context.doors.size()
	for i in range(door_data.size()):
		var entry: Dictionary = door_data[i]
		var door_cell: Vector2i = entry.get("cell", exit_cell)
		var key_cells: Array = entry.get("keys", [])
		var key_count: int = key_cells.size()
		var door_color: Color = entry.get("color", context.get_group_color(i))
		var initially_open: bool = key_count <= 0
		var door = LEVEL_NODE_FACTORY.create_door_node(door_index_offset + i, key_count, initially_open, cell_size, cell_size, door_color)
		door.position = maze_offset + Vector2(door_cell.x * cell_size, door_cell.y * cell_size)
		context.doors.append(door)
		context.add_generated_node(door, main_scene)
		if key_count > 0:
			for cell in key_cells:
				var key_pos = MAZE_UTILS.maze_cell_to_world(cell, maze_offset, cell_size)
				var key_node = LEVEL_NODE_FACTORY.create_key_node(context.key_items.size(), door, key_pos, key_count, door_color)
				context.key_items.append(key_node)
				context.add_generated_node(key_node, main_scene)
		LOGGER.log_generation("Maze+Keys door %d at %s with %d keys" % [door_index_offset + i, str(door_cell), key_count])

	context.set_player_spawn_override(MAZE_UTILS.maze_cell_to_world(start_cell, maze_offset, cell_size))

func _select_maze_door_cells(path: Array, start_cell: Vector2i, exit_cell: Vector2i, offset: Vector2, cell_size: float, desired: int) -> Array:
	var candidates: Array = []
	for variant in path:
		var cell: Vector2i = variant
		if cell == start_cell or cell == exit_cell:
			continue
		candidates.append(cell)
	if candidates.is_empty():
		return []
	var selected: Array = []
	var min_spacing: float = cell_size * 3.5
	var attempts: int = 0
	while selected.size() < min(desired, candidates.size()) and attempts < 40:
		var best_cell: Vector2i = candidates[0]
		var best_score: float = - INF
		for cell in candidates:
			if selected.has(cell):
				continue
			var score = _maze_spread_score(cell, selected, start_cell, exit_cell, offset, cell_size)
			if score > best_score:
				best_score = score
				best_cell = cell
		selected.append(best_cell)
		if selected.size() >= desired:
			break
		var filtered: Array = []
		for cell in candidates:
			if selected.has(cell):
				continue
			var keep := true
			var world = MAZE_UTILS.maze_cell_to_world(cell, offset, cell_size)
			for chosen in selected:
				var chosen_world = MAZE_UTILS.maze_cell_to_world(chosen, offset, cell_size)
				if chosen_world.distance_to(world) < min_spacing:
					keep = false
					break
			if keep:
				filtered.append(cell)
		if filtered.is_empty() and min_spacing > cell_size * 1.2:
			min_spacing *= 0.8
			filtered = []
			for cell in candidates:
				if selected.has(cell):
					continue
				filtered.append(cell)
		candidates = filtered
		attempts += 1
	return selected

func _maze_spread_score(cell: Vector2i, existing: Array, start_cell: Vector2i, exit_cell: Vector2i, offset: Vector2, cell_size: float) -> float:
	var world = MAZE_UTILS.maze_cell_to_world(cell, offset, cell_size)
	var start_world = MAZE_UTILS.maze_cell_to_world(start_cell, offset, cell_size)
	var exit_world = MAZE_UTILS.maze_cell_to_world(exit_cell, offset, cell_size)
	var score = min(world.distance_to(start_world), world.distance_to(exit_world))
	for chosen in existing:
		var chosen_world = MAZE_UTILS.maze_cell_to_world(chosen, offset, cell_size)
		score = min(score, world.distance_to(chosen_world))
	return score

func _collect_reachable_cells_before_door(grid: Array, start_cell: Vector2i, blocked_cells: Array) -> Array:
	var rows = grid.size()
	if rows <= 0:
		return []
	var cols = grid[0].size()
	var queue: Array = []
	var visited := {}
	var reachable: Array = []
	queue.append(start_cell)
	visited[start_cell] = true
	reachable.append(start_cell)
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next = cell + dir
			if next.x < 0 or next.x >= cols or next.y < 0 or next.y >= rows:
				continue
			if grid[next.y][next.x]:
				continue
			if blocked_cells.has(next):
				continue
			if visited.has(next):
				continue
			visited[next] = true
			reachable.append(next)
			queue.append(next)
	return reachable

func _select_maze_key_cells(
	reachable_cells: Array,
	desired: int,
	offset: Vector2,
	cell_size: float,
	door_cell: Vector2i,
	start_cell: Vector2i,
	exit_cell: Vector2i,
	taken_cells: Array,
	door_worlds: Array,
	key_world_positions: Array,
	start_world: Vector2,
	exit_world: Vector2
) -> Array:
	var candidates: Array = []
	for variant in reachable_cells:
		var cell: Vector2i = variant
		if cell == start_cell or cell == exit_cell or cell == door_cell:
			continue
		if taken_cells.has(cell):
			continue
		candidates.append(cell)
	if candidates.is_empty() or desired <= 0:
		return []
	var result: Array = []
	var min_spacing: float = cell_size * 2.5 # Increased from 2.0
	var door_world = MAZE_UTILS.maze_cell_to_world(door_cell, offset, cell_size)
	var attempts: int = 0
	while result.size() < desired and attempts < 80 and not candidates.is_empty():
		var best_cell: Vector2i = candidates[0]
		var best_score: float = - INF
		for cell in candidates:
			var world = MAZE_UTILS.maze_cell_to_world(cell, offset, cell_size)
			# Prioritize distance from door more heavily
			var door_distance = world.distance_to(door_world)
			var score = door_distance * 1.5 # Weight door distance more
			score = min(score, world.distance_to(start_world))
			score = min(score, world.distance_to(exit_world))
			for door_world_other in door_worlds:
				if door_world_other == door_world:
					continue
				score = min(score, world.distance_to(door_world_other))
			for existing_world in key_world_positions:
				score = min(score, world.distance_to(existing_world))
			if score > best_score:
				best_score = score
				best_cell = cell
		result.append(best_cell)
		var best_world = MAZE_UTILS.maze_cell_to_world(best_cell, offset, cell_size)
		key_world_positions.append(best_world)
		taken_cells.append(best_cell)
		var filtered: Array = []
		for cell in candidates:
			if cell == best_cell:
				continue
			var world = MAZE_UTILS.maze_cell_to_world(cell, offset, cell_size)
			# Increased minimum distance from door from 1.6 to 2.5
			if best_world.distance_to(world) >= min_spacing and world.distance_to(door_world) >= cell_size * 2.5:
				filtered.append(cell)
		candidates = filtered
		if candidates.is_empty() and result.size() < desired and min_spacing > cell_size * 0.9:
			min_spacing *= 0.85
			for cell in reachable_cells:
				if result.has(cell):
					continue
				if taken_cells.has(cell):
					continue
				if cell == start_cell or cell == exit_cell or cell == door_cell:
					continue
				var world = MAZE_UTILS.maze_cell_to_world(cell, offset, cell_size)
				# Increased minimum distance from door from 1.4 to 2.0
				if world.distance_to(door_world) < cell_size * 2.0:
					continue
				var too_close := false
				for existing_world in key_world_positions:
					if existing_world.distance_to(world) < min_spacing:
						too_close = true
						break
				if too_close:
					continue
				candidates.append(cell)
		attempts += 1
	return result

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
		var world_pos = MAZE_UTILS.maze_cell_to_world(cell, offset, cell_size)
		var coin = LEVEL_NODE_FACTORY.create_coin_node(context.coins.size(), world_pos)
		context.coins.append(coin)
		context.add_generated_node(coin, main_scene)

func _get_random_maze_cell(cols: int, rows: int) -> Vector2i:
	"""Get a random odd cell for maze generation that's not on the edge"""
	var attempts = 0
	while attempts < 100:
		# Ensure we're well inside the maze, not on the outer edge
		var x = randi_range(3, cols - 4) | 1 # Ensure odd and not on edge
		var y = randi_range(3, rows - 4) | 1 # Ensure odd and not on edge
		var cell = Vector2i(x, y)
		# Double check we're well inside the maze boundaries
		if cell.x >= 3 and cell.x < cols - 3 and cell.y >= 3 and cell.y < rows - 3:
			return cell
		attempts += 1
	# Fallback to center if random fails
	return Vector2i(int(cols / 2.0) | 1, int(rows / 2.0) | 1)

func _fill_unreachable_areas(grid: Array, start_cell: Vector2i, offset: Vector2, cell_size: float, main_scene) -> void:
	var job = MAZE_REACHABILITY_JOB.new()
	var logger_callable := Callable()
	if _debug_logging:
		logger_callable = Callable(self, "_log_debug")
	job.setup(
		context,
		main_scene,
		grid.duplicate(true),
		start_cell,
		offset,
		cell_size,
		PLAYER_COLLISION_SIZE,
		BLACK_SHADOW_COLOR,
		_debug_logging,
		logger_callable
	)
	if context and context is Node:
		context.add_child(job)
	elif main_scene and is_instance_valid(main_scene):
		main_scene.call_deferred("add_child", job)
	else:
		job.queue_free()
func _spawn_maze_walls(grid: Array, offset: Vector2, cell_size: float, main_scene) -> void:
	var rows = grid.size()
	var cols = grid[0].size()
	var thickness = cell_size * context.MAZE_WALL_SIZE_RATIO
	var half_thickness = thickness * 0.5
	for y in range(rows):
		var _start_x = -1
		for x in range(cols):
			if grid[y][x]:
				continue
			var base := offset + Vector2(x * cell_size, y * cell_size)
			if y == 0 or grid[y - 1][x]:
				var top_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(context.maze_walls.size(), cell_size, thickness, WALL_COLOR)
				top_wall.position = base + Vector2(0.0, -half_thickness)
				context.maze_walls.append(top_wall)
				context.add_generated_node(top_wall, main_scene)
			if y == rows - 1 or grid[y + 1][x]:
				var bottom_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(context.maze_walls.size(), cell_size, thickness, WALL_COLOR)
				bottom_wall.position = base + Vector2(0.0, cell_size - half_thickness)
				context.maze_walls.append(bottom_wall)
				context.add_generated_node(bottom_wall, main_scene)
			if x == 0 or grid[y][x - 1]:
				var left_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(context.maze_walls.size(), thickness, cell_size, WALL_COLOR)
				left_wall.position = base + Vector2(-half_thickness, 0.0)
				context.maze_walls.append(left_wall)
				context.add_generated_node(left_wall, main_scene)
			if x == cols - 1 or grid[y][x + 1]:
				var right_wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(context.maze_walls.size(), thickness, cell_size, WALL_COLOR)
				right_wall.position = base + Vector2(cell_size - half_thickness, 0.0)
				context.maze_walls.append(right_wall)
				context.add_generated_node(right_wall, main_scene)
