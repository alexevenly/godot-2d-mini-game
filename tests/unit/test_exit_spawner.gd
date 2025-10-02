extends "res://tests/unit/test_utils.gd"

const LevelUtilsScript = preload("res://scripts/LevelUtils.gd")
const ExitSpawner = preload("res://scripts/ExitSpawner.gd")

func get_suite_name() -> String:
	return "ExitSpawner"

func _make_obstacle(position: Vector2) -> Node2D:
	var obstacle := Node2D.new()
	obstacle.position = position
	return obstacle

func test_generate_exit_creates_exit_with_children() -> void:
	var spawner := ExitSpawner.new()
	var exit := spawner.generate_exit(1.0, [], 0.0, Node.new())
	assert_true(exit != null)
	assert_eq(exit.name, "Exit")
	var body: ColorRect = exit.get_node("ExitBody")
	assert_true(body != null)
	assert_vector_near(body.position, Vector2.ZERO, 0.001)
	var label: Label = exit.get_node("ExitLabel")
	assert_true(label != null)
	assert_eq(label.text, "EXIT")

func test_is_exit_position_valid_enforces_margin() -> void:
	var spawner := ExitSpawner.new()
	var dims := LevelUtilsScript.get_scaled_level_dimensions(1.0)
	var inside := Vector2(100, 100)
	assert_true(spawner.is_exit_position_valid(inside, dims.width, dims.height))
	var near_edge := Vector2(10, 10)
	assert_false(spawner.is_exit_position_valid(near_edge, dims.width, dims.height))

func test_clear_exit_queues_previous_instance() -> void:
	var spawner := ExitSpawner.new()
	spawner.create_exit_at(Vector2(100, 100), Node.new())
	var first_exit := spawner.get_exit()
	assert_false(first_exit == null)
	spawner.clear_exit()
	assert_true(first_exit.is_queued_for_deletion())
	assert_true(spawner.get_exit() == null)
