extends Node2D

const MIN_EXIT_DISTANCE = 0.4  # 40% of level diagonal (more reasonable for small levels)

var exit = null
var current_level_size = 1.0

func generate_exit(level_size: float, obstacles: Array, min_exit_distance_ratio: float = 0.4, main_scene = null) -> Node2D:
	current_level_size = level_size
	clear_exit()
	
	var max_attempts = 100
	var attempts = 0
	
	# Get level dimensions using common utilities
	var dimensions = LevelUtils.get_scaled_level_dimensions(current_level_size)
	var level_width = dimensions.width
	var level_height = dimensions.height
	var offset_x = dimensions.offset_x
	var offset_y = dimensions.offset_y
	
	while attempts < max_attempts:
		# Get position using common utilities with more variety
		var pos = LevelUtils.get_grid_position(current_level_size, 6, 4, 80, 50)
		
		# Check minimum distance from player (configurable ratio of level diagonal)
		var level_diagonal = Vector2(level_width, level_height).length()
		var min_distance = level_diagonal * min_exit_distance_ratio
		
		if pos.distance_to(LevelUtils.PLAYER_START) >= min_distance:
			# Check distance from obstacles
			var valid = true
			for obstacle in obstacles:
				if pos.distance_to(obstacle.position) < 80:  # Increased margin for exit
					valid = false
					break
			
			# Check that exit is not over boundaries (64x64 exit size)
			if valid and is_exit_position_valid(pos, level_width, level_height):
				create_exit_at(pos, main_scene)
				return exit
		
		attempts += 1
	
	# Fallback: place exit at a random safe distance
	var fallback_x = randi_range(level_width - 200, level_width - 100) + offset_x
	var fallback_y = randi_range(level_height - 200, level_height - 100) + offset_y
	var fallback_pos = Vector2(fallback_x, fallback_y)
	create_exit_at(fallback_pos, main_scene)
	return exit

func is_exit_position_valid(pos: Vector2, level_width: int, level_height: int) -> bool:
	# Check that exit (64x64) is fully within the level boundaries
	var margin = 32  # Half of exit size
	return LevelUtils.is_position_within_bounds(pos, level_width, level_height, margin)

func create_exit_at(pos: Vector2, main_scene = null):
	exit = Area2D.new()
	exit.name = "Exit"
	exit.position = pos
	
	# Create visual body
	var body = ColorRect.new()
	body.name = "ExitBody"
	body.offset_right = 64
	body.offset_bottom = 64
	body.color = Color(0.4, 0.4, 0.4, 1)  # Start gray (inactive)
	exit.add_child(body)
	
	# Create collision
	var collision = CollisionShape2D.new()
	collision.name = "ExitCollision"
	var shape = RectangleShape2D.new()
	shape.size = Vector2(64, 64)
	collision.shape = shape
	collision.position = Vector2(32, 32)
	exit.add_child(collision)
	
	# Create label
	var label = Label.new()
	label.name = "ExitLabel"
	label.offset_left = 8
	label.offset_top = 20
	label.offset_right = 56
	label.offset_bottom = 44
	label.text = "EXIT"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	exit.add_child(label)
	
	# Add to the main scene tree (Main node)
	if main_scene:
		main_scene.add_child(exit)
	else:
		get_tree().current_scene.add_child(exit)

func clear_exit():
	if exit and is_instance_valid(exit):
		exit.queue_free()
	exit = null

func get_exit() -> Node2D:
	return exit
