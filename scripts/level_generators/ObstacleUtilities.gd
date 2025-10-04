extends Object
class_name ObstacleUtilities

const LEVEL_UTILS := preload("res://scripts/LevelUtils.gd")

var context

func _init(level_context):
	context = level_context

func clear_in_rects(rects: Array) -> void:
	if context.obstacles.is_empty():
		return
	var to_remove: Array = []
	for obstacle in context.obstacles:
		if not is_instance_valid(obstacle):
			if not to_remove.has(obstacle):
				to_remove.append(obstacle)
			continue
		var obstacle_rect = LEVEL_UTILS.get_obstacle_rect(obstacle)
		for rect in rects:
			if rect is Rect2 and obstacle_rect.intersects(rect):
				if not to_remove.has(obstacle):
					to_remove.append(obstacle)
				break
	_remove_obstacles(to_remove)

func clear_near_points(points: Array, radius: float) -> void:
	if context.obstacles.is_empty() or points.is_empty() or radius <= 0.0:
		return
	var radius_sq = radius * radius
	var to_remove: Array = []
	for obstacle in context.obstacles:
		if not is_instance_valid(obstacle):
			if not to_remove.has(obstacle):
				to_remove.append(obstacle)
			continue
		for point in points:
			if typeof(point) != TYPE_VECTOR2:
				continue
			if obstacle.position.distance_squared_to(point) <= radius_sq:
				if not to_remove.has(obstacle):
					to_remove.append(obstacle)
				break
	_remove_obstacles(to_remove)

func clear_around_position(position: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return
	clear_near_points([position], radius)

func _remove_obstacles(obstacles_to_remove: Array) -> void:
	if obstacles_to_remove.is_empty():
		return
	var spawner_obstacles: Array = []
	if context.obstacle_spawner and is_instance_valid(context.obstacle_spawner):
		spawner_obstacles = context.obstacle_spawner.get_obstacles()
	for obstacle in obstacles_to_remove:
		if obstacle == null:
			continue
		if context.obstacles.has(obstacle):
			context.obstacles.erase(obstacle)
		if spawner_obstacles and spawner_obstacles.has(obstacle):
			spawner_obstacles.erase(obstacle)
		if is_instance_valid(obstacle):
			obstacle.queue_free()
