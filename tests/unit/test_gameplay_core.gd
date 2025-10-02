extends "res://tests/unit/test_utils.gd"

const Logger = preload("res://scripts/Logger.gd")
const SmoothCamera = preload("res://scripts/SmoothCamera.gd")
const KeyScript = preload("res://scripts/Key.gd")
const DoorScript = preload("res://scripts/Door.gd")
const PlayerScript = preload("res://scripts/Player.gd")

class DoorStub extends Node:
	var register_count: int = 0

	func register_key() -> void:
		register_count += 1

func get_suite_name() -> String:
	return "GameplayCore"

func test_logger_toggle_updates_state() -> void:
	var original: bool = bool(Logger._enabled[Logger.Category.GENERATION])
	Logger.set_category_enabled(Logger.Category.GENERATION, false)
	assert_false(Logger._enabled[Logger.Category.GENERATION])
	Logger.set_category_enabled(Logger.Category.GENERATION, original)
	assert_eq(Logger._enabled[Logger.Category.GENERATION], original)

func test_smooth_camera_tracks_player_velocity() -> void:
	var camera = SmoothCamera.new()
	camera.global_position = Vector2.ZERO
	camera.is_initialized = true
	var player = CharacterBody2D.new()
	player.global_position = Vector2(10, 0)
	player.velocity = Vector2(20, 0)
	camera.player = player
	camera._process(0.5)
	assert_true(camera.global_position.x > 0.0)

func test_key_collects_only_player() -> void:
	var key = KeyScript.new()
	var door = DoorStub.new()
	key.door_reference = door
	key.door_id = 7
	key._on_body_entered(Node2D.new())
	var player = CharacterBody2D.new()
	player.name = "Player"
	key._on_body_entered(player)
	assert_eq(door.register_count, 1)

func test_door_register_key_opens() -> void:
	var door = DoorScript.new()
	door.required_keys = 1
	door.body = ColorRect.new()
	door.collision = CollisionShape2D.new()
	door._apply_closed_state()
	door.register_key()
	assert_true(door._is_open)

func test_player_boost_parameters_and_apply() -> void:
	var player = PlayerScript.new()
	player.speed_boost_multiplier = 1.5
	player.max_boost_stacks = 2.0
	player.boost_decay_time = 2.0
	player._setup_boost_parameters()
	assert_near(player.boost_increment, 0.5, 0.0001)
	player.speed_boost_enabled = true
	player.boost_increment = 0.3
	player.max_boost_value = 0.4
	player.current_boost_value = 0.2
	player.current_speed = PlayerScript.SPEED
	player.apply_speed_boost()
	assert_near(player.current_boost_value, 0.4, 0.0001)
	assert_near(player.current_speed, PlayerScript.SPEED * 1.4, 0.0001)
