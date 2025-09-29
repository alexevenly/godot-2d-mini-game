extends Camera2D

@export var follow_speed = 3.0
@export var look_ahead_distance = 30.0

var target_position = Vector2()
var is_initialized = false
var player = null

func _ready():
	# Make this camera current
	make_current()
	# Get player reference
	player = get_node("../Player")
	# Initialize target position
	target_position = global_position
	is_initialized = true

func _process(delta):
	if not is_initialized or not player or not is_instance_valid(player):
		return

	# Calculate target position with look-ahead based on player velocity
	var player_velocity = Vector2()
	if player.has_method("get") and player.get("velocity"):
		player_velocity = player.velocity

	var look_ahead = player_velocity.normalized() * look_ahead_distance
	target_position = player.global_position + look_ahead

	# Smooth camera movement with better interpolation
	global_position = global_position.lerp(target_position, follow_speed * delta)
