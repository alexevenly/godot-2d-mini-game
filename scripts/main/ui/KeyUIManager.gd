extends RefCounted

class_name KeyUIManager

const NEUTRAL_COLOR := Color(1, 1, 1, 1)
const DEFAULT_KEY_COLOR := Color(0.9, 0.9, 0.2, 1.0)

var key_container: Control = null
var key_status_container: Control = null
var key_checkbox_nodes: Array[CheckBox] = []
var available_key_colors_by_door: Dictionary = {}
var collected_colors: Array[Color] = []
var target_collected_count: int = 0

func setup_containers(key_container_ref: Control, key_status_container_ref: Control) -> void:
	key_container = key_container_ref
	key_status_container = key_status_container_ref
	clear()

func clear() -> void:
	key_checkbox_nodes.clear()
	available_key_colors_by_door.clear()
	collected_colors.clear()
	target_collected_count = 0
	if key_status_container:
		for child in key_status_container.get_children():
			var control_child: Control = child as Control
			if control_child and is_instance_valid(control_child):
				control_child.queue_free()
	if key_container:
		key_container.visible = false

func build_from_keys(key_nodes: Array[Area2D]) -> void:
	clear()
	if key_nodes == null:
		key_nodes = [] as Array[Area2D]
	var total_keys: int = key_nodes.size()
	if total_keys <= 0 or key_status_container == null:
		return
	if key_container:
		key_container.visible = true
	for index in range(total_keys):
		var checkbox: CheckBox = CheckBox.new()
		checkbox.disabled = true
		checkbox.focus_mode = Control.FOCUS_NONE
		checkbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		checkbox.button_pressed = false
		var key_node: Area2D = key_nodes[index] if index < key_nodes.size() else null
		var color: Color = DEFAULT_KEY_COLOR
		if key_node and key_node.has_meta("group_color"):
			color = key_node.get_meta("group_color")
		var door_identifier: int = index
		if key_node and key_node.has_method("get"):
			var door_value = key_node.get("door_id")
			if door_value != null:
				door_identifier = int(door_value)
		var door_colors: Array = available_key_colors_by_door.get(door_identifier, [])
		door_colors.append(color)
		available_key_colors_by_door[door_identifier] = door_colors
		checkbox.modulate = NEUTRAL_COLOR
		key_status_container.add_child(checkbox)
		key_checkbox_nodes.append(checkbox)
	_refresh_checkboxes()

func update_key_status_display(collected_keys: int) -> void:
	target_collected_count = clamp(collected_keys, 0, key_checkbox_nodes.size())
	_refresh_checkboxes()

func mark_key_collected(door_id: int) -> void:
	var color_queue: Array = available_key_colors_by_door.get(door_id, [])
	var key_color: Color = DEFAULT_KEY_COLOR
	if color_queue.size() > 0:
		key_color = color_queue[0]
		color_queue.remove_at(0)
		available_key_colors_by_door[door_id] = color_queue
	collected_colors.append(key_color)
	target_collected_count = min(collected_colors.size(), key_checkbox_nodes.size())
	_refresh_checkboxes()

func _refresh_checkboxes() -> void:
	for index in range(key_checkbox_nodes.size()):
		var checkbox: CheckBox = key_checkbox_nodes[index]
		if checkbox == null or not is_instance_valid(checkbox):
			continue
		var is_collected: bool = index < target_collected_count
		checkbox.button_pressed = is_collected
		if is_collected:
			var color_index: int = min(index, collected_colors.size() - 1)
			var collected_color: Color = collected_colors[color_index] if color_index >= 0 else DEFAULT_KEY_COLOR
			checkbox.modulate = collected_color
		else:
			checkbox.modulate = NEUTRAL_COLOR
	if key_container:
		key_container.visible = key_checkbox_nodes.size() > 0
