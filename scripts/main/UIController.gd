class_name UIController
extends RefCounted

const KEY_UI_MANAGER := preload("res://scripts/main/ui/KeyUIManager.gd")

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
var door_container: Control = null
var door_status_container: Control = null
var _key_ui_manager
var path_indicator_label: Label = null

var key_checkbox_nodes: Array[Button]:
	get:
		return _key_ui_manager.key_checkbox_nodes if _key_ui_manager else [] as Array[Button]

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
	door_container_ref: Control,
	door_status_container_ref: Control,
	speed_label_ref: Label = null,
	path_indicator_ref: Label = null
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
	door_container = door_container_ref
	door_status_container = door_status_container_ref
	speed_label = speed_label_ref
	path_indicator_label = path_indicator_ref
	if _key_ui_manager == null:
		_key_ui_manager = KEY_UI_MANAGER.new()
	_key_ui_manager.setup_containers(key_container, key_status_container, door_container, door_status_container)

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
	if _key_ui_manager:
		_key_ui_manager.clear()

func setup_key_ui(key_nodes: Array[Area2D]) -> void:
	if _key_ui_manager == null:
		return
	_key_ui_manager.build_from_keys(key_nodes)

func setup_door_ui(door_nodes: Array) -> void:
	if _key_ui_manager == null:
		return
	_key_ui_manager.build_from_doors(door_nodes)

func update_key_status_display(collected_keys: int) -> void:
	if _key_ui_manager:
		_key_ui_manager.update_key_status_display(collected_keys)

func mark_key_collected(door_id: int) -> void:
	if _key_ui_manager:
		_key_ui_manager.mark_key_collected(door_id)

func mark_door_opened(door_id: int, door_color: Color) -> void:
	if _key_ui_manager:
		_key_ui_manager.mark_door_opened(door_id, door_color)

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

func update_path_indicator(is_multi_path: bool) -> void:
	if path_indicator_label:
		if is_multi_path:
			path_indicator_label.text = "MULTI-PATH MAZE"
			path_indicator_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2)) # Green
		else:
			path_indicator_label.text = "SINGLE-PATH MAZE"
			path_indicator_label.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2)) # Red
		path_indicator_label.visible = true

func hide_path_indicator() -> void:
	if path_indicator_label:
		path_indicator_label.visible = false
