extends RefCounted

class_name KeyUIManager

var key_container: Control = null
var key_status_container: Control = null
var key_checkbox_nodes: Array[CheckBox] = []
var key_colors: Array[Color] = []
var key_door_ids: Array[int] = []
var collected_key_counts: Dictionary = {}
var key_slot_counts: Dictionary = {}

func setup_containers(key_container_ref: Control, key_status_container_ref: Control) -> void:
	key_container = key_container_ref
	key_status_container = key_status_container_ref
	clear()

func clear() -> void:
	key_checkbox_nodes.clear()
	key_colors.clear()
	key_door_ids.clear()
	collected_key_counts.clear()
	key_slot_counts.clear()
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
		var color: Color = Color(0.9, 0.9, 0.2, 1.0)
		if key_node and key_node.has_meta("group_color"):
			color = key_node.get_meta("group_color")
		key_colors.append(color)
		var door_identifier: int = index
		if key_node and key_node.has_method("get"):
			var door_value = key_node.get("door_id")
			if door_value != null:
				door_identifier = int(door_value)
		key_door_ids.append(door_identifier)
		key_slot_counts[door_identifier] = key_slot_counts.get(door_identifier, 0) + 1
		checkbox.modulate = color
		key_status_container.add_child(checkbox)
		key_checkbox_nodes.append(checkbox)
	_refresh_checkboxes()

func update_key_status_display(collected_keys: int) -> void:
	collected_key_counts.clear()
	var remaining: int = clamp(collected_keys, 0, key_door_ids.size())
	for door_id in key_door_ids:
		if remaining <= 0:
			break
		var total_slots: int = int(key_slot_counts.get(door_id, 0))
		if total_slots <= 0:
			continue
		var current: int = int(collected_key_counts.get(door_id, 0))
		if current >= total_slots:
			continue
		collected_key_counts[door_id] = current + 1
		remaining -= 1
	_refresh_checkboxes()

func mark_key_collected(door_id: int) -> void:
	var total_slots: int = int(key_slot_counts.get(door_id, 0))
	if total_slots <= 0:
		return
	var collected: int = int(collected_key_counts.get(door_id, 0))
	if collected >= total_slots:
		return
	collected_key_counts[door_id] = collected + 1
	_refresh_checkboxes()

func _refresh_checkboxes() -> void:
	var per_door_usage: Dictionary = {}
	for index in range(key_checkbox_nodes.size()):
		var checkbox: CheckBox = key_checkbox_nodes[index]
		if checkbox == null or not is_instance_valid(checkbox):
			continue
		var door_identifier: int = key_door_ids[index] if index < key_door_ids.size() else index
		var collected_total: int = int(collected_key_counts.get(door_identifier, 0))
		var used: int = int(per_door_usage.get(door_identifier, 0))
		var is_collected: bool = used < collected_total
		per_door_usage[door_identifier] = used + 1
		checkbox.button_pressed = is_collected
		var base_color: Color = key_colors[index] if index < key_colors.size() else Color(0.9, 0.9, 0.2, 1.0)
		if is_collected:
			var highlight: Color = base_color.lightened(0.35)
			highlight.a = base_color.a
			checkbox.modulate = highlight
		else:
			checkbox.modulate = base_color
	if key_container:
		key_container.visible = key_checkbox_nodes.size() > 0
