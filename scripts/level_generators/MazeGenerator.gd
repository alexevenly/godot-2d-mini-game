extends Object
class_name MazeGenerator

const LOGGER := preload("res://scripts/Logger.gd")
const MAZE_UTILS := preload("res://scripts/level_generators/MazeUtils.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")

const PLAYER_COLLISION_SIZE := 32.0
const BLACK_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 1.0)

const MAZE_LAYOUT_BUILDER := preload("res://scripts/level_generators/maze/MazeLayoutBuilder.gd")
const COMPLEX_MAZE_LAYOUT_BUILDER := preload("res://scripts/level_generators/maze/ComplexMazeLayoutBuilder.gd")
const MAZE_DOOR_PLANNER := preload("res://scripts/level_generators/maze/MazeDoorAndKeyPlanner.gd")
const MAZE_COIN_DISTRIBUTOR := preload("res://scripts/level_generators/maze/MazeCoinDistributor.gd")
const MAZE_DEBUG_LOGGER := preload("res://scripts/level_generators/maze/MazeDebugLogger.gd")

var context
var _layout_builder
var _complex_layout_builder
var _door_planner
var _coin_distributor
var _debug_logger

func _init(level_context, _obstacle_helper):
	context = level_context
	_layout_builder = MAZE_LAYOUT_BUILDER.new(context)
	_complex_layout_builder = COMPLEX_MAZE_LAYOUT_BUILDER.new(context)
	_door_planner = MAZE_DOOR_PLANNER.new()
	_coin_distributor = MAZE_COIN_DISTRIBUTOR.new(context)
	_debug_logger = MAZE_DEBUG_LOGGER.new()

func generate_complex_maze_level(include_coins: bool, main_scene, player_start_position: Vector2) -> void:
	var layout := _build_complex_layout(main_scene, player_start_position)
	if layout.is_empty():
		return
	var grid: Array = layout.get("grid", [])
	var cols: int = layout.get("cols", 0)
	var rows: int = layout.get("rows", 0)
	var cell_size: float = layout.get("cell_size", 0.0)
	var maze_offset: Vector2 = layout.get("maze_offset", Vector2.ZERO)
	var start_cell: Vector2i = layout.get("start_cell", Vector2i.ZERO)
	var farthest_data = MAZE_UTILS.find_farthest_cell(grid, start_cell, cols, rows)
	var exit_cell: Vector2i = layout.get("exit_cell", farthest_data["cell"])
	var path: Array = MAZE_UTILS.reconstruct_maze_path(grid, start_cell, exit_cell, cols, rows)
	var path_steps: int = max(path.size() - 1, int(farthest_data.get("distance", 0)))
	context.last_maze_path_length = float(max(path_steps, 1)) * cell_size
	var exit_position = MAZE_UTILS.maze_cell_to_world(exit_cell, maze_offset, cell_size)
	context.exit_spawner.clear_exit()
	context.exit_spawner.create_exit_at(exit_position, main_scene)
	var exit_node = context.exit_spawner.get_exit()
	if exit_node:
		context.exit_pos = exit_node.position
	context.coins.clear()
	if include_coins:
		_coin_distributor.populate_with_offpath_ratio(grid, start_cell, exit_cell, maze_offset, cell_size, main_scene, 0.5)

func generate_complex_maze_keys_level(main_scene, level: int, player_start_position: Vector2) -> void:
	var layout := _build_complex_layout(main_scene, player_start_position)
	if layout.is_empty():
		return
	var grid: Array = layout.get("grid", [])
	var cols: int = layout.get("cols", 0)
	var rows: int = layout.get("rows", 0)
	var cell_size: float = layout.get("cell_size", 0.0)
	var maze_offset: Vector2 = layout.get("maze_offset", Vector2.ZERO)
	var start_cell: Vector2i = layout.get("start_cell", Vector2i.ZERO)
	var start_world: Vector2 = layout.get("start_world", Vector2.ZERO)
	var farthest_data = MAZE_UTILS.find_farthest_cell(grid, start_cell, cols, rows)
	var exit_cell: Vector2i = layout.get("exit_cell", farthest_data["cell"])
	var path: Array = MAZE_UTILS.reconstruct_maze_path(grid, start_cell, exit_cell, cols, rows)
	var path_steps: int = max(path.size() - 1, int(farthest_data.get("distance", 0)))
	context.last_maze_path_length = float(max(path_steps, 1)) * cell_size
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
	var door_cells: Array = _door_planner.select_door_cells(path, start_cell, exit_cell, maze_offset, cell_size, desired_door_count)
	if door_cells.is_empty():
		door_cells.append(exit_cell)
	else:
		door_cells.sort_custom(func(a, b):
			var ia: int = int(path_index.get(a, 0))
			var ib: int = int(path_index.get(b, 0))
			return ia < ib)
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
		var reachable_cells: Array = _door_planner.collect_reachable_cells_before_door(grid, start_cell, blocked)
		var keys_target = clamp(1 + int(floor(level / 4.0)) + (i % 2), 1, 4)
		var key_cells: Array = _door_planner.select_key_cells(
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
			"color": color,
			"reachable": reachable_cells.duplicate()
		})
	var off_path_required = _ensure_complex_keys_off_path(door_data, taken_cells, path, start_cell, exit_cell)
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
	var actual_off_path := 0
	for cell in taken_cells:
		if not path_index.has(cell):
			actual_off_path += 1
	LOGGER.log_generation("Maze complex+Keys placed %d keys (%d off-path, required %d)" % [taken_cells.size(), actual_off_path, off_path_required])

func generate_maze_level(include_coins: bool, main_scene, player_start_position: Vector2) -> void:
	var layout := _build_layout(main_scene, player_start_position)
	if layout.is_empty():
		return
	var grid: Array = layout.get("grid", [])
	var cols: int = layout.get("cols", 0)
	var rows: int = layout.get("rows", 0)
	var cell_size: float = layout.get("cell_size", 0.0)
	var maze_offset: Vector2 = layout.get("maze_offset", Vector2.ZERO)
	var start_cell: Vector2i = layout.get("start_cell", Vector2i.ZERO)
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
	context.coins.clear()
	if include_coins:
		_coin_distributor.populate(grid, start_cell, farthest, maze_offset, cell_size, main_scene)

func generate_maze_keys_level(main_scene, level: int, player_start_position: Vector2) -> void:
	var layout := _build_layout(main_scene, player_start_position)
	if layout.is_empty():
		return
	var grid: Array = layout.get("grid", [])
	var cols: int = layout.get("cols", 0)
	var rows: int = layout.get("rows", 0)
	var cell_size: float = layout.get("cell_size", 0.0)
	var maze_offset: Vector2 = layout.get("maze_offset", Vector2.ZERO)
	var start_cell: Vector2i = layout.get("start_cell", Vector2i.ZERO)
	var start_world: Vector2 = layout.get("start_world", Vector2.ZERO)
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
	var door_cells: Array = _door_planner.select_door_cells(path, start_cell, exit_cell, maze_offset, cell_size, desired_door_count)
	if door_cells.is_empty():
		door_cells.append(exit_cell)
	else:
		door_cells.sort_custom(func(a, b):
			var ia: int = int(path_index.get(a, 0))
			var ib: int = int(path_index.get(b, 0))
			return ia < ib)
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
		var reachable_cells: Array = _door_planner.collect_reachable_cells_before_door(grid, start_cell, blocked)
		var keys_target = clamp(1 + int(floor(level / 4.0)) + (i % 2), 1, 4)
		var key_cells: Array = _door_planner.select_key_cells(
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

func _ensure_complex_keys_off_path(door_data: Array, taken_cells: Array, path: Array, start_cell: Vector2i, exit_cell: Vector2i) -> int:
	var path_index := {}
	for variant in path:
		var cell: Vector2i = variant
		path_index[cell] = true
	var total_keys := 0
	var off_path := 0
	for entry in door_data:
		var keys: Array = entry.get("keys", [])
		total_keys += keys.size()
		for key_cell in keys:
			if not path_index.has(key_cell):
				off_path += 1
	if total_keys <= 0:
		taken_cells.clear()
		return 0
	var required := int(ceil(total_keys * 0.5))
	if off_path < required:
		var needed := required - off_path
		var taken_set := {}
		for entry in door_data:
			for key_cell in entry.get("keys", []):
				taken_set[key_cell] = true
		for i in range(door_data.size()):
			if needed <= 0:
				break
			var entry: Dictionary = door_data[i]
			var keys: Array = entry.get("keys", [])
			if keys.is_empty():
				continue
			var door_cell: Vector2i = entry.get("cell", start_cell)
			var reachable: Array = entry.get("reachable", [])
			var candidates: Array = []
			for variant in reachable:
				var candidate: Vector2i = variant
				if candidate == start_cell or candidate == exit_cell or candidate == door_cell:
					continue
				if path_index.has(candidate):
					continue
				if taken_set.has(candidate):
					continue
				candidates.append(candidate)
			candidates.shuffle()
			for key_index in range(keys.size()):
				if needed <= 0:
					break
				var current_cell: Vector2i = keys[key_index]
				if not path_index.has(current_cell):
					continue
				while candidates.size() > 0 and needed > 0:
					var candidate: Vector2i = candidates.pop_back()
					if taken_set.has(candidate):
						continue
					taken_set.erase(current_cell)
					keys[key_index] = candidate
					taken_set[candidate] = true
					needed -= 1
					break
			entry["keys"] = keys
		taken_cells.clear()
		off_path = 0
		for entry in door_data:
			var keys: Array = entry.get("keys", [])
			for key_cell in keys:
				taken_cells.append(key_cell)
				if not path_index.has(key_cell):
					off_path += 1
		return required
	taken_cells.clear()
	for entry in door_data:
		for key_cell in entry.get("keys", []):
			taken_cells.append(key_cell)
	return required

func _build_layout(main_scene, player_start_position: Vector2) -> Dictionary:
	_debug_logger.configure()
	return _layout_builder.build(main_scene, player_start_position, _debug_logger, PLAYER_COLLISION_SIZE, BLACK_SHADOW_COLOR)

func _build_complex_layout(main_scene, player_start_position: Vector2) -> Dictionary:
	_debug_logger.configure()
	return _complex_layout_builder.build(main_scene, player_start_position, _debug_logger, PLAYER_COLLISION_SIZE, BLACK_SHADOW_COLOR)

