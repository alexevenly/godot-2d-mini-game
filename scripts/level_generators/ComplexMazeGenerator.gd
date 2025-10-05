extends Object
class_name ComplexMazeGenerator

const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")

const WALL_COLOR := Color(0.15, 0.18, 0.28, 1)
const EXIT_COLOR := Color(0.2, 0.8, 0.2, 1)

var context
var _walls: Array = []
var _exit_cell: Vector2i
var _start_cell: Vector2i
var _is_multi_path: bool = false

func _init(level_context):
	context = level_context

func generate_complex_maze(include_coins: bool, include_keys: bool, main_scene, level: int, player_start_position: Vector2) -> void:
	_clear_existing()
	
	# Random 50/50 chance for single vs multi-path maze
	_is_multi_path = randf() < 0.5
	
	var dims = LEVEL_UTILS.get_scaled_level_dimensions(context.current_level_size)
	var level_width: float = float(dims.width)
	var level_height: float = float(dims.height)
	var offset = Vector2(dims.offset_x, dims.offset_y)
	
	# Calculate grid that fills the entire level area
	var cell_size = 64.0 # Fixed cell size for complex maze (larger than player collision ~32)
	var cols = int(floor(level_width / cell_size))
	var rows = int(floor(level_height / cell_size))
	
	# Ensure minimum size
	cols = max(cols, 8)
	rows = max(rows, 6)
	
	# Generate maze grid with proper connectivity
	var grid = _generate_maze_grid(cols, rows, _is_multi_path)
	
	# Find start and exit positions
	_start_cell = _find_start_cell(grid, cols, rows, player_start_position, offset, cell_size)
	_exit_cell = _find_exit_cell(grid, cols, rows, _start_cell)
	
	# Build walls and place objects
	_build_maze_walls(grid, cols, rows, offset, cell_size, main_scene)
	_place_exit(main_scene, offset, cell_size)
	
	if include_coins:
		_place_coins(grid, cols, rows, offset, cell_size, main_scene)
	
	if include_keys:
		_place_keys(grid, cols, rows, offset, cell_size, main_scene, level)
	
	# Set player spawn override
	var start_world = Vector2(offset.x + _start_cell.x * cell_size + cell_size * 0.5,
							 offset.y + _start_cell.y * cell_size + cell_size * 0.5)
	context.set_player_spawn_override(start_world)

func _generate_maze_grid(cols: int, rows: int, is_multi_path: bool = false) -> Array:
	# Initialize grid - each cell has 4 possible walls (top, right, bottom, left)
	var grid: Array = []
	for y in range(rows):
		var row: Array = []
		for x in range(cols):
			# Each cell starts with all walls (represented as bit flags)
			# Bit 0: top wall, Bit 1: right wall, Bit 2: bottom wall, Bit 3: left wall
			row.append(15) # 1111 in binary - all walls present
		grid.append(row)
	
	# Use recursive backtracking to create maze
	var stack: Array = []
	var visited: Array = []
	
	# Initialize visited array
	for y in range(rows):
		var visited_row: Array = []
		for x in range(cols):
			visited_row.append(false)
		visited.append(visited_row)
	
	# Start from a random cell
	var start_x = randi_range(0, cols - 1)
	var start_y = randi_range(0, rows - 1)
	stack.append(Vector2i(start_x, start_y))
	visited[start_y][start_x] = true
	
	# For multi-path mazes, create additional openings
	if is_multi_path:
		_create_additional_paths(grid, cols, rows)
	
	var directions = [
		{"dir": Vector2i(0, -1), "wall_bit": 0, "opposite_bit": 2}, # up
		{"dir": Vector2i(1, 0), "wall_bit": 1, "opposite_bit": 3}, # right
		{"dir": Vector2i(0, 1), "wall_bit": 2, "opposite_bit": 0}, # down
		{"dir": Vector2i(-1, 0), "wall_bit": 3, "opposite_bit": 1} # left
	]
	
	while not stack.is_empty():
		var current = stack[-1]
		var neighbors: Array = []
		
		# Find unvisited neighbors
		for dir_data in directions:
			var next = current + dir_data.dir
			if (next.x >= 0 and next.x < cols and
				next.y >= 0 and next.y < rows and
				not visited[next.y][next.x]):
				neighbors.append(dir_data)
		
		if neighbors.size() > 0:
			# Choose random neighbor
			var chosen = neighbors[randi() % neighbors.size()]
			var next_cell = current + chosen.dir
			
			# Remove walls between current and next cell
			grid[current.y][current.x] &= ~(1 << chosen.wall_bit)
			grid[next_cell.y][next_cell.x] &= ~(1 << chosen.opposite_bit)
			
			# Mark as visited and add to stack
			visited[next_cell.y][next_cell.x] = true
			stack.append(next_cell)
		else:
			# Backtrack
			stack.pop_back()
	
	return grid

func _find_start_cell(grid: Array, cols: int, rows: int, player_start: Vector2, offset: Vector2, cell_size: float) -> Vector2i:
	# Convert player start to grid coordinates
	var grid_x = int(floor((player_start.x - offset.x) / cell_size))
	var grid_y = int(floor((player_start.y - offset.y) / cell_size))
	
	# Clamp to valid range
	grid_x = clamp(grid_x, 0, cols - 1)
	grid_y = clamp(grid_y, 0, rows - 1)
	
	return Vector2i(grid_x, grid_y)

func _find_exit_cell(grid: Array, cols: int, rows: int, start_cell: Vector2i) -> Vector2i:
	# Use BFS to find the farthest reachable cell from start
	var visited: Array = []
	for y in range(rows):
		var row: Array = []
		for x in range(cols):
			row.append(false)
		visited.append(row)
	
	var queue: Array = []
	var distances: Array = []
	
	# Initialize distances
	for y in range(rows):
		var dist_row: Array = []
		for x in range(cols):
			dist_row.append(-1)
		distances.append(dist_row)
	
	queue.append(start_cell)
	visited[start_cell.y][start_cell.x] = true
	distances[start_cell.y][start_cell.x] = 0
	
	var farthest = start_cell
	var max_distance = 0
	
	while not queue.is_empty():
		var current = queue.pop_front()
		var current_dist = distances[current.y][current.x]
		
		if current_dist > max_distance:
			max_distance = current_dist
			farthest = current
		
		# Check all 4 directions
		var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		var wall_bits = [0, 1, 2, 3] # top, right, bottom, left
		
		for i in range(4):
			var next = current + directions[i]
			if (next.x >= 0 and next.x < cols and
				next.y >= 0 and next.y < rows and
				not visited[next.y][next.x]):
				# Check if there's no wall between current and next
				var current_walls = grid[current.y][current.x]
				var has_wall = (current_walls & (1 << wall_bits[i])) != 0
				
				if not has_wall:
					visited[next.y][next.x] = true
					distances[next.y][next.x] = current_dist + 1
					queue.append(next)
	
	return farthest

func _build_maze_walls(grid: Array, cols: int, rows: int, offset: Vector2, cell_size: float, main_scene) -> void:
	var wall_thickness = 4.0 # Thicker walls (2x original)
	
	for y in range(rows):
		for x in range(cols):
			var cell_walls = grid[y][x]
			var cell_pos = Vector2(offset.x + x * cell_size, offset.y + y * cell_size)
			
			# Check each wall direction
			if (cell_walls & 1) != 0: # Top wall
				_create_wall_segment(cell_pos + Vector2(0, 0), cell_size, wall_thickness, main_scene)
			if (cell_walls & 2) != 0: # Right wall
				_create_wall_segment(cell_pos + Vector2(cell_size - wall_thickness, 0), wall_thickness, cell_size, main_scene)
			if (cell_walls & 4) != 0: # Bottom wall
				_create_wall_segment(cell_pos + Vector2(0, cell_size - wall_thickness), cell_size, wall_thickness, main_scene)
			if (cell_walls & 8) != 0: # Left wall
				_create_wall_segment(cell_pos + Vector2(0, 0), wall_thickness, cell_size, main_scene)

func _create_wall_segment(pos: Vector2, width: float, height: float, main_scene) -> void:
	var wall = LEVEL_NODE_FACTORY.create_maze_wall_segment(_walls.size(), width, height, WALL_COLOR)
	wall.position = pos
	_walls.append(wall)
	context.add_generated_node(wall, main_scene)

func _place_exit(main_scene, offset: Vector2, cell_size: float) -> void:
	# Create exit as a cell with 3 walls (only one opening)
	var exit_pos = Vector2(offset.x + _exit_cell.x * cell_size + cell_size * 0.5,
						   offset.y + _exit_cell.y * cell_size + cell_size * 0.5)
	
	# Create exit visual as a special cell (3px smaller in each dimension)
	var exit_body = ColorRect.new()
	exit_body.name = "ExitBody"
	var half_cell = cell_size * 0.5
	var shrink = 3.0
	exit_body.offset_left = - half_cell + shrink
	exit_body.offset_top = - half_cell + shrink
	exit_body.offset_right = half_cell - shrink
	exit_body.offset_bottom = half_cell - shrink
	exit_body.color = EXIT_COLOR
	
	var exit = Area2D.new()
	exit.name = "Exit"
	exit.position = exit_pos
	exit.z_index = 1 # Above background but below walls
	exit.add_child(exit_body)
	
	# Create collision for exit
	var collision = CollisionShape2D.new()
	collision.name = "ExitCollision"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(cell_size * 0.8, cell_size * 0.8) # Slightly smaller than cell
	collision.shape = shape
	exit.add_child(collision)
	
	# Add exit label
	var label = Label.new()
	label.name = "ExitLabel"
	label.offset_left = - cell_size * 0.3
	label.offset_top = - cell_size * 0.3
	label.offset_right = cell_size * 0.3
	label.offset_bottom = cell_size * 0.3
	label.text = "EXIT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exit.add_child(label)
	
	context.add_generated_node(exit, main_scene)
	context.exit_pos = exit_pos
	
	# Store exit reference for level object binder
	if context.has_method("set_exit_reference"):
		context.set_exit_reference(exit)

func _place_coins(grid: Array, cols: int, rows: int, offset: Vector2, cell_size: float, main_scene) -> void:
	# Place coins in accessible cells, avoiding start and exit
	var reachable_cells = _get_reachable_cells(grid, cols, rows, _start_cell)
	reachable_cells.erase(_start_cell)
	reachable_cells.erase(_exit_cell)
	
	var coin_count = min(8, reachable_cells.size())
	reachable_cells.shuffle()
	
	for i in range(coin_count):
		var cell = reachable_cells[i]
		var coin_pos = Vector2(offset.x + cell.x * cell_size + cell_size * 0.5,
							   offset.y + cell.y * cell_size + cell_size * 0.5)
		
		var coin = LEVEL_NODE_FACTORY.create_coin_node(context.coins.size(), coin_pos)
		context.coins.append(coin)
		context.add_generated_node(coin, main_scene)

func _place_keys(grid: Array, cols: int, rows: int, offset: Vector2, cell_size: float, main_scene, level: int) -> void:
	# Simple key placement for now - can be enhanced later
	var reachable_cells = _get_reachable_cells(grid, cols, rows, _start_cell)
	reachable_cells.erase(_start_cell)
	reachable_cells.erase(_exit_cell)
	
	if reachable_cells.size() > 0:
		var key_cell = reachable_cells[randi() % reachable_cells.size()]
		var key_pos = Vector2(offset.x + key_cell.x * cell_size + cell_size * 0.5,
							  offset.y + key_cell.y * cell_size + cell_size * 0.5)
		
		# Create a simple key (placeholder)
		var key = Area2D.new()
		key.name = "Key"
		key.position = key_pos
		
		var key_body = ColorRect.new()
		key_body.name = "KeyBody"
		key_body.offset_right = 20
		key_body.offset_bottom = 20
		key_body.color = Color(1, 0.5, 0, 1)
		key.add_child(key_body)
		
		context.add_generated_node(key, main_scene)

func _get_reachable_cells(grid: Array, cols: int, rows: int, start_cell: Vector2i) -> Array:
	var visited: Array = []
	for y in range(rows):
		var row: Array = []
		for x in range(cols):
			row.append(false)
		visited.append(row)
	
	var reachable: Array = []
	var queue: Array = [start_cell]
	visited[start_cell.y][start_cell.x] = true
	
	while not queue.is_empty():
		var current = queue.pop_front()
		reachable.append(current)
		
		# Check all 4 directions
		var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		var wall_bits = [0, 1, 2, 3]
		
		for i in range(4):
			var next = current + directions[i]
			if (next.x >= 0 and next.x < cols and
				next.y >= 0 and next.y < rows and
				not visited[next.y][next.x]):
				var current_walls = grid[current.y][current.x]
				var has_wall = (current_walls & (1 << wall_bits[i])) != 0
				
				if not has_wall:
					visited[next.y][next.x] = true
					queue.append(next)
	
	return reachable

func _create_additional_paths(grid: Array, cols: int, rows: int) -> void:
	# Create 2-3 additional paths by removing walls strategically
	var path_count = randi_range(2, 3)
	for i in range(path_count):
		var x = randi_range(1, cols - 2)
		var y = randi_range(1, rows - 2)
		
		# Remove a random wall to create an opening
		var wall_to_remove = randi_range(0, 3)
		grid[y][x] &= ~(1 << wall_to_remove)
		
		# Also remove the opposite wall in the adjacent cell
		var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
		var opposite_bits = [2, 3, 0, 1]
		var next = Vector2i(x, y) + directions[wall_to_remove]
		if next.x >= 0 and next.x < cols and next.y >= 0 and next.y < rows:
			grid[next.y][next.x] &= ~(1 << opposite_bits[wall_to_remove])

func get_is_multi_path() -> bool:
	return _is_multi_path

func _clear_existing() -> void:
	for wall in _walls:
		if is_instance_valid(wall):
			wall.queue_free()
	_walls.clear()
