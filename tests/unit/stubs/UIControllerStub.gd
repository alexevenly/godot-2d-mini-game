class_name UIController
extends RefCounted

var last_coin_total := -1
var last_coin_collected := -1
var last_exit_active := false
var last_exit: Node = null
var last_keys := -1
var buttons_visible := false
var restart_text := ""
var level_progress := ""
var key_checkbox_nodes: Array = []

func setup(_main, _timer_label, _coin_label, _level_label, _game_over, _win_label, _restart, _menu, _key_container, _key_status) -> void:
	pass

func update_coin_display(total: int, collected: int) -> void:
	last_coin_total = total
	last_coin_collected = collected

func update_exit_state(active: bool, exit_node: Node) -> void:
	last_exit_active = active
	last_exit = exit_node

func setup_key_ui(_keys: Array[Area2D]) -> void:
	pass

func update_key_status_display(collected: int) -> void:
	last_keys = collected

func show_game_over_ui(text: String) -> void:
	buttons_visible = true
	restart_text = text

func show_win_ui(text: String) -> void:
	buttons_visible = true
	restart_text = text

func hide_endgame_ui() -> void:
	buttons_visible = false

func set_restart_button_text(text: String) -> void:
	restart_text = text

func set_endgame_buttons_visible(visible: bool) -> void:
	buttons_visible = visible

func update_level_progress(text: String) -> void:
	level_progress = text

func clear_key_ui() -> void:
	key_checkbox_nodes.clear()
