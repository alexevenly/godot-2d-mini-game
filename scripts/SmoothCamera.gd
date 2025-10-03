extends Camera2D

@export var follow_speed = 3.0
@export var look_ahead_distance = 30.0
@export var limited_field_of_view_enabled = true
@export var visibility_radius = 200.0

var target_position = Vector2()
var is_initialized = false
var player = null
var fog_manager = null
var last_visibility_radius := -1.0
const FogOfWarManager = preload("res://scripts/FogOfWarManager.gd")

func _ready():
	# Make this camera current
	make_current()
	# Get player reference
	player = get_node("../Player")
	# Initialize target position
	target_position = global_position
	is_initialized = true
	
	# Check if limited field of view is enabled from main menu
	if Engine.has_meta("limited_field_of_view"):
		limited_field_of_view_enabled = Engine.get_meta("limited_field_of_view")
	
	# Create limited field of view overlay
	if limited_field_of_view_enabled:
		_setup_limited_field_of_view()

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
	
	# Update limited field of view
	if limited_field_of_view_enabled and fog_manager:
		if not is_equal_approx(visibility_radius, last_visibility_radius):
			fog_manager.set_visibility_radius(visibility_radius)
			last_visibility_radius = visibility_radius

func _setup_limited_field_of_view():
	if fog_manager:
		return
	if FogOfWarManager == null:
		return
	fog_manager = FogOfWarManager.new()
	fog_manager.set_player(player)
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.add_child(fog_manager)
		var total_children := current_scene.get_child_count()
		var ui_node = current_scene.get_node_or_null("UI")
		if ui_node:
			current_scene.move_child(ui_node, total_children - 1)
			if total_children >= 2:
				current_scene.move_child(fog_manager, total_children - 2)
		else:
			current_scene.move_child(fog_manager, total_children - 1)
	fog_manager.set_visibility_radius(visibility_radius)
	last_visibility_radius = visibility_radius
