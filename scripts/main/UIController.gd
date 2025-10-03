class_name UIController
extends RefCounted

var main = null
var timer_label: Label = null
var coin_label: Label = null
var level_progress_label: Label = null
var speed_label: Label = null
var game_over_label: Label = null
var win_label: Label = null
var restart_button: Button = null
var menu_button: Button = null
var key_container: Control = null
var key_status_container: Control = null
var key_checkbox_nodes: Array[CheckBox] = []
var key_colors: Array[Color] = []

func setup(
	main_ref,
	timer_label_ref: Label,
	coin_label_ref: Label,
	level_progress_label_ref: Label,
	game_over_label_ref: Label,
	win_label_ref: Label,
	restart_button_ref: Button,
	menu_button_ref: Button,
	key_container_ref: Control,
	key_status_container_ref: Control,
	speed_label_ref: Label = null
) -> void:
	main = main_ref
	timer_label = timer_label_ref
	coin_label = coin_label_ref
	level_progress_label = level_progress_label_ref
	game_over_label = game_over_label_ref
	win_label = win_label_ref
	restart_button = restart_button_ref
	menu_button = menu_button_ref
	key_container = key_container_ref
	key_status_container = key_status_container_ref
	speed_label = speed_label_ref

func update_timer_display(game_time: float) -> void:
	if timer_label:
		timer_label.text = "Time: " + "%.2f" % game_time

func update_coin_display(total_coins: int, collected_coins: int) -> void:
	if coin_label == null:
		return
	coin_label.visible = total_coins > 0
	if coin_label.visible:
		coin_label.text = "Coins: " + str(collected_coins) + "/" + str(total_coins)
	else:
		coin_label.text = ""

func update_level_progress(progress_text: String) -> void:
	if level_progress_label:
		level_progress_label.text = progress_text

func update_speed_display(current_speed: float, boost_count: int) -> void:
	if speed_label:
		speed_label.text = "Speed: %.0f (%dx)" % [current_speed, boost_count]

func update_exit_state(exit_active: bool, exit_node: Node) -> void:
	if exit_node == null:
		return
	var exit_body: ColorRect = exit_node.get_node("ExitBody") as ColorRect
	if exit_body == null:
		return
	if exit_active:
		exit_body.color = Color(0.2, 0.8, 0.2, 1)
	else:
		exit_body.color = Color(0.4, 0.4, 0.4, 1)

func clear_key_ui() -> void:
	key_checkbox_nodes.clear()
	key_colors.clear()
	if key_status_container:
		for child in key_status_container.get_children():
			var control_child: Control = child as Control
			if control_child and is_instance_valid(control_child):
				control_child.queue_free()
	if key_container:
		key_container.visible = false

func setup_key_ui(key_nodes: Array[Area2D]) -> void:
	clear_key_ui()
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
		checkbox.modulate = color
		key_status_container.add_child(checkbox)
		key_checkbox_nodes.append(checkbox)
	update_key_status_display(0)

func update_key_status_display(collected_keys: int) -> void:
	for index in range(key_checkbox_nodes.size()):
		var checkbox: CheckBox = key_checkbox_nodes[index]
		if checkbox == null or not is_instance_valid(checkbox):
			continue
		var is_collected: bool = index < collected_keys
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

func show_game_over_ui(restart_text: String) -> void:
	if game_over_label:
		game_over_label.visible = true
	if win_label:
		win_label.visible = false
	set_restart_button_text(restart_text)
	set_endgame_buttons_visible(true)

func show_win_ui(restart_text: String) -> void:
	if win_label:
		win_label.visible = true
	if game_over_label:
		game_over_label.visible = false
	set_restart_button_text(restart_text)
	set_endgame_buttons_visible(true)

func hide_endgame_ui() -> void:
	if game_over_label:
		game_over_label.visible = false
	if win_label:
		win_label.visible = false
	set_endgame_buttons_visible(false)

func set_endgame_buttons_visible(visible: bool) -> void:
	if restart_button:
		restart_button.visible = visible
	if menu_button:
		menu_button.visible = visible

func set_restart_button_text(text: String) -> void:
	if restart_button:
		restart_button.text = text
