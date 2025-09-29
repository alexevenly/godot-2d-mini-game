extends CharacterBody2D

const SPEED := 200.0
const CONFIG_PATH := "res://config/game.cfg"

# Configurable speed boost settings
@export var speed_boost_enabled := true
@export var speed_boost_multiplier := 1.5
@export var boost_decay_time := 1.2
@export var max_boost_stacks := 3.0
@export var ghost_trail_enabled := true

@onready var player_body: Control = $PlayerBody

var current_speed: float = SPEED
var current_boost_value: float = 0.0
var boost_increment: float = 0.0
var max_boost_value: float = 0.0
var boost_decay_per_second: float = 0.0

var ghost_container: Node2D = null
var ghost_spawn_timer: float = 0.0
var ghost_base_lifetime: float = 0.25
var ghost_extra_lifetime: float = 0.7
var ghost_spawn_interval: float = 0.08
var ghost_spawn_interval_min: float = 0.02

func _ready():
	_load_config()
	_setup_boost_parameters()
	_setup_ghost_container()
	current_speed = SPEED

func _load_config():
	var cfg := ConfigFile.new()
	var err := cfg.load(CONFIG_PATH)
	if err == OK:
		speed_boost_multiplier = float(cfg.get_value("gameplay", "speed_boost_multiplier", speed_boost_multiplier))
		boost_decay_time = float(cfg.get_value("gameplay", "speed_boost_decay_time", boost_decay_time))
		max_boost_stacks = float(cfg.get_value("gameplay", "speed_boost_max_stacks", max_boost_stacks))
		ghost_base_lifetime = float(cfg.get_value("gameplay", "ghost_base_lifetime", ghost_base_lifetime))
		ghost_extra_lifetime = float(cfg.get_value("gameplay", "ghost_extra_lifetime", ghost_extra_lifetime))
		ghost_spawn_interval = float(cfg.get_value("gameplay", "ghost_spawn_interval", ghost_spawn_interval))
		ghost_spawn_interval_min = float(cfg.get_value("gameplay", "ghost_spawn_interval_min", ghost_spawn_interval_min))
	else:
		push_warning("Player.gd: Could not load config file at %s (error %d). Using defaults." % [CONFIG_PATH, err])

func _setup_boost_parameters():
	max_boost_stacks = max(max_boost_stacks, 1.0)
	boost_increment = max(speed_boost_multiplier - 1.0, 0.0)
	max_boost_value = boost_increment * max_boost_stacks
	if boost_decay_time > 0.0:
		boost_decay_per_second = boost_increment / boost_decay_time
	else:
		boost_decay_per_second = boost_increment

func _setup_ghost_container():
	if not ghost_trail_enabled:
		return
	var parent := get_parent()
	if parent:
		ghost_container = parent.get_node_or_null("PlayerGhosts")
		if ghost_container == null:
			ghost_container = Node2D.new()
			ghost_container.name = "PlayerGhosts"
			ghost_container.z_index = max(z_index - 1, 0)
			parent.add_child(ghost_container)

func _physics_process(delta):
	_update_boost(delta)

	var direction := Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		direction.x -= 1
	if Input.is_action_pressed("move_right"):
		direction.x += 1
	if Input.is_action_pressed("move_up"):
		direction.y -= 1
	if Input.is_action_pressed("move_down"):
		direction.y += 1

	if direction.length() > 0.0:
		direction = direction.normalized()
		rotation = direction.angle()

	velocity = direction * current_speed
	move_and_slide()

func _update_boost(delta: float) -> void:
	if not speed_boost_enabled or boost_increment <= 0.0:
		current_boost_value = 0.0
		current_speed = SPEED
		return

	if current_boost_value > 0.0:
		if boost_decay_per_second > 0.0:
			current_boost_value = max(current_boost_value - boost_decay_per_second * delta, 0.0)
		else:
			current_boost_value = 0.0

	if current_boost_value <= 0.0:
		current_speed = SPEED
		_advance_ghost_trail(delta, 0.0)
		return

	current_speed = SPEED * (1.0 + current_boost_value)
	_advance_ghost_trail(delta, current_boost_value)

func _advance_ghost_trail(delta: float, boost_value: float) -> void:
	if not ghost_trail_enabled or ghost_container == null:
		return

	var ratio := 0.0
	if max_boost_value > 0.0:
		ratio = clamp(boost_value / max_boost_value, 0.0, 1.0)

	if ratio <= 0.0:
		return

	ghost_spawn_timer += delta
	var interval: float = float(lerp(ghost_spawn_interval, ghost_spawn_interval_min, ratio))
	interval = max(interval, 0.01)
	if ghost_spawn_timer >= interval:
		ghost_spawn_timer = 0.0
		_spawn_ghost(ratio)

func _spawn_ghost(strength_ratio: float) -> void:
	if player_body == null:
		return

	var ghost := Node2D.new()
	ghost.position = global_position
	ghost.rotation = rotation
	ghost.scale = scale
	ghost.z_index = max(z_index - 1, 0)
	ghost_container.add_child(ghost)

	var body_clone := player_body.duplicate()
	ghost.add_child(body_clone)
	if body_clone is Control:
		body_clone.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var base_alpha := 0.25
	var alpha: float = float(lerp(base_alpha, 0.8, strength_ratio))
	ghost.modulate = Color(1.0, 1.0, 1.0, alpha)

	var lifetime := ghost_base_lifetime + ghost_extra_lifetime * strength_ratio
	var tween := ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, max(lifetime, 0.05)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(Callable(ghost, "queue_free"))

func apply_speed_boost():
	if not speed_boost_enabled or boost_increment <= 0.0:
		return

	if max_boost_value <= 0.0:
		max_boost_value = boost_increment

	current_boost_value = min(current_boost_value + boost_increment, max_boost_value)
	current_speed = SPEED * (1.0 + current_boost_value)
	ghost_spawn_timer = 0.0
