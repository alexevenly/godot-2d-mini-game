extends Object

class_name KeyUICheckboxFactory

const NEUTRAL_COLOR := Color(1, 1, 1, 1)
const DEFAULT_KEY_COLOR := Color(0.9, 0.9, 0.2, 1.0)
const DEFAULT_DOOR_COLOR := Color(0.35, 0.35, 0.75, 1.0)
const CHECKBOX_SIZE := Vector2(28, 28)
const CHECKBOX_BORDER_COLOR := Color(1, 1, 1, 1)
const CHECKBOX_PRESSED_ALPHA := 0.45
const CHECKBOX_HOVER_ALPHA := 0.35
const CHECKBOX_BASE_ALPHA := 0.25

static func create_checkbox() -> Button:
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
	apply_theme(checkbox)
	return checkbox

static func apply_theme(checkbox: Button) -> void:
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

static func clear_container_nodes(container: Control, nodes: Array) -> void:
	if container:
		for child in container.get_children():
			var control_child: Control = child as Control
			if control_child and is_instance_valid(control_child):
				control_child.queue_free()
	nodes.clear()
	update_visibility(container, nodes)

static func update_visibility(container: Control, nodes: Array) -> void:
	if container:
		container.visible = nodes.size() > 0
