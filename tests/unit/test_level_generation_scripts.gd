extends "res://tests/unit/test_utils.gd"

const LevelNodeFactory = preload("res://scripts/level_generators/LevelNodeFactory.gd")
const ObstacleUtilities = preload("res://scripts/level_generators/ObstacleUtilities.gd")
const KeyLevelGenerator = preload("res://scripts/level_generators/KeyLevelGenerator.gd")
const MazeGenerator = preload("res://scripts/level_generators/MazeGenerator.gd")
const ObstacleSpawner = preload("res://scripts/ObstacleSpawner.gd")
const CoinSpawner = preload("res://scripts/CoinSpawner.gd")
const LevelUtils = preload("res://scripts/LevelUtils.gd")

class ObstacleSpawnerStub extends RefCounted:
	var reference: Array

	func _init(obstacles: Array):
		reference = obstacles

	func get_obstacles() -> Array:
		return reference

class ObstacleContextStub extends RefCounted:
	var obstacles: Array = []
	var obstacle_spawner: ObstacleSpawnerStub

	func _init():
		obstacle_spawner = ObstacleSpawnerStub.new(obstacles)

func _make_obstacle(position: Vector2) -> StaticBody2D:
	var obstacle := track_node(StaticBody2D.new())
	obstacle.position = position
	var body := ColorRect.new()
	body.name = "ObstacleBody"
	body.offset_right = 40
	body.offset_bottom = 40
	obstacle.add_child(body)
	return obstacle

func get_suite_name() -> String:
	return "LevelGenerationScripts"

func test_level_node_factory_creates_door_with_children() -> void:
	var door := track_node(LevelNodeFactory.create_door_node(2, 1, false, 60.0, 40.0, Color(0.2, 0.4, 0.6)))
	assert_eq(door.name, "Door2")
	assert_eq(door.required_keys, 1)
	var body: ColorRect = door.get_node("DoorBody")
	assert_true(body != null)
	var collision: CollisionShape2D = door.get_node("DoorCollision")
	assert_true(collision != null)

func test_level_node_factory_key_node_references_door() -> void:
	var door := track_node(LevelNodeFactory.create_door_node(1, 2, false, 50.0, 30.0, Color(0.5, 0.2, 0.2)))
	var key := track_node(LevelNodeFactory.create_key_node(0, door, Vector2(12, 18), 2, Color(0.5, 0.2, 0.2)))
	assert_eq(key.door_reference, door)
	assert_eq(key.required_key_count, 2)
	assert_eq(key.position, Vector2(12, 18))
	var body: ColorRect = key.get_node("KeyBody")
	assert_true(body != null)

func test_obstacle_utilities_clears_rect_overlaps() -> void:
	var context := ObstacleContextStub.new()
	var first := _make_obstacle(Vector2(100, 100))
	var second := _make_obstacle(Vector2(400, 400))
	context.obstacles.append(first)
	context.obstacles.append(second)
	var utilities := track_object(ObstacleUtilities.new(context))
	utilities.clear_in_rects([Rect2(Vector2(80, 80), Vector2(80, 80))])
	assert_false(context.obstacles.has(first))
	assert_true(context.obstacles.has(second))

func test_obstacle_utilities_clears_near_points() -> void:
	var context := ObstacleContextStub.new()
	var close_obstacle := _make_obstacle(Vector2(200, 200))
	var far_obstacle := _make_obstacle(Vector2(400, 400))
	context.obstacles.append(close_obstacle)
	context.obstacles.append(far_obstacle)
	var utilities := track_object(ObstacleUtilities.new(context))
	utilities.clear_near_points([Vector2(205, 205)], 50.0)
	assert_false(context.obstacles.has(close_obstacle))
	assert_true(context.obstacles.has(far_obstacle))

func test_key_level_generator_sample_far_points_within_bounds() -> void:
	var generator := KeyLevelGenerator.new({}, null)
	seed(1)
	var points := generator._sample_far_points(3, Vector2(10, 20), 200.0, 150.0, 40.0)
	assert_eq(points.size(), 3)
	for point in points:
		assert_true(point.x >= 10.0)
		assert_true(point.x <= 210.0)
		assert_true(point.y >= 20.0)
		assert_true(point.y <= 170.0)

func test_maze_generator_select_key_cells_excludes_special_cells() -> void:
	var generator := track_object(MazeGenerator.new({}, null)) as MazeGenerator
	var reachable := [Vector2i(1, 1), Vector2i(3, 1), Vector2i(5, 1), Vector2i(3, 3)]
	var taken := []
	var door_worlds: Array = []
	var key_world_positions: Array = []
	var result := generator._select_maze_key_cells(reachable, 2, Vector2.ZERO, 10.0, Vector2i(3, 1), Vector2i(1, 1), Vector2i(7, 7), taken, door_worlds, key_world_positions, Vector2.ZERO, Vector2(70, 70))
	assert_eq(result.size(), 2)
	for cell in result:
		assert_false(cell == Vector2i(1, 1))
		assert_false(cell == Vector2i(3, 1))

func test_obstacle_spawner_rejects_near_player_or_existing_obstacles() -> void:
	var spawner := track_node(ObstacleSpawner.new())
	var near_player := _make_obstacle(LevelUtils.PLAYER_START)
	assert_false(spawner.is_valid_obstacle_position(near_player))
	var existing := _make_obstacle(Vector2(300, 300))
	spawner.obstacles.append(existing)
	var too_close := _make_obstacle(Vector2(340, 300))
	assert_false(spawner.is_valid_obstacle_position(too_close))

func test_coin_spawner_add_coin_adds_to_collection() -> void:
	var spawner := track_node(CoinSpawner.new())
	spawner.coins = [] as Array[Area2D]
	var coin := track_node(Area2D.new())
	var parent := track_node(Node.new())
	spawner._add_coin(coin, parent)
	assert_true(spawner.coins.has(coin))

func test_coin_spawner_create_coin_sets_unique_name() -> void:
	var spawner := track_node(CoinSpawner.new())
	spawner.current_level_size = 1.0
	var coin := track_node(spawner._create_coin(4, 3))
	assert_eq(coin.name, "Coin0")
	var body: ColorRect = coin.get_node("CoinBody")
	assert_true(body != null)
