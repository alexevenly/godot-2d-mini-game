extends RefCounted

class_name LevelObjectBinder

var main_node = null
var ui_controller = null

func setup(main_ref, ui_controller_ref) -> void:
	main_node = main_ref
	ui_controller = ui_controller_ref

func bind_from_generator(level_generator) -> Dictionary:
	var result := {
		"exit": null,
		"coins": [] as Array[Area2D],
		"keys": [] as Array[Area2D],
		"doors": [] as Array[StaticBody2D],
		"spawn_override": Vector2.ZERO,
		"has_spawn_override": false
	}
	if level_generator == null or not is_instance_valid(level_generator):
		return result
	var exit_node = level_generator.get_generated_exit()
	if exit_node and is_instance_valid(exit_node):
		_connect_exit(exit_node)
	result.exit = exit_node
	var coins: Array[Area2D] = level_generator.get_generated_coins() as Array[Area2D]
	_connect_coins(coins)
	result.coins = coins
	var doors: Array[StaticBody2D] = level_generator.get_generated_doors() as Array[StaticBody2D]
	_connect_doors(doors)
	result.doors = doors
	var keys: Array[Area2D] = level_generator.get_generated_keys() as Array[Area2D]
	_connect_keys(keys)
	result.keys = keys
	var spawn_override_variant: Variant = level_generator.get_player_spawn_override()
	var has_spawn_override: bool = typeof(spawn_override_variant) == TYPE_VECTOR2
	result.has_spawn_override = has_spawn_override
	if has_spawn_override:
		result.spawn_override = spawn_override_variant
	return result

func _connect_doors(doors: Array[StaticBody2D]) -> void:
	if main_node == null:
		return
	for door in doors:
		var door_body: StaticBody2D = door
		if door_body and is_instance_valid(door_body) and door_body.has_signal("door_opened"):
			var door_callable: Callable = Callable(main_node, "_on_door_opened")
			if not door_body.is_connected("door_opened", door_callable):
				door_body.connect("door_opened", door_callable)

func _connect_exit(exit_node: Node) -> void:
	if main_node == null or exit_node == null:
		return
	var exit_callable: Callable = Callable(main_node, "_on_exit_entered")
	if exit_node.has_signal("body_entered") and not exit_node.body_entered.is_connected(exit_callable):
		exit_node.body_entered.connect(exit_callable)

func _connect_coins(coins: Array[Area2D]) -> void:
	if main_node == null:
		return
	for coin in coins:
		var coin_area: Area2D = coin
		if coin_area and is_instance_valid(coin_area):
			var coin_callable: Callable = Callable(main_node, "_on_coin_collected").bind(coin_area)
			if coin_area.has_signal("body_entered") and not coin_area.body_entered.is_connected(coin_callable):
				coin_area.body_entered.connect(coin_callable)

func _connect_keys(keys: Array[Area2D]) -> void:
	if main_node == null:
		return
	for key in keys:
		var key_node: Area2D = key
		if key_node and is_instance_valid(key_node) and key_node.has_signal("key_collected"):
			var key_callable: Callable = Callable(main_node, "_on_key_collected")
			if not key_node.is_connected("key_collected", key_callable):
				key_node.connect("key_collected", key_callable)
