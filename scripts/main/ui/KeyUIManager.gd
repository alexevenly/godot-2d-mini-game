extends RefCounted

class_name KeyUIManager

const CHECKBOX_FACTORY = preload("res://scripts/main/ui/KeyUICheckboxFactory.gd")
const COLOR_RESOLVER = preload("res://scripts/main/ui/KeyUIColorResolver.gd")

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
	_clear_keys()
	_clear_doors()

func build_from_keys(key_nodes: Array[Area2D]) -> void:
	_clear_keys()
	available_key_colors_by_door.clear()
	collected_colors.clear()
	target_collected_count = 0
	if key_nodes == null:
		key_nodes = [] as Array[Area2D]
	var total_keys: int = key_nodes.size()
	if total_keys <= 0 or key_status_container == null:
		CHECKBOX_FACTORY.update_visibility(key_container, key_checkbox_nodes)
		return
	for index in range(total_keys):
		var checkbox: Button = CHECKBOX_FACTORY.create_checkbox()
		var key_node: Area2D = key_nodes[index] if index < key_nodes.size() else null
		var metadata := COLOR_RESOLVER.resolve_key_metadata(key_node, index, CHECKBOX_FACTORY.DEFAULT_KEY_COLOR)
		var door_colors: Array = available_key_colors_by_door.get(metadata.id, [])
		door_colors.append(metadata.color)
		available_key_colors_by_door[metadata.id] = door_colors
		key_status_container.add_child(checkbox)
		key_checkbox_nodes.append(checkbox)
	CHECKBOX_FACTORY.update_visibility(key_container, key_checkbox_nodes)
	_refresh_checkboxes()

func build_from_doors(door_nodes: Array) -> void:
	_clear_doors()
	if door_nodes == null:
		door_nodes = [] as Array[StaticBody2D]
	var total_doors: int = door_nodes.size()
	if total_doors <= 0 or door_status_container == null:
		CHECKBOX_FACTORY.update_visibility(door_container, door_checkbox_nodes)
		return
	for index in range(total_doors):
		var checkbox: Button = CHECKBOX_FACTORY.create_checkbox()
		var door_body: StaticBody2D = door_nodes[index] if index < door_nodes.size() else null
		var door_id: int = COLOR_RESOLVER.resolve_door_identifier(door_body, index)
		var door_color: Color = COLOR_RESOLVER.resolve_door_color(door_body, CHECKBOX_FACTORY.DEFAULT_DOOR_COLOR)
		door_index_by_id[door_id] = door_checkbox_nodes.size()
		door_colors_by_id[door_id] = door_color
		door_status_container.add_child(checkbox)
		door_checkbox_nodes.append(checkbox)
	CHECKBOX_FACTORY.update_visibility(door_container, door_checkbox_nodes)

func update_key_status_display(collected_keys: int) -> void:
	target_collected_count = clamp(collected_keys, 0, key_checkbox_nodes.size())
	_refresh_checkboxes()

func mark_key_collected(door_id: int) -> void:
	var color_queue: Array = available_key_colors_by_door.get(door_id, [])
	var key_color: Color = CHECKBOX_FACTORY.DEFAULT_KEY_COLOR
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
		var new_checkbox: Button = CHECKBOX_FACTORY.create_checkbox()
		door_status_container.add_child(new_checkbox)
		door_checkbox_nodes.append(new_checkbox)
		target_index = door_checkbox_nodes.size() - 1
		door_index_by_id[door_id] = target_index
	var checkbox: Button = door_checkbox_nodes[target_index]
	if checkbox == null or not is_instance_valid(checkbox):
		return
	var color_to_use: Color = door_color if typeof(door_color) == TYPE_COLOR else CHECKBOX_FACTORY.DEFAULT_DOOR_COLOR
	door_colors_by_id[door_id] = color_to_use
	checkbox.button_pressed = true
	checkbox.modulate = color_to_use
	CHECKBOX_FACTORY.update_visibility(door_container, door_checkbox_nodes)

func _refresh_checkboxes() -> void:
	for index in range(key_checkbox_nodes.size()):
		var checkbox: Button = key_checkbox_nodes[index]
		if checkbox == null or not is_instance_valid(checkbox):
			continue
		var is_collected: bool = index < target_collected_count
		checkbox.button_pressed = is_collected
		if is_collected:
			var color_index: int = min(index, collected_colors.size() - 1)
			var collected_color: Color = collected_colors[color_index] if color_index >= 0 else CHECKBOX_FACTORY.DEFAULT_KEY_COLOR
			checkbox.modulate = collected_color
		else:
			checkbox.modulate = CHECKBOX_FACTORY.NEUTRAL_COLOR
	CHECKBOX_FACTORY.update_visibility(key_container, key_checkbox_nodes)

func _clear_keys() -> void:
	CHECKBOX_FACTORY.clear_container_nodes(key_status_container, key_checkbox_nodes)

func _clear_doors() -> void:
	CHECKBOX_FACTORY.clear_container_nodes(door_status_container, door_checkbox_nodes)
	door_index_by_id.clear()
	door_colors_by_id.clear()
