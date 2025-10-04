extends "res://tests/unit/test_utils.gd"

const GameState = preload("res://scripts/GameState.gd")
const GameFlowController = preload("res://scripts/main/GameFlowController.gd")
const UIController = preload("res://scripts/main/UIController.gd")
const StatisticsLogger = preload("res://scripts/main/StatisticsLogger.gd")

class FakeTree:
	extends RefCounted
	signal process_frame

	var change_scene_path = null

	func change_scene_to_file(path: String) -> void:
		change_scene_path = path

class PlayerStub:
	extends CharacterBody2D

	func _init() -> void:
		set_physics_process(true)

class TimerManagerStub:
	extends RefCounted

	var last_registered = null

	func register_level_result(value: float) -> void:
		last_registered = value

class LevelControllerStub:
	extends RefCounted

	var coins: Array[Area2D] = []

	func _init(coins_array: Array[Area2D]) -> void:
		coins = coins_array

	func get_active_coins() -> Array[Area2D]:
		return coins

class UIStub:
	extends RefCounted

	var game_over_visible := false
	var win_visible := false
	var last_restart_text := ""
	var level_progress := ""
	var buttons_visible := false

	func show_game_over_ui(text: String) -> void:
		game_over_visible = true
		win_visible = false
		last_restart_text = text
		buttons_visible = true

	func show_win_ui(text: String) -> void:
		win_visible = true
		game_over_visible = false
		last_restart_text = text
		buttons_visible = true

	func hide_endgame_ui() -> void:
		game_over_visible = false
		win_visible = false
		buttons_visible = false

	func set_restart_button_text(text: String) -> void:
		last_restart_text = text

	func set_endgame_buttons_visible(visible: bool) -> void:
		buttons_visible = visible

	func update_level_progress(text: String) -> void:
		level_progress = text

	func update_exit_state(_active: bool, _exit: Node) -> void:
		pass

	func update_coin_display(_total: int, _collected: int) -> void:
		pass

	func setup_key_ui(_keys: Array[Area2D]) -> void:
		pass

	func setup_door_ui(_doors: Array[StaticBody2D]) -> void:
		pass

	func update_key_status_display(_count: int) -> void:
		pass

	func mark_key_collected(_door_id: int) -> void:
		pass

	func mark_door_opened(_door_id: int, _door_color: Color) -> void:
		pass

class StatisticsLoggerStub:
	extends RefCounted

	var called := false

	func log_level_statistics() -> void:
		called = true

class MainStub:
	extends Node

	var game_state: GameState
	var timer: Timer
	var player: PlayerStub
	var ui_controller: UIController = null
	var level_controller: LevelControllerStub = null
	var statistics_logger: StatisticsLogger = null
	var prevent_game_over = false
	var collected_coins := 0
	var previous_coin_count := 0
	var exit_active := false
	var exit = null
	var game_time := 0.0
	var level_start_time := 0.0
	var play_area := ColorRect.new()
	var tree := FakeTree.new()

	func _init() -> void:
		game_state = GameState.new()
		game_state._ready()
		add_child(game_state)
		timer = Timer.new()
		add_child(timer)
		player = PlayerStub.new()
		add_child(player)
		add_child(play_area)

	@warning_ignore("native_method_override")
	func get_tree():
		return tree

	func _on_timer_timeout() -> void:
		pass

func get_suite_name() -> String:
	return "MainSystems"

func test_handle_timer_for_non_playing_state_disconnects_timeout() -> void:
	var main := track_node(MainStub.new())
	main.game_state.set_state(GameState.GameStateType.WON)
	main.timer.timeout.connect(main._on_timer_timeout)
	var controller = GameFlowController.new()
	controller.setup(main, UIStub.new(), null, null)
	controller.handle_timer_for_game_state()
	assert_near(main.timer.wait_time, 999999.0, 0.001)
	assert_false(main.timer.timeout.is_connected(main._on_timer_timeout))

func test_trigger_game_over_updates_state_and_ui() -> void:
	var main := track_node(MainStub.new())
	main.game_state.set_state(GameState.GameStateType.PLAYING)
	main.timer.timeout.connect(main._on_timer_timeout)
	var ui := UIStub.new()
	var controller = GameFlowController.new()
	controller.setup(main, ui, null, null)
	controller.trigger_game_over()
	assert_eq(main.game_state.current_state, GameState.GameStateType.LOST)
	assert_true(ui.game_over_visible)
	assert_eq(ui.last_restart_text, "Restart")
	assert_true(main.player.is_physics_processing() == false)
	assert_near(main.timer.wait_time, 999999.0, 0.001)
	assert_false(main.timer.timeout.is_connected(main._on_timer_timeout))

func test_trigger_level_win_sets_prevent_flag_on_final_level() -> void:
	var main := track_node(MainStub.new())
	main.game_state.current_level = 7
	main.game_state.set_state(GameState.GameStateType.PLAYING)
	main.timer.timeout.connect(main._on_timer_timeout)
	var ui := UIStub.new()
	var stats := StatisticsLoggerStub.new()
	var controller = GameFlowController.new()
	controller.setup(main, ui, null, stats)
	controller.trigger_level_win()
	assert_eq(main.game_state.current_state, GameState.GameStateType.WON)
	assert_true(ui.win_visible)
	assert_true(stats.called)
	assert_true(main.prevent_game_over)
	assert_eq(ui.last_restart_text, "Start all over again?")
	assert_false(main.timer.timeout.is_connected(main._on_timer_timeout))

func test_ui_controller_coin_and_key_updates() -> void:
	var controller = UIController.new()
	var main := track_node(Node.new())
	var timer_label := track_node(Label.new())
	var coin_label := track_node(Label.new())
	var level_label := track_node(Label.new())
	var game_over := track_node(Label.new())
	var win_label := track_node(Label.new())
	var restart := track_node(Button.new())
	var menu := track_node(Button.new())
	var key_container := track_node(Control.new())
	var key_status := track_node(Control.new())
	var door_container := track_node(Control.new())
	var door_status := track_node(Control.new())
	controller.setup(main, timer_label, coin_label, level_label, game_over, win_label, restart, menu, key_container, key_status, door_container, door_status)
	controller.update_coin_display(0, 0)
	assert_false(coin_label.visible)
	assert_eq(coin_label.text, "")
	controller.update_coin_display(3, 1)
	assert_true(coin_label.visible)
	assert_eq(coin_label.text, "Coins: 1/3")
	var key := track_node(Area2D.new())
	key.set_meta("group_color", Color(0.5, 0.6, 0.2))
	controller.setup_key_ui([key])
	assert_true(key_container.visible)
	assert_eq(controller.key_checkbox_nodes.size(), 1)
	controller.update_key_status_display(1)
	var checkbox: CheckBox = controller.key_checkbox_nodes[0]
	assert_true(checkbox.button_pressed)

func test_ui_controller_updates_exit_visual_state() -> void:
	var controller = UIController.new()
	var main := track_node(Node.new())
	var timer_label := track_node(Label.new())
	var coin_label := track_node(Label.new())
	var level_label := track_node(Label.new())
	var game_over := track_node(Label.new())
	var win_label := track_node(Label.new())
	var restart := track_node(Button.new())
	var menu := track_node(Button.new())
	var key_container := track_node(Control.new())
	var key_status := track_node(Control.new())
	var door_container := track_node(Control.new())
	var door_status := track_node(Control.new())
	controller.setup(main, timer_label, coin_label, level_label, game_over, win_label, restart, menu, key_container, key_status, door_container, door_status)
	var exit := track_node(Area2D.new())
	var body := track_node(ColorRect.new())
	body.name = "ExitBody"
	exit.add_child(body)
	controller.update_exit_state(false, exit)
	assert_near(body.color.g, 0.4, 0.0001)
	controller.update_exit_state(true, exit)
	assert_near(body.color.g, 0.8, 0.0001)

func test_statistics_logger_records_line_and_registers_surplus() -> void:
	var main := track_node(MainStub.new())
	main.game_state.current_level = 3
	main.game_state.current_level_size = 1.2
	main.play_area.size = Vector2(400, 300)
	main.game_time = 12.5
	main.collected_coins = 2
	var exit := track_node(Area2D.new())
	var exit_body := track_node(CollisionShape2D.new())
	exit.add_child(exit_body)
	exit.global_position = Vector2(200, 160)
	main.exit = exit
	main.player.global_position = Vector2(220, 180)
	var coin := track_node(Area2D.new())
	var level_controller := LevelControllerStub.new([coin])
	var timer_manager := TimerManagerStub.new()
	var logger := StatisticsLogger.new()
	logger.setup(main, timer_manager, level_controller)
	var file_path := "user://stats_logger_test.csv"
	var stats_file := FileAccess.open(file_path, FileAccess.WRITE_READ)
	assert_true(stats_file != null)
	logger.statistics_file = stats_file
	main.level_start_time = Time.get_ticks_msec() / 1000.0
	logger.log_level_statistics()
	assert_eq(timer_manager.last_registered, 12.5)
	stats_file.flush()
	stats_file.seek(0)
	var content := stats_file.get_as_text()
	stats_file.close()
	var lines := content.strip_edges().split("\n")
	assert_eq(lines.size(), 1)
	var parts := lines[0].split(",")
	assert_eq(parts[0], str(main.game_state.current_level))
	assert_eq(parts[5], str(main.collected_coins))
	assert_eq(parts[10], str(1.0 if level_controller.coins.size() == 0 else float(main.collected_coins) / float(max(level_controller.coins.size(), 1))))
