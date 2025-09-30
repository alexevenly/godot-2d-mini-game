extends Object
class_name CoinNavigation

const LevelUtils = preload("res://scripts/LevelUtils.gd")

static func build_navigation_context(level_size: float, obstacles: Array, cell_size: float, player_diameter: float, path_width_scale: float) -> Dictionary:
	var dimensions := LevelUtils.get_scaled_level_dimensions(level_size)
	var level_width: float = float(dimensions.width)
	var level_height: float = float(dimensions.height)
	var offset := Vector2(dimensions.offset_x, dimensions.offset_y)
	var cols := int(ceil(level_width / cell_size))
	var rows := int(ceil(level_height / cell_size))

	var blocked: Array = []
	for y in range(rows):
		var row := []
		row.resize(cols)
		for x in range(cols):
			row[x] = false
		blocked.append(row)

	var clearance := (player_diameter * path_width_scale) * 0.5
	var min_x := offset.x + clearance
	var max_x := offset.x + level_width - clearance
	var min_y := offset.y + clearance
	var max_y := offset.y + level_height - clearance

	for y in range(rows):
		for x in range(cols):
			var cell_center := offset + Vector2(float(x) + 0.5, float(y) + 0.5) * cell_size
			if cell_center.x < min_x or cell_center.x > max_x or cell_center.y < min_y or cell_center.y > max_y:
				blocked[y][x] = true

	for obstacle in obstacles:
		var rect := LevelUtils.get_obstacle_rect(obstacle)
		_mark_rect_blocked(blocked, rect, offset, cols, rows, cell_size, clearance)

	return {
		"blocked": blocked,
		"cols": cols,
		"rows": rows,
		"cell_size": cell_size,
		"offset": offset
	}

static func has_clear_path(navigation_ctx: Dictionary, start: Vector2, goal: Vector2) -> bool:
	if navigation_ctx.is_empty():
		return true

	var start_cell := _world_to_cell(navigation_ctx, start)
	var goal_cell := _world_to_cell(navigation_ctx, goal)

	if not _cell_in_bounds(navigation_ctx, start_cell) or not _cell_in_bounds(navigation_ctx, goal_cell):
		return false

	var blocked: Array = navigation_ctx["blocked"]
	if blocked[goal_cell.y][goal_cell.x]:
		return false

	if blocked[start_cell.y][start_cell.x]:
		blocked[start_cell.y][start_cell.x] = false

	var rows: int = navigation_ctx["rows"]
	var cols: int = navigation_ctx["cols"]
	var visited: Array = []
	for y in range(rows):
		var row := []
		row.resize(cols)
		for x in range(cols):
			row[x] = false
		visited.append(row)

	var queue: Array = []
	queue.append(start_cell)
	visited[start_cell.y][start_cell.x] = true

	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal_cell:
			return true

		for neighbor in _get_neighbors(cell):
			if not _cell_in_bounds(navigation_ctx, neighbor):
				continue
			if visited[neighbor.y][neighbor.x]:
				continue
			if blocked[neighbor.y][neighbor.x]:
				continue
			if abs(neighbor.x - cell.x) == 1 and abs(neighbor.y - cell.y) == 1:
				if blocked[cell.y][neighbor.x] or blocked[neighbor.y][cell.x]:
					continue
			visited[neighbor.y][neighbor.x] = true
			queue.append(neighbor)

	return false

static func _mark_rect_blocked(blocked: Array, rect: Rect2, offset: Vector2, cols: int, rows: int, cell_size: float, clearance: float) -> void:
	var expanded := rect.grow(clearance)
	var min_col := int(floor((expanded.position.x - offset.x) / cell_size))
	var max_col := int(ceil((expanded.position.x + expanded.size.x - offset.x) / cell_size)) - 1
	var min_row := int(floor((expanded.position.y - offset.y) / cell_size))
	var max_row := int(ceil((expanded.position.y + expanded.size.y - offset.y) / cell_size)) - 1

	for y in range(max(min_row, 0), min(max_row, rows - 1) + 1):
		for x in range(max(min_col, 0), min(max_col, cols - 1) + 1):
			blocked[y][x] = true

static func _world_to_cell(navigation_ctx: Dictionary, point: Vector2) -> Vector2i:
	var offset: Vector2 = navigation_ctx["offset"]
	var cell_size: float = navigation_ctx["cell_size"]
	var x := int(floor((point.x - offset.x) / cell_size))
	var y := int(floor((point.y - offset.y) / cell_size))
	return Vector2i(x, y)

static func _cell_in_bounds(navigation_ctx: Dictionary, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < navigation_ctx["cols"] and cell.y >= 0 and cell.y < navigation_ctx["rows"]

static func _get_neighbors(cell: Vector2i) -> Array:
	return [
		cell + Vector2i(1, 0),
		cell + Vector2i(-1, 0),
		cell + Vector2i(0, 1),
		cell + Vector2i(0, -1),
		cell + Vector2i(1, 1),
		cell + Vector2i(1, -1),
		cell + Vector2i(-1, 1),
		cell + Vector2i(-1, -1)
	]
