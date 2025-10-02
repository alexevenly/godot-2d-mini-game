extends "res://tests/unit/test_utils.gd"

const MainScript = preload("res://tests/unit/stubs/MainStub.gd")
const UIControllerScript = preload("res://tests/unit/stubs/UIControllerStub.gd")
const GameFlowControllerScript = preload("res://tests/unit/stubs/GameFlowControllerStub.gd")
const LevelController = preload("res://scripts/main/LevelController.gd")
const GameState = preload("res://scripts/GameState.gd")
const LevelUtils = preload("res://scripts/LevelUtils.gd")

class LevelGeneratorStub:
	extends RefCounted

	var cleared := false

	func clear_existing_objects() -> void:
		cleared = true

class MainStub:
	extends "res://tests/unit/stubs/MainStub.gd"

	var player: CharacterBody2D
	var game_state: GameState
	var play_area := ColorRect.new()
	var boundaries := Node2D.new()
	var exit: Node = null
	var total_coins := 0
	var collected_coins := 0
	var previous_coin_count := 0
	var exit_active := false
	var collected_keys_count := 0
	var total_keys := 0
	var level_generator: Variant = null

	func _init() -> void:
		player = CharacterBody2D.new()
		add_child(player)
		game_state = GameState.new()
		game_state._ready()
		add_child(game_state)
		add_child(play_area)
		add_child(boundaries)

func get_suite_name() -> String:
	return "LevelController"

func _make_controller():
	var controller = LevelController.new()
	controller.ui_controller = UIControllerScript.new()
	return controller

func test_position_player_within_level_uses_dimensions() -> void:
	var main := track_node(MainStub.new())
	main.game_state.current_level_size = 1.0
	var controller = _make_controller()
	controller.main = main
	controller.position_player_within_level(1.0)
	var dims: Dictionary = LevelUtils.get_scaled_level_dimensions(1.0)
	var expected_x: float = max(dims.offset_x + (dims.width * 0.1), 50.0)
	var expected_y: float = max(dims.offset_y + (dims.height * 0.5), 50.0)
	assert_vector_near(main.player.position, Vector2(expected_x, expected_y), 0.001)

func test_handle_coin_collected_updates_counts_and_ui() -> void:
	var main := track_node(MainStub.new())
	var controller = _make_controller()
	controller.main = main
	var ui = controller.ui_controller
	main.total_coins = 2
	main.collected_coins = 0
	main.previous_coin_count = 0
	main.exit = track_node(Area2D.new())
	main.exit_active = false
	controller.coins = [] as Array[Area2D]
	var coin: Area2D = track_node(Area2D.new())
	controller.coins.append(coin)
	main.game_state.set_state(GameState.GameStateType.PLAYING)
	controller.handle_coin_collected(main.player, coin)
	assert_eq(main.collected_coins, 1)
	assert_eq(main.previous_coin_count, 1)
	assert_true(coin.is_queued_for_deletion())
	assert_true(controller.coins.is_empty())
	assert_true(main.exit_active == (main.collected_coins >= main.total_coins))
	assert_eq(ui.last_coin_total, 2)
	assert_eq(ui.last_coin_collected, 1)
	assert_eq(ui.last_exit, main.exit)

func test_handle_key_collected_clamps_total() -> void:
	var main := track_node(MainStub.new())
	var controller = _make_controller()
	controller.main = main
	var ui = controller.ui_controller
	main.total_keys = 1
	controller.handle_key_collected()
	assert_eq(main.collected_keys_count, 1)
	assert_eq(ui.last_keys, 1)
	controller.handle_key_collected()
	assert_eq(main.collected_keys_count, 1)
	assert_eq(ui.last_keys, 1)

func test_clear_level_objects_queues_matching_children_and_clears_generator() -> void:
	var main := track_node(MainStub.new())
	var controller = _make_controller()
	controller.main = main
	var obstacle: Node2D = track_node(Node2D.new())
	obstacle.name = "Obstacle1"
	main.add_child(obstacle)
	var coin_node: Node2D = track_node(Node2D.new())
	coin_node.name = "Coin0"
	main.add_child(coin_node)
	var door: Node2D = track_node(Node2D.new())
	door.name = "DoorA"
	main.add_child(door)
	var key: Node2D = track_node(Node2D.new())
	key.name = "KeyItem"
	main.add_child(key)
	var maze_wall: Node2D = track_node(Node2D.new())
	maze_wall.name = "MazeWall3"
	main.add_child(maze_wall)
	var exit_node: Node2D = track_node(Node2D.new())
	exit_node.name = "Exit"
	main.add_child(exit_node)
	var other: Node2D = track_node(Node2D.new())
	other.name = "Decor"
	main.add_child(other)
	var generator: LevelGeneratorStub = LevelGeneratorStub.new()
	controller.main.level_generator = generator
	controller.clear_level_objects()
	assert_true(obstacle.is_queued_for_deletion())
	assert_true(coin_node.is_queued_for_deletion())
	assert_true(door.is_queued_for_deletion())
	assert_true(key.is_queued_for_deletion())
	assert_true(maze_wall.is_queued_for_deletion())
	assert_true(exit_node.is_queued_for_deletion())
	assert_false(other.is_queued_for_deletion())
	assert_true(generator.cleared)
