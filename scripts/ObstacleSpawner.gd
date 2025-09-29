extends Node2D

var obstacles = []
var current_level_size = 1.0

func generate_obstacles(level_size: float, use_full_map_coverage: bool = true, main_scene = null, level: int = 1) -> Array:
	print("ObstacleSpawner: Generating obstacles for level size: ", level_size, " level: ", level)
	print("ObstacleSpawner: Self valid: ", is_instance_valid(self))
	print("ObstacleSpawner: Parent valid: ", is_instance_valid(get_parent()))
	current_level_size = level_size
	clear_obstacles()
	
	# Generate obstacles based on level size and level number (progressive scaling)
	var base_obstacle_count = randi_range(40, 60)  # 
	var level_multiplier = 1.0 + (level - 1) * 0.2  # +20% per level
	var obstacle_count = int(base_obstacle_count * current_level_size * level_multiplier)
	print("ObstacleSpawner: Target count: ", obstacle_count, " (level multiplier: ", level_multiplier, ")")
	print("ObstacleSpawner: Full map coverage: ", use_full_map_coverage)
	
	for i in range(obstacle_count):
		var obstacle = create_obstacle(use_full_map_coverage)
		if is_valid_obstacle_position(obstacle):
			obstacles.append(obstacle)
			# Add to the main scene tree (Main node)
			print("ObstacleSpawner: Before add_child - Self valid: ", is_instance_valid(self))
			print("ObstacleSpawner: Before add_child - Parent valid: ", is_instance_valid(get_parent()))
			if main_scene:
				main_scene.add_child(obstacle)
			else:
				get_tree().current_scene.add_child(obstacle)
			print("ObstacleSpawner: After add_child - Self valid: ", is_instance_valid(self))
			print("ObstacleSpawner: After add_child - Parent valid: ", is_instance_valid(get_parent()))
			print("ObstacleSpawner: Added obstacle ", i, " at ", obstacle.position)
		else:
			print("ObstacleSpawner: Rejected obstacle ", i, " at ", obstacle.position)
	
	print("ObstacleSpawner: Final count: ", obstacles.size())
	return obstacles

func create_obstacle(use_full_map_coverage: bool = true):
	var obstacle = StaticBody2D.new()
	obstacle.name = "Obstacle" + str(obstacles.size())
	
	# Random size
	var width = randi_range(30, 80)
	var height = randi_range(30, 80)
	
	# Get position using common utilities with more variety
	# Use more grid cells for full map coverage
	var grid_cols = 8 if use_full_map_coverage else 6
	var grid_rows = 6 if use_full_map_coverage else 5
	var pos = LevelUtils.get_grid_position(current_level_size, grid_cols, grid_rows, 40, 40)
	obstacle.position = pos
	
	# Create visual body
	var body = ColorRect.new()
	body.name = "ObstacleBody"
	body.offset_right = width
	body.offset_bottom = height
	body.color = Color(0.4, 0.2, 0.1, 1)
	obstacle.add_child(body)
	
	# Create collision
	var collision = CollisionShape2D.new()
	collision.name = "ObstacleCollision"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(width, height)
	collision.shape = shape
	collision.position = Vector2(width/2.0, height/2.0)
	obstacle.add_child(collision)
	
	return obstacle

func is_valid_obstacle_position(obstacle) -> bool:
	# Check distance from player start (player size + 5% gap)
	if obstacle.position.distance_to(LevelUtils.PLAYER_START) < 100:
		return false
	
	# Check overlap with existing obstacles (ensure player can pass between them)
	# Player size is ~32px, so we need at least 32 + 5% = ~34px gap
	for existing in obstacles:
		if obstacle.position.distance_to(existing.position) < 70:  # Increased from 60 to 70
			return false
	
	return true

func clear_obstacles():
	for obstacle in obstacles:
		if is_instance_valid(obstacle):
			obstacle.queue_free()
	obstacles.clear()

func get_obstacles() -> Array:
	return obstacles
