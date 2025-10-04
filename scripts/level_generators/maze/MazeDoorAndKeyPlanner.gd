extends RefCounted
class_name MazeDoorAndKeyPlanner

const MAZE_UTILS := preload("res://scripts/level_generators/MazeUtils.gd")

func select_door_cells(path: Array, start_cell: Vector2i, exit_cell: Vector2i, offset: Vector2, cell_size: float, desired: int) -> Array:
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

func collect_reachable_cells_before_door(grid: Array, start_cell: Vector2i, blocked_cells: Array) -> Array:
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

func select_key_cells(
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
	var min_spacing: float = cell_size * 2.5
	var door_world = MAZE_UTILS.maze_cell_to_world(door_cell, offset, cell_size)
	var attempts: int = 0
	while result.size() < desired and attempts < 80 and not candidates.is_empty():
		var best_cell: Vector2i = candidates[0]
		var best_score: float = -INF
		for cell in candidates:
			var world = MAZE_UTILS.maze_cell_to_world(cell, offset, cell_size)
			var door_distance = world.distance_to(door_world)
			var score = door_distance * 1.5
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

func _maze_spread_score(cell: Vector2i, existing: Array, start_cell: Vector2i, exit_cell: Vector2i, offset: Vector2, cell_size: float) -> float:
	var world = MAZE_UTILS.maze_cell_to_world(cell, offset, cell_size)
	var start_world = MAZE_UTILS.maze_cell_to_world(start_cell, offset, cell_size)
	var exit_world = MAZE_UTILS.maze_cell_to_world(exit_cell, offset, cell_size)
	var score = min(world.distance_to(start_world), world.distance_to(exit_world))
	for chosen in existing:
		var chosen_world = MAZE_UTILS.maze_cell_to_world(chosen, offset, cell_size)
		score = min(score, world.distance_to(chosen_world))
	return score
