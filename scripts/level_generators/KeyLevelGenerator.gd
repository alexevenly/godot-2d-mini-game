extends Node

class_name KeysGenerator

const EDGE_TYPE_OPEN := StringName("open")
const EDGE_TYPE_WALL := StringName("wall")
const EDGE_TYPE_DOOR := StringName("door")

const MIN_DIMENSION := 14
const MAX_DIMENSION := 22
const MIN_DOOR_PAIRS := 2
const MAX_DOOR_PAIRS := 4
const MAX_ATTEMPTS := 64
const EXTRA_EDGE_CHANCE := 0.32
const THIN_WALL_TRIES := 12
const MAX_THIN_WALLS := 3

const COLOR_SEQUENCE := [StringName("Y"), StringName("R"), StringName("B"), StringName("P")]
const COLOR_MAP := {
	StringName("Y"): Color(1.0, 0.756863, 0.027451, 1.0),
	StringName("R"): Color(0.956863, 0.262745, 0.211765, 1.0),
	StringName("B"): Color(0.129412, 0.588235, 0.952941, 1.0),
	StringName("P"): Color(0.611765, 0.152941, 0.690196, 1.0)
}

@export var cell_size: int = 32
@export var line_thickness: float = 0.12

var origin_offset: Vector2 = Vector2.ZERO
var last_render_data: Dictionary = {}
class EdgeSpec:
	var type: StringName
	var color: StringName

	func _init(t: StringName = EDGE_TYPE_OPEN, c: StringName = StringName()):
		type = t
		color = c

class KeySpec:
	var cell: Vector2i
	var color: StringName

	func _init(p_cell: Vector2i, p_color: StringName):
		cell = p_cell
		color = p_color

class DoorSpec:
	var a: Vector2i
	var b: Vector2i
	var color: StringName

	func _init(p_a: Vector2i, p_b: Vector2i, p_color: StringName):
		a = p_a
		b = p_b
		color = p_color

class WallSpec:
	var a: Vector2i
	var b: Vector2i

	func _init(p_a: Vector2i, p_b: Vector2i):
		a = p_a
		b = p_b

class KeysLevel:
	var width: int
	var height: int
	var start: Vector2i
	var exit: Vector2i
	var keys: Array[KeySpec] = []
	var doors: Array[DoorSpec] = []
	var thin_walls: Array[WallSpec] = []
	var adjacency: Dictionary = {}

	func _init(p_width: int, p_height: int, p_start: Vector2i, p_exit: Vector2i, p_adjacency: Dictionary):
		width = p_width
		height = p_height
		start = p_start
		exit = p_exit
		adjacency = p_adjacency

	func get_edge(a: Vector2i, b: Vector2i) -> EdgeSpec:
		if adjacency.has(a) and adjacency[a].has(b):
			return adjacency[a][b]
		return null

func generate(seed: int = 0, door_pairs: int = -1) -> KeysLevel:
	var rng := RandomNumberGenerator.new()
	if seed == 0:
		rng.randomize()
	else:
		rng.seed = seed
	for _attempt in range(MAX_ATTEMPTS):
		var width := rng.randi_range(MIN_DIMENSION, MAX_DIMENSION)
		var height := rng.randi_range(MIN_DIMENSION, MAX_DIMENSION)
		var start := Vector2i(width / 2, height / 2)
		var build: Dictionary = _build_base_graph(width, height, start, rng)
		if build.is_empty():
			continue
		var adjacency: Dictionary = build["adjacency"]
		var exit_cell: Vector2i = _select_exit(start, adjacency)
		var path: Array[Vector2i] = _bfs_path(start, exit_cell, adjacency)
		if path.size() < 6:
			continue
		var max_pairs: int = min(MAX_DOOR_PAIRS, int((path.size() - 2) / 2))
		if max_pairs < MIN_DOOR_PAIRS:
			continue
		var target_pairs := door_pairs
		if target_pairs < MIN_DOOR_PAIRS:
			target_pairs = rng.randi_range(MIN_DOOR_PAIRS, max_pairs)
		target_pairs = clamp(target_pairs, MIN_DOOR_PAIRS, max_pairs)
		var colors: Array[StringName] = []
		for color_index in range(target_pairs):
			colors.append(COLOR_SEQUENCE[color_index])
		_shuffle_with_rng(colors, rng)
		var placement: Dictionary = _place_keys_and_doors(path, colors, adjacency, rng)
		if placement.is_empty():
			continue
		var level := KeysLevel.new(width, height, start, exit_cell, adjacency)
		level.keys = placement["keys"]
		level.doors = placement["doors"]
		_add_thin_walls(level, path, rng)
		if not _validate_level(level):
			continue
		return level
	return null

func render(level: KeysLevel, parent: Node) -> void:
	if level == null or parent == null:
		return
	last_render_data = {
		"container": null,
		"door_lines": [] as Array[Line2D],
		"door_bodies": [] as Array[StaticBody2D],
		"wall_lines": [] as Array[Line2D],
		"wall_bodies": [] as Array[StaticBody2D],
		"keys": [] as Array[Area2D],
		"exit": null
	}
	var container: Node2D = Node2D.new()
	container.name = "KeysLevel"
	container.position = origin_offset
	parent.add_child(container)
	last_render_data["container"] = container
	var thickness_px: float = clamp(cell_size * line_thickness, 2.0, 8.0)
	for wall in level.thin_walls:
		var wall_line: Line2D = _draw_edge(container, wall.a, wall.b, thickness_px, Color.WHITE, true)
		(last_render_data["wall_lines"] as Array[Line2D]).append(wall_line)
	for door in level.doors:
		var color: Color = COLOR_MAP.get(door.color, Color.WHITE)
		var door_line: Line2D = _draw_edge(container, door.a, door.b, thickness_px, color, false)
		var door_body: StaticBody2D = _draw_collision(container, door.a, door.b, thickness_px)
		(last_render_data["door_lines"] as Array[Line2D]).append(door_line)
		(last_render_data["door_bodies"] as Array[StaticBody2D]).append(door_body)
	for wall in level.thin_walls:
		var wall_body: StaticBody2D = _draw_collision(container, wall.a, wall.b, thickness_px)
		(last_render_data["wall_bodies"] as Array[StaticBody2D]).append(wall_body)
	var key_size: float = min(cell_size * 0.35, cell_size * 0.4)
	for key_spec in level.keys:
		var key_node: Area2D = _draw_key(container, key_spec, key_size)
		(last_render_data["keys"] as Array[Area2D]).append(key_node)
	var exit_rect: ColorRect = _draw_exit(container, level.exit)
	last_render_data["exit"] = exit_rect

func get_render_data() -> Dictionary:
	return last_render_data.duplicate(true)

func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2((cell.x + 0.5) * float(cell_size), (cell.y + 0.5) * float(cell_size)) + origin_offset

func find_path_with_keys(level: KeysLevel) -> Array[Vector2i]:
	if level == null:
		return []
	var color_to_bit: Dictionary = {}
	for i in range(level.keys.size()):
		color_to_bit[level.keys[i].color] = i
	var key_lookup: Dictionary = {}
	for key_spec in level.keys:
		key_lookup[key_spec.cell] = key_spec.color
	var start_state := Vector3i(level.start.x, level.start.y, 0)
	var queue: Array[Vector3i] = [start_state]
	var visited: Dictionary = {}
	visited[start_state] = null
	while not queue.is_empty():
		var state: Vector3i = queue.pop_front()
		var cell := Vector2i(state.x, state.y)
		var mask := state.z
		if cell == level.exit:
			return _reconstruct_path(visited, state)
		for neighbor in level.adjacency.get(cell, {}):
			var edge: EdgeSpec = level.adjacency[cell][neighbor]
			if edge == null or edge.type == EDGE_TYPE_WALL:
				continue
			if edge.type == EDGE_TYPE_DOOR:
				var bit: int = color_to_bit.get(edge.color, -1)
				if bit == -1 or (mask & (1 << bit)) == 0:
					continue
			var next_mask: int = mask
			if key_lookup.has(neighbor):
				var bit_index: int = color_to_bit.get(key_lookup[neighbor], -1)
				if bit_index >= 0:
					next_mask = next_mask | (1 << bit_index)
			var next_state: Vector3i = Vector3i(neighbor.x, neighbor.y, next_mask)
			if not visited.has(next_state):
				visited[next_state] = state
				queue.append(next_state)
	return []

func _build_base_graph(width: int, height: int, start: Vector2i, rng: RandomNumberGenerator) -> Dictionary:
	var adjacency: Dictionary = {}
	for y in range(height):
		for x in range(width):
			adjacency[Vector2i(x, y)] = {}
	var stack: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for dir in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var next := Vector2i(current.x + dir[0], current.y + dir[1])
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height:
				continue
			if visited.has(next):
				continue
			options.append(next)
		if options.is_empty():
			stack.pop_back()
			continue
		_shuffle_with_rng(options, rng)
		var chosen: Vector2i = options.front()
		visited[chosen] = true
		stack.append(chosen)
		_link_cells(adjacency, current, chosen, EDGE_TYPE_OPEN, StringName())
	for y in range(height):
		for x in range(width):
			var cell := Vector2i(x, y)
			for offset in [[1, 0], [0, 1]]:
				var neighbor := Vector2i(x + offset[0], y + offset[1])
				if neighbor.x >= width or neighbor.y >= height:
					continue
				if adjacency[cell].has(neighbor):
					continue
				if rng.randf() < EXTRA_EDGE_CHANCE:
					_link_cells(adjacency, cell, neighbor, EDGE_TYPE_OPEN, StringName())
	return {"adjacency": adjacency}

func _select_exit(start: Vector2i, adjacency: Dictionary) -> Vector2i:
	var queue: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var last := start
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		last = cell
		for neighbor in adjacency.get(cell, {}):
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return last

func _bfs_path(start: Vector2i, goal: Vector2i, adjacency: Dictionary) -> Array[Vector2i]:
	var queue: Array[Vector2i] = [start]
	var parent: Dictionary = {start: Vector2i(-1, -1)}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal:
			break
		for neighbor in adjacency.get(cell, {}):
			if parent.has(neighbor):
				continue
			var edge: EdgeSpec = adjacency[cell][neighbor]
			if edge == null or edge.type == EDGE_TYPE_WALL:
				continue
			parent[neighbor] = cell
			queue.append(neighbor)
	if not parent.has(goal):
		return []
	var path: Array[Vector2i] = []
	var current := goal
	while current != Vector2i(-1, -1):
		path.push_front(current)
		current = parent.get(current, Vector2i(-1, -1))
	return path

func _place_keys_and_doors(path: Array[Vector2i], colors: Array, adjacency: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var door_specs: Array[DoorSpec] = []
	var key_specs: Array[KeySpec] = []
	var prev_bound := 1
	for i in range(colors.size()):
		var remaining := colors.size() - i - 1
		var max_key_index := path.size() - 2 - (remaining * 2)
		if max_key_index < prev_bound:
			return {}
		var key_index := rng.randi_range(prev_bound, max_key_index)
		var min_door_index := key_index + 1
		var max_door_index := path.size() - 1 - (remaining * 2 + 1)
		if max_door_index < min_door_index:
			return {}
		var door_index := rng.randi_range(min_door_index, max_door_index)
		var key_cell: Vector2i = path[key_index]
		var door_a: Vector2i = path[door_index - 1]
		var door_b: Vector2i = path[door_index]
		var color: StringName = colors[i]
		key_specs.append(KeySpec.new(key_cell, color))
		_set_edge_type(adjacency, door_a, door_b, EDGE_TYPE_DOOR, color)
		door_specs.append(DoorSpec.new(door_a, door_b, color))
		prev_bound = door_index + 1
	return {"doors": door_specs, "keys": key_specs}

func _add_thin_walls(level: KeysLevel, path: Array[Vector2i], rng: RandomNumberGenerator) -> void:
	var path_edges: Dictionary = {}
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		path_edges[_edge_key(a, b)] = true
	var candidates: Array = []
	var seen: Dictionary = {}
	for cell in level.adjacency.keys():
		for neighbor in level.adjacency[cell].keys():
			var edge_key: String = _edge_key(cell, neighbor)
			if seen.has(edge_key):
				continue
			seen[edge_key] = true
			var edge: EdgeSpec = level.adjacency[cell][neighbor]
			if edge == null or edge.type != EDGE_TYPE_OPEN:
				continue
			if path_edges.has(edge_key):
				continue
			candidates.append([cell, neighbor])
	_shuffle_with_rng(candidates, rng)
	var added: int = 0
	for attempt in range(min(THIN_WALL_TRIES, candidates.size())):
		if added >= MAX_THIN_WALLS:
			break
		var pair: Array = candidates[attempt]
		var a: Vector2i = pair[0]
		var b: Vector2i = pair[1]
		_set_edge_type(level.adjacency, a, b, EDGE_TYPE_WALL, StringName())
		if _has_basic_path(level, true):
			level.thin_walls.append(WallSpec.new(a, b))
			added += 1
		else:
			_set_edge_type(level.adjacency, a, b, EDGE_TYPE_OPEN, StringName())

func _validate_level(level: KeysLevel) -> bool:
	var path: Array[Vector2i] = find_path_with_keys(level)
	if path.is_empty():
		return false
	if not _doors_preserve_connectivity(level):
		return false
	if not _doors_gate_progress(level):
		return false
	return true

func _doors_preserve_connectivity(level: KeysLevel) -> bool:
	var backups: Array = []
	for door in level.doors:
		var edge: EdgeSpec = level.get_edge(door.a, door.b)
		if edge == null:
			return false
		backups.append([edge, edge.type, edge.color])
		edge.type = EDGE_TYPE_OPEN
		edge.color = StringName()
	var connected: bool = _has_basic_path(level, true)
	for data in backups:
		var edge: EdgeSpec = data[0]
		edge.type = data[1]
		edge.color = data[2]
	return connected

func _doors_gate_progress(level: KeysLevel) -> bool:
	for door in level.doors:
		var edge: EdgeSpec = level.get_edge(door.a, door.b)
		if edge == null:
			return false
		var old_type := edge.type
		var old_color := edge.color
		edge.type = EDGE_TYPE_WALL
		var connected: bool = _has_basic_path(level, true)
		edge.type = old_type
		edge.color = old_color
		if connected:
			return false
	return true

func _has_basic_path(level: KeysLevel, allow_doors: bool) -> bool:
	var queue: Array[Vector2i] = [level.start]
	var visited: Dictionary = {level.start: true}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == level.exit:
			return true
		for neighbor in level.adjacency.get(cell, {}):
			if visited.has(neighbor):
				continue
			var edge: EdgeSpec = level.adjacency[cell][neighbor]
			if edge == null:
				continue
			if edge.type == EDGE_TYPE_WALL:
				continue
			if edge.type == EDGE_TYPE_DOOR and not allow_doors:
				continue
			visited[neighbor] = true
			queue.append(neighbor)
	return false

func _link_cells(adjacency: Dictionary, a: Vector2i, b: Vector2i, type: StringName, color: StringName) -> void:
	var edge := EdgeSpec.new(type, color)
	adjacency[a][b] = edge
	adjacency[b][a] = edge

func _set_edge_type(adjacency: Dictionary, a: Vector2i, b: Vector2i, type: StringName, color: StringName) -> void:
	if not adjacency.has(a) or not adjacency[a].has(b):
		if type == EDGE_TYPE_OPEN:
			_link_cells(adjacency, a, b, type, color)
		return
	var edge: EdgeSpec = adjacency[a][b]
	if edge == null:
		edge = EdgeSpec.new(type, color)
		adjacency[a][b] = edge
		adjacency[b][a] = edge
		return
	edge.type = type
	edge.color = color

func _edge_key(a: Vector2i, b: Vector2i) -> String:
	if a < b:
		return "%d_%d_%d_%d" % [a.x, a.y, b.x, b.y]
	return "%d_%d_%d_%d" % [b.x, b.y, a.x, a.y]

func _reconstruct_path(visited: Dictionary, end_state: Vector3i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var current := end_state
	while visited.has(current):
		result.push_front(Vector2i(current.x, current.y))
		var prev: Variant = visited[current]
		if prev == null:
			break
		current = prev
	return result

func _shuffle_with_rng(array: Array, rng: RandomNumberGenerator) -> void:
	for i in range(array.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp: Variant = array[i]
		array[i] = array[j]
		array[j] = temp

func _draw_edge(parent: Node, a: Vector2i, b: Vector2i, thickness: float, color: Color, is_wall: bool) -> Line2D:
	var line := Line2D.new()
	line.width = thickness
	line.default_color = color
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	var start_point: Vector2
	var end_point: Vector2
	if a.x != b.x:
		var left: int = min(a.x, b.x)
		var y: int = a.y
		start_point = Vector2(left * cell_size, (y + 0.5) * cell_size)
		end_point = Vector2((left + 1) * cell_size, (y + 0.5) * cell_size)
	else:
		var top: int = min(a.y, b.y)
		var x: int = a.x
		start_point = Vector2((x + 0.5) * cell_size, top * cell_size)
		end_point = Vector2((x + 0.5) * cell_size, (top + 1) * cell_size)
	line.add_point(start_point)
	line.add_point(end_point)
	line.z_index = 1 if is_wall else 2
	parent.add_child(line)
	return line

func _draw_collision(parent: Node, a: Vector2i, b: Vector2i, thickness: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if a.x != b.x:
		rect.size = Vector2(cell_size, thickness)
		body.position = Vector2((min(a.x, b.x) + 0.5) * cell_size, (a.y + 0.5) * cell_size)
	else:
		rect.size = Vector2(thickness, cell_size)
		body.position = Vector2((a.x + 0.5) * cell_size, (min(a.y, b.y) + 0.5) * cell_size)
	shape.shape = rect
	body.add_child(shape)
	parent.add_child(body)
	return body

func _draw_key(parent: Node, key_spec: KeySpec, key_size: float) -> Area2D:
	var area := Area2D.new()
	area.position = Vector2((key_spec.cell.x + 0.5) * cell_size, (key_spec.cell.y + 0.5) * cell_size)
	var rect := ColorRect.new()
	rect.color = COLOR_MAP.get(key_spec.color, Color.WHITE)
	rect.size = Vector2(key_size, key_size)
	rect.position = Vector2(-key_size * 0.5, -key_size * 0.5)
	var shape := CollisionShape2D.new()
	var collider := RectangleShape2D.new()
	collider.size = Vector2(key_size, key_size)
	shape.shape = collider
	shape.position = Vector2.ZERO
	area.add_child(shape)
	area.add_child(rect)
	parent.add_child(area)
	return area

func _draw_exit(parent: Node, exit_cell: Vector2i) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = Color.html("#4caf50")
	rect.size = Vector2(cell_size, cell_size)
	rect.position = Vector2(exit_cell.x * cell_size, exit_cell.y * cell_size)
	parent.add_child(rect)
	return rect
