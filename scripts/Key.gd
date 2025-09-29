extends Area2D

signal key_collected(door_id: int)

@export var door_path: NodePath
@export var door_id: int = 0
@export var required_key_count: int = 1

var door_reference: Node = null

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body == null:
		return
	if not body.is_class("CharacterBody2D"):
		return
	if body.name != "Player":
		return
	var door = _get_door()
	if door:
		door.register_key()
	emit_signal("key_collected", door_id)
	queue_free()

func _get_door():
	if door_reference and is_instance_valid(door_reference):
		return door_reference
	if door_path.is_empty():
		return null
	return get_node_or_null(door_path)
