extends Object
class_name MazeUtils

static func init_maze_grid(cols: int, rows: int) -> Array:
	var grid: Array = []
	for y in range(rows):
		var row := []
		row.resize(cols)
		for x in range(cols):
			row[x] = true
		grid.append(row)
	return grid

static func carve_maze(grid: Array, cell: Vector2i, cols: int, rows: int) -> void:
	grid[cell.y][cell.x] = false
	var directions = [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
	directions.shuffle()
	for dir in directions:
		var next = cell + dir
		if next.x <= 0 or next.x >= cols - 1 or next.y <= 0 or next.y >= rows - 1:
			continue
		if grid[next.y][next.x]:
			var between = cell + Vector2i(dir.x / 2, dir.y / 2)
			grid[between.y][between.x] = false
			carve_maze(grid, next, cols, rows)

static func find_farthest_cell(grid: Array, start: Vector2i, cols: int, rows: int) -> Dictionary:
	var visited: Array = []
	for y in range(rows):
		var row := []
		row.resize(cols)
		for x in range(cols):
			row[x] = false
		visited.append(row)
	var queue: Array = []
	queue.append({"cell": start, "dist": 0})
	visited[start.y][start.x] = true
	var farthest = start
	var max_dist = 0
	while not queue.is_empty():
		var item = queue.pop_front()
		var cell: Vector2i = item["cell"]
		var dist: int = item["dist"]
		if dist > max_dist:
			max_dist = dist
			farthest = cell
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next = cell + dir
			if next.x < 0 or next.x >= cols or next.y < 0 or next.y >= rows:
				continue
			if grid[next.y][next.x] or visited[next.y][next.x]:
				continue
			visited[next.y][next.x] = true
			queue.append({"cell": next, "dist": dist + 1})
	return {"cell": farthest, "distance": max_dist}

static func reconstruct_maze_path(grid: Array, start: Vector2i, goal: Vector2i, cols: int, rows: int) -> Array:
	var visited: Dictionary = {}
	var parents: Dictionary = {}
	var queue: Array = []
	queue.append(start)
	visited[start] = true
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal:
			break
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next = cell + dir
			if next.x < 0 or next.x >= cols or next.y < 0 or next.y >= rows:
				continue
			if grid[next.y][next.x] or visited.has(next):
				continue
			visited[next] = true
			parents[next] = cell
			queue.append(next)
	var path: Array = []
	if not visited.has(goal):
		path.append(start)
		return path
	var current = goal
	while true:
		path.push_front(current)
		if current == start:
			break
		if not parents.has(current):
			break
		current = parents[current]
	return path

static func pick_maze_key_cells(grid: Array, path: Array, start_cell: Vector2i, door_cell: Vector2i, exit_cell: Vector2i, desired: int) -> Array:
	var result: Array = []
	if desired <= 0:
		return result
	var path_candidates: Array = []
	for cell_variant in path:
		var cell: Vector2i = cell_variant
		if cell == start_cell or cell == door_cell or cell == exit_cell:
			continue
		if path_candidates.has(cell):
			continue
		path_candidates.append(cell)
	path_candidates.shuffle()
	for cell in path_candidates:
		if result.size() >= desired:
			break
		result.append(cell)
	if result.size() >= desired:
		return result
	var rows = grid.size()
	if rows <= 0:
		return result
	var cols = grid[0].size() if rows > 0 else 0
	var extras: Array = []
	for y in range(rows):
		for x in range(cols):
			if grid[y][x]:
				continue
			var candidate = Vector2i(x, y)
			if candidate == start_cell or candidate == door_cell or candidate == exit_cell:
				continue
			if result.has(candidate):
				continue
			extras.append(candidate)
	extras.shuffle()
	for cell in extras:
		if result.size() >= desired:
			break
		result.append(cell)
	return result

static func maze_cell_to_world(cell: Vector2i, offset: Vector2, cell_size: float) -> Vector2:
	return offset + Vector2(cell.x * cell_size + cell_size * 0.5, cell.y * cell_size + cell_size * 0.5)

static func world_to_maze_cell(world: Vector2, offset: Vector2, cell_size: float) -> Vector2i:
	var x = int(floor((world.x - offset.x) / cell_size))
	var y = int(floor((world.y - offset.y) / cell_size))
	return Vector2i(x, y)

static func ensure_odd_cell(cell: Vector2i, cols: int, rows: int) -> Vector2i:
	var result = cell
	result.x = clamp(result.x, 1, cols - 2)
	result.y = clamp(result.y, 1, rows - 2)
	if result.x % 2 == 0:
		result.x += 1 if (result.x + 1 < cols) else -1
	if result.y % 2 == 0:
		result.y += 1 if (result.y + 1 < rows) else -1
	return result
