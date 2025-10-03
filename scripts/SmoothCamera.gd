extends Camera2D

@export var follow_speed = 3.0
@export var look_ahead_distance = 30.0
@export var limited_field_of_view_enabled = true
@export var visibility_radius = 200.0

var target_position = Vector2()
var is_initialized = false
var player = null
var fog_overlay: ColorRect = null

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
	if limited_field_of_view_enabled and fog_overlay:
		_update_limited_field_of_view()

func _setup_limited_field_of_view():
	"""Create proper limited field of view overlay using multiple overlays"""
	# Create a large black overlay that covers everything
	fog_overlay = ColorRect.new()
	fog_overlay.color = Color(0, 0, 0, 1)
	fog_overlay.z_index = 1000
	fog_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Make it cover a large area around the level
	var level_size = 2000 # Large enough to cover any level
	fog_overlay.position = Vector2(-level_size, -level_size)
	fog_overlay.size = Vector2(level_size * 2, level_size * 2)
	
	# Add to scene
	get_tree().current_scene.add_child(fog_overlay)

func _update_limited_field_of_view():
	"""Update limited field of view visibility around player using proper circular cutout"""
	if not fog_overlay or not player:
		return
	
	# Clear any existing visibility cutouts
	_clear_visibility_cutouts()
	
	# Create a circular cutout by creating multiple overlays around the player
	var player_pos = player.global_position
	var radius = visibility_radius
	
	# Create circular visibility by creating multiple rectangular overlays
	# This creates a cross-shaped cutout that approximates a circle
	var overlay_size = radius * 2
	var window_size = radius * 1.2 # Smaller window for better circular effect
	
	# Top overlay (covers area above the visibility circle)
	var top_overlay = ColorRect.new()
	top_overlay.color = Color(0, 0, 0, 1)
	top_overlay.z_index = 1001
	top_overlay.position = Vector2(player_pos.x - overlay_size, player_pos.y - overlay_size)
	top_overlay.size = Vector2(overlay_size * 2, overlay_size - window_size)
	get_tree().current_scene.add_child(top_overlay)
	
	# Bottom overlay (covers area below the visibility circle)
	var bottom_overlay = ColorRect.new()
	bottom_overlay.color = Color(0, 0, 0, 1)
	bottom_overlay.z_index = 1001
	bottom_overlay.position = Vector2(player_pos.x - overlay_size, player_pos.y + window_size)
	bottom_overlay.size = Vector2(overlay_size * 2, overlay_size - window_size)
	get_tree().current_scene.add_child(bottom_overlay)
	
	# Left overlay (covers area to the left of the visibility circle)
	var left_overlay = ColorRect.new()
	left_overlay.color = Color(0, 0, 0, 1)
	left_overlay.z_index = 1001
	left_overlay.position = Vector2(player_pos.x - overlay_size, player_pos.y - window_size)
	left_overlay.size = Vector2(overlay_size - window_size, window_size * 2)
	get_tree().current_scene.add_child(left_overlay)
	
	# Right overlay (covers area to the right of the visibility circle)
	var right_overlay = ColorRect.new()
	right_overlay.color = Color(0, 0, 0, 1)
	right_overlay.z_index = 1001
	right_overlay.position = Vector2(player_pos.x + window_size, player_pos.y - window_size)
	right_overlay.size = Vector2(overlay_size - window_size, window_size * 2)
	get_tree().current_scene.add_child(right_overlay)

func _clear_visibility_cutouts():
	"""Clear all visibility cutout overlays"""
	# Find and remove all overlays with z_index 1001 (our visibility cutouts)
	var scene = get_tree().current_scene
	if scene:
		for child in scene.get_children():
			if child is ColorRect and child.z_index == 1001:
				child.queue_free()