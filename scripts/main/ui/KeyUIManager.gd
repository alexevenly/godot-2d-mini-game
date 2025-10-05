extends RefCounted

class_name KeyUIManager

const NEUTRAL_COLOR := Color(1, 1, 1, 1)
const DEFAULT_KEY_COLOR := Color(0.9, 0.9, 0.2, 1.0)
const DEFAULT_DOOR_COLOR := Color(0.35, 0.35, 0.75, 1.0)
const CHECKBOX_SIZE := Vector2(28, 28)
const CHECKBOX_BORDER_COLOR := Color(1, 1, 1, 1)
const CHECKBOX_PRESSED_ALPHA := 0.45
const CHECKBOX_HOVER_ALPHA := 0.35
const CHECKBOX_BASE_ALPHA := 0.25

var key_container: Control = null
var key_status_container: Control = null
var door_container: Control = null
var door_status_container: Control = null
var key_checkbox_nodes: Array[Button] = []
var door_checkbox_nodes: Array[Button] = []
var available_key_colors_by_door: Dictionary = {}
var collected_colors: Array[Color] = []
var target_collected_count: int = 0
var door_index_by_id: Dictionary = {}
var door_colors_by_id: Dictionary = {}

func setup_containers(
	key_container_ref: Control,
	key_status_container_ref: Control,
	door_container_ref: Control = null,
	door_status_container_ref: Control = null
) -> void:
	key_container = key_container_ref
	key_status_container = key_status_container_ref
	door_container = door_container_ref
	door_status_container = door_status_container_ref
	clear()

func clear() -> void:
	available_key_colors_by_door.clear()
	collected_colors.clear()
	target_collected_count = 0
	_clear_key_checkboxes()
	_clear_door_checkboxes()

func build_from_keys(key_nodes: Array[Area2D]) -> void:
	_clear_key_checkboxes()
	available_key_colors_by_door.clear()
	collected_colors.clear()
	target_collected_count = 0
	if key_nodes == null:
		key_nodes = [] as Array[Area2D]
	var total_keys: int = key_nodes.size()
	if total_keys <= 0 or key_status_container == null:
		_update_container_visibility(key_container, key_checkbox_nodes)
		return
	for index in range(total_keys):
		var checkbox: Button = _create_status_checkbox()
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
		key_status_container.add_child(checkbox)
		key_checkbox_nodes.append(checkbox)
	_update_container_visibility(key_container, key_checkbox_nodes)
	_refresh_checkboxes()

func build_from_doors(door_nodes: Array) -> void:
	_clear_door_checkboxes()
	if door_nodes == null:
		door_nodes = [] as Array[StaticBody2D]
	var total_doors: int = door_nodes.size()
	if total_doors <= 0 or door_status_container == null:
		_update_container_visibility(door_container, door_checkbox_nodes)
		return
	for index in range(total_doors):
		var checkbox: Button = _create_status_checkbox()
		var door_body: StaticBody2D = door_nodes[index] if index < door_nodes.size() else null
		var door_id: int = index
		var door_color: Color = DEFAULT_DOOR_COLOR
		if door_body:
			if door_body.has_method("get"):
				var door_id_value = door_body.get("door_id")
				if door_id_value != null:
					door_id = int(door_id_value)
			if door_body.has_method("get_door_color"):
				door_color = door_body.get_door_color()
			elif door_body.has_meta("group_color"):
				door_color = door_body.get_meta("group_color")
			elif door_body.has_method("get"):
				var door_color_value = door_body.get("door_color")
				if typeof(door_color_value) == TYPE_COLOR:
					door_color = door_color_value
		door_index_by_id[door_id] = door_checkbox_nodes.size()
		door_colors_by_id[door_id] = door_color
		door_status_container.add_child(checkbox)
		door_checkbox_nodes.append(checkbox)
	_update_container_visibility(door_container, door_checkbox_nodes)

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

func mark_door_opened(door_id: int, door_color: Color) -> void:
	var target_index: int = int(door_index_by_id.get(door_id, -1))
	if target_index < 0:
		if door_status_container == null:
			return
		var new_checkbox: Button = _create_status_checkbox()
		door_status_container.add_child(new_checkbox)
		door_checkbox_nodes.append(new_checkbox)
		target_index = door_checkbox_nodes.size() - 1
		door_index_by_id[door_id] = target_index
	var checkbox: Button = door_checkbox_nodes[target_index]
	if checkbox == null or not is_instance_valid(checkbox):
		return
	var color_to_use: Color = door_color if typeof(door_color) == TYPE_COLOR else DEFAULT_DOOR_COLOR
	door_colors_by_id[door_id] = color_to_use
	checkbox.button_pressed = true
	checkbox.modulate = color_to_use
	_update_container_visibility(door_container, door_checkbox_nodes)

func _refresh_checkboxes() -> void:
	for index in range(key_checkbox_nodes.size()):
		var checkbox: Button = key_checkbox_nodes[index]
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
	_update_container_visibility(key_container, key_checkbox_nodes)

func _create_status_checkbox() -> Button:
	var checkbox: Button = Button.new()
	checkbox.toggle_mode = true
	checkbox.focus_mode = Control.FOCUS_NONE
	checkbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	checkbox.button_pressed = false
	checkbox.text = ""
	checkbox.flat = false
	checkbox.modulate = NEUTRAL_COLOR
	checkbox.custom_minimum_size = CHECKBOX_SIZE
	checkbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	checkbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_checkbox_theme(checkbox)
	return checkbox

func _apply_checkbox_theme(checkbox: Button) -> void:
	var base_style := StyleBoxFlat.new()
	base_style.bg_color = Color(1, 1, 1, CHECKBOX_BASE_ALPHA)
	base_style.border_color = CHECKBOX_BORDER_COLOR
	base_style.set_border_width_all(2)
	base_style.set_corner_radius_all(0)
	base_style.set_content_margin_all(0)
	var hover_style: StyleBoxFlat = base_style.duplicate()
	hover_style.bg_color = Color(1, 1, 1, CHECKBOX_HOVER_ALPHA)
	var pressed_style: StyleBoxFlat = base_style.duplicate()
	pressed_style.bg_color = Color(1, 1, 1, CHECKBOX_PRESSED_ALPHA)
	var disabled_style: StyleBoxFlat = base_style.duplicate()
	disabled_style.bg_color = Color(1, 1, 1, CHECKBOX_BASE_ALPHA)
	checkbox.add_theme_stylebox_override("normal", base_style)
	checkbox.add_theme_stylebox_override("hover", hover_style)
	checkbox.add_theme_stylebox_override("pressed", pressed_style)
	checkbox.add_theme_stylebox_override("disabled", disabled_style)
	checkbox.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _clear_key_checkboxes() -> void:
	if key_status_container:
		for child in key_status_container.get_children():
			var control_child: Control = child as Control
			if control_child and is_instance_valid(control_child):
				control_child.queue_free()
	key_checkbox_nodes.clear()
	_update_container_visibility(key_container, key_checkbox_nodes)

func _clear_door_checkboxes() -> void:
	if door_status_container:
		for child in door_status_container.get_children():
			var control_child: Control = child as Control
			if control_child and is_instance_valid(control_child):
				control_child.queue_free()
	door_checkbox_nodes.clear()
	door_index_by_id.clear()
	door_colors_by_id.clear()
	_update_container_visibility(door_container, door_checkbox_nodes)

func _update_container_visibility(container: Control, nodes: Array) -> void:
	if container:
		container.visible = nodes.size() > 0
