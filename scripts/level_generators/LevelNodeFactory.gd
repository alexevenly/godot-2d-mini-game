extends Object
class_name LevelNodeFactory

const DOOR_SCRIPT := preload("res://scripts/Door.gd")
const KEY_SCRIPT := preload("res://scripts/Key.gd")

static func create_door_node(index: int, required_keys: int, initially_open: bool, height: float, width: float, group_color: Color) -> StaticBody2D:
	var door := StaticBody2D.new()
	door.name = "Door%d" % index
	door.set_script(DOOR_SCRIPT)
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

static func create_barrier_segment(name_index: int, width: float, height: float, color: Color) -> StaticBody2D:
	var barrier := StaticBody2D.new()
	barrier.name = "DoorBarrier%d" % name_index

	var body := ColorRect.new()
	body.name = "BarrierBody"
	body.offset_right = width
	body.offset_bottom = height
	body.color = color
	barrier.add_child(body)

	var collision := CollisionShape2D.new()
	collision.name = "BarrierCollision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision.shape = shape
	collision.position = Vector2(width * 0.5, height * 0.5)
	barrier.add_child(collision)

	return barrier

static func create_key_node(name_index: int, door: StaticBody2D, spawn_position: Vector2, required_keys: int, key_color: Color) -> Area2D:
	var key := Area2D.new()
	key.name = "Key%d" % name_index
	key.position = spawn_position
	key.set_script(KEY_SCRIPT)
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

static func create_coin_node(name_index: int, spawn_position: Vector2) -> Area2D:
	var coin := Area2D.new()
	coin.name = "Coin" + str(name_index)
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

static func create_maze_wall(name_index: int, cell_size: float, wall_color: Color, size_ratio: float) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.name = "MazeWall" + str(name_index)

	var thickness := cell_size * size_ratio
	var inset := (cell_size - thickness) * 0.5

	var body := ColorRect.new()
	body.name = "WallBody"
	body.offset_left = inset
	body.offset_top = inset
	body.offset_right = inset + thickness
	body.offset_bottom = inset + thickness
	body.color = wall_color
	wall.add_child(body)

	var collision := CollisionShape2D.new()
	collision.name = "WallCollision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(thickness, thickness)
	collision.shape = shape
	collision.position = Vector2(cell_size * 0.5, cell_size * 0.5)
	wall.add_child(collision)

	return wall

static func create_maze_wall_segment(name_index: int, width: float, height: float, wall_color: Color) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.name = "MazeWall" + str(name_index)

	var body := ColorRect.new()
	body.name = "WallBody"
	body.offset_right = width
	body.offset_bottom = height
	body.color = wall_color
	wall.add_child(body)

	var collision := CollisionShape2D.new()
	collision.name = "WallCollision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision.shape = shape
	collision.position = Vector2(width * 0.5, height * 0.5)
	wall.add_child(collision)

	return wall

static func create_maze_shadow_segment(name_index: int, width: float, height: float, wall_color: Color) -> Node2D:
	var container := Node2D.new()
	container.name = "MazeShadow" + str(name_index)
	container.z_as_relative = false
	container.z_index = 3400

	var body := ColorRect.new()
	body.name = "ShadowBody"
	body.offset_right = width
	body.offset_bottom = height
	body.color = wall_color
	body.z_index = container.z_index
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.add_child(body)

	return container
