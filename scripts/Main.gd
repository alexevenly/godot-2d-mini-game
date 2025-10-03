class_name Main
extends Node2D

const LevelController = preload("res://scripts/main/LevelController.gd")
const UIController = preload("res://scripts/main/UIController.gd")
const StatisticsLogger = preload("res://scripts/main/StatisticsLogger.gd")
const GameFlowController = preload("res://scripts/main/GameFlowController.gd")
const LevelGenerator = preload("res://scripts/LevelGenerator.gd")
const TimerManager = preload("res://scripts/TimerManager.gd")
const GameState = preload("res://scripts/GameState.gd")

@onready var player: CharacterBody2D = $Player
@onready var timer: Timer = $Timer
@onready var timer_label: Label = $UI/TimerLabel
@onready var coin_label: Label = $UI/CoinLabel
@onready var level_progress_label: Label = $UI/LevelProgressLabel
@onready var speed_label: Label = $UI/SpeedLabel
@onready var game_over_label: Label = $UI/GameOverLabel
@onready var win_label: Label = $UI/WinLabel
@onready var restart_button: Button = $UI/RestartButton
@onready var menu_button: Button = $UI/MenuButton
@onready var key_container: Control = $UI/KeyContainer
@onready var key_status_container: Control = $UI/KeyContainer/KeyStatus
@onready var level_generator: LevelGenerator = $LevelGenerator
@onready var timer_manager: TimerManager = $TimerManager
@onready var play_area: ColorRect = $PlayArea
@onready var boundaries: Node2D = $Boundaries
@onready var game_state: GameState = $GameState

var game_time: float = 30.0
var total_coins: int = 0
var collected_coins: int = 0
var previous_coin_count: int = 0
var total_keys: int = 0
var collected_keys_count: int = 0
var exit_active: bool = false
var exit: Area2D = null
var prevent_game_over: bool = false
var level_start_time: float = 0.0
var level_initializing: bool = false

var ui_controller: UIController = null
var level_controller: LevelController = null
var statistics_logger: StatisticsLogger = null
var game_flow_controller: GameFlowController = null

func _ready() -> void:
	ui_controller = UIController.new()
	ui_controller.setup(self, timer_label, coin_label, level_progress_label, speed_label, game_over_label, win_label, restart_button, menu_button, key_container, key_status_container)
	level_controller = LevelController.new()
	level_controller.setup(self, ui_controller)
	statistics_logger = StatisticsLogger.new()
	statistics_logger.setup(self, timer_manager, level_controller)
	game_flow_controller = GameFlowController.new()
	game_flow_controller.setup(self, ui_controller, level_controller, statistics_logger)
	level_controller.set_game_flow_controller(game_flow_controller)
	timer.timeout.connect(_on_timer_timeout)
	restart_button.pressed.connect(_on_restart_pressed)
	menu_button.pressed.connect(_on_menu_pressed)
	statistics_logger.init_logging()
	level_controller.generate_new_level()
	ui_controller.update_timer_display(game_time)
	ui_controller.update_coin_display(total_coins, collected_coins)
	ui_controller.update_exit_state(exit_active, exit)
	ui_controller.update_level_progress(game_state.get_level_progress_text())

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	if not game_state.is_game_active():
		return
	if level_initializing:
		return
	game_time -= delta
	ui_controller.update_timer_display(game_time)
	
	# Update tug of war force
	if game_state.has_method("update_tug_of_war_force"):
		game_state.update_tug_of_war_force(delta)
	
	# Update speed display
	if player and is_instance_valid(player):
		var boost_count = player.get_boost_count()
		ui_controller.update_speed_display(player.current_speed, boost_count)
	
	if game_time <= 0.0:
		game_flow_controller.trigger_game_over()

func _on_coin_collected(body: Node, coin: Area2D) -> void:
	level_controller.handle_coin_collected(body, coin)

func _on_key_collected(_door_id: int) -> void:
	level_controller.handle_key_collected()

func _on_timer_timeout() -> void:
	game_flow_controller.on_timer_timeout()

func _on_exit_entered(body: Node) -> void:
	game_flow_controller.on_exit_entered(body)

func _on_restart_pressed() -> void:
	await game_flow_controller.handle_restart_pressed()

func _on_menu_pressed() -> void:
	prevent_game_over = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
