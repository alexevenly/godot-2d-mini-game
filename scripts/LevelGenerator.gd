extends Node2D

const Logger = preload("res://scripts/Logger.gd")

const DOOR_GROUP_COLORS := [
	Color(0.95, 0.49, 0.38, 1.0), # Coral
	Color(0.41, 0.68, 0.95, 1.0), # Sky blue
	Color(0.55, 0.83, 0.42, 1.0), # Green
	Color(0.95, 0.75, 0.35, 1.0), # Amber
	Color(0.74, 0.56, 0.95, 1.0), # Violet
	Color(0.37, 0.82, 0.74, 1.0)  # Teal
]

var obstacles: Array = []
var coins: Array = []
var exit_pos: Vector2 = Vector2.ZERO
var current_level_size: float = 1.0

var doors: Array = []
var key_items: Array = []
var maze_walls: Array = []
var key_barriers: Array = []
var player_spawn_override: Vector2 = Vector2.ZERO
var has_player_spawn_override: bool = false
var last_maze_path_length: float = 0.0

const MAZE_BASE_CELL_SIZE := 64.0

# Spawner nodes
@onready var obstacle_spawner = $ObstacleSpawner
@onready var coin_spawner = $CoinSpawner
@onready var exit_spawner = $ExitSpawner

func generate_level(level_size := 1.0, generate_obstacles := true, generate_coins := true, min_exit_distance_ratio := 0.4, use_full_map_coverage := true, main_scene: Node = null, level := 1, preserved_coin_count := 0, player_start_position: Vector2 = LevelUtils.PLAYER_START, level_type: int = GameState.LevelType.OBSTACLES_COINS):
	Logger.log_generation("LevelGenerator starting (size %.2f, type %d)" % [level_size, level_type])
	current_level_size = level_size
	exit_pos = Vector2.ZERO
	last_maze_path_length = 0.0
	clear_existing_objects()
	match level_type:
		GameState.LevelType.KEYS:
			_generate_keys_level(main_scene, level, player_start_position)
		GameState.LevelType.MAZE:
			_generate_maze_level(false, main_scene, player_start_position)
		GameState.LevelType.MAZE_COINS:
			_generate_maze_level(true, main_scene, player_start_position)
		_:
			_generate_standard_level(level_size, generate_obstacles, generate_coins, min_exit_distance_ratio, use_full_map_coverage, main_scene, level, preserved_coin_count, player_start_position)
	return 0

func _generate_standard_level(level_size: float, generate_obstacles: bool, generate_coins_flag: bool, min_exit_distance_ratio: float, use_full_map_coverage: bool, main_scene, level: int, preserved_coin_count: int, player_start_position: Vector2) -> void:
	# Step 1: Generate obstacles first (if enabled)
	if generate_obstacles:
		if obstacle_spawner and is_instance_valid(obstacle_spawner):
			obstacles = obstacle_spawner.generate_obstacles(level_size, use_full_map_coverage, main_scene, level)
			Logger.log_generation("LevelGenerator received %d obstacles" % obstacles.size())
		else:
			Logger.log_error("ObstacleSpawner unavailable; recreating instance")
			obstacle_spawner = preload("res://scripts/ObstacleSpawner.gd").new()
			obstacle_spawner.name = "ObstacleSpawner"
			add_child(obstacle_spawner)
			obstacles = obstacle_spawner.generate_obstacles(level_size, use_full_map_coverage, main_scene, level)
	else:
		Logger.log_generation("Obstacle generation disabled for this level")

	# Step 2: Generate exit
	if exit_spawner and is_instance_valid(exit_spawner):
		var exit_node = exit_spawner.generate_exit(level_size, obstacles, min_exit_distance_ratio, main_scene)
		if exit_node:
			exit_pos = exit_node.position
		else:
			Logger.log_error("ExitSpawner failed to create exit")
	else:
		Logger.log_error("ExitSpawner reference missing")

	# Step 3: Generate coins
	if generate_coins_flag:
		if coin_spawner and is_instance_valid(coin_spawner):
			coins = coin_spawner.generate_coins(level_size, obstacles, exit_pos, player_start_position, use_full_map_coverage, main_scene, level, preserved_coin_count)
			Logger.log_generation("LevelGenerator received %d coins" % coins.size())
		else:
			Logger.log_error("CoinSpawner unavailable; recreating instance")
			coin_spawner = preload("res://scripts/CoinSpawner.gd").new()
			coin_spawner.name = "CoinSpawner"
			add_child(coin_spawner)
			coins = coin_spawner.generate_coins(level_size, obstacles, exit_pos, player_start_position, use_full_map_coverage, main_scene, level, preserved_coin_count)
	else:
		Logger.log_generation("Coin generation disabled for this level")

func _generate_keys_level(main_scene, level: int, player_start_position: Vector2) -> void:
	var dims = LevelUtils.get_scaled_level_dimensions(current_level_size)
	var level_width: float = float(dims.width)
	var level_height: float = float(dims.height)
	var offset = Vector2(dims.offset_x, dims.offset_y)

	var max_doors = clamp(1 + int(ceil(level / 2.0)), 1, 3)
	var door_count = randi_range(1, max_doors)
	var door_width = 48.0
	var max_gap_height = max(level_height - 200.0, 140.0)
	var door_gap_height = clamp(level_height * 0.35, 140.0, max_gap_height)
	var segment_width = level_width / float(door_count + 1)

	var door_states: Array = []
	for i in range(door_count):
		door_states.append(true)
	if door_count > 1 and randi_range(0, 100) < 35:
		var open_index = randi_range(0, door_count - 1)
		door_states[open_index] = false

	var closed_indices: Array = []
	for i in range(door_count):
		if door_states[i]:
			closed_indices.append(i)
	if closed_indices.is_empty():
		door_states[0] = true
		closed_indices.append(0)

	var min_keys = max(2, closed_indices.size())
	var max_keys = 6
	var key_total = randi_range(min_keys, max_keys)
	var keys_per_door := {}
	for i in range(door_count):
		keys_per_door[i] = 0
	var remaining = key_total
	for idx in closed_indices:
		keys_per_door[idx] = 1
		remaining -= 1
	while remaining > 0 and closed_indices.size() > 0:
		var idx = closed_indices[randi() % closed_indices.size()]
		keys_per_door[idx] += 1
		remaining -= 1

	var door_layouts: Array = []
	for i in range(door_count):
		var center_x = offset.x + segment_width * float(i + 1)
		var min_center_y = offset.y + door_gap_height * 0.5 + 60.0
		var max_center_y = offset.y + level_height - door_gap_height * 0.5 - 60.0
		if max_center_y <= min_center_y:
			min_center_y = offset.y + level_height * 0.5
			max_center_y = min_center_y
		var door_center_y = randf_range(min_center_y, max_center_y)
		var door_top = door_center_y - door_gap_height * 0.5
		var layout := {
			"index": i,
			"center_x": center_x,
			"door_top": door_top,
			"door_bottom": door_top + door_gap_height,
			"keys_needed": int(keys_per_door[i]),
			"initially_open": not door_states[i],
			"color": _get_group_color(i)
		}
		door_layouts.append(layout)

	var spawn_y = clamp(player_start_position.y, offset.y + 80.0, offset.y + level_height - 80.0)
	var spawn_override = Vector2(offset.x + 80.0, spawn_y)
	_generate_key_level_obstacles(current_level_size, main_scene, level, offset, level_width, level_height, door_layouts, door_width, spawn_override)

	exit_spawner.clear_exit()
	coins.clear()
	var door_positions: Array = []
	var key_positions: Array = []
	var door_group_colors: Array = []
	for layout in door_layouts:
		var i = int(layout.get("index", 0))
		var center_x = float(layout.get("center_x", offset.x))
		door_positions.append(center_x)
		var door_top = float(layout.get("door_top", offset.y))
		var door_bottom = float(layout.get("door_bottom", door_top + door_gap_height))
		var group_color: Color = layout.get("color", _get_group_color(i))
		door_group_colors.append(group_color)
		var initially_open = layout.get("initially_open", false)
		var door = _create_door_node(i, int(layout.get("keys_needed", 0)), initially_open, door_gap_height, door_width, group_color)
		door.position = Vector2(center_x - door_width * 0.5, door_top)
		doors.append(door)
		_add_generated_node(door, main_scene)

		var top_segment_height = max(door_top - offset.y, 0.0)
		if top_segment_height > 0.0:
			var top_segment = _create_barrier_segment(door_width, top_segment_height)
			top_segment.position = Vector2(center_x - door_width * 0.5, offset.y)
			key_barriers.append(top_segment)
			_add_generated_node(top_segment, main_scene)

		var bottom_segment_height = max(offset.y + level_height - door_bottom, 0.0)
		if bottom_segment_height > 0.0:
			var bottom_segment = _create_barrier_segment(door_width, bottom_segment_height)
			bottom_segment.position = Vector2(center_x - door_width * 0.5, door_bottom)
			key_barriers.append(bottom_segment)
			_add_generated_node(bottom_segment, main_scene)

		var keys_needed = int(layout.get("keys_needed", 0))
		if keys_needed <= 0:
			continue

		var segment_left: float
		if i == 0:
			segment_left = offset.x + 60.0
		else:
			segment_left = door_positions[i - 1] + door_width * 0.5 + 60.0
		var segment_right = center_x - door_width * 0.5 - 60.0
		if segment_right <= segment_left:
			segment_right = segment_left + 40.0
		var min_y = offset.y + 80.0
		var max_y = offset.y + level_height - 80.0

		for j in range(keys_needed):
			var attempts = 0
			var key_pos = Vector2.ZERO
			var placed = false
			while attempts < 40 and not placed:
				key_pos = Vector2(randf_range(segment_left, segment_right), randf_range(min_y, max_y))
				var too_close = false
				for existing in key_positions:
					if existing.distance_to(key_pos) < 50.0:
						too_close = true
						break
				if not too_close:
					placed = true
				else:
					attempts += 1
			if not placed:
				key_pos = Vector2((segment_left + segment_right) * 0.5, offset.y + level_height * 0.5)
			key_positions.append(key_pos)
			var key_color = door_group_colors[i] if i < door_group_colors.size() else _get_group_color(i)
			var key_node = _create_key_node(door, key_pos, keys_needed, key_color)
			key_items.append(key_node)
			_add_generated_node(key_node, main_scene)

	_clear_obstacles_near_points(key_positions, 70.0)

	var exit_position = Vector2(offset.x + level_width - 120.0, offset.y + level_height * 0.5)
	exit_spawner.create_exit_at(exit_position, main_scene)
	var exit_node = exit_spawner.get_exit()
	if exit_node:
		exit_pos = exit_node.position
		_clear_obstacles_around_position(exit_pos, 100.0)

	_set_player_spawn_override(spawn_override)

func _generate_maze_level(include_coins: bool, main_scene, player_start_position: Vector2) -> void:
	var dims = LevelUtils.get_scaled_level_dimensions(current_level_size)
	var level_width: float = float(dims.width)
	var level_height: float = float(dims.height)
	var offset = Vector2(dims.offset_x, dims.offset_y)

	var cell_size = MAZE_BASE_CELL_SIZE
	var cols = int(floor(level_width / cell_size))
	var rows = int(floor(level_height / cell_size))
	cols = max(cols | 1, 5)
	rows = max(rows | 1, 5)
	var maze_width = cols * cell_size
	var maze_height = rows * cell_size
	var maze_offset = offset + Vector2((level_width - maze_width) * 0.5, (level_height - maze_height) * 0.5)

	var start_cell = _world_to_maze_cell(player_start_position, maze_offset, cell_size)
	start_cell = _ensure_odd_cell(start_cell, cols, rows)

	var grid = _init_maze_grid(cols, rows)
	_carve_maze(grid, start_cell, cols, rows)
	_spawn_maze_walls(grid, maze_offset, cell_size, main_scene)

	var farthest_data = _find_farthest_cell(grid, start_cell, cols, rows)
	var farthest: Vector2i = farthest_data["cell"]
	var path_steps: int = farthest_data["distance"]
	last_maze_path_length = float(max(path_steps, 1)) * cell_size
	var exit_position = _maze_cell_to_world(farthest, maze_offset, cell_size)
	exit_spawner.clear_exit()
	exit_spawner.create_exit_at(exit_position, main_scene)
	var exit_node = exit_spawner.get_exit()
	if exit_node:
		exit_pos = exit_node.position

	_set_player_spawn_override(_maze_cell_to_world(start_cell, maze_offset, cell_size))

	coins.clear()
	if include_coins:
		_generate_maze_coins(grid, start_cell, farthest, maze_offset, cell_size, main_scene)

func get_generated_coins():
	return coins

func get_generated_keys():
	return key_items

func get_generated_exit():
	if exit_spawner:
		return exit_spawner.get_exit()
	return null

func get_player_spawn_override():
	if has_player_spawn_override:
		return player_spawn_override
	return null

func get_last_maze_path_length() -> float:
	return last_maze_path_length

func is_exit_position_valid(pos, level_width, level_height):
	var margin = 32
	return pos.x >= margin and pos.x <= level_width - margin and pos.y >= margin and pos.y <= level_height - margin

func clear_existing_objects():
	for node in doors:
		if is_instance_valid(node):
			node.queue_free()
	doors.clear()
	for node in key_barriers:
		if is_instance_valid(node):
			node.queue_free()
	key_barriers.clear()
	for node in key_items:
		if is_instance_valid(node):
			node.queue_free()
	key_items.clear()
	for node in maze_walls:
		if is_instance_valid(node):
			node.queue_free()
	maze_walls.clear()

	if obstacle_spawner and is_instance_valid(obstacle_spawner):
		obstacle_spawner.clear_obstacles()
	if coin_spawner and is_instance_valid(coin_spawner):
		coin_spawner.clear_coins()
	if exit_spawner and is_instance_valid(exit_spawner):
		exit_spawner.clear_exit()

	for obstacle in obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	obstacles.clear()
	for coin in coins:
		if is_instance_valid(coin):
			coin.queue_free()
	coins.clear()
	exit_pos = Vector2.ZERO
	has_player_spawn_override = false
	player_spawn_override = Vector2.ZERO

func _set_player_spawn_override(pos: Vector2) -> void:
	has_player_spawn_override = true
	player_spawn_override = pos

func _add_generated_node(node: Node, main_scene) -> void:
	if node == null:
		return
	if main_scene:
		main_scene.call_deferred("add_child", node)
	else:
		call_deferred("add_child", node)

func _create_door_node(index: int, required_keys: int, initially_open: bool, height: float, width: float, group_color: Color) -> StaticBody2D:
	var door := StaticBody2D.new()
	door.name = "Door%d" % index
	door.set_script(preload("res://scripts/Door.gd"))
	door.required_keys = required_keys
	door.initially_open = initially_open
	door.door_id = index
	door.door_color = group_color
	door.set_meta("group_color", group_color)

	var body := ColorRect.new()
	body.name = "DoorBody"
	body.offset_right = width
	body.offset_bottom = height
	body.color = group_color
	door.add_child(body)

	var collision := CollisionShape2D.new()
	collision.name = "DoorCollision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision.shape = shape
	collision.position = Vector2(width * 0.5, height * 0.5)
	door.add_child(collision)

	return door

func _create_barrier_segment(width: float, height: float) -> StaticBody2D:
	var barrier := StaticBody2D.new()
	barrier.name = "DoorBarrier%d" % key_barriers.size()

	var body := ColorRect.new()
	body.name = "BarrierBody"
	body.offset_right = width
	body.offset_bottom = height
	body.color = Color(0.18, 0.21, 0.32, 1)
	barrier.add_child(body)

	var collision := CollisionShape2D.new()
	collision.name = "BarrierCollision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision.shape = shape
	collision.position = Vector2(width * 0.5, height * 0.5)
	barrier.add_child(collision)

	return barrier

func _create_key_node(door: StaticBody2D, spawn_position: Vector2, required_keys: int, key_color: Color) -> Area2D:
	var key := Area2D.new()
	key.name = "Key%d" % key_items.size()
	key.position = spawn_position
	key.set_script(preload("res://scripts/Key.gd"))
	if door and door.is_inside_tree():
		key.door_path = door.get_path()
	else:
		key.door_path = NodePath()
	key.required_key_count = required_keys
	key.door_reference = door
	if door:
		key.door_id = door.door_id
	key.key_color = key_color
	key.set_meta("group_color", key_color)

	var body := ColorRect.new()
	body.name = "KeyBody"
	body.offset_right = 24
	body.offset_bottom = 24
	body.color = key_color
	key.add_child(body)

	var collision := CollisionShape2D.new()
	collision.name = "KeyCollision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(24, 24)
	collision.shape = shape
	collision.position = Vector2(12, 12)
	key.add_child(collision)

	return key

func _generate_key_level_obstacles(level_size: float, main_scene, level: int, offset: Vector2, level_width: float, level_height: float, door_layouts: Array, door_width: float, spawn_override: Vector2) -> void:
	if obstacle_spawner == null or not is_instance_valid(obstacle_spawner):
		Logger.log_error("ObstacleSpawner unavailable for key level")
		return

	obstacles = obstacle_spawner.generate_obstacles(level_size, true, main_scene, level)
	if obstacles.is_empty():
		return

	var door_margin = 60.0
	var clearance_rects: Array = []
	for layout in door_layouts:
		if typeof(layout) != TYPE_DICTIONARY:
			continue
		var center_x = float(layout.get("center_x", offset.x))
		var rect_position = Vector2(center_x - (door_width * 0.5 + door_margin), offset.y)
		var rect_size = Vector2(door_width + door_margin * 2.0, level_height)
		clearance_rects.append(Rect2(rect_position, rect_size))

	if not clearance_rects.is_empty():
		_clear_obstacles_in_rects(clearance_rects)

	if spawn_override != Vector2.ZERO:
		_clear_obstacles_around_position(spawn_override, 140.0)

func _clear_obstacles_in_rects(rects: Array) -> void:
	if obstacles.is_empty():
		return

	var to_remove: Array = []
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			if not to_remove.has(obstacle):
				to_remove.append(obstacle)
			continue
		var obstacle_rect = LevelUtils.get_obstacle_rect(obstacle)
		for rect in rects:
			if rect is Rect2 and obstacle_rect.intersects(rect):
				if not to_remove.has(obstacle):
					to_remove.append(obstacle)
				break

	_remove_obstacles(to_remove)

func _clear_obstacles_near_points(points: Array, radius: float) -> void:
	if obstacles.is_empty() or points.is_empty() or radius <= 0.0:
		return

	var radius_sq = radius * radius
	var to_remove: Array = []
	for obstacle in obstacles:
		if not is_instance_valid(obstacle):
			if not to_remove.has(obstacle):
				to_remove.append(obstacle)
			continue
		for point in points:
			if typeof(point) != TYPE_VECTOR2:
				continue
			if obstacle.position.distance_squared_to(point) <= radius_sq:
				if not to_remove.has(obstacle):
					to_remove.append(obstacle)
				break

	_remove_obstacles(to_remove)

func _clear_obstacles_around_position(position: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	_clear_obstacles_near_points([position], radius)

func _remove_obstacles(obstacles_to_remove: Array) -> void:
	if obstacles_to_remove.is_empty():
		return

	var spawner_obstacles: Array = []
	if obstacle_spawner and is_instance_valid(obstacle_spawner):
		spawner_obstacles = obstacle_spawner.get_obstacles()

	for obstacle in obstacles_to_remove:
		if obstacle == null:
			continue
		if obstacles.has(obstacle):
			obstacles.erase(obstacle)
		if spawner_obstacles and spawner_obstacles.has(obstacle):
			spawner_obstacles.erase(obstacle)
		if is_instance_valid(obstacle):
			obstacle.queue_free()

func _get_group_color(index: int) -> Color:
	if DOOR_GROUP_COLORS.is_empty():
		return Color(0.9, 0.9, 0.2, 1.0)
	return DOOR_GROUP_COLORS[index % DOOR_GROUP_COLORS.size()]

func _create_coin_node(spawn_position: Vector2) -> Area2D:
	var coin := Area2D.new()
	coin.name = "Coin" + str(coins.size())
	coin.position = spawn_position

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

func _create_maze_wall(cell_size: float) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.name = "MazeWall" + str(maze_walls.size())

	var body := ColorRect.new()
	body.name = "WallBody"
	body.offset_right = cell_size
	body.offset_bottom = cell_size
	body.color = Color(0.15, 0.18, 0.28, 1)
	wall.add_child(body)

	var collision := CollisionShape2D.new()
	collision.name = "WallCollision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cell_size, cell_size)
	collision.shape = shape
	collision.position = Vector2(cell_size * 0.5, cell_size * 0.5)
	wall.add_child(collision)

	return wall

func _init_maze_grid(cols: int, rows: int) -> Array:
	var grid: Array = []
	for y in range(rows):
		var row := []
		row.resize(cols)
		for x in range(cols):
			row[x] = true
		grid.append(row)
	return grid

func _carve_maze(grid: Array, cell: Vector2i, cols: int, rows: int) -> void:
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
			_carve_maze(grid, next, cols, rows)

func _spawn_maze_walls(grid: Array, offset: Vector2, cell_size: float, main_scene) -> void:
	var rows = grid.size()
	var cols = grid[0].size()
	for y in range(rows):
		for x in range(cols):
			if grid[y][x]:
				var wall = _create_maze_wall(cell_size)
				wall.position = offset + Vector2(x * cell_size, y * cell_size)
				maze_walls.append(wall)
				if main_scene:
					main_scene.call_deferred("add_child", wall)
				else:
					call_deferred("add_child", wall)

func _find_farthest_cell(grid: Array, start: Vector2i, cols: int, rows: int) -> Dictionary:
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
		var world_pos = _maze_cell_to_world(cell, offset, cell_size)
		var coin = _create_coin_node(world_pos)
		coins.append(coin)
		if main_scene:
			main_scene.call_deferred("add_child", coin)
		else:
			call_deferred("add_child", coin)

func _maze_cell_to_world(cell: Vector2i, offset: Vector2, cell_size: float) -> Vector2:
	return offset + Vector2(cell.x * cell_size + cell_size * 0.5, cell.y * cell_size + cell_size * 0.5)

func _world_to_maze_cell(world: Vector2, offset: Vector2, cell_size: float) -> Vector2i:
	var x = int(floor((world.x - offset.x) / cell_size))
	var y = int(floor((world.y - offset.y) / cell_size))
	return Vector2i(x, y)

func _ensure_odd_cell(cell: Vector2i, cols: int, rows: int) -> Vector2i:
	var result = cell
	result.x = clamp(result.x, 1, cols - 2)
	result.y = clamp(result.y, 1, rows - 2)
	if result.x % 2 == 0:
		result.x += 1 if (result.x + 1 < cols) else -1
	if result.y % 2 == 0:
		result.y += 1 if (result.y + 1 < rows) else -1
	return result

