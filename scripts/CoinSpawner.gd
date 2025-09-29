extends Node2D

const Logger = preload("res://scripts/Logger.gd")

const NAV_CELL_SIZE := 16.0
const PLAYER_DIAMETER := 32.0
const PATH_WIDTH_SCALE := 1.05

var coins: Array = []
var current_level_size: float = 1.0

func generate_coins(level_size: float, obstacles: Array, exit_pos: Vector2, player_start: Vector2, use_full_map_coverage: bool = true, main_scene: Node = null, level: int = 1, preserved_coin_count: int = 0) -> Array:
	Logger.log_generation("CoinSpawner: generating coins (size %.2f, level %d)" % [level_size, level])
	current_level_size = level_size
	clear_coins()

	# 1) Счёт монет с мягкой прогрессией
	var base_coin_count: int = randi_range(10, 25)
	var level_multiplier: float = 1.0 + (level - 1) * 0.12 # было 0.15
	var coin_count: int = int(base_coin_count * current_level_size * level_multiplier)

	if level == 1:
		coin_count = max(6, coin_count)
	else:
		coin_count = max(preserved_coin_count + randi_range(1, 3), coin_count)

	# Ограничим разумными рамками
	coin_count = clamp(coin_count, 6, 40)

	Logger.log_generation("CoinSpawner target count %d (mult %.2f, preserved %d)" % [coin_count, level_multiplier, preserved_coin_count])
	if not use_full_map_coverage:
		Logger.log_generation("CoinSpawner using centered coverage grid")

	var navigation_ctx := _build_navigation_context(obstacles)

	# 2) Параметры генерации
	var grid_cols: int
	var grid_rows: int
	if use_full_map_coverage:
		grid_cols = 8
		grid_rows = 6
	else:
		grid_cols = 6
		grid_rows = 5

	# 3) Попытки: больше и с поэтапным послаблением
	var max_attempts_total: int = coin_count * 60
	var attempts_total: int = 0

	for i in range(coin_count):
		var placed := false
		var coin_attempts := 0

		while not placed and coin_attempts < 80: # было 20
			# коэффициент «расслабления» ограничений от 0.0 до 1.0
			var relax: float = clamp(float(coin_attempts) / 60.0, 0.0, 1.0)

			var coin := create_coin(grid_cols, grid_rows)
			if is_valid_coin_position_relaxed(coin.position, obstacles, exit_pos, relax) and _has_clear_path(navigation_ctx, player_start, coin.position):
				coins.append(coin)
				if main_scene:
					main_scene.call_deferred("add_child", coin)
				else:
					get_tree().current_scene.call_deferred("add_child", coin)
				placed = true
			else:
				coin.queue_free()
				coin_attempts += 1
				attempts_total += 1
				if attempts_total >= max_attempts_total:
					break

			if not placed:
				# Последний шанс: ослабляем максимально, но всё ещё избегаем жёстких пересечений
				var coin_fallback := create_coin(grid_cols, grid_rows)
				if is_valid_coin_position_relaxed(coin_fallback.position, obstacles, exit_pos, 1.0) and _has_clear_path(navigation_ctx, player_start, coin_fallback.position):
					coins.append(coin_fallback)
					if main_scene:
						main_scene.call_deferred("add_child", coin_fallback)
					else:
						get_tree().current_scene.call_deferred("add_child", coin_fallback)
				else:
					coin_fallback.queue_free()

		if attempts_total >= max_attempts_total:
			break

	Logger.log_generation("CoinSpawner placed %d coins" % coins.size())
	return coins

func create_coin(grid_cols: int, grid_rows: int) -> Area2D:
	var coin := Area2D.new()
	coin.name = "Coin" + str(coins.size())

	var pos := LevelUtils.get_grid_position(current_level_size, grid_cols, grid_rows, 40, 30)
	coin.position = pos

	var body := ColorRect.new()
	body.name = "CoinBody"
	body.offset_right = 20
	body.offset_bottom = 20
	body.color = Color(1, 1, 0, 1)
	coin.add_child(body)

	var collision := CollisionShape2D.new()
	collision.name = "CoinCollision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 20)
	collision.shape = shape
	collision.position = Vector2(10, 10)
	coin.add_child(collision)

	return coin

# --- Новая валидация с поэтапным «расслаблением» ---
# relax = 0.0 (строго) … 1.0 (мягко)
func is_valid_coin_position_relaxed(p: Vector2, obstacles: Array, exit_pos: Vector2, relax: float) -> bool:
	# Базовые радиусы
	var player_margin_strict: float = 24.0 # строгий запас
	var player_margin_relaxed: float = 10.0 # мягкий запас

	var coin_radius: float = 10.0
	var min_coin_gap_strict: float = 40.0
	var min_coin_gap_relaxed: float = 26.0

	var exit_gap_strict: float = 80.0
	var exit_gap_relaxed: float = 40.0

	# Лерпим в зависимости от relax
	var player_margin: float = lerp(player_margin_strict, player_margin_relaxed, relax)
	var min_coin_gap: float = lerp(min_coin_gap_strict, min_coin_gap_relaxed, relax)
	var exit_gap: float = lerp(exit_gap_strict, exit_gap_relaxed, relax)

	# 1) Дистанция от старта игрока
	if p.distance_to(LevelUtils.PLAYER_START) < (60.0 - 20.0 * relax):
		return false

	# 2) Препятствия: используем grow по Rect2 вместо полудиагонали
	for obstacle in obstacles:
		var r: Rect2 = LevelUtils.get_obstacle_rect(obstacle)
		var grown := r.grow(player_margin + coin_radius)
		if grown.has_point(p):
			return false

	# 3) Дистанция от других монет
	for c in coins:
		if p.distance_to(c.position) < min_coin_gap:
			return false

	# 4) Дистанция от выхода (и сравниваем корректно с ZERO)
	if exit_pos != Vector2.ZERO:
		if p.distance_to(exit_pos) < exit_gap:
			return false

	return true

func clear_coins():
	for coin in coins:
		if is_instance_valid(coin):
			coin.queue_free()
	coins.clear()

func _build_navigation_context(obstacles: Array) -> Dictionary:
	var dimensions := LevelUtils.get_scaled_level_dimensions(current_level_size)
	var level_width: float = float(dimensions.width)
	var level_height: float = float(dimensions.height)
	var offset := Vector2(dimensions.offset_x, dimensions.offset_y)
	var cell_size := NAV_CELL_SIZE
	var cols := int(ceil(level_width / cell_size))
	var rows := int(ceil(level_height / cell_size))

	var blocked: Array = []
	for y in range(rows):
		var row := []
		row.resize(cols)
		for x in range(cols):
			row[x] = false
		blocked.append(row)

	var clearance := (PLAYER_DIAMETER * PATH_WIDTH_SCALE) * 0.5
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

func _mark_rect_blocked(blocked: Array, rect: Rect2, offset: Vector2, cols: int, rows: int, cell_size: float, clearance: float) -> void:
	var expanded := rect.grow(clearance)
	var min_col := int(floor((expanded.position.x - offset.x) / cell_size))
	var max_col := int(ceil((expanded.position.x + expanded.size.x - offset.x) / cell_size)) - 1
	var min_row := int(floor((expanded.position.y - offset.y) / cell_size))
	var max_row := int(ceil((expanded.position.y + expanded.size.y - offset.y) / cell_size)) - 1

	for y in range(max(min_row, 0), min(max_row, rows - 1) + 1):
		for x in range(max(min_col, 0), min(max_col, cols - 1) + 1):
			blocked[y][x] = true

func _has_clear_path(navigation_ctx: Dictionary, start: Vector2, goal: Vector2) -> bool:
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

func _world_to_cell(navigation_ctx: Dictionary, point: Vector2) -> Vector2i:
	var offset: Vector2 = navigation_ctx["offset"]
	var cell_size: float = navigation_ctx["cell_size"]
	var x := int(floor((point.x - offset.x) / cell_size))
	var y := int(floor((point.y - offset.y) / cell_size))
	return Vector2i(x, y)

func _cell_in_bounds(navigation_ctx: Dictionary, cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < navigation_ctx["cols"] and cell.y >= 0 and cell.y < navigation_ctx["rows"]

func _get_neighbors(cell: Vector2i) -> Array:
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
