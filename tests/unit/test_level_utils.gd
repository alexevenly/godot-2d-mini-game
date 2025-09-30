extends UnitTestSuite

const LevelUtils = preload("res://scripts/LevelUtils.gd")

class FakeBody:
	extends Node
	var offset_right := 120.0
	var offset_bottom := 80.0
	var offset_left := -60.0
	var offset_top := -40.0

func get_suite_name() -> String:
	return "LevelUtils"

func test_get_scaled_level_dimensions_scales_values() -> void:
	var dims := LevelUtils.get_scaled_level_dimensions(1.5)
	assert_eq(dims["width"], int(1024 * 1.5))
	assert_eq(dims["height"], int(600 * 1.5))
	assert_near(dims["offset_x"], (1024 - int(1024 * 1.5)) / 2.0, 0.0001)
	assert_near(dims["offset_y"], (600 - int(600 * 1.5)) / 2.0, 0.0001)

func test_get_grid_position_stays_within_bounds() -> void:
	seed(1)
	var level_size := 1.2
	var margin := 40
	var pos := LevelUtils.get_grid_position(level_size, 4, 3, margin, 5)
	var dims := LevelUtils.get_scaled_level_dimensions(level_size)
	var level_width := dims["width"]
	var level_height := dims["height"]
	var offset_x := dims["offset_x"]
	var offset_y := dims["offset_y"]
	assert_true(pos.x >= margin + offset_x)
	assert_true(pos.x <= level_width - margin + offset_x)
	assert_true(pos.y >= margin + offset_y)
	assert_true(pos.y <= level_height - margin + offset_y)

func test_is_position_within_bounds_behaves_consistently() -> void:
	var inside := Vector2(150, 120)
	assert_true(LevelUtils.is_position_within_bounds(inside, 400, 300, 50))
	var outside := Vector2(20, 10)
	assert_false(LevelUtils.is_position_within_bounds(outside, 400, 300, 50))

func test_get_obstacle_rect_prefers_custom_body() -> void:
	var obstacle := Node2D.new()
	obstacle.position = Vector2(200, 150)
	var body := FakeBody.new()
	body.name = "ObstacleBody"
	obstacle.add_child(body)
	var rect := LevelUtils.get_obstacle_rect(obstacle)
	assert_near(rect.position.x, 200 - body.offset_right / 2.0, 0.0001)
	assert_near(rect.position.y, 150 - body.offset_bottom / 2.0, 0.0001)
	assert_near(rect.size.x, body.offset_right, 0.0001)
	assert_near(rect.size.y, body.offset_bottom, 0.0001)

func test_update_level_boundaries_adjusts_nodes() -> void:
	var play_area := ColorRect.new()
	var boundaries := Node2D.new()
	_boundaries_add_wall(boundaries, "TopWall")
	_boundaries_add_wall(boundaries, "BottomWall")
	_boundaries_add_wall(boundaries, "LeftWall", horizontal := false)
	_boundaries_add_wall(boundaries, "RightWall", horizontal := false)
	LevelUtils.update_level_boundaries(0.8, play_area, boundaries)
	var dims := LevelUtils.get_scaled_level_dimensions(0.8)
	assert_vector_near(play_area.position, Vector2(dims["offset_x"], dims["offset_y"]), 0.001)
	assert_vector_near(play_area.size, Vector2(dims["width"], dims["height"]), 0.001)
	var top_wall := boundaries.get_node("TopWall")
	assert_vector_near(top_wall.position, Vector2(dims["width"] / 2.0 + dims["offset_x"], -20 + dims["offset_y"]), 0.001)
	var top_body := top_wall.get_node("TopWallBody")
	assert_near(top_body.offset_left, -dims["width"] / 2.0, 0.001)
	assert_near(top_body.offset_right, dims["width"] / 2.0, 0.001)
	var right_wall := boundaries.get_node("RightWall")
	assert_vector_near(right_wall.position, Vector2(dims["width"] + 20 + dims["offset_x"], dims["height"] / 2.0 + dims["offset_y"]), 0.001)
	var right_collision := right_wall.get_node("RightWallCollision")
	assert_near(right_collision.shape.size.x, 40, 0.001)
	assert_near(right_collision.shape.size.y, dims["height"], 0.001)

func _boundaries_add_wall(parent: Node2D, name: String, horizontal := true) -> void:
	var wall := Node2D.new()
	wall.name = name
	var body := FakeBody.new()
	body.name = name + "Body"
	if horizontal:
		body.offset_left = -10
		body.offset_right = 10
		body.offset_top = -10
		body.offset_bottom = 10
	else:
		body.offset_left = -10
		body.offset_right = 10
		body.offset_top = -10
		body.offset_bottom = 10
	wall.add_child(body)
	var collision := CollisionShape2D.new()
	collision.name = name + "Collision"
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10, 10)
	collision.shape = shape
	wall.add_child(collision)
	parent.add_child(wall)
