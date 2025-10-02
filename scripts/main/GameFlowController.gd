class_name GameFlowController
extends RefCounted

const Logger = preload("res://scripts/Logger.gd")
const GameState = preload("res://scripts/GameState.gd")

var main = null
var ui_controller = null
var level_controller = null
var statistics_logger = null

func setup(
	main_ref,
	ui_controller_ref,
	level_controller_ref,
	statistics_logger_ref
) -> void:
	main = main_ref
	ui_controller = ui_controller_ref
	level_controller = level_controller_ref
	statistics_logger = statistics_logger_ref

func handle_timer_for_game_state() -> void:
	if main.game_state.current_state != GameState.GameStateType.PLAYING:
		if main.timer.timeout.is_connected(main._on_timer_timeout):
			main.timer.timeout.disconnect(main._on_timer_timeout)
		main.timer.wait_time = 999999
		main.timer.stop()
		Logger.log_game_mode("Timer halted because state is %s" % [_get_state_label(main.game_state.current_state)])

func trigger_game_over() -> void:
	if not main.game_state.is_game_active():
		return
	if main.prevent_game_over:
		return
	Logger.log_game_mode("Game over on level %d (size %.2f)" % [main.game_state.current_level, main.game_state.current_level_size])
	main.game_state.set_state(GameState.GameStateType.LOST)
	main.game_state.drop_progress_on_loss()
	Logger.log_game_mode("Progress reset to level 1 after loss")
	ui_controller.show_game_over_ui("Restart")
	if main.player:
		main.player.set_physics_process(false)
	main.timer.stop()
	if main.timer.timeout.is_connected(main._on_timer_timeout):
		main.timer.timeout.disconnect(main._on_timer_timeout)
	main.timer.wait_time = 999999
	main.timer.stop()
	ui_controller.update_level_progress(main.game_state.get_level_progress_text())

func trigger_level_win() -> void:
	if not main.game_state.is_game_active():
		return
	Logger.log_game_mode("Level %d completed (size %.2f)" % [main.game_state.current_level, main.game_state.current_level_size])
	main.game_state.set_state(GameState.GameStateType.WON)
	ui_controller.show_win_ui("Continue")
	if main.player:
		main.player.set_physics_process(false)
	main.timer.stop()
	if main.timer.timeout.is_connected(main._on_timer_timeout):
		main.timer.timeout.disconnect(main._on_timer_timeout)
	if statistics_logger:
		statistics_logger.log_level_statistics()
	if main.game_state.current_level >= 7:
		ui_controller.set_restart_button_text("Start all over again?")
		Logger.log_game_mode("All 7 levels completed; awaiting restart")
		main.prevent_game_over = true
		return
	ui_controller.set_restart_button_text("Continue")
	Logger.log_game_mode("Continue to next level when ready")

func handle_restart_pressed() -> void:
	Logger.log_game_mode("Restart requested on level %d (size %.2f)" % [main.game_state.current_level, main.game_state.current_level_size])
	main.collected_coins = main.previous_coin_count
	main.exit_active = false
	ui_controller.hide_endgame_ui()
	handle_timer_for_game_state()
	if main.prevent_game_over and main.game_state.current_state == GameState.GameStateType.WON:
		Logger.log_game_mode("Restarting fresh run after completing all levels")
		main.prevent_game_over = false
		main.game_state.reset_to_start()
		Logger.log_game_mode("Reset to level 1; prevent_game_over cleared")
	elif main.game_state.current_state == GameState.GameStateType.WON:
		Logger.log_game_mode("Advancing from level %d" % main.game_state.current_level)
		var completed_all_levels: bool = main.game_state.advance_level()
		Logger.log_game_mode("Advanced to level %d (size %.2f)" % [main.game_state.current_level, main.game_state.current_level_size])
		if completed_all_levels:
			ui_controller.set_restart_button_text("Start all over again?")
			Logger.log_game_mode("All levels complete; waiting for full restart")
			main.prevent_game_over = true
			main.timer.stop()
			main.timer.wait_time = 999999
			if main.timer.timeout.is_connected(main._on_timer_timeout):
				main.timer.timeout.disconnect(main._on_timer_timeout)
			return
		ui_controller.set_restart_button_text("Continue")
		Logger.log_game_mode("Next level %d prepared (size %.2f)" % [main.game_state.current_level, main.game_state.current_level_size])
	elif main.game_state.current_state == GameState.GameStateType.LOST:
		main.prevent_game_over = false
		Logger.log_game_mode("Prevent game over flag cleared after loss")
	else:
		ui_controller.set_restart_button_text("Continue")
		Logger.log_game_mode("Next level %d prepared (size %.2f)" % [main.game_state.current_level, main.game_state.current_level_size])
		main.prevent_game_over = false
	main.game_state.set_state(GameState.GameStateType.PLAYING)
	ui_controller.update_level_progress(main.game_state.get_level_progress_text())
	main.timer.stop()
	if not main.prevent_game_over and not main.timer.timeout.is_connected(main._on_timer_timeout):
		main.timer.timeout.connect(main._on_timer_timeout)
	elif main.prevent_game_over:
		Logger.log_game_mode("Timer left disconnected; all levels completed")
	main.timer.stop()
	if main.player and is_instance_valid(main.player):
		level_controller.position_player_within_level()
		main.player.z_index = 100
		main.player.set_physics_process(true)
	level_controller.clear_level_objects()
	await main.get_tree().process_frame
	if main.game_state.current_level > 7:
		main.game_state.reset_to_start()
		Logger.log_game_mode("Level exceeded cap during restart; reset to %d" % main.game_state.current_level)
	if not main.prevent_game_over:
		level_controller.generate_new_level()
	else:
		Logger.log_game_mode("Generation skipped because campaign is complete")

func on_timer_timeout() -> void:
	if main.game_state.current_state != GameState.GameStateType.PLAYING:
		Logger.log_game_mode("Timer timeout ignored; state is %s" % [_get_state_label(main.game_state.current_state)])
		main.timer.stop()
		main.timer.wait_time = 999999
		if main.timer.timeout.is_connected(main._on_timer_timeout):
			main.timer.timeout.disconnect(main._on_timer_timeout)
		return
	if not main.game_state.is_game_active():
		Logger.log_game_mode("Timer timeout ignored; game inactive")
		main.timer.stop()
		main.timer.wait_time = 999999
		return
	trigger_game_over()

func on_exit_entered(body: Node) -> void:
	if body == main.player and main.game_state.is_game_active() and main.exit_active:
		trigger_level_win()

func _get_state_label(state: int) -> String:
	match state:
		GameState.GameStateType.PLAYING:
			return "PLAYING"
		GameState.GameStateType.WON:
			return "WON"
		GameState.GameStateType.LOST:
			return "LOST"
	return str(state)
