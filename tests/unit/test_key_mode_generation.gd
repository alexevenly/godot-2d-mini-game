extends "res://tests/unit/test_utils.gd"

const KeyRingLayoutPlanner = preload("res://scripts/level_generators/key/KeyRingLayoutPlanner.gd")
const KeyRingDoorSpawner = preload("res://scripts/level_generators/key/KeyRingDoorSpawner.gd")
const MazeGenerator = preload("res://scripts/level_generators/MazeGenerator.gd")

class KeyRingContextStub extends RefCounted:
	var suite
	var doors: Array = []
	var key_items: Array = []
	var key_barriers: Array = []
	var obstacles: Array = []
	var generated_nodes: Array = []
	var palette := [Color(0.92, 0.45, 0.32), Color(0.32, 0.58, 0.92), Color(0.52, 0.78, 0.36)]

	func _init(test_suite):
		suite = test_suite

	func get_group_color(index: int) -> Color:
		return palette[index % palette.size()]

	func add_generated_node(node, _scene) -> void:
		generated_nodes.append(node)
		if node is Node:
			suite.track_node(node)

class ObstacleUtilsStub extends RefCounted:
	var cleared_positions: Array = []

	func clear_around_position(position: Vector2, radius: float) -> void:
		cleared_positions.append({"position": position, "radius": radius})

class ExitSpawnerStub extends Node:
	var suite
	var exit_node: Area2D = null
	var positions: Array = []

	func _init(test_suite):
		suite = test_suite

	func clear_exit() -> void:
		if exit_node and exit_node.is_inside_tree():
			exit_node.queue_free()
		exit_node = null

	func create_exit_at(position: Vector2, _scene) -> void:
		positions.append(position)
		exit_node = suite.track_node(Area2D.new())
		exit_node.position = position

	func get_exit() -> Area2D:
		return exit_node

class MazeKeyContextStub extends Node:
	var suite
	var doors: Array = []
	var key_items: Array = []
	var key_barriers: Array = []
	var maze_walls: Array = []
	var coins: Array = []
	var last_maze_path_length: float = 0.0
	var obstacles: Array = []
	var exit_pos: Vector2 = Vector2.ZERO
	var exit_spawner: ExitSpawnerStub
	var spawn_override: Vector2 = Vector2.ZERO
	var current_level_size: float = 1.0
	var palette := [Color(0.86, 0.33, 0.41), Color(0.31, 0.74, 0.62), Color(0.62, 0.48, 0.92)]

	func _init(test_suite):
		suite = test_suite
		exit_spawner = suite.track_node(ExitSpawnerStub.new(suite))

	func get_group_color(index: int) -> Color:
		return palette[index % palette.size()]

	func add_generated_node(node, _scene) -> void:
		if node is Node:
			suite.track_node(node)
		if node is StaticBody2D and node.name.begins_with("Door"):
			doors.append(node)
		elif node is StaticBody2D and node.name.begins_with("DoorBarrier"):
			key_barriers.append(node)
		elif node is Area2D and node.name.begins_with("Key"):
			key_items.append(node)

	func set_player_spawn_override(position: Vector2) -> void:
		spawn_override = position

	func get_maze_cell_size() -> float:
		return 48.0

	func get_maze_wall_size_ratio() -> float:
		return 0.12

	func is_maze_full_cover() -> bool:
		return true

class MazeGeneratorProbe extends MazeGenerator:
	var layout_override: Dictionary = {}

	func set_layout(layout: Dictionary) -> void:
		layout_override = layout

	func _build_layout(_main_scene, _player_start_position: Vector2) -> Dictionary:
		return layout_override

func get_suite_name() -> String:
	return "KeyModeGeneration"

func test_key_ring_layout_creates_nested_rings_with_doors() -> void:
	var context := KeyRingContextStub.new(self)
	var planner := KeyRingLayoutPlanner.new(context)
	var layout := planner.create_layout(Vector2.ZERO, 800.0, 600.0, 6)
	var rings: Array = layout.get("rings", [])
	assert_true(rings.size() >= 2)
	var outer: Dictionary = rings[0]
	var inner: Dictionary = rings[rings.size() - 1]
	var spawn: Vector2 = layout.get("spawn", Vector2.ZERO)
	assert_true(spawn.x <= float(outer.get("left", spawn.x + 1.0)))
	assert_between(spawn.y, float(outer.get("top", spawn.y)) + 80.0, float(outer.get("bottom", spawn.y)) - 80.0)
	var exit_position: Vector2 = layout.get("exit", Vector2.ZERO)
	assert_vector_near(exit_position, inner.get("center", Vector2.ZERO), 0.01)
	var total_doors := 0
	for ring in rings:
		var doors: Array = ring.get("doors", [])
		total_doors += doors.size()
		for door in doors:
			assert_between(float(door.get("fraction", 0.5)), 0.18, 0.82)
			assert_true(door.has("position"))
	assert_true(total_doors >= rings.size())

func test_key_ring_door_spawner_emits_blocking_door_and_perimeter_keys() -> void:
	var context := KeyRingContextStub.new(self)
	var planner := KeyRingLayoutPlanner.new(context)
	var layout := planner.create_layout(Vector2.ZERO, 720.0, 540.0, 5)
	var rings: Array = layout.get("rings", [])
	var obstacle_utils := ObstacleUtilsStub.new()
	var spawner: KeyRingDoorSpawner = KeyRingDoorSpawner.new(context, obstacle_utils)
	spawner.spawn(rings, null)
	assert_true(context.doors.size() >= 1)
	assert_true(context.key_items.size() >= context.doors.size())
	for door in context.doors:
		assert_false(door.initially_open)
		assert_true(door.required_keys > 0)
	assert_eq(obstacle_utils.cleared_positions.size(), context.key_items.size())
	for key in context.key_items:
		assert_instanceof(key, "Area2D")
		var aligned := false
		for ring in rings:
			var margin: float = float(ring.get("inner_margin", 0.0))
			var top := float(ring.get("top", 0.0)) + margin
			var bottom := float(ring.get("bottom", 0.0)) - margin
			var left := float(ring.get("left", 0.0)) + margin
			var right := float(ring.get("right", 0.0)) - margin
			if abs(key.position.y - top) <= 1.5 or abs(key.position.y - bottom) <= 1.5 or abs(key.position.x - left) <= 1.5 or abs(key.position.x - right) <= 1.5:
				aligned = true
				break
		assert_true(aligned, "Key should align to ring perimeter")

func test_maze_generator_keys_mode_spawns_blocking_doors_and_keys() -> void:
	var context := track_node(MazeKeyContextStub.new(self))
	var generator := MazeGeneratorProbe.new(context, null)
	var cell_size := 48.0
	var grid: Array = []
	for y in range(5):
		var row: Array = []
		for x in range(5):
			row.append(true)
		grid.append(row)
	var open_cells := [Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1), Vector2i(3, 2), Vector2i(3, 3), Vector2i(2, 3)]
	for cell in open_cells:
		grid[cell.y][cell.x] = false
	var start_cell := Vector2i(1, 1)
	var layout := {
		"grid": grid,
		"cols": 5,
		"rows": 5,
		"cell_size": cell_size,
		"maze_offset": Vector2.ZERO,
		"start_cell": start_cell,
		"start_world": Vector2(cell_size * (start_cell.x + 0.5), cell_size * (start_cell.y + 0.5))
	}
	generator.set_layout(layout)
	generator.generate_maze_keys_level(null, 4, Vector2.ZERO)
	assert_true(context.doors.size() >= 1)
	assert_true(context.key_items.size() >= context.doors.size())
	for door in context.doors:
		assert_false(door.initially_open)
		assert_true(door.required_keys > 0)
	for key in context.key_items:
		assert_true(key.door_reference != null)
		assert_true(key.required_key_count >= key.door_reference.required_keys)
	assert_true(context.exit_spawner.get_exit() != null)
	assert_vector_near(context.exit_pos, context.exit_spawner.get_exit().position, 0.001)
	var expected_spawn := Vector2(cell_size * (start_cell.x + 0.5), cell_size * (start_cell.y + 0.5))
	assert_vector_near(context.spawn_override, expected_spawn, 0.001)
