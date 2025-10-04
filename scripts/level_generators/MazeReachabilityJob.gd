extends Node

const LOGGER := preload("res://scripts/Logger.gd")
const LEVEL_NODE_FACTORY := preload("res://scripts/level_generators/LevelNodeFactory.gd")
const MAZE_UTILS := preload("res://scripts/level_generators/MazeUtils.gd")

var context
var main_scene: Node = null
var grid: Array = []
var start_cell: Vector2i = Vector2i.ZERO
var offset: Vector2 = Vector2.ZERO
var cell_size: float = 64.0
var player_collision_size: float = 32.0
var shadow_color: Color = Color(0, 0, 0, 1)
var debug_logging := false
var debug_logger: Callable = Callable()

func setup(
	context_ref,
	main_scene_ref: Node,
	grid_data: Array,
	start: Vector2i,
	offset_data: Vector2,
	cell_size_value: float,
	player_size: float,
	shadow_col: Color,
	debug_enabled: bool,
	debug_callable: Callable
) -> void:
	context = context_ref
	main_scene = main_scene_ref
	grid = grid_data
	start_cell = start
	offset = offset_data
	cell_size = cell_size_value
	player_collision_size = player_size
	shadow_color = shadow_col
	debug_logging = debug_enabled
	debug_logger = debug_callable

func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_evaluate()
	queue_free()

func _evaluate() -> void:
	if context == null or not is_instance_valid(context):
		return
	if grid.is_empty():
		return
	var space_state := _get_space_state()
	if space_state == null:
		_log_debug("Maze reachability evaluation skipped: space state unavailable")
		return
	var rows: int = grid.size()
	var cols: int = (grid[0] as Array).size()
	var reachable := _find_reachable_areas(space_state, rows, cols)
	var unreachable_count := 0
	for y in range(rows):
		for x in range(cols):
			if not grid[y][x] and not reachable[y][x]:
				unreachable_count += 1
				var base := offset + Vector2(x * cell_size, y * cell_size)
				var shadow := LEVEL_NODE_FACTORY.create_maze_shadow_segment(
					context.maze_shadows.size(),
					cell_size,
					cell_size,
					shadow_color
				)
				shadow.position = base
				context.maze_shadows.append(shadow)
				context.add_generated_node(shadow, main_scene)
	if unreachable_count > 0:
		_log_debug("Maze unreachable pockets filled: %d" % unreachable_count)
	else:
		_log_debug("Maze reachable everywhere from start cell %s" % str(start_cell))


func _find_reachable_areas(space_state: PhysicsDirectSpaceState2D, rows: int, cols: int) -> Array:
	var reachable: Array = []
	for y in range(rows):
		var row: Array = []
		row.resize(cols)
		for x in range(cols):
			row[x] = false
		reachable.append(row)
	var start_pos := start_cell
	var needs_fallback: bool = (
		start_pos.x < 0 or start_pos.x >= cols or
		start_pos.y < 0 or start_pos.y >= rows or
		grid[start_pos.y][start_pos.x]
	)
	if needs_fallback:
		start_pos = Vector2i(-1, -1)
		for y in range(rows):
			var found := false
			for x in range(cols):
				if not grid[y][x]:
					start_pos = Vector2i(x, y)
					found = true
					break
			if found:
				break
	if start_pos == Vector2i(-1, -1):
		return reachable
	var player_shape := RectangleShape2D.new()
	player_shape.size = Vector2(player_collision_size, player_collision_size)
	var start_world := MAZE_UTILS.maze_cell_to_world(start_pos, offset, cell_size)
	if not _can_player_fit_at(space_state, player_shape, start_world):
		_log_debug("Start cell %s blocked for player footprint" % str(start_pos))
		player_shape = null
	var queue: Array = [start_pos]
	reachable[start_pos.y][start_pos.x] = true
	var directions := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for dir in directions:
			var next: Vector2i = current + dir
			if (
				next.x >= 0 and next.x < cols and
				next.y >= 0 and next.y < rows and
				not grid[next.y][next.x] and
				not reachable[next.y][next.x]
			):
				if player_shape and not _can_traverse_between_cells(space_state, player_shape, current, next):
					continue
				reachable[next.y][next.x] = true
				queue.append(next)
	return reachable

func _can_traverse_between_cells(
	space_state: PhysicsDirectSpaceState2D,
	player_shape: RectangleShape2D,
	current: Vector2i,
	next: Vector2i
) -> bool:
	var from_world := MAZE_UTILS.maze_cell_to_world(current, offset, cell_size)
	var to_world := MAZE_UTILS.maze_cell_to_world(next, offset, cell_size)
	if not _can_player_fit_at(space_state, player_shape, to_world):
		return false
	var delta: Vector2 = to_world - from_world
	var max_extent: float = max(player_shape.size.x, player_shape.size.y)
	var step_distance: float = max(max_extent * 0.35, 6.0)
	var steps := int(ceil(delta.length() / step_distance))
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var sample: Vector2 = from_world.lerp(to_world, t)
		if not _can_player_fit_at(space_state, player_shape, sample):
			return false
	return true

func _can_player_fit_at(
	space_state: PhysicsDirectSpaceState2D,
	player_shape: RectangleShape2D,
	position: Vector2
) -> bool:
	if space_state == null or player_shape == null:
		return true
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = player_shape
	params.transform = Transform2D.IDENTITY
	params.transform.origin = position
	params.collide_with_areas = false
	params.collide_with_bodies = true
	params.margin = 0.05
	var results := space_state.intersect_shape(params, 1)
	return results.is_empty()


func _get_space_state() -> PhysicsDirectSpaceState2D:
	if main_scene and is_instance_valid(main_scene):
		var world: World2D = main_scene.get_world_2d()
		if world:
			return world.direct_space_state
	if context and is_instance_valid(context):
		var context_world: World2D = context.get_world_2d()
		if context_world:
			return context_world.direct_space_state
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var tree: SceneTree = loop
		var root := tree.root
		if root and root.world_2d:
			return root.world_2d.direct_space_state
	return null

func _log_debug(message: String) -> void:
	if debug_logger.is_valid():
		debug_logger.call(message)
	elif debug_logging:
		LOGGER.log_generation(message)
