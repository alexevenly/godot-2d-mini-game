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
	var path_index := {}
	for i in range(path.size()):
		var path_cell: Vector2i = path[i]
		path_index[path_cell] = i

	context.coins.clear()
	context.exit_spawner.clear_exit()

	var exit_position = MazeUtils.maze_cell_to_world(exit_cell, maze_offset, cell_size)
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
	var start_world = MazeUtils.maze_cell_to_world(start_cell, maze_offset, cell_size)
	var exit_world = MazeUtils.maze_cell_to_world(exit_cell, maze_offset, cell_size)
	var door_worlds: Array[Vector2] = []
	for door_cell in door_cells:
		door_worlds.append(MazeUtils.maze_cell_to_world(door_cell, maze_offset, cell_size))
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
			var fallback_score: float = -INF
			var door_world = door_worlds[i]
			for variant in reachable_cells:
				var candidate: Vector2i = variant
				if candidate == start_cell or candidate == exit_cell or candidate == door_cell:
					continue
				if taken_cells.has(candidate):
					continue
				var world = MazeUtils.maze_cell_to_world(candidate, maze_offset, cell_size)
				var score = min(world.distance_to(door_world), world.distance_to(start_world))
				score = min(score, world.distance_to(exit_world))
				for existing_world in key_world_positions:
					score = min(score, world.distance_to(existing_world))
				if score > fallback_score:
					fallback_score = score
					fallback_cell = candidate
			if fallback_cell != door_cell:
				key_cells.append(fallback_cell)
				var fallback_world = MazeUtils.maze_cell_to_world(fallback_cell, maze_offset, cell_size)
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
		var door = LevelNodeFactory.create_door_node(door_index_offset + i, key_count, initially_open, cell_size, cell_size, door_color)
		door.position = maze_offset + Vector2(door_cell.x * cell_size, door_cell.y * cell_size)
		context.doors.append(door)
		context.add_generated_node(door, main_scene)
		if key_count > 0:
			for cell in key_cells:
				var key_pos = MazeUtils.maze_cell_to_world(cell, maze_offset, cell_size)
				var key_node = LevelNodeFactory.create_key_node(context.key_items.size(), door, key_pos, key_count, door_color)
				context.key_items.append(key_node)
				context.add_generated_node(key_node, main_scene)
		Logger.log_generation("Maze+Keys door %d at %s with %d keys" % [door_index_offset + i, str(door_cell), key_count])

	context.set_player_spawn_override(MazeUtils.maze_cell_to_world(start_cell, maze_offset, cell_size))

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
		var best_score: float = -INF
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
			var world = MazeUtils.maze_cell_to_world(cell, offset, cell_size)
			for chosen in selected:
				var chosen_world = MazeUtils.maze_cell_to_world(chosen, offset, cell_size)
				if chosen_world.distance_to(world) < min_spacing:
					keep = false
					break
			if keep:
				filtered.append(cell)
		candidates = filtered
		attempts += 1
	return selected

func _collect_reachable_cells_before_door(grid: Array, start_cell: Vector2i, blocked_cells: Array) -> Array:
	var reachable: Array = []
	var visited := {}
	var queue: Array = [start_cell]
	visited[start_cell] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		reachable.append(cell)
		for direction in MazeUtils.CARDINAL_DIRS:
			var neighbor = cell + direction
			if not MazeUtils.is_cell_within_bounds(neighbor, grid):
				continue
			if blocked_cells.has(neighbor):
				continue
			if visited.has(neighbor):
				continue
			if MazeUtils.is_wall_between(cell, neighbor, grid):
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return reachable

func _select_maze_key_cells(
	reachable_cells: Array,
	target_count: int,
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
		if cell == start_cell or cell == door_cell:
			continue
		if taken_cells.has(cell):
			continue
		if MazeUtils.is_adjacent(cell, door_cell) or MazeUtils.is_adjacent(cell, start_cell) or MazeUtils.is_adjacent(cell, exit_cell):
			continue
		candidates.append(cell)
	if candidates.is_empty():
		return []

	var selected: Array = []
	var attempts: int = 0
	var min_spacing: float = cell_size * 2.5
	while selected.size() < min(target_count, candidates.size()) and attempts < 60:
		var best_cell: Vector2i = candidates[0]
		var best_score: float = -INF
		for cell in candidates:
			if selected.has(cell):
				continue
			var score = _maze_key_score(cell, door_cell, start_cell, exit_cell, offset, cell_size, door_worlds, key_world_positions, start_world, exit_world)
			if score > best_score:
				best_score = score
				best_cell = cell
		selected.append(best_cell)
		if selected.size() >= target_count:
			break
		var filtered: Array = []
		for cell in candidates:
			if selected.has(cell):
				continue
			var keep := true
			var world = MazeUtils.maze_cell_to_world(cell, offset, cell_size)
			for chosen in selected:
				var chosen_world = MazeUtils.maze_cell_to_world(chosen, offset, cell_size)
				if chosen_world.distance_to(world) < min_spacing:
					keep = false
					break
			if keep:
				filtered.append(cell)
		candidates = filtered
		attempts += 1
	return selected

func _maze_spread_score(cell: Vector2i, selected: Array, start_cell: Vector2i, exit_cell: Vector2i, offset: Vector2, cell_size: float) -> float:
	var world = MazeUtils.maze_cell_to_world(cell, offset, cell_size)
	var score = min(world.distance_to(MazeUtils.maze_cell_to_world(start_cell, offset, cell_size)), world.distance_to(MazeUtils.maze_cell_to_world(exit_cell, offset, cell_size)))
	for chosen in selected:
		var chosen_world = MazeUtils.maze_cell_to_world(chosen, offset, cell_size)
		score = min(score, world.distance_to(chosen_world))
	return score

func _maze_key_score(
	cell: Vector2i,
	door_cell: Vector2i,
	start_cell: Vector2i,
	exit_cell: Vector2i,
	offset: Vector2,
	cell_size: float,
	door_worlds: Array,
	key_world_positions: Array,
	start_world: Vector2,
	exit_world: Vector2
) -> float:
	var world = MazeUtils.maze_cell_to_world(cell, offset, cell_size)
	var score = min(world.distance_to(start_world), world.distance_to(exit_world))
	var door_world = MazeUtils.maze_cell_to_world(door_cell, offset, cell_size)
	score = min(score, world.distance_to(door_world))
	for existing_world in door_worlds:
		score = min(score, world.distance_to(existing_world))
	for existing in key_world_positions:
		score = min(score, world.distance_to(existing))
	return score

func _spawn_maze_walls(grid: Array, maze_offset: Vector2, cell_size: float, main_scene) -> void:
	context.maze_walls.clear()
	for entry in MazeUtils.enumerate_maze_walls(grid):
		var cell: Vector2i = entry["cell"]
		var orientation: int = entry["orientation"]
		var wall_length: float = float(entry["length"]) * cell_size
		var wall = LevelNodeFactory.create_maze_wall_node(context.maze_walls.size(), wall_length, cell_size, WALL_COLOR)
		var world_pos = MazeUtils.maze_cell_to_world(cell, maze_offset, cell_size)
		if orientation == MazeUtils.WallOrientation.HORIZONTAL:
			world_pos.y += cell_size * 0.5
		else:
			world_pos.x += cell_size * 0.5
		wall.position = world_pos
		context.maze_walls.append(wall)
		context.add_generated_node(wall, main_scene)

func _generate_maze_coins(grid: Array, start_cell: Vector2i, farthest: Vector2i, maze_offset: Vector2, cell_size: float, main_scene) -> void:
	var coin_cells: Array = MazeUtils.sample_maze_coin_cells(grid, start_cell, farthest)
	for cell in coin_cells:
		var position = MazeUtils.maze_cell_to_world(cell, maze_offset, cell_size)
		var coin = LevelNodeFactory.create_coin_node(context.coins.size(), position)
		context.coins.append(coin)
		context.add_generated_node(coin, main_scene)
