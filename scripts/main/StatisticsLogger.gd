class_name StatisticsLogger
extends RefCounted

const GameLogger = preload("res://scripts/Logger.gd")

var main = null
var timer_manager = null
var level_controller = null
var statistics_file: FileAccess = null

func setup(main_ref, timer_manager_ref, level_controller_ref) -> void:
	main = main_ref
	timer_manager = timer_manager_ref
	level_controller = level_controller_ref

func init_logging() -> void:
	var logs_dir: String = "logs"
	if not DirAccess.dir_exists_absolute(logs_dir):
		DirAccess.make_dir_recursive_absolute(logs_dir)
	var timestamp: String = Time.get_datetime_string_from_system()
	var filename: String = "logs/statistics_" + timestamp.replace(":", "-") + ".log"
	statistics_file = FileAccess.open(filename, FileAccess.WRITE)
	if statistics_file:
		statistics_file.store_line("Level,Size,MapWidth,MapHeight,CoinsTotal,CoinsCollected,TimeGiven,TimeUsed,TimeLeft,Distance,CompletionRate")
		statistics_file.flush()
	else:
		Logger.log_error("Could not create statistics file", [filename])

func log_level_statistics() -> void:
	if statistics_file == null:
		Logger.log_error("Statistics file was null while logging level statistics")
		return
	var distance: float = 0.0
	var completion_time: float = Time.get_ticks_msec() / 1000.0 - main.level_start_time
	var time_left: float = main.game_time
	if main.player and main.exit:
		distance = main.player.global_position.distance_to(main.exit.global_position)
	var coins: Array[Area2D] = level_controller.get_active_coins() if level_controller else []
	var coin_total: int = coins.size()
	var completion_rate: float = 1.0 if coin_total == 0 else float(main.collected_coins) / float(max(coin_total, 1))
	var stats_parts: Array[String] = [
		str(main.game_state.current_level),
		str(main.game_state.current_level_size),
		str(main.play_area.size.x),
		str(main.play_area.size.y),
		str(coin_total),
		str(main.collected_coins),
		str(main.timer.wait_time),
		str(completion_time),
		str(time_left),
		str(distance),
		str(completion_rate)
	]
	var stats_line: String = ",".join(stats_parts)
	statistics_file.store_line(stats_line)
	statistics_file.flush()
	if timer_manager:
		timer_manager.register_level_result(time_left)
	else:
		Logger.log_error("TimerManager not found while logging statistics")
