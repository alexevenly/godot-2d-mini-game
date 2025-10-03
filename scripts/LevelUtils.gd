class_name LevelUtils

const GameLogger = preload("res://scripts/Logger.gd")

# Common constants for all level generation scripts
const BASE_LEVEL_WIDTH = 1024
const BASE_LEVEL_HEIGHT = 600
const PLAYER_START = Vector2(100, 300)

# Helper functions for level generation
static func get_scaled_level_dimensions(level_size: float) -> Dictionary:
	var level_width = int(float(BASE_LEVEL_WIDTH) * level_size)
	var level_height = int(float(BASE_LEVEL_HEIGHT) * level_size)
	var offset_x = float(BASE_LEVEL_WIDTH - level_width) / 2.0
	var offset_y = float(BASE_LEVEL_HEIGHT - level_height) / 2.0

	return {
		"width": level_width,
		"height": level_height,
		"offset_x": offset_x,
		"offset_y": offset_y
	}

static func get_grid_position(level_size: float, grid_cols: int, grid_rows: int, margin: int, random_offset: int) -> Vector2:
	var dimensions = get_scaled_level_dimensions(level_size)
	var level_width = dimensions.width
	var level_height = dimensions.height
	var offset_x = dimensions.offset_x
	var offset_y = dimensions.offset_y

	# Ensure minimum dimensions
	level_width = max(level_width, 200) # Minimum 200px width
	level_height = max(level_height, 150) # Minimum 150px height

	var available_width = level_width - 2 * margin
	var available_height = level_height - 2 * margin

	# Ensure we have positive available space
	available_width = max(available_width, 100)
	available_height = max(available_height, 100)

	var grid_x = randi_range(0, grid_cols - 1)
	var grid_y = randi_range(0, grid_rows - 1)

	# Fix grid calculation - avoid division by zero
	var grid_step_x = available_width / float(max(grid_cols - 1, 1))
	var grid_step_y = available_height / float(max(grid_rows - 1, 1))

	var pos = Vector2(
		margin + offset_x + (grid_x * grid_step_x) + randi_range(-random_offset, random_offset),
		margin + offset_y + (grid_y * grid_step_y) + randi_range(-random_offset, random_offset)
	)

	# Ensure position is within bounds
	pos.x = clamp(pos.x, margin + offset_x, level_width - margin + offset_x)
	pos.y = clamp(pos.y, margin + offset_y, level_height - margin + offset_y)

	return pos

static func is_position_within_bounds(pos: Vector2, level_width: int, level_height: int, margin: int) -> bool:
	return (pos.x >= margin and pos.x <= level_width - margin and
	pos.y >= margin and pos.y <= level_height - margin)

static func get_obstacle_rect(obstacle: Node2D) -> Rect2:
	var obstacle_body = obstacle.get_node("ObstacleBody")
	if obstacle_body:
		return Rect2(
		obstacle.position.x - obstacle_body.offset_right / 2,
		obstacle.position.y - obstacle_body.offset_bottom / 2,
		obstacle_body.offset_right,
		obstacle_body.offset_bottom
	)
	return Rect2(obstacle.position.x - 40, obstacle.position.y - 40, 80, 80) # Fallback

static func update_level_boundaries(level_size: float, play_area: ColorRect, boundaries: Node2D):
	# Get scaled dimensions
	var dimensions = get_scaled_level_dimensions(level_size)
	var level_width = dimensions.width
	var level_height = dimensions.height
	var offset_x = dimensions.offset_x
	var offset_y = dimensions.offset_y

	# Update play area
	if play_area:
		GameLogger.log_generation("LevelUtils updating play area (width %.2f, height %.2f, offset %.2f, %.2f)" % [level_width, level_height, offset_x, offset_y])
		play_area.position = Vector2(offset_x, offset_y)
		play_area.size = Vector2(level_width, level_height)
		GameLogger.log_generation("LevelUtils play area positioned at %s size %s" % [str(play_area.position), str(play_area.size)])

	# Update boundaries
	if boundaries:
		# Top wall
		var top_wall = boundaries.get_node("TopWall")
		if top_wall:
			top_wall.position = Vector2(level_width / 2.0 + offset_x, -20 + offset_y)
			var top_wall_body = top_wall.get_node("TopWallBody")
			if top_wall_body:
				top_wall_body.offset_left = - level_width / 2.0
				top_wall_body.offset_right = level_width / 2.0
			var top_wall_collision = top_wall.get_node("TopWallCollision")
			if top_wall_collision and top_wall_collision.shape:
				top_wall_collision.shape.size = Vector2(level_width, 40)

		# Bottom wall
		var bottom_wall = boundaries.get_node("BottomWall")
		if bottom_wall:
			bottom_wall.position = Vector2(level_width / 2.0 + offset_x, level_height + 20 + offset_y)
			var bottom_wall_body = bottom_wall.get_node("BottomWallBody")
			if bottom_wall_body:
				bottom_wall_body.offset_left = - level_width / 2.0
				bottom_wall_body.offset_top = level_height
				bottom_wall_body.offset_right = level_width / 2.0
				bottom_wall_body.offset_bottom = level_height + 20
			var bottom_wall_collision = bottom_wall.get_node("BottomWallCollision")
			if bottom_wall_collision and bottom_wall_collision.shape:
				bottom_wall_collision.shape.size = Vector2(level_width, 40)

		# Left wall
		var left_wall = boundaries.get_node("LeftWall")
		if left_wall:
			left_wall.position = Vector2(-20 + offset_x, level_height / 2.0 + offset_y)
			var left_wall_body = left_wall.get_node("LeftWallBody")
			if left_wall_body:
				left_wall_body.offset_left = -20
				left_wall_body.offset_top = - level_height / 2.0
				left_wall_body.offset_bottom = level_height / 2.0
			var left_wall_collision = left_wall.get_node("LeftWallCollision")
			if left_wall_collision and left_wall_collision.shape:
				left_wall_collision.shape.size = Vector2(40, level_height)

		# Right wall
		var right_wall = boundaries.get_node("RightWall")
		if right_wall:
			right_wall.position = Vector2(level_width + 20 + offset_x, level_height / 2.0 + offset_y)
			var right_wall_body = right_wall.get_node("RightWallBody")
			if right_wall_body:
				right_wall_body.offset_left = level_width
				right_wall_body.offset_top = - level_height / 2.0
				right_wall_body.offset_right = level_width + 20
				right_wall_body.offset_bottom = level_height / 2.0
			var right_wall_collision = right_wall.get_node("RightWallCollision")
			if right_wall_collision and right_wall_collision.shape:
				right_wall_collision.shape.size = Vector2(40, level_height)
