extends RefCounted
class_name ComplexMazeGraph

static func get_edge_cells(cells: Dictionary, columns: int, rows: int) -> Array:
	var edges: Array = []
	for cell in cells.values():
		var typed = cell
		if typed == null: continue
		var pos: Vector2i = typed.grid_pos
		if pos.x == 0 or pos.x == columns - 1 or pos.y == 0 or pos.y == rows - 1:
			edges.append(typed)
	return edges

static func connected_neighbours(cells: Dictionary, columns: int, rows: int, cell) -> Array:
	var result: Array = []
	if cell == null: return result
	var pos: Vector2i = cell.grid_pos
	if pos.x > 0:
		var left_cell = cells.get(Vector2i(pos.x - 1, pos.y))
		if left_cell and not cell.wall_left and not left_cell.wall_right:
			result.append(left_cell)
	if pos.x < columns - 1:
		var right_cell = cells.get(Vector2i(pos.x + 1, pos.y))
		if right_cell and not cell.wall_right and not right_cell.wall_left:
			result.append(right_cell)
	if pos.y > 0:
		var up_cell = cells.get(Vector2i(pos.x, pos.y - 1))
		if up_cell and not cell.wall_up and not up_cell.wall_down:
			result.append(up_cell)
	if pos.y < rows - 1:
		var down_cell = cells.get(Vector2i(pos.x, pos.y + 1))
		if down_cell and not cell.wall_down and not down_cell.wall_up:
			result.append(down_cell)
	return result

static func compute_distances(cells: Dictionary, columns: int, rows: int, start_cell) -> Dictionary:
	var distances: Dictionary = {}
	if start_cell == null: return distances
	var queue: Array = [start_cell]
	distances[start_cell] = 0
	while queue.size() > 0:
		var current = queue.pop_front()
		var base = int(distances.get(current, 0))
		for neighbour in connected_neighbours(cells, columns, rows, current):
			if distances.has(neighbour): continue
			distances[neighbour] = base + 1
			queue.append(neighbour)
	return distances

static func pick_exit_cell(cells: Dictionary, columns: int, rows: int, start_cell):
	var edges = get_edge_cells(cells, columns, rows)
	var distances = compute_distances(cells, columns, rows, start_cell)
	var best = start_cell
	var best_distance := -1
	for cell in edges:
		var dist = int(distances.get(cell, -1))
		if dist > best_distance:
			best_distance = dist
			best = cell
	return best
