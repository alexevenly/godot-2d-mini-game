extends RefCounted
class_name MazeReachabilityHelper

const MAZE_REACHABILITY_JOB: GDScript = preload("res://scripts/level_generators/MazeReachabilityJob.gd")

static func spawn_job(
	context,
	main_scene,
	grid: Array,
	start_cell: Vector2i,
	offset: Vector2,
	cell_size: float,
	player_collision_size: float,
	shadow_color: Color,
	debug_logger
) -> void:
	var job = MAZE_REACHABILITY_JOB.new()
	var logger_callable := Callable()
	var debug_enabled: bool = debug_logger and debug_logger.is_enabled()
	if debug_enabled:
		logger_callable = Callable(debug_logger, "log")
	job.setup(
		context,
		main_scene,
		grid.duplicate(true),
		start_cell,
		offset,
		cell_size,
		player_collision_size,
		shadow_color,
		debug_enabled,
		logger_callable
	)
	if context and context is Node:
		context.add_child(job)
	elif main_scene and is_instance_valid(main_scene):
		main_scene.call_deferred("add_child", job)
	else:
		job.queue_free()
